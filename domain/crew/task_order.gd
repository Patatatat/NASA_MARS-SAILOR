class_name TaskOrder
extends RefCounted

var id: StringName = &""
var crew_id: StringName = &""
var category: StringName = &""
var target_id: StringName = &""
var task_type: StringName = &""
var required_hours: float = 0.0
var completed_hours: float = 0.0
var state: StringName = &"queued"
var reason_id: StringName = &""

func as_dict() -> Dictionary:
	return {"id": String(id), "crew_id": String(crew_id), "category": String(category),
		"target_id": String(target_id), "task_type": String(task_type),
		"required_hours": required_hours, "completed_hours": completed_hours,
		"state": String(state), "reason_id": String(reason_id)}
