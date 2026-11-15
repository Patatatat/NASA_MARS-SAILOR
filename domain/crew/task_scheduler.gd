class_name TaskScheduler
extends RefCounted

const CATEGORIES := [&"survival", &"emergency_eva", &"production", &"science_construction"]

var building_service

func validate_order(order: TaskOrder) -> GameContracts.ValidationResult:
	if order == null or not CATEGORIES.has(order.category):
		return GameContracts.failure(&"invalid_task_category")
	if String(order.crew_id).is_empty() or String(order.target_id).is_empty() or String(order.task_type).is_empty():
		return GameContracts.failure(&"invalid_task")
	if order.task_type not in [&"research", &"repair", &"clean", &"refuel"]:
		return GameContracts.failure(&"invalid_task")
	if not is_finite(order.required_hours) or order.required_hours <= 0.0:
		return GameContracts.failure(&"invalid_work_hours")
	var member: Dictionary = GameState.data.get("crew", {}).get("members", {}).get(String(order.crew_id), {})
	if member.is_empty() or not bool(member.get("alive", false)):
		return GameContracts.failure(&"crew_unavailable")
	if bool(member.get("shelter", false)):
		return GameContracts.failure(&"crew_unavailable")
	if member.get("forbidden_categories", []).has(String(order.category)):
		return GameContracts.failure(&"category_forbidden")
	if not String(member.get("task_id", "")).is_empty():
		return GameContracts.failure(&"crew_busy")
	return GameContracts.success()

func enqueue(order: TaskOrder) -> GameContracts.ValidationResult:
	var result := validate_order(order)
	if not result.ok:
		return result
	var state: Dictionary = GameState.data["crew"]
	if String(order.id).is_empty():
		order.id = StringName("task_%d" % int(state["next_task_id"]))
		state["next_task_id"] = int(state["next_task_id"]) + 1
	if state["tasks"].has(String(order.id)):
		return GameContracts.failure(&"duplicate_task")
	state["tasks"][String(order.id)] = order.as_dict()
	state["members"][String(order.crew_id)]["task_id"] = String(order.id)
	SignalBus.crew_changed.emit(order.crew_id)
	return result

func cancel(task_id: StringName) -> GameContracts.ValidationResult:
	var task: Dictionary = GameState.data.get("crew", {}).get("tasks", {}).get(String(task_id), {})
	if task.is_empty() or task.get("state") in ["completed", "cancelled"]:
		return GameContracts.failure(&"task_not_active")
	# Work already performed is never refunded; R2 owns any reserved material cost.
	task["state"] = "cancelled"
	if building_service != null:
		building_service.cancel_pending_task(task_id)
	var member: Dictionary = GameState.data["crew"]["members"].get(task["crew_id"], {})
	if not member.is_empty() and member.get("task_id") == String(task_id):
		member["task_id"] = ""
		SignalBus.crew_changed.emit(StringName(task["crew_id"]))
	return GameContracts.success()

func progress(crew_id: StringName, hours: float) -> float:
	if not is_finite(hours) or hours <= 0.0:
		return 0.0
	var state: Dictionary = GameState.data.get("crew", {})
	var member: Dictionary = state.get("members", {}).get(String(crew_id), {})
	if member.is_empty():
		return 0.0
	var id := String(member.get("task_id", ""))
	var task: Dictionary = state.get("tasks", {}).get(id, {})
	if task.is_empty() or task.get("state") in ["completed", "cancelled"]:
		return 0.0
	if building_service != null and building_service.get_status(StringName(task["target_id"])) == null:
		cancel(StringName(id))
		return 0.0
	if member.get("forbidden_categories", []).has(task["category"]):
		task["state"] = "suspended"
		return 0.0
	if bool(member.get("shelter", false)) and task["category"] == "emergency_eva":
		task["state"] = "suspended"
		return 0.0
	if task["task_type"] == "research" and building_service != null:
		if building_service.power == null or not building_service.power.is_powered(StringName(task["target_id"])):
			task["state"] = "blocked"
			return 0.0
	task["state"] = "active"
	var before := float(task["completed_hours"])
	task["completed_hours"] = minf(float(task["required_hours"]), float(task["completed_hours"]) + hours)
	var earned := float(task["completed_hours"]) - before
	if task["task_type"] == "research" and earned > 0.0:
		state["completed_work"].append({"task_id": id, "target_id": task["target_id"], "work_hours": earned,
			"total_hours": float(task["completed_hours"]), "category": task["category"]})
	if float(task["completed_hours"]) + 0.000001 < float(task["required_hours"]):
		return earned
	if task["task_type"] in ["repair", "refuel", "clean"] and building_service != null:
		var applied: GameContracts.ValidationResult = building_service.apply_task_result(StringName(id), StringName(task["target_id"]), {"completed": true})
		if not applied.ok:
			task["state"] = "blocked"
			return earned
	task["state"] = "completed"
	task["completed_sol"] = int(GameState.data["clock"]["sol"])
	member["task_id"] = ""
	SignalBus.crew_changed.emit(crew_id)
	return earned

func consume_completed_work(category: StringName) -> Array[Dictionary]:
	var state: Dictionary = GameState.data.get("crew", {})
	var pending: Array = state.get("completed_work", [])
	var result: Array[Dictionary] = []
	var keep: Array = []
	for work in pending:
		if work.get("category") == String(category):
			result.append(work.duplicate(true))
		else:
			keep.append(work)
	state["completed_work"] = keep
	return result
