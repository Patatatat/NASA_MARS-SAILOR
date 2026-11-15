class_name RocketVisual
extends Node3D

var rocket_id: StringName

func set_rocket_state(status: Dictionary) -> void:
	rocket_id = StringName(status.get("id", ""))
	visible = bool(status.get("landed", false)) and status.get("disposition", "available") == "available"
