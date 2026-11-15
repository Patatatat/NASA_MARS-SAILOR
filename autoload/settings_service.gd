class_name GameSettingsService
extends Node

const USER_SETTINGS_PATH := "user://settings.cfg"
const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080"]
const DEFAULTS := {"language": "es", "master_volume": 0.8, "sfx_volume": 0.8,
	"ambient_volume": 0.45, "show_tutorial": true, "ui_scale": 1.0,
	"fullscreen": false, "resolution": "1600x900"}
var _current: Dictionary = DEFAULTS.duplicate(true)

func _ready() -> void:
	SignalBus.state_restored.connect(rebuild_from_state)
	get_window().min_size = Vector2i(960, 540)
	_load_user_settings()
	get_tree().root.get_node("LocalizationDB").set_language(StringName(_current.get("language", "es")))
	_apply_display_settings()
	get_window().content_scale_factor = float(_current.get("ui_scale", 1.0))

func rebuild_from_state() -> void:
	var saved: Variant = GameState.data.get("settings", {})
	if saved is Dictionary:
		_current.merge(saved, true)
	get_tree().root.get_node("LocalizationDB").rebuild_from_state()
	get_window().content_scale_factor = float(_current.get("ui_scale", 1.0))
	_apply_display_settings()

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
		if key == "fullscreen" and not values[key] is bool:
			return GameContracts.failure(&"invalid_setting")
		if key == "resolution" and not RESOLUTIONS.has(String(values[key])):
			return GameContracts.failure(&"invalid_setting")
	_current.merge(values.duplicate(true), true)
	if not GameState.data.is_empty():
		GameState.data.get_or_add("settings", {}).merge(values.duplicate(true), true)
	_persist_user_settings()
	if values.has("language"):
		get_tree().root.get_node("LocalizationDB").set_language(StringName(values["language"]))
	if values.has("ui_scale"):
		get_window().content_scale_factor = float(values["ui_scale"])
	if values.has("fullscreen") or values.has("resolution"):
		_apply_display_settings()
	return GameContracts.success()

func _load_user_settings() -> void:
	var config := ConfigFile.new()
	if config.load(USER_SETTINGS_PATH) != OK:
		return
	var saved: Variant = config.get_value("settings", "values", {})
	if not saved is Dictionary:
		return
	for key in saved:
		if DEFAULTS.has(key):
			_current[key] = saved[key]

func _persist_user_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "values", _current.duplicate(true))
	config.save(USER_SETTINGS_PATH)

func _apply_display_settings() -> void:
	var resolution_parts := String(_current.get("resolution", "1600x900")).split("x")
	if resolution_parts.size() != 2:
		return
	var target_size := Vector2i(int(resolution_parts[0]), int(resolution_parts[1]))
	var window := get_window()
	# Keep the selected render resolution active in fullscreen too. Godot sizes a
	# fullscreen window to the monitor, so content_scale_size controls the game's
	# virtual render size while window.size controls windowed mode.
	window.content_scale_size = target_size
	if bool(_current.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		window.size = target_size
