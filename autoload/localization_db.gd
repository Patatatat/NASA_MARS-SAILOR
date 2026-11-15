class_name LocalizationDatabase
extends Node

const LANGUAGES := [&"es", &"en"]
var language: StringName = &"es"
var _tables: Dictionary = {}

func _ready() -> void:
	for code in LANGUAGES:
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/locales/%s.json" % code))
		_tables[String(code)] = value if value is Dictionary else {}

func set_language(code: StringName) -> GameContracts.ValidationResult:
	if not LANGUAGES.has(code):
		return GameContracts.failure(&"invalid_language")
	language = code
	if not GameState.data.is_empty():
		GameState.data.get_or_add("settings", {})["language"] = String(code)
	SignalBus.language_changed.emit(code)
	return GameContracts.success()

func rebuild_from_state() -> void:
	var saved := StringName(GameState.data.get("settings", {}).get("language", "es"))
	language = saved if LANGUAGES.has(saved) else &"es"
	SignalBus.language_changed.emit(language)

func translate_key(message_key: StringName, params: Dictionary = {}) -> String:
	var key := String(message_key)
	var fallback := "error.action_unavailable" if key.begins_with("error.") else key
	var value := String(_tables.get(String(language), {}).get(key, _tables.get("en", {}).get(key,
		_tables.get(String(language), {}).get(fallback, fallback))))
	for name in params:
		value = value.replace("{%s}" % name, str(params[name]))
	return value

func has_key_in_both(key: StringName) -> bool:
	return _tables.get("es", {}).has(String(key)) and _tables.get("en", {}).has(String(key))

