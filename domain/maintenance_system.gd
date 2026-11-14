extends RefCounted
## Estado de mantenimiento dentro del dominio; no conoce escenas ni minijuegos.

var _state: Dictionary
var _rules: Dictionary
var _sol_seconds: int
var _generation: int
var _counter: int = 0
var _next_notice: int = 0
var _changes: Array[Dictionary] = []

func reset(state: Dictionary, config: Dictionary, generation: int) -> void:
	_state = state
	_rules = config.maintenance
	_sol_seconds = int(config.sol_seconds)
	_generation = generation
	_counter = 0
	_next_notice = 0
	_changes.clear()

func attach(building: Dictionary) -> void:
	building.maintenance = {"state": "healthy", "next_due_seconds": -1, "request_id": "", "age_seconds": 0,
		"shutdown_until": 0, "attempts": 0, "elapsed_real_seconds": 0.0, "session": {}}

func tick() -> void:
	var crisis: bool = not _state.event.is_empty()
	sync_sessions()
	var pending := 0
	for building: Dictionary in _state.buildings:
		if building.maintenance.state in ["requested", "degraded"]:
			pending += 1
	for building: Dictionary in _state.buildings:
		if building.kind not in ["reactor", "oxygen_generator"] or building.remaining_seconds > 0:
			continue
		var m: Dictionary = building.maintenance
		var now: int = _state.elapsed_seconds
		if m.next_due_seconds < 0:
			m.next_due_seconds = now - 1 + int(_rules.interval_sols) * _sol_seconds
		if m.state in ["requested", "degraded"]:
			var session_live: bool = m.session.get("state") in ["active", "suspended"]
			# Atender el aviso no cuenta como ignorarlo. Evita apagados durante
			# los 15 segundos de minijuego a x4; el límite de sesión sigue vigente.
			if not session_live:
				m.age_seconds += 1
			if m.age_seconds >= int(_rules.shutdown_after_sols) * _sol_seconds:
				m.state = "shutdown"
				m.shutdown_until = now + int(_rules.shutdown_duration_sols) * _sol_seconds
				if m.session.get("state") in ["active", "suspended"]:
					m.session.state = "interrupted_shutdown"
				pending -= 1
				_change("maintenance_shutdown", building)
			elif m.age_seconds >= int(_rules.degrade_after_sols) * _sol_seconds and m.state == "requested":
				m.state = "degraded"
				_change("maintenance_degraded", building)
		elif m.state == "healthy" and building.enabled and now >= m.next_due_seconds and now >= _next_notice and not crisis and pending < int(_rules.max_pending):
			_counter += 1
			m.request_id = "r%d-maint%d" % [_generation, _counter]
			m.state = "requested"
			m.age_seconds = 0
			m.attempts = 0
			m.elapsed_real_seconds = 0.0
			m.session = {}
			pending += 1
			_next_notice = now + int(_rules.global_gap_seconds)
			_change("maintenance_requested", building)

func sync_sessions() -> void:
	var suspended: bool = not _state.event.is_empty() or _state.sheltered
	for building: Dictionary in _state.buildings:
		var m: Dictionary = building.maintenance
		if m.session.get("state") not in ["active", "suspended"]:
			continue
		var next_state := "suspended" if suspended else "active"
		if m.session.state != next_state:
			m.session.state = next_state
			_change("maintenance_" + next_state, building)

func advance_real(seconds: float) -> void:
	sync_sessions()
	for building: Dictionary in _state.buildings:
		var m: Dictionary = building.maintenance
		if m.session.get("state") != "active":
			continue
		m.elapsed_real_seconds = minf(float(_rules.session_max_real_seconds), snappedf(m.elapsed_real_seconds + seconds, 0.000000001))
		if m.elapsed_real_seconds + 0.000000001 >= float(_rules.session_max_real_seconds):
			m.session.state = "timeout"
			_change("maintenance_timeout", building)

func begin(building_id: String) -> Dictionary:
	var building := _building(building_id)
	if building.is_empty():
		return _reply(false, "unknown_building")
	var m: Dictionary = building.maintenance
	if m.state not in ["requested", "degraded"]:
		return _reply(false, "maintenance_not_pending")
	if not _state.event.is_empty() or _state.sheltered:
		return _reply(false, "maintenance_suspended")
	if m.session.get("state") in ["active", "suspended"]:
		return _reply(false, "maintenance_session_active")
	for candidate: Dictionary in _state.buildings:
		if candidate.maintenance.session.get("state") in ["active", "suspended"]:
			return _reply(false, "another_maintenance_active")
	if m.attempts >= int(_rules.max_attempts) or m.elapsed_real_seconds >= float(_rules.session_max_real_seconds):
		return _reply(false, "maintenance_attempts_exhausted")
	var robot_support := false
	for robot: Dictionary in _state.roberts:
		if robot.state == "available":
			robot_support = true
	m.attempts += 1
	m.session = {"id": "%s-a%d" % [m.request_id, m.attempts], "state": "active", "building_id": building_id,
		"minigame_id": "load_balance" if building.kind == "reactor" else "oxygen_reaction",
		"robot_support": robot_support, "difficulty_multiplier": float(_rules.robot_difficulty_multiplier) if robot_support else 1.0}
	_change("maintenance_started", building)
	return _reply(true, "", m.session)

func apply_result(session_id: String, success: bool, elapsed_seconds: float, abandoned: bool = false) -> Dictionary:
	if not is_finite(elapsed_seconds) or elapsed_seconds < 0 or elapsed_seconds > float(_rules.session_max_real_seconds) or (success and abandoned):
		return _reply(false, "invalid_maintenance_result")
	for building: Dictionary in _state.buildings:
		var m: Dictionary = building.maintenance
		if m.session.get("id") != session_id:
			continue
		if m.session.get("state") == "suspended" or not _state.event.is_empty() or _state.sheltered:
			return _reply(false, "maintenance_suspended")
		if m.session.get("state") != "active" or m.state not in ["requested", "degraded"]:
			return _reply(false, "maintenance_result_already_closed")
		m.elapsed_real_seconds = maxf(m.elapsed_real_seconds, elapsed_seconds)
		m.session.state = "success" if success else ("abandoned" if abandoned else "failure")
		if success:
			m.state = "healthy"
			m.age_seconds = 0
			m.next_due_seconds = _state.elapsed_seconds + int(_rules.interval_sols) * _sol_seconds
		_change("maintenance_" + m.session.state, building)
		return _reply(true, "", {"building_id": building.id, "session_id": session_id, "success": success})
	return _reply(false, "unknown_maintenance_session")

func reactivate(building_id: String) -> Dictionary:
	var building := _building(building_id)
	if building.is_empty():
		return _reply(false, "unknown_building")
	var m: Dictionary = building.maintenance
	if m.state != "shutdown":
		return _reply(false, "maintenance_not_shutdown")
	if _state.elapsed_seconds < m.shutdown_until:
		return _reply(false, "maintenance_cooling_down")
	var cost := {"mass": float(_rules.reactivation_mass)}
	if _state.resources.mass < cost.mass:
		return _reply(false, "insufficient_mass", {}, cost)
	_state.resources.mass -= cost.mass
	m.state = "healthy"
	m.age_seconds = 0
	m.shutdown_until = 0
	m.next_due_seconds = _state.elapsed_seconds + int(_rules.interval_sols) * _sol_seconds
	_change("maintenance_reactivated", building, {"cost": cost})
	return _reply(true, "", {"building_id": building.id}, cost)

func multiplier(building: Dictionary) -> float:
	if building.maintenance.state == "shutdown":
		return 0.0
	return float(_rules.degraded_multiplier) if building.maintenance.state == "degraded" else 1.0

func drain_changes() -> Array[Dictionary]:
	var changes := _changes.duplicate(true)
	_changes.clear()
	return changes

func _building(id: String) -> Dictionary:
	for building: Dictionary in _state.buildings:
		if building.id == id:
			return building
	return {}

func _change(reason: String, building: Dictionary, details: Dictionary = {}) -> void:
	_changes.append({"reason": reason, "target": building.id, "details": details.duplicate(true), "maintenance": building.maintenance.duplicate(true), "seconds": _state.elapsed_seconds})

func _reply(ok: bool, code: String, result: Dictionary = {}, cost: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "error_code": code, "cost": cost.duplicate(true), "result": result.duplicate(true)}
