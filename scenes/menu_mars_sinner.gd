extends Control

const GAME_SCENE: String = "res://scenes/simulation_lab.tscn"
const SETTINGS_SCENE: String = "res://scenes/settings.tscn"
const SettingsManagerScript = preload("res://scripts/settings_manager.gd")

@onready var _play_button: Button = $CenterContainer/PanelContainer/VBoxContainer/Btn_play
@onready var _settings_button: Button = $CenterContainer/PanelContainer/VBoxContainer/Btn_settings
@onready var _settings_manager: SettingsManagerScript = get_node("/root/SettingsManager") as SettingsManagerScript

func _ready() -> void:
	_play_button.pressed.connect(_open_game)
	_settings_button.pressed.connect(_open_settings)
	_settings_manager.language_changed.connect(_on_language_changed)
	_settings_manager.translate_tree(self)

func _on_language_changed() -> void:
	_settings_manager.translate_tree(self)

func _open_game() -> void:
	_change_scene(GAME_SCENE)

func _open_settings() -> void:
	_change_scene(SETTINGS_SCENE)

func _change_scene(scene_path: String) -> void:
	var error_code: int = get_tree().change_scene_to_file(scene_path)
	if error_code != OK:
		push_error("No se pudo abrir %s: %s" % [scene_path, error_string(error_code)])
