class_name ScienceCard
extends RefCounted

var id: StringName
var source_id: StringName
var title_key: StringName
var body_key: StringName
var model_limit_key: StringName

func as_dict() -> Dictionary:
	return {"id": String(id), "source_id": String(source_id), "title_key": String(title_key),
		"body_key": String(body_key), "model_limit_key": String(model_limit_key)}
