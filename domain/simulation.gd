extends RefCounted
## Autoridad única del estado. No depende del árbol ni de la interfaz.

signal state_updated(snapshot: Dictionary)
signal run_finished(result: Dictionary)

const Config = preload("res://domain/simulation_config.gd")
const SPECIALISTS := ["engineer", "medic", "botanist", "scientist", "geologist", "technician"]
const POWER_ORDER := ["habitat", "oxygen_generator", "greenhouse", "laboratory", "solar", "reactor"]

var _config: Dictionary = {}
var _state: Dictionary = {}
var _accumulator: float = 0.0
var _publishing: bool = false
var _finished_emitted: bool = false

func configure(data: Dictionary) -> Dictionary:
	if _publishing or not _state.is_empty():
		return _reply(false, "already_initialized")
	var checked := Config.validate(data)
	if not checked.ok:
		return _reply(false, checked.error_code)
	_config = checked.data
	return _reply(true)

func reset_run(crew_ids: Array, run_seed: int = 1) -> Dictionary:
	if _publishing:
		return _reply(false, "busy")
	if _config.is_empty():
		return _reply(false, "not_configured")
	if crew_ids.size() != 4:
		return _reply(false, "select_four")
	var crew: Array = []
	var seen: Array = []
	for id: Variant in crew_ids:
		if not id is String or id not in SPECIALISTS or id in seen:
			return _reply(false, "invalid_crew")
		seen.append(id)
		crew.append({"id": id, "health": 100.0, "alive": true})
	_state = {"schema_version": 1, "seed": run_seed, "phase": "planning", "elapsed_seconds": 0,
		"sol": 1, "completed_sols": 0, "paused": false, "speed": 1.0, "crew": crew,
		"resources": _config.initial.duplicate(true), "buildings": [], "power": {},
		"deficits": {"air": 0.0, "water": 0.0, "food": 0.0}, "log": [], "result": {}}
	_accumulator = 0.0
	_finished_emitted = false
	_state.buildings.append(_building("b1", "habitat", Vector2i(2, 2), 0))
	_resolve_power()
	_publish()
	return _reply(true)

func get_snapshot() -> Dictionary:
	return _state.duplicate(true)

func get_catalog() -> Dictionary:
	return _config.duplicate(true)

func start_run() -> Dictionary:
	if _publishing or _state.get("phase") != "planning":
		return _reply(false, "invalid_phase")
	_state.phase = "running"
	_record("run_started", "", {})
	_publish()
	return _reply(true)

func preview_placement(kind: String, cell: Vector2i) -> Dictionary:
	if _state.is_empty() or _state.phase == "finished":
		return _reply(false, "invalid_phase")
	if kind == "habitat" or not _config.buildings.has(kind):
		return _reply(false, "invalid_building")
	if cell.x < 0 or cell.y < 0 or cell.x >= _config.grid_size or cell.y >= _config.grid_size:
		return _reply(false, "outside_grid")
	for building: Dictionary in _state.buildings:
		if building.x == cell.x and building.y == cell.y:
			return _reply(false, "occupied_cell")
	if kind == "reactor" and absi(cell.x - 2) + absi(cell.y - 2) < 2:
		return _reply(false, "reactor_too_close")
	var cost := {"mass": float(_config.buildings[kind].mass)}
	if _state.resources.mass < cost.mass:
		return _reply(false, "insufficient_mass", cost)
	return _reply(true, "", cost, {"duration_seconds": int(_config.buildings[kind].build_seconds)})

func place_building(kind: String, cell: Vector2i) -> Dictionary:
	if _publishing:
		return _reply(false, "busy")
	var check := preview_placement(kind, cell)
	if not check.ok:
		return check
	var id := "b%d" % (_state.buildings.size() + 1)
	_state.resources.mass -= check.cost.mass
	_state.buildings.append(_building(id, kind, cell, check.result.duration_seconds))
	_record("construction_paid", id, {"cost": check.cost.duplicate(true), "kind": kind})
	_resolve_power()
	_publish()
	return _reply(true, "", check.cost, {"building_id": id})

func set_enabled(building_id: String, enabled: bool) -> Dictionary:
	if _publishing or _state.is_empty() or _state.phase == "finished":
		return _reply(false, "invalid_phase")
	for building: Dictionary in _state.buildings:
		if building.id == building_id:
			if building.kind == "habitat":
				return _reply(false, "habitat_required")
			if building.enabled != enabled:
				building.enabled = enabled
				_record("building_enabled", building_id, {"enabled": enabled})
				_resolve_power()
				_publish()
			return _reply(true)
	return _reply(false, "unknown_building")

func set_paused(paused: bool) -> Dictionary:
	if _publishing or _state.get("phase") != "running":
		return _reply(false, "invalid_phase")
	_state.paused = paused
	_publish()
	return _reply(true)

func set_speed(speed: float) -> Dictionary:
	if _publishing or _state.is_empty() or _state.phase == "finished" or speed not in [0.5, 1.0, 2.0, 4.0]:
		return _reply(false, "invalid_speed")
	_state.speed = speed
	_publish()
	return _reply(true)

func advance(real_seconds: float) -> Dictionary:
	if _publishing or not is_finite(real_seconds) or real_seconds < 0.0:
		return _reply(false, "invalid_delta")
	if _state.is_empty():
		return _reply(false, "not_initialized")
	if _state.phase != "running" or _state.paused:
		return _reply(true)
	# Solo procesamos segundos lógicos completos; un frame puede cruzar varios soles.
	var remaining := float(_config.sol_seconds * _config.target_sols - _state.elapsed_seconds)
	_accumulator += minf(real_seconds * _state.speed, remaining)
	while _accumulator + 0.000000001 >= 1.0 and _state.phase == "running":
		_accumulator = maxf(0.0, _accumulator - 1.0)
		_tick()
	_publish()
	return _reply(true)

func _tick() -> void:
	_state.elapsed_seconds += 1
	_resolve_power()
	var seconds_per_sol := float(_config.sol_seconds)
	for building: Dictionary in _state.buildings:
		if not building.powered:
			continue
		var definition: Dictionary = _config.buildings[building.kind]
		var water := float(definition.water_per_sol) / seconds_per_sol
		if _state.resources.water + 0.000000001 < water:
			building.warning = "water_shortage"
			_record("production_blocked_water", building.id, {"required": water})
			continue
		_state.resources.water = maxf(0.0, _state.resources.water - water)
		var bonus := float(_config.botanist_multiplier) if building.kind == "greenhouse" and _has_alive("botanist") else 1.0
		_state.resources.air += float(definition.air_per_sol) * bonus / seconds_per_sol
		_state.resources.food += float(definition.food_per_sol) * bonus / seconds_per_sol
	var alive := _alive_count()
	var damage := 0.0
	for resource: String in ["air", "water", "food"]:
		var need := float(_config.consumption_per_crew_per_sol[resource]) * alive / seconds_per_sol
		var missing := maxf(0.0, need - float(_state.resources[resource]))
		_state.resources[resource] = maxf(0.0, float(_state.resources[resource]) - need)
		if missing > 0.000000001:
			_state.deficits[resource] += missing
			damage += missing * float(_config.health_loss_per_missing_unit) / maxi(alive, 1)
			_record("crew_deficit", resource, {"missing": missing})
	for member: Dictionary in _state.crew:
		if member.alive:
			member.health = maxf(0.0, member.health - damage)
			if member.health <= 0.000000001:
				member.health = 0.0
				member.alive = false
				_record("crew_died", member.id, {"reason": "resource_deficit"})
	# La construcción termina después de la economía; produce desde el siguiente tick.
	for building: Dictionary in _state.buildings:
		if building.remaining_seconds > 0:
			building.remaining_seconds -= 1
			if building.remaining_seconds == 0:
				_record("construction_completed", building.id, {})
	_state.completed_sols = int(_state.elapsed_seconds / int(_config.sol_seconds))
	_state.sol = mini(_state.completed_sols + 1, int(_config.target_sols))
	_resolve_power()
	if _alive_count() == 0:
		_finish("total_defeat")
	elif _state.elapsed_seconds >= _config.sol_seconds * _config.target_sols:
		var supported: bool = _state.buildings[0].powered and _state.resources.air > 0.000000001
		_finish("relief_achieved" if supported else "partial_defeat")

func _resolve_power() -> void:
	var supply := 0.0
	var demand := 0.0
	for building: Dictionary in _state.buildings:
		building.powered = false
		building.warning = ""
		if building.remaining_seconds > 0 or not building.enabled:
			continue
		var definition: Dictionary = _config.buildings[building.kind]
		var bonus := float(_config.engineer_multiplier) if _has_alive("engineer") else 1.0
		supply += float(definition.power_supply) * bonus
	var available := supply
	for kind: String in POWER_ORDER:
		for building: Dictionary in _state.buildings:
			if building.kind != kind or building.remaining_seconds > 0 or not building.enabled:
				continue
			var needed := float(_config.buildings[kind].power_demand)
			if kind == "oxygen_generator" and _has_alive("technician"):
				needed *= float(_config.technician_multiplier)
			demand += needed
			if needed <= available + 0.000000001:
				available = maxf(0.0, available - needed)
				building.powered = true
			else:
				building.warning = "power_shortage"
			if building.powered and float(_config.buildings[kind].water_per_sol) / float(_config.sol_seconds) > float(_state.resources.water) + 0.000000001:
				building.warning = "water_shortage"
	_state.power = {"supply": supply, "demand": demand, "used": supply - available, "spare": available}

func _has_alive(id: String) -> bool:
	for member: Dictionary in _state.crew:
		if member.id == id and member.alive:
			return true
	return false

func _alive_count() -> int:
	var count := 0
	for member: Dictionary in _state.crew:
		if member.alive:
			count += 1
	return count

func _building(id: String, kind: String, cell: Vector2i, duration: int) -> Dictionary:
	return {"id": id, "kind": kind, "x": cell.x, "y": cell.y, "level": 1,
		"enabled": true, "powered": false, "remaining_seconds": duration, "warning": ""}

func _record(reason: String, target: String, details: Dictionary) -> void:
	_state.log.append({"id": "d%d" % (_state.log.size() + 1), "seconds": _state.elapsed_seconds,
		"reason": reason, "target": target, "details": details.duplicate(true)})

func _finish(verdict: String) -> void:
	_state.phase = "finished"
	_accumulator = 0.0
	_state.result = {"verdict": verdict, "elapsed_seconds": _state.elapsed_seconds, "alive": _alive_count()}
	_record("run_finished", "", _state.result)

func _publish() -> void:
	# Evita que un consumidor reentre y cambie el dominio en mitad de una notificación.
	_publishing = true
	state_updated.emit(get_snapshot())
	if _state.phase == "finished" and not _finished_emitted:
		_finished_emitted = true
		run_finished.emit(_state.result.duplicate(true))
	_publishing = false

func _reply(ok: bool, code: String = "", cost: Dictionary = {}, result: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "error_code": code, "cost": cost.duplicate(true), "result": result.duplicate(true)}
