class_name DialogueEntry
extends RefCounted

var id: StringName
var kind: StringName
var severity: StringName
var message_key: StringName
var params: Dictionary = {}
var created_sol: int = 1
var acknowledged: bool = false
var resolved: bool = false
var source_id: StringName = &""
var focus_target: StringName = &""

func as_dict() -> Dictionary:
	return {"id": String(id), "kind": String(kind), "severity": String(severity),
		"message_key": String(message_key), "params": params.duplicate(true),
		"created_sol": created_sol, "acknowledged": acknowledged, "resolved": resolved,
		"source_id": String(source_id), "focus_target": String(focus_target)}
