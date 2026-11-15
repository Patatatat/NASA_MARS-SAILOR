class_name GameSettingsService
extends Node

const DEFAULTS := {"language": "es", "master_volume": 0.8, "sfx_volume": 0.8,
	"ambient_volume": 0.45, "show_tutorial": true, "ui_scale": 1.0}
var _current: Dictionary = DEFAULTS.duplicate(true)

func _ready() -> void:
	SignalBus.state_restored.connect(rebuild_from_state)
	get_window().min_size = Vector2i(960, 540)

func rebuild_from_state() -> void:
	_current = DEFAULTS.duplicate(true)
	_current.merge(GameState.data.get("settings", {}), true)
	get_tree().root.get_node("LocalizationDB").rebuild_from_state()
	get_window().content_scale_factor = float(_current.get("ui_scale", 1.0))

func get_settings() -> Dictionary:
	var result := _current.duplicate(true)
	result.merge(GameState.data.get("settings", {}), true)
	return result

func apply_settings(values: Dictionary) -> GameContracts.ValidationResult:
	for key in values:
		if not DEFAULTS.has(key):
			return GameContracts.failure(&"invalid_setting", {"key": key})
		if key == "language" and not LocalizationDatabase.LANGUAGES.has(StringName(values[key])):
			return GameContracts.failure(&"invalid_language")
		if key.ends_with("volume") and (not (values[key] is float or values[key] is int) or float(values[key]) < 0.0 or float(values[key]) > 1.0):
			return GameContracts.failure(&"invalid_volume")
		if key == "show_tutorial" and not values[key] is bool:
			return GameContracts.failure(&"invalid_setting")
		if key == "ui_scale" and (not (values[key] is int or values[key] is float) or not float(values[key]) in [1.0, 1.15, 1.25]):
			return GameContracts.failure(&"invalid_setting")
	_current.merge(values.duplicate(true), true)
	if not GameState.data.is_empty():
		GameState.data.get_or_add("settings", {}).merge(values.duplicate(true), true)
	if values.has("language"):
		get_tree().root.get_node("LocalizationDB").set_language(StringName(values["language"]))
	if values.has("ui_scale"):
		get_window().content_scale_factor = float(values["ui_scale"])
	return GameContracts.success()
