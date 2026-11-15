class_name BuildingLogEntry
extends RefCounted

var id: StringName
var kind: StringName
var severity: StringName
var message_key: StringName
var params: Dictionary = {}
var sol: int
var reason_id: StringName

func as_dict() -> Dictionary:
	return {"id": String(id), "kind": String(kind), "severity": String(severity),
		"message_key": String(message_key), "params": params.duplicate(true),
		"sol": sol, "reason_id": String(reason_id)}
