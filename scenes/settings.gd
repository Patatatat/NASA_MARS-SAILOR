extends Control

const MENU_SCENE: String = "res://scenes/MenuMarsSinner.tscn"
const SettingsManagerScript = preload("res://scripts/settings_manager.gd")

@onready var _back_button: Button = $CenterContainer/PanelContainer/VBoxContainer/BtnBack
@onready var _master_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/Master_volume_HSlider
@onready var _music_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/Music_volume_HSlider
@onready var _sfx_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/SFX_volume_HSlider
@onready var _master_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Master_volume_Label
@onready var _music_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Music_volume_label
@onready var _sfx_label: Label = $CenterContainer/PanelContainer/VBoxContainer/SFX_volume_label
@onready var _settings_manager: SettingsManagerScript = get_node("/root/SettingsManager") as SettingsManagerScript

func _ready() -> void:
	_back_button.pressed.connect(_open_menu)
	_settings_manager.language_changed.connect(_on_language_changed)
	var saved_values := _get_sound_values()
	_master_slider.value = float(saved_values.master)
	_music_slider.value = float(saved_values.music)
	_sfx_slider.value = float(saved_values.sfx)
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_update_percentage(_master_label, "MASTER VOLUME", _master_slider.value)
	_update_percentage(_music_label, "MUSIC VOLUME", _music_slider.value)
	_update_percentage(_sfx_label, "SFX VOLUME", _sfx_slider.value)
	_settings_manager.translate_tree(self)

func _on_master_volume_changed(value: float) -> void:
	_update_percentage(_master_label, "MASTER VOLUME", value)
	_save_sound_value("master", value)

func _on_music_volume_changed(value: float) -> void:
	_update_percentage(_music_label, "MUSIC VOLUME", value)
	_save_sound_value("music", value)

func _on_sfx_volume_changed(value: float) -> void:
	_update_percentage(_sfx_label, "SFX VOLUME", value)
	_save_sound_value("sfx", value)

func _update_percentage(label: Label, volume_name: String, value: float) -> void:
	label.text = "%s: %d%%" % [volume_name, roundi(value)]
	_settings_manager.translate_tree(label)

func _get_sound_values() -> Dictionary:
	return _settings_manager.get_sound_percentages()

func _save_sound_value(key: String, value: float) -> void:
	_settings_manager.set_sound_percentage(key, value)

func _on_language_changed() -> void:
	_update_percentage(_master_label, "MASTER VOLUME", _master_slider.value)
	_update_percentage(_music_label, "MUSIC VOLUME", _music_slider.value)
	_update_percentage(_sfx_label, "SFX VOLUME", _sfx_slider.value)
	_settings_manager.translate_tree(self)

func _open_menu() -> void:
	var error_code: int = get_tree().change_scene_to_file(MENU_SCENE)
	if error_code != OK:
		push_error("No se pudo volver al menú: %s" % error_string(error_code))
