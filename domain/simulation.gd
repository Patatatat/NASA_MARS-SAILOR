extends RefCounted
## Autoridad única del estado. No depende del árbol ni de la interfaz.

signal state_updated(snapshot: Dictionary)
signal run_finished(result: Dictionary)
signal event_changed(event: Dictionary)
signal robert_changed(robert: Dictionary)
signal maintenance_changed(change: Dictionary)
signal sol_report_ready(report: Dictionary)

const Config = preload("res://domain/simulation_config.gd")
const Maintenance = preload("res://domain/maintenance_system.gd")
const SolReport = preload("res://domain/sol_report.gd")
const SurvivalDirector = preload("res://domain/survival_director.gd")
const RunSummary = preload("res://domain/run_summary.gd")
const SPECIALISTS := ["engineer", "medic", "botanist", "scientist", "geologist", "technician"]
const POWER_ORDER := ["habitat", "oxygen_generator", "greenhouse", "laboratory", "solar", "reactor"]
const BUILDING_FOOTPRINTS := {
	"habitat": 3,
	"solar": 3,
	"reactor": 4,
	"oxygen_generator": 2,
	"greenhouse": 3,
	"laboratory": 2
}

var _config: Dictionary = {}
var _state: Dictionary = {}
var _accumulator: float = 0.0
var _publishing: bool = false
var _finished_emitted: bool = false
var _event_rng: RandomNumberGenerator
var _mission_rng: RandomNumberGenerator
var _map_rng: RandomNumberGenerator
var _event_plan: Array[Dictionary] = []
var _notifications: Array[Dictionary] = []
var _maintenance := Maintenance.new()
var _run_generation: int = 0
var _director := SurvivalDirector.new()

func _init(event_rng: RandomNumberGenerator = null, mission_rng: RandomNumberGenerator = null) -> void:
	_event_rng = event_rng if event_rng != null else RandomNumberGenerator.new()
	_mission_rng = mission_rng if mission_rng != null else RandomNumberGenerator.new()
	_map_rng = RandomNumberGenerator.new()

func configure(data: Dictionary) -> Dictionary:
	if _publishing or not _state.is_empty():
		return _reply(false, "already_initialized")
	var checked := Config.validate(data)
	if not checked.ok:
		return _reply(false, checked.error_code)
	_config = checked.data
	return _reply(true)

func reset_run(crew_ids: Array, run_seed: int = 1, scenario_id: String = "frontier") -> Dictionary:
	if _publishing:
		return _reply(false, "busy")
	if _config.is_empty():
		return _reply(false, "not_configured")
	if not _config.scenarios.has(scenario_id):
		return _reply(false, "invalid_scenario")
	if crew_ids.size() != 4:
		return _reply(false, "select_four")
	var crew: Array = []
	var seen: Array = []
	for id: Variant in crew_ids:
		if not id is String or id not in SPECIALISTS or id in seen:
			return _reply(false, "invalid_crew")
		seen.append(id)
		crew.append({"id": id, "health": 100.0, "alive": true, "dose": 0.0, "dose_avoided": 0.0})
	_event_rng.seed = run_seed
	_mission_rng.seed = run_seed ^ 0x524F4245
	_map_rng.seed = run_seed ^ 0x4D415000
	var generated_map := _generate_map()
	_state = {"schema_version": 1, "seed": run_seed, "phase": "planning", "elapsed_seconds": 0,
		"sol": 1, "completed_sols": 0, "paused": false, "speed": 1.0, "crew": crew,
		"resources": _config.initial.duplicate(true), "buildings": [], "power": {},
		"map": generated_map, "deficits": {"air": 0.0, "food": 0.0}, "log": [], "result": {}}
	_state.scenario = scenario_id
	var scenario: Dictionary = _config.scenarios[scenario_id]
	if scenario_id != "frontier":
		_state.resources.energy = minf(_state.resources.energy, scenario.energy_limit)
		_state.resources.food = minf(_state.resources.food, scenario.food_limit)
	_state.event = {}
	_state.sheltered = false
	_state.burial = {"state": "surface", "remaining_seconds": 0}
	_state.roberts = []
	_state.mission_count = 0
	_state.metrics = {"solar_output_lost_power_seconds": 0.0}
	_state.metrics.scientist_extra_upgrade_work = 0.0
	_run_generation += 1
	_state.run_generation = _run_generation
	_state.sol_reports = []
	_state.current_sol_report = SolReport.open(_state)
	RunSummary.initialize(_state)
	_maintenance.reset(_state, _config, _run_generation)
	for id: String in ["robert_1", "robert_2"]:
		_state.roberts.append({"id": id, "state": "available", "mission_id": "", "destination": "", "return_seconds": 0, "storm_exposed": false})
	_event_plan.clear()
	_notifications.clear()
	for kind: String in ["storm", "solar_particles"]:
		var definition: Dictionary = _config.events[kind].duplicate(true)
		if kind == "storm" and scenario_id != "frontier":
			definition.start_sols_min = scenario.storm_min
			definition.start_sols_max = scenario.storm_max
			definition.probability = scenario.storm_probability
		var start_sol := _event_rng.randi_range(int(definition.start_sols_min), int(definition.start_sols_max))
		_event_plan.append({"kind": kind, "occurs": _roll(_event_rng, float(definition.probability)),
			"probability": definition.probability, "start_seconds": (start_sol - 1) * int(_config.sol_seconds),
			"duration_seconds": int(definition.duration_sols) * int(_config.sol_seconds), "state": "pending"})
	_state.forecast = _build_forecast()
	_accumulator = 0.0
	_finished_emitted = false
	var habitat_center := int((_config.grid_size - 1) / 2)
	_state.buildings.append(_building("b1", "habitat", Vector2i(habitat_center, habitat_center), 0))
	if scenario.damaged_greenhouse:
		var greenhouse := _building("b2", "greenhouse", Vector2i(10, 15), 0)
		greenhouse.crop_health = 45.0
		_state.buildings.append(greenhouse)
	_director.reset(_state, _config)
	_resolve_power()
	RunSummary.sample(_state, _config)
	_publish()
	return _reply(true)

func get_snapshot() -> Dictionary:
	return _state.duplicate(true)

func _generate_map() -> Dictionary:
	var configured_sizes: Array = _config.map_sizes
	var size := int(configured_sizes[_map_rng.randi_range(0, configured_sizes.size() - 1)])
	var shape := "irregular" if _map_rng.randf() < 0.5 else "square"
	var blocked: Array[int] = []
	var outside: Array[int] = []
	var obstacles: Array[int] = []
	var center := float(_config.grid_size - 1) * 0.5
	var half := float(size) * 0.5
	for y: int in range(int(_config.grid_size)):
		for x: int in range(int(_config.grid_size)):
			var dx := absf(float(x) - center)
			var dy := absf(float(y) - center)
			var inside := dx < half and dy < half
			if inside and shape == "irregular" and maxf(dx, dy) > 3.0:
				var edge_wave := sin(float(x) * 0.53) * 0.8 + cos(float(y) * 0.41) * 0.6
				inside = maxf(dx, dy) < half - 1.5 + edge_wave
			var protected_hub := dx <= 6.0 and dy <= 6.0
			if not inside:
				outside.append(y * int(_config.grid_size) + x)
			if inside and not protected_hub and _map_rng.randf() < float(_config.map_obstacle_ratio):
				inside = false
				obstacles.append(y * int(_config.grid_size) + x)
			if not inside:
				blocked.append(y * int(_config.grid_size) + x)
	return {"size": size, "shape": shape, "blocked_cells": blocked, "outside_cells": outside, "obstacle_cells": obstacles}

func _cell_is_blocked(cell: Vector2i) -> bool:
	return int(cell.y * int(_config.grid_size) + cell.x) in _state.map.blocked_cells

func get_catalog() -> Dictionary:
	return _config.duplicate(true)

func get_run_summary() -> Dictionary:
	if _state.is_empty():
		return _reply(false, "not_initialized")
	if _state.phase != "finished":
		return _reply(false, "not_finished")
	return _reply(true, "", {}, _state.run_summary)

func begin_maintenance(building_id: String) -> Dictionary:
	return _maintenance_command("begin", [building_id])

func apply_maintenance_result(session_id: String, success: bool, elapsed_seconds: float, abandoned: bool = false) -> Dictionary:
	return _maintenance_command("apply_result", [session_id, success, elapsed_seconds, abandoned])

func reactivate_building(building_id: String) -> Dictionary:
	return _maintenance_command("reactivate", [building_id])

func _maintenance_command(method: String, args: Array) -> Dictionary:
	if _publishing or _state.get("phase") != "running":
		return _reply(false, "invalid_phase")
	var result: Dictionary = _maintenance.callv(method, args)
	if result.ok:
		_drain_maintenance()
		_resolve_power()
		_publish()
	return result

func _drain_maintenance() -> void:
	for change: Dictionary in _maintenance.drain_changes():
		var details: Dictionary = change.details.duplicate(true)
		details.request_id = change.maintenance.request_id
		details.session = change.maintenance.session.duplicate(true)
		_record(change.reason, change.target, details)
		_queue("maintenance", change)

func get_building_status(building_id: String) -> Dictionary:
	var building := _find_building(building_id)
	if building.is_empty():
		return _reply(false, "unknown_building")
	var status: Dictionary = building.duplicate(true)
	status.definition = _definition(building).duplicate(true)
	status.output_multiplier = _maintenance.multiplier(building) * _director.multiplier(building)
	status.active_event = _state.event.duplicate(true)
	var bonus := float(_config.botanist_multiplier) if building.kind == "greenhouse" and _has_alive("botanist") else 1.0
	var operating: bool = building.powered
	status.effective_production_per_sol = {
		"air": float(status.definition.air_per_sol) * bonus * status.output_multiplier if operating else 0.0,
		"food": float(status.definition.food_per_sol) * bonus * status.output_multiplier if operating else 0.0}
	status.local_log = []
	for entry: Dictionary in _state.log:
		if entry.target == building_id:
			status.local_log.append(entry.duplicate(true))
	status.blocked_this_sol = _state.current_sol_report.blocked_seconds.get(building_id, {}).duplicate(true)
	return _reply(true, "", {}, status)

func get_forecast() -> Dictionary:
	# La previsión usa ventanas sorteadas con la semilla, pero nunca revela si el evento ocurrirá.
	if not _state.is_empty() and _state.has("forecast"):
		return _state.forecast.duplicate(true)
	return _config.get("events", {}).duplicate(true)

func _build_forecast() -> Dictionary:
	var forecast: Dictionary = _config.events.duplicate(true)
	for planned: Dictionary in _event_plan:
		var event: Dictionary = forecast[planned.kind]
		event.probability = planned.probability
		event.start_seconds = planned.start_seconds
		event.duration_seconds = planned.duration_seconds
		event.start_sol = int(planned.start_seconds / int(_config.sol_seconds)) + 1
	return forecast

func set_sheltered(enabled: bool) -> Dictionary:
	if _publishing or _state.get("phase") != "running":
		return _reply(false, "invalid_phase")
	if _state.sheltered != enabled:
		_state.sheltered = enabled
		_record("shelter_changed", "crew", {"enabled": enabled})
		_maintenance.sync_sessions()
		_drain_maintenance()
		_publish()
	return _reply(true)

func bury_habitat() -> Dictionary:
	if _publishing or _state.get("phase") != "running":
		return _reply(false, "invalid_phase")
	if _state.burial.state != "surface":
		return _reply(false, "burial_already_started")
	var cost := {"regolith": float(_config.radiation.bury_regolith)}
	if _state.resources.regolith < cost.regolith:
		return _reply(false, "insufficient_resources", cost)
	_state.resources.regolith -= cost.regolith
	_state.burial = {"state": "building", "remaining_seconds": int(_config.radiation.bury_seconds)}
	_record("burial_paid", "b1", {"cost": cost})
	_publish()
	return _reply(true, "", cost)

func preview_robert(robert_id: String, destination_id: String) -> Dictionary:
	if _state.get("phase") != "running":
		return _reply(false, "invalid_phase")
	var robot := _find_robert(robert_id)
	if robot.is_empty():
		return _reply(false, "unknown_robert")
	if robot.state != "available":
		return _reply(false, "robert_unavailable")
	if not _config.roberts.destinations.has(destination_id):
		return _reply(false, "unknown_destination")
	if _state.sheltered:
		return _reply(false, "crew_sheltered")
	var laboratory_ready := false
	for building: Dictionary in _state.buildings:
		if building.kind == "laboratory" and building.powered:
			laboratory_ready = true
	if not laboratory_ready:
		return _reply(false, "laboratory_not_operational")
	var cost := {"power_demand": float(_config.roberts.power_demand)}
	if _state.power.spare + 0.000000001 < cost.power_demand:
		return _reply(false, "insufficient_power", cost)
	var destination: Dictionary = _config.roberts.destinations[destination_id]
	return _reply(true, "", cost, {"duration_seconds": int(_config.roberts.duration_sols * _config.sol_seconds),
		"resource": destination.resource, "amount": _mission_yield(destination),
		"loss_probability": _mission_risk(destination, _active("storm")), "risk_may_increase_in_storm": true})

func send_robert(robert_id: String, destination_id: String) -> Dictionary:
	if _publishing:
		return _reply(false, "busy")
	var checked := preview_robert(robert_id, destination_id)
	if not checked.ok:
		return checked
	var robot := _find_robert(robert_id)
	_state.mission_count += 1
	robot.state = "on_mission"
	robot.mission_id = "m%d" % _state.mission_count
	robot.destination = destination_id
	robot.return_seconds = _state.elapsed_seconds + checked.result.duration_seconds
	robot.storm_exposed = _active("storm")
	_record("robert_dispatched", robot.id, {"mission_id": robot.mission_id, "destination": destination_id, "cost": checked.cost, "return_seconds": robot.return_seconds})
	_queue("robert", robot)
	_resolve_power()
	_publish()
	return _reply(true, "", checked.cost, {"mission_id": robot.mission_id, "return_seconds": robot.return_seconds})

func get_building_footprint_size(kind: String) -> int:
	return int(BUILDING_FOOTPRINTS.get(kind, 0))

func get_building_footprint_cells(kind: String, anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var size := get_building_footprint_size(kind)
	if size <= 0:
		return cells
	# Para medidas pares, el ancla es la celda superior izquierda de las dos centrales.
	# El espacio adicional queda hacia +X/+Y para que la regla sea estable en toda la malla.
	var first_offset := -floori(float(size - 1) / 2.0)
	for y: int in range(first_offset, first_offset + size):
		for x: int in range(first_offset, first_offset + size):
			cells.append(anchor + Vector2i(x, y))
	return cells

func start_run() -> Dictionary:
	if _publishing or _state.get("phase") != "planning":
		return _reply(false, "invalid_phase")
	_state.phase = "running"
	_record("run_started", "", {})
	_publish()
	return _reply(true)

func preview_upgrade(building_id: String) -> Dictionary:
	if _state.get("phase") != "running":
		return _reply(false, "invalid_phase")
	var building := _find_building(building_id)
	if building.is_empty():
		return _reply(false, "unknown_building")
	if not _config.upgrades.has(building.kind):
		return _reply(false, "upgrade_not_supported")
	if building.remaining_seconds > 0:
		return _reply(false, "building_under_construction")
	if building.level >= 2:
		return _reply(false, "max_level")
	if building.upgrade_remaining_work > 0:
		return _reply(false, "upgrade_in_progress")
	if _state.sheltered:
		return _reply(false, "crew_sheltered")
	var upgrade: Dictionary = _config.upgrades[building.kind]
	var cost := {"regolith": float(upgrade.regolith)}
	if _state.resources.regolith < cost.regolith:
		return _reply(false, "insufficient_regolith", cost)
	return _reply(true, "", cost, {"target_level": 2,
		"duration_seconds": ceili(float(upgrade.duration_seconds) / _upgrade_work_rate()),
		"base_duration_seconds": int(upgrade.duration_seconds),
		"current": _definition(building).duplicate(true), "next": upgrade.duplicate(true)})

func start_upgrade(building_id: String) -> Dictionary:
	if _publishing:
		return _reply(false, "busy")
	var checked := preview_upgrade(building_id)
	if not checked.ok:
		return checked
	var building := _find_building(building_id)
	_state.resources.regolith -= checked.cost.regolith
	building.upgrade_remaining_work = float(checked.result.base_duration_seconds)
	building.upgrade_total_work = building.upgrade_remaining_work
	_record("upgrade_paid", building_id, {"cost": checked.cost, "target_level": 2,
		"base_duration_seconds": checked.result.base_duration_seconds})
	_publish()
	return checked

func _find_building(id: String) -> Dictionary:
	for building: Dictionary in _state.buildings:
		if building.id == id:
			return building
	return {}

func _definition(building: Dictionary) -> Dictionary:
	return _config.upgrades[building.kind] if building.level == 2 else _config.buildings[building.kind]

func _upgrade_work_rate() -> float:
	return 1.0 / float(_config.scientist_upgrade_duration_multiplier) if _has_alive("scientist") else 1.0

func _advance_upgrades() -> void:
	if _state.sheltered:
		return
	for building: Dictionary in _state.buildings:
		if building.upgrade_remaining_work <= 0:
			continue
		var work := minf(building.upgrade_remaining_work, _upgrade_work_rate())
		_state.metrics.scientist_extra_upgrade_work += maxf(0.0, work - 1.0)
		building.upgrade_remaining_work = maxf(0.0, building.upgrade_remaining_work - work)
		if building.upgrade_remaining_work < 0.000000001:
			building.upgrade_remaining_work = 0.0
			building.level = 2
			_record("upgrade_completed", building.id, {"level": 2})

func preview_placement(kind: String, cell: Vector2i) -> Dictionary:
	if _state.is_empty() or _state.phase == "finished":
		return _reply(false, "invalid_phase")
	if kind == "habitat" or not _config.buildings.has(kind):
		return _reply(false, "invalid_building")
	if cell.x < 0 or cell.y < 0 or cell.x >= _config.grid_size or cell.y >= _config.grid_size:
		return _reply(false, "outside_grid")
	if kind == "reactor":
		var habitat: Dictionary = _state.buildings[0]
		if absi(cell.x - int(habitat.x)) + absi(cell.y - int(habitat.y)) < 2:
			return _reply(false, "reactor_too_close")
	var proposed_cells := get_building_footprint_cells(kind, cell)
	for proposed_cell: Vector2i in proposed_cells:
		if proposed_cell.x < 0 or proposed_cell.y < 0 or proposed_cell.x >= _config.grid_size or proposed_cell.y >= _config.grid_size:
			return _reply(false, "footprint_outside_grid")
		if _cell_is_blocked(proposed_cell):
			return _reply(false, "terrain_blocked", {}, {"cell": {"x": proposed_cell.x, "y": proposed_cell.y}})
	var occupied_cells: Dictionary = {}
	for building: Dictionary in _state.buildings:
		var existing_anchor := Vector2i(int(building.x), int(building.y))
		for occupied_cell: Vector2i in get_building_footprint_cells(str(building.kind), existing_anchor):
			occupied_cells[occupied_cell] = building.id
	for proposed_cell: Vector2i in proposed_cells:
		if occupied_cells.has(proposed_cell):
			return _reply(false, "occupied_footprint", {}, {
				"blocking_building": occupied_cells[proposed_cell],
				"cell": {"x": proposed_cell.x, "y": proposed_cell.y}
			})
	var cost := {"regolith": float(_config.buildings[kind].regolith)}
	if _state.resources.regolith < cost.regolith:
		return _reply(false, "insufficient_regolith", cost)
	return _reply(true, "", cost, {"duration_seconds": int(_config.buildings[kind].build_seconds)})

func place_building(kind: String, cell: Vector2i) -> Dictionary:
	if _publishing:
		return _reply(false, "busy")
	var check := preview_placement(kind, cell)
	if not check.ok:
		return check
	var id := "b%d" % (_state.buildings.size() + 1)
	_state.resources.regolith -= check.cost.regolith
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
	var sim_left := minf(real_seconds * _state.speed, maxf(0.0, remaining - _accumulator))
	while sim_left > 0.000000001 and _state.phase == "running":
		var step := minf(sim_left, 1.0 - _accumulator)
		_maintenance.advance_real(step / float(_state.speed))
		_accumulator += step
		sim_left = maxf(0.0, sim_left - step)
		if _accumulator + 0.000000001 >= 1.0:
			_accumulator = 0.0
			_tick()
	_drain_maintenance()
	_publish()
	return _reply(true)

func _tick() -> void:
	_state.elapsed_seconds += 1
	_update_events()
	_director.before_step()
	_drain_survival()
	_maintenance.tick()
	_drain_maintenance()
	_resolve_power()
	if _active("storm") and _is_day():
		var loss := 0.0
		for building: Dictionary in _state.buildings:
			if building.kind == "solar" and building.enabled and building.remaining_seconds == 0:
				var bonus := float(_config.engineer_multiplier) if _has_alive("engineer") else 1.0
				loss += float(_definition(building).power_supply) * bonus * (1.0 - float(_config.events.storm.solar_multiplier))
		_state.metrics.solar_output_lost_power_seconds += loss
	_settle_energy()
	var seconds_per_sol := float(_config.sol_seconds)
	for building: Dictionary in _state.buildings:
		if not building.powered:
			var reason := "power_shortage"
			if building.remaining_seconds > 0:
				reason = "under_construction"
			elif not building.enabled:
				reason = "disabled"
			elif building.maintenance.state == "shutdown":
				reason = "maintenance_shutdown"
			elif building.covered:
				reason = "storm_cover"
			elif building.night_cut:
				reason = "night_cut"
			elif building.repair_remaining > 0:
				reason = "repair"
			SolReport.blocked(_state.current_sol_report, building.id, reason)
			continue
		var definition: Dictionary = _definition(building)
		var bonus := float(_config.botanist_multiplier) if building.kind == "greenhouse" and _has_alive("botanist") else 1.0
		var air := float(definition.air_per_sol) * bonus * _maintenance.multiplier(building) * _director.multiplier(building) / seconds_per_sol
		var food := float(definition.food_per_sol) * bonus * _maintenance.multiplier(building) * _director.multiplier(building) / seconds_per_sol
		_state.resources.air += air
		_state.resources.food += food
		SolReport.add(_state.current_sol_report, "production", "air", air)
		SolReport.add(_state.current_sol_report, "production", "food", food)
	var alive := _alive_count()
	var damage := 0.0
	for resource: String in ["air", "food"]:
		var need := float(_config.consumption_per_crew_per_sol[resource]) * alive / seconds_per_sol
		var missing := maxf(0.0, need - float(_state.resources[resource]))
		SolReport.add(_state.current_sol_report, "requested_consumption", resource, need)
		SolReport.add(_state.current_sol_report, "consumption", resource, need - missing)
		SolReport.add(_state.current_sol_report, "deficits", resource, missing)
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
	_director.after_step()
	_drain_survival()
	_apply_radiation()
	# La construcción termina después de la economía; produce desde el siguiente tick.
	for building: Dictionary in _state.buildings:
		if building.remaining_seconds > 0 and not _state.sheltered:
			building.remaining_seconds -= 1
			if building.remaining_seconds == 0:
				_record("construction_completed", building.id, {})
	_advance_upgrades()
	if _state.burial.state == "building" and not _state.sheltered:
		_state.burial.remaining_seconds -= 1
		if _state.burial.remaining_seconds == 0:
			_state.burial.state = "buried"
			_record("habitat_buried", "b1", {})
	_update_roberts()
	var sol_ended: bool = _state.elapsed_seconds % int(_config.sol_seconds) == 0
	_state.completed_sols = int(_state.elapsed_seconds / int(_config.sol_seconds))
	_state.sol = mini(_state.completed_sols + 1, int(_config.target_sols))
	_resolve_power()
	RunSummary.sample(_state, _config)
	if sol_ended:
		_close_sol_report(false)
	if _alive_count() == 0:
		_finish("total_defeat")
	elif _state.elapsed_seconds >= _config.sol_seconds * _config.target_sols:
		var supported: bool = _state.buildings[0].powered and _state.resources.air > 0.000000001
		_finish("relief_achieved" if supported else "partial_defeat")
	if sol_ended and _state.phase == "running":
		_state.current_sol_report = SolReport.open(_state)

func _close_sol_report(partial: bool) -> void:
	var report := SolReport.close(_state, partial)
	_state.sol_reports.append(report.duplicate(true))
	_queue("sol_report", report)

func _resolve_power() -> void:
	var supply := 0.0
	var demand := 0.0
	for building: Dictionary in _state.buildings:
		building.powered = false
		building.warning = ""
		building.power_output = 0.0
		building.power_demand = 0.0
		if building.maintenance.state == "shutdown":
			building.warning = "maintenance_shutdown"
		elif building.maintenance.state == "degraded":
			building.warning = "maintenance_degraded"
		if building.remaining_seconds > 0 or not building.enabled or building.maintenance.state == "shutdown" or building.covered or building.night_cut or building.repair_remaining > 0:
			continue
		var definition: Dictionary = _definition(building)
		var bonus := float(_config.engineer_multiplier) if _has_alive("engineer") else 1.0
		var output := float(definition.power_supply) * bonus * _maintenance.multiplier(building) * _director.multiplier(building)
		if building.kind == "solar":
			output *= float(_config.events.storm.solar_multiplier) if _active("storm") else 1.0
			if not _is_day():
				output = 0.0
		building.power_output = output
		supply += output
	var needed_by_kind: Dictionary = {}
	for kind: String in _power_order():
		for building: Dictionary in _state.buildings:
			if building.kind != kind or building.remaining_seconds > 0 or not building.enabled or building.maintenance.state == "shutdown" or building.covered or building.night_cut or building.repair_remaining > 0:
				continue
			var needed := float(_definition(building).power_demand)
			if kind == "oxygen_generator" and _has_alive("technician"):
				needed *= float(_config.technician_multiplier)
			building.power_demand = needed
			demand += needed
			needed_by_kind[building.id] = needed
	var battery_rate := minf(float(_config.energy_discharge_rate), float(_state.resources.energy))
	var available := supply + battery_rate
	for kind: String in _power_order():
		for building: Dictionary in _state.buildings:
			if building.kind != kind or not needed_by_kind.has(building.id):
				continue
			var needed := float(needed_by_kind[building.id])
			if needed <= available + 0.000000001:
				available = maxf(0.0, available - needed)
				building.powered = true
			else:
				building.warning = "power_shortage"
	# Las expediciones consumen la energía sobrante después de los edificios.
	for robot: Dictionary in _state.roberts:
		robot.powered = false
		if robot.state == "on_mission":
			var needed := float(_config.roberts.power_demand)
			demand += needed
			if available + 0.000000001 >= needed:
				available = maxf(0.0, available - needed)
				robot.powered = true
	var used := supply + battery_rate - available
	_state.power = {"supply": supply, "demand": demand, "used": used, "spare": available,
		"battery_rate": battery_rate, "battery_used": maxf(0.0, used - supply),
		"is_day": _is_day(), "energy": float(_state.resources.energy), "capacity": float(_config.energy_capacity)}

func _settle_energy() -> void:
	var generation := float(_state.power.supply)
	var used := float(_state.power.used)
	var draw := maxf(0.0, used - generation)
	var surplus := maxf(0.0, generation - used)
	var previous_energy := float(_state.resources.energy)
	_state.resources.energy = clampf(float(_state.resources.energy) + surplus - draw,
		0.0, float(_config.energy_capacity))
	var energy_delta := float(_state.resources.energy) - previous_energy
	if energy_delta > 0.000000001:
		SolReport.add(_state.current_sol_report, "production", "energy", energy_delta)
	elif energy_delta < -0.000000001:
		SolReport.add(_state.current_sol_report, "consumption", "energy", -energy_delta)
	_state.power.energy = float(_state.resources.energy)

func _is_day() -> bool:
	return posmod(_state.elapsed_seconds, int(_config.sol_seconds)) < int(_config.day_seconds)

func _active(kind: String) -> bool:
	return _state.get("event", {}).get("kind") == kind and _state.event.get("state") == "active"

func _update_events() -> void:
	var now: int = _state.elapsed_seconds
	for planned: Dictionary in _event_plan:
		var definition: Dictionary = _config.events[planned.kind]
		var start: int = int(planned.start_seconds)
		var end: int = start + int(planned.duration_seconds)
		var next: String = planned.state
		if planned.state == "pending" and now >= start - int(_config.events.warning_seconds):
			next = "warning" if planned.occurs else "skipped"
		if planned.occurs and now >= start:
			next = "active" if now < end else "ended"
		if next == planned.state:
			continue
		planned.state = next
		var event := {"kind": planned.kind, "state": next, "start_seconds": start, "end_seconds": end, "seconds": now}
		if next in ["warning", "active"]:
			_state.event = event.duplicate(true)
		elif _state.event.get("kind") == planned.kind:
			_state.event = {}
		_record("event_" + next, planned.kind, event)
		_queue("event", event)

func _apply_radiation() -> void:
	var rules: Dictionary = _config.radiation
	var raw := float(rules.ambient_dose_per_sol) / float(_config.sol_seconds)
	if _active("solar_particles"):
		raw += float(_config.events.solar_particles.dose_per_sol) / float(_config.sol_seconds)
	var outside_work: bool = _state.salvage.remaining > 0
	for building: Dictionary in _state.buildings:
		outside_work = outside_work or building.repair_remaining > 0
	if outside_work and not _state.sheltered:
		raw += float(_config.survival.outside_dose_per_second)
	var multiplier := 1.0
	if _has_alive("medic"):
		multiplier *= float(rules.medic_multiplier)
	if _state.sheltered:
		multiplier *= float(rules.shelter_multiplier)
	if _state.burial.state == "buried":
		multiplier *= float(rules.buried_multiplier)
	for member: Dictionary in _state.crew:
		if not member.alive:
			continue
		var previous: float = member.dose
		var increment := raw * multiplier
		member.dose += increment
		member.dose_avoided += raw - increment
		# Daño solo por la dosis NUEVA por encima del umbral, nunca por toda la historia.
		var harmful := maxf(0, member.dose - float(rules.damage_threshold)) - maxf(0, previous - float(rules.damage_threshold))
		member.health = maxf(0, member.health - harmful * float(rules.health_loss_per_dose))
		if member.health <= 0.000000001:
			member.health = 0.0
			member.alive = false
			_record("crew_died", member.id, {"reason": "radiation", "dose": member.dose})
	if _active("solar_particles"):
		_record("radiation_exposure", "crew", {"raw_dose_per_crew": raw, "multiplier": multiplier})

func _find_robert(id: String) -> Dictionary:
	for robot: Dictionary in _state.roberts:
		if robot.id == id:
			return robot
	return {}

func _mission_risk(destination: Dictionary, exposed: bool) -> float:
	var probability := float(destination.loss_probability)
	if exposed:
		probability += float(_config.roberts.storm_loss_probability)
	if _has_alive("geologist"):
		probability *= float(_config.roberts.geologist_risk_multiplier)
	return clampf(probability, 0.0, 1.0)

func _mission_yield(destination: Dictionary) -> float:
	return float(destination.amount) * (float(_config.roberts.geologist_yield_multiplier) if _has_alive("geologist") else 1.0)

func _update_roberts() -> void:
	for robot: Dictionary in _state.roberts:
		if robot.state != "on_mission":
			continue
		if _active("storm"):
			robot.storm_exposed = true
		if _state.elapsed_seconds < robot.return_seconds:
			continue
		var destination: Dictionary = _config.roberts.destinations[robot.destination]
		var risk := _mission_risk(destination, robot.storm_exposed)
		var lost := _roll(_mission_rng, risk)
		robot.state = "lost" if lost else "available"
		var cargo := {} if lost else {destination.resource: _mission_yield(destination)}
		for resource: String in cargo:
			_state.resources[resource] += cargo[resource]
			SolReport.add(_state.current_sol_report, "imports", resource, float(cargo[resource]))
		_record("robert_lost" if lost else "robert_returned", robot.id,
			{"mission_id": robot.mission_id, "destination": robot.destination, "cargo": cargo, "loss_probability": risk, "storm_exposed": robot.storm_exposed})
		_queue("robert", robot)

func _roll(rng: RandomNumberGenerator, probability: float) -> bool:
	var roll := rng.randf()
	return probability >= 1.0 or (probability > 0.0 and roll < probability)

func _queue(kind: String, payload: Dictionary) -> void:
	_notifications.append({"kind": kind, "payload": payload.duplicate(true)})

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
	var building := {"id": id, "kind": kind, "x": cell.x, "y": cell.y, "level": 1,
		"enabled": true, "powered": false, "remaining_seconds": duration, "warning": "",
		"upgrade_remaining_work": 0.0, "upgrade_total_work": 0.0}
	building.merge({"damage": 0.0, "crop_health": 100.0, "covered": false, "cover_seconds": 0, "storm_decision": "inaction", "night_cut": false, "cut_seconds": 0, "night_decision": "", "repair_remaining": 0, "repair_decision": "", "lotus": false})
	_maintenance.attach(building)
	return building

func _record(reason: String, target: String, details: Dictionary) -> void:
	_state.log.append({"id": "d%d" % (_state.log.size() + 1), "seconds": _state.elapsed_seconds,
		"reason": reason, "target": target, "details": details.duplicate(true)})
	_state.current_sol_report.fact_ids.append(_state.log[-1].id)
	RunSummary.observe(_state, reason, target, details, _state.log[-1].id)

func _finish(verdict: String) -> void:
	if _state.elapsed_seconds % int(_config.sol_seconds) != 0:
		_close_sol_report(true)
	_state.phase = "finished"
	_accumulator = 0.0
	_state.result = {"verdict": verdict, "elapsed_seconds": _state.elapsed_seconds, "alive": _alive_count()}
	_record("run_finished", "", _state.result)
	_state.run_summary = RunSummary.build(_state, _config)

func _publish() -> void:
	# Evita que un consumidor reentre y cambie el dominio en mitad de una notificación.
	_publishing = true
	state_updated.emit(get_snapshot())
	for notice: Dictionary in _notifications:
		if notice.kind == "event":
			event_changed.emit(notice.payload.duplicate(true))
		elif notice.kind == "robert":
			robert_changed.emit(notice.payload.duplicate(true))
		elif notice.kind == "maintenance":
			maintenance_changed.emit(notice.payload.duplicate(true))
		elif notice.kind == "sol_report":
			sol_report_ready.emit(notice.payload.duplicate(true))
	_notifications.clear()
	if _state.phase == "finished" and not _finished_emitted:
		_finished_emitted = true
		run_finished.emit(_state.result.duplicate(true))
	_publishing = false

func _reply(ok: bool, code: String = "", cost: Dictionary = {}, result: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "error_code": code, "cost": cost.duplicate(true), "result": result.duplicate(true)}

func _power_order() -> Array:
	if _state.get("priority", "air") == "food":
		return ["habitat", "greenhouse", "oxygen_generator", "laboratory", "solar", "reactor"]
	return POWER_ORDER

func _drain_survival() -> void:
	for fact: Dictionary in _director.facts:
		if fact.reason == "salvage_returned":
			SolReport.add(_state.current_sol_report, "imports", "regolith", float(fact.details.regolith))
		for resource: String in fact.details.get("cost", {}):
			SolReport.add(_state.current_sol_report, "consumption", resource, float(fact.details.cost[resource]))
		_record(fact.reason, fact.target, fact.details)
	_director.facts.clear()

func choose_decision(id: String, option_id: String) -> Dictionary:
	if _publishing or _state.get("phase") != "running":
		return _reply(false, "invalid_phase")
	var result := _director.choose(id, option_id)
	if result.ok:
		_drain_survival()
		_resolve_power()
		_publish()
	return result

func survival_command(action: String, building_id: String = "") -> Dictionary:
	if _publishing or _state.get("phase") not in ["planning", "running"]:
		return _reply(false, "invalid_phase")
	var result := _director.command(action, building_id)
	if result.ok:
		_drain_survival()
		_resolve_power()
		_publish()
	return result
