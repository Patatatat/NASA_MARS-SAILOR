class_name EventState
extends RefCounted

var id: StringName
var type: StringName
var phase: StringName
var start_sol: int
var end_sol: int
var source_id: StringName = &""
var target_ids: Array[StringName] = []
var modifiers: Dictionary = {}

static func from_dict(value: Dictionary) -> EventState:
	var result := EventState.new()
	result.id = StringName(value.get("id", ""))
	result.type = StringName(value.get("type", ""))
	result.phase = StringName(value.get("phase", ""))
	result.start_sol = int(value.get("start_sol", 0))
	result.end_sol = int(value.get("end_sol", 0))
	result.source_id = StringName(value.get("source_id", ""))
	for id in value.get("target_ids", []):
		result.target_ids.append(StringName(id))
	result.modifiers = value.get("modifiers", {}).duplicate(true)
	return result
