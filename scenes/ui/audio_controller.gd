class_name AudioController
extends Node

var _priority: int = 0

func _ready() -> void:
	SignalBus.log_entry_added.connect(_on_log)
	SignalBus.building_changed.connect(_on_building)

func _on_log(entry: RefCounted) -> void:
	# Event alerts already have a dedicated sound in AudioManager.
	if entry is DialogueEntry and not String(entry.id).begins_with("event_"):
		play_notice(entry.kind == &"critical")

func _on_building(_id: StringName, change_type: StringName) -> void:
	if change_type == &"damaged":
		play_notice(true)

func play_notice(critical: bool) -> void:
	var next_priority := 2 if critical else 1
	_priority = next_priority
	AudioManager.play_notice(critical)

func get_priority() -> int:
	return _priority
