class_name ResearchService
extends RefCounted

var power: PowerService
var crew_service
var _seen_work: Dictionary = {}

func initialize() -> void:
	_seen_work.clear()
	GameState.data["research"] = {"unlocked": [], "points": 0.0, "active": "", "progress": 0.0, "seen_tasks": {}}

func rebuild_from_state() -> void:
	_seen_work = GameState.data.get("research", {}).get("seen_tasks", {}).duplicate(true)

func get_snapshot() -> Dictionary:
	return GameState.data.get("research", {}).duplicate(true)

func validate_research(tech_id: StringName) -> GameContracts.ValidationResult:
	var definition: Dictionary = ConfigDB.balance.get("research", {})
	if not definition.has(String(tech_id)):
		return GameContracts.failure(&"unknown_technology")
	var state: Dictionary = GameState.data.get("research", {})
	if state.get("unlocked", []).has(String(tech_id)):
		return GameContracts.failure(&"already_unlocked")
	if not String(state.get("active", "")).is_empty():
		return GameContracts.failure(&"research_busy")
	var powered_lab := false
	for id in GameState.data.get("buildings", {}).get("instances", {}):
		if GameState.data["buildings"]["instances"][id].get("type") == "laboratory" and power.is_powered(StringName(id)):
			powered_lab = true
			break
	if not powered_lab:
		return GameContracts.failure(&"powered_laboratory_required")
	return GameContracts.success()

func start_research(tech_id: StringName) -> GameContracts.ValidationResult:
	var result := validate_research(tech_id)
	if not result.ok:
		return result
	GameState.data["research"]["active"] = String(tech_id)
	GameState.data["research"]["progress"] = 0.0
	SignalBus.research_changed.emit(tech_id, &"started")
	return result

func step(_delta_seconds: float) -> void:
	if crew_service == null or not crew_service.has_method("consume_completed_work"):
		return
	for work in crew_service.consume_completed_work(&"science_construction"):
		if work is Dictionary:
			consume_work(work)

func consume_work(work: Dictionary) -> GameContracts.ValidationResult:
	var id := String(work.get("task_id", ""))
	var hours := float(work.get("work_hours", 0.0))
	var total := float(work.get("total_hours", hours))
	# Old saves used a boolean for a fully credited task. New saves retain a
	# cumulative watermark so partial work and reloads cannot count twice.
	var previous: Variant = _seen_work.get(id, 0.0)
	if id.is_empty() or not is_finite(hours) or hours <= 0.0 or not is_finite(total) or (previous is bool and previous):
		return GameContracts.failure(&"invalid_work")
	var earned := total - float(previous)
	if earned <= 0.0000001:
		return GameContracts.failure(&"invalid_work")
	if earned > hours + 0.000001:
		# A pre-fix save may contain hours worked on an unfinished task that
		# were never credited. Recover them only from its actual task record.
		var task: Dictionary = GameState.data.get("crew", {}).get("tasks", {}).get(id, {})
		if _seen_work.has(id) or task.get("task_type") != "research" or task.get("target_id") != work.get("target_id") or not is_equal_approx(float(task.get("completed_hours", -1)), total):
			return GameContracts.failure(&"invalid_work")
	var state: Dictionary = GameState.data["research"]
	var active := String(state.get("active", ""))
	var lab_id := String(work.get("target_id", ""))
	var lab: Dictionary = GameState.data.get("buildings", {}).get("instances", {}).get(lab_id, {})
	if lab.get("type") != "laboratory" or not power.is_powered(StringName(lab_id)):
		return GameContracts.failure(&"powered_laboratory_required")
	_seen_work[id] = total
	state["seen_tasks"] = _seen_work.duplicate(true)
	var multiplier := float(ConfigDB.balance["buildings"]["laboratory"]["research_per_astronaut_hour"])
	if active.is_empty():
		state["points"] = float(state.get("points", 0.0)) + earned * multiplier
		return GameContracts.success()
	state["progress"] = float(state["progress"]) + earned * multiplier
	var required := float(ConfigDB.balance["research"][active])
	if float(state["progress"]) + 0.000001 >= required:
		state["points"] = float(state.get("points", 0.0)) + maxf(0.0, float(state["progress"]) - required)
		state["unlocked"].append(active)
		state["active"] = ""
		state["progress"] = 0.0
		SignalBus.research_changed.emit(StringName(active), &"unlocked")
	else:
		SignalBus.research_changed.emit(StringName(active), &"progress")
	return GameContracts.success()

func on_sol_ended(_sol: int) -> void:
	pass
