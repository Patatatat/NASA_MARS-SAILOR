class_name SettingsMenu
extends PanelContainer

var _column: VBoxContainer

func _ready() -> void:
	_column = UiHelpers.column(self)
	SignalBus.language_changed.connect(_refresh)
	_refresh()

func _refresh(_code: StringName = &"") -> void:
	if _column == null:
		return
	UiHelpers.clear(_column)
	_column.add_child(UiHelpers.label(_tr(&"menu.settings"), 24))
	var row := UiHelpers.row(_column)
	row.add_child(UiHelpers.button("Español", func(): _language(&"es")))
	row.add_child(UiHelpers.button("English", func(): _language(&"en")))
	var settings: Dictionary = SettingsService.get_settings()
	_column.add_child(UiHelpers.label(_tr(&"ui.scale_title"), 22))
	_column.add_child(UiHelpers.label(_tr(&"ui.scale_help")))
	var scales := UiHelpers.row(_column)
	for index in 3:
		var scale_value: float = [1.0, 1.15, 1.25][index]
		var choice := UiHelpers.button(_tr(StringName("ui.scale.%d" % index)), func(): SettingsService.apply_settings({"ui_scale": scale_value}); _refresh())
		choice.toggle_mode = true
		choice.button_pressed = is_equal_approx(float(settings.get("ui_scale", 1.0)), scale_value)
		scales.add_child(choice)
	for key in ["master_volume", "sfx_volume", "ambient_volume"]:
		_column.add_child(UiHelpers.label(_tr(StringName("ui.%s" % key))))
		var volume := HSlider.new()
		volume.min_value = 0.0
		volume.max_value = 1.0
		volume.step = 0.05
		volume.custom_minimum_size.y = 36
		volume.value = float(settings.get(key, 0.8))
		volume.value_changed.connect(func(value): SettingsService.apply_settings({key: value}))
		_column.add_child(volume)
	_column.add_child(UiHelpers.button(_tr(&"ui.reactivate_tutorial"), func(): DialogueService.new().reactivate_tutorial()))

func _language(code: StringName) -> void:
	get_tree().root.get_node("SettingsService").apply_settings({"language": String(code)})

func _tr(key: StringName) -> String:
	return get_tree().root.get_node("LocalizationDB").translate_key(key)

