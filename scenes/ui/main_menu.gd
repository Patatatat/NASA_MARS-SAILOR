class_name MainMenu
extends Control

signal start_requested(profiles: Array[StringName])
signal continue_requested()

const AUTOSAVE_PATH := "user://saves/autosave.json"
const SETTINGS_MENU_SCENE: PackedScene = preload("res://scenes/ui/settings_menu.tscn")

var _canvas: Control
var _settings_menu: SettingsMenu
var _page: StringName = &"main"
var _rows: Array[Dictionary] = []
var _selected_index := -1
var _continue_button: Button
var _new_game_button: Button
var _back_button: Button
var _chooser: AstronautSelect
var _message: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiHelpers.mission_theme()
	_canvas = UiHelpers.create_menu_canvas(self)
	SignalBus.language_changed.connect(_on_language_changed)
	_render_main()

func _render_main() -> void:
	_page = &"main"
	_canvas.visible = true
	UiHelpers.clear(_canvas)
	UiHelpers.add_menu_background(_canvas, Vector2(-128.0, 178.0))
	_rows.clear()
	_selected_index = -1
	_message = null
	_continue_button = null
	_new_game_button = null
	_back_button = null

	var title := UiHelpers.add_menu_label(_canvas, "b e y o n d\n o u r  h o m e", Vector2(91.0, 60.0), Vector2(1395.0, 230.0), 96)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_add_menu_row(_tr(&"menu.continue"), Vector2(81.0, 452.0), Vector2(421.0, 73.0), 40,
		Vector2(10.0, 0.0), _continue_or_start, true)
	_continue_button = _rows.back()["button"]
	_add_menu_row(_tr(&"menu.new_game"), Vector2(81.0, 545.0), Vector2(421.0, 73.0), 40,
		Vector2.ZERO, _show_select)
	_new_game_button = _rows.back()["button"]
	_add_menu_row(_tr(&"menu.settings"), Vector2(81.0, 638.0), Vector2(421.0, 73.0), 40,
		Vector2.ZERO, _show_settings)
	_add_menu_row(_tr(&"menu.credits"), Vector2(81.0, 731.0), Vector2(421.0, 73.0), 40,
		Vector2.ZERO, _show_credits)
	_add_menu_row(_tr(&"ui.back"), Vector2(81.0, 824.0), Vector2(421.0, 73.0), 40,
		Vector2(8.0, 0.0), _quit)

	var has_save := FileAccess.file_exists(AUTOSAVE_PATH)
	_selected_index = 0 if has_save else 1
	for index in _rows.size():
		UiHelpers.animate_menu_option(_rows[index], index == _selected_index, true)
	(_continue_button if has_save else _new_game_button).grab_focus()
	refresh_availability()

func show_main_menu() -> void:
	if is_instance_valid(_settings_menu):
		remove_child(_settings_menu)
		_settings_menu.queue_free()
		_settings_menu = null
	_render_main()

func _add_menu_row(text_value: String, position_value: Vector2, size_value: Vector2, font_size: int,
		text_offset: Vector2, action: Callable, header: bool = false) -> void:
	var index := _rows.size()
	var option := UiHelpers.make_menu_option(_canvas, text_value, position_value, size_value,
		font_size, text_offset, action, header)
	_rows.append(option)
	var button: Button = option["button"]
	button.mouse_entered.connect(_select_menu_row.bind(index))
	button.mouse_exited.connect(_clear_menu_row.bind(index))
	button.focus_entered.connect(_select_menu_row.bind(index))
	button.focus_exited.connect(_clear_menu_row.bind(index))

func _select_menu_row(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	_selected_index = index
	for row_index in _rows.size():
		UiHelpers.animate_menu_option(_rows[row_index], row_index == _selected_index)

func _clear_menu_row(index: int) -> void:
	if _selected_index != index or index < 0 or index >= _rows.size():
		return
	_selected_index = -1
	UiHelpers.animate_menu_option(_rows[index], false)

func _continue_or_start() -> void:
	continue_requested.emit()

func refresh_availability() -> void:
	if is_instance_valid(_continue_button):
		_continue_button.disabled = not FileAccess.file_exists(AUTOSAVE_PATH)
		_continue_button.tooltip_text = "" if FileAccess.file_exists(AUTOSAVE_PATH) else _tr(&"ui.continue_starts_new")

func _show_select() -> void:
	_page = &"select"
	UiHelpers.clear(_canvas)
	var background := ColorRect.new()
	background.color = Color("0b0e18")
	background.size = UiHelpers.MENU_DESIGN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(background)
	_chooser = AstronautSelect.new()
	_chooser.position = Vector2.ZERO
	_chooser.size = UiHelpers.MENU_DESIGN_SIZE
	_canvas.add_child(_chooser)
	_chooser.start_requested.connect(func(ids: Array[StringName]): start_requested.emit(ids))
	_rows.clear()
	_add_menu_row(_tr(&"ui.back"), Vector2(81.0, 980.0), Vector2(421.0, 73.0), 40,
		Vector2(8.0, 0.0), _render_main)
	_back_button = _rows.back()["button"]
	for index in _rows.size():
		UiHelpers.animate_menu_option(_rows[index], index == 0, true)
	_back_button.grab_focus()

func _show_settings() -> void:
	_page = &"settings"
	_canvas.visible = false
	_settings_menu = SETTINGS_MENU_SCENE.instantiate() as SettingsMenu
	_settings_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_settings_menu)
	_settings_menu.back_requested.connect(_return_from_settings)

func _return_from_settings() -> void:
	if is_instance_valid(_settings_menu):
		remove_child(_settings_menu)
		_settings_menu.queue_free()
		_settings_menu = null
	_render_main()

func _show_credits() -> void:
	if is_instance_valid(_message):
		_message.queue_free()
	_message = UiHelpers.add_menu_label(_canvas, _tr(&"ui.credits_message"),
		Vector2(81.0, 895.0), Vector2(900.0, 55.0), 24)
	_message.modulate.a = 0.0
	var tween := _message.create_tween()
	tween.tween_property(_message, "modulate:a", 1.0, 0.2)

func _quit() -> void:
	if OS.has_feature("web"):
		show_message(_tr(&"ui.web_quit"))
	else:
		get_tree().quit()

func show_message(value: String) -> void:
	if not is_instance_valid(_canvas):
		return
	if is_instance_valid(_message):
		_message.queue_free()
	_message = UiHelpers.add_menu_label(_canvas, value, Vector2(81.0, 895.0), Vector2(1100.0, 60.0), 24)

func _on_language_changed(_code: StringName) -> void:
	if _page == &"main":
		_render_main()
	elif _page == &"select":
		if is_instance_valid(_chooser):
			_chooser.refresh()
		if is_instance_valid(_back_button):
			_back_button.text = _tr(&"ui.back")

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if _page == &"select":
			_render_main()
		elif _page == &"main":
			_quit()
		get_viewport().set_input_as_handled()

func _tr(key: StringName) -> String:
	return get_tree().root.get_node("LocalizationDB").translate_key(key)
