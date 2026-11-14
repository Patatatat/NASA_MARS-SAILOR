extends Control

const MENU_SCENE: String = "res://scenes/MenuMarsSinner.tscn"
const SOUND_VALUES_META: String = "mars_sound_percentages"
const DEFAULT_SOUND_VALUES: Dictionary = {"master": 0, "music": 0, "sfx": 0}

@onready var _back_button: Button = $CenterContainer/PanelContainer/VBoxContainer/BtnBack
@onready var _master_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/Master_volume_HSlider
@onready var _music_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/Music_volume_HSlider
@onready var _sfx_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/SFX_volume_HSlider
@onready var _master_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Master_volume_Label
@onready var _music_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Music_volume_label
@onready var _sfx_label: Label = $CenterContainer/PanelContainer/VBoxContainer/SFX_volume_label

func _ready() -> void:
	_back_button.pressed.connect(_open_menu)
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

func _get_sound_values() -> Dictionary:
	var saved_values: Variant = get_tree().root.get_meta(SOUND_VALUES_META, DEFAULT_SOUND_VALUES)
	var values: Dictionary = DEFAULT_SOUND_VALUES.duplicate(true)
	if saved_values is Dictionary:
		for key: String in values.keys():
			values[key] = clampi(roundi(float(saved_values.get(key, values[key]))), 0, 100)
	return values

func _save_sound_value(key: String, value: float) -> void:
	var values := _get_sound_values()
	values[key] = clampi(roundi(value), 0, 100)
	get_tree().root.set_meta(SOUND_VALUES_META, values)

func _open_menu() -> void:
	var error_code: int = get_tree().change_scene_to_file(MENU_SCENE)
	if error_code != OK:
		push_error("No se pudo volver al menú: %s" % error_string(error_code))
