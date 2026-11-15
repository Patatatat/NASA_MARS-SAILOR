class_name MainMenu
extends Control

signal start_requested(profiles: Array[StringName])
signal continue_requested()

var _stack: VBoxContainer
var _page: StringName = &"main"
var _back_button: Button
var _card: PanelContainer
var _continue: Button
var _message: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiHelpers.mission_theme()
	var background := ColorRect.new()
	background.color = Color("1b2737")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_card = PanelContainer.new()
	add_child(_card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(scroll)
	_stack = UiHelpers.column(scroll)
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SignalBus.language_changed.connect(_on_language_changed)
	resized.connect(_layout_card)
	_refresh()
	_layout_card()

func _layout_card() -> void:
	if _card == null:
		return
	var width := minf(840.0, size.x - 40.0)
	var height := minf(480.0 if _page == &"main" else 820.0, size.y - 40.0)
	_card.position = (size - Vector2(width, height)) * 0.5
	_card.size = Vector2(width, height)

func _refresh(_code: StringName = &"") -> void:
	if _stack == null:
		return
	_page = &"main"
	_message = null
	UiHelpers.clear(_stack)
	_stack.add_child(UiHelpers.label(_tr(&"game.title"), 36))
	_stack.add_child(UiHelpers.label(_tr(&"ui.objective")))
	_stack.add_child(UiHelpers.label(_tr(&"ui.menu_intro")))
	_stack.add_child(UiHelpers.button(_tr(&"menu.new_game"), _show_select, true))
	_continue = UiHelpers.button(_tr(&"menu.continue"), func(): continue_requested.emit())
	_stack.add_child(_continue)
	refresh_availability()
	_stack.add_child(UiHelpers.button(_tr(&"menu.settings"), _show_settings))
	_stack.add_child(UiHelpers.button(_tr(&"menu.quit"), _quit))
	_layout_card()

func refresh_availability() -> void:
	if is_instance_valid(_continue):
		_continue.disabled = not FileAccess.file_exists("user://saves/autosave.json")
		_continue.tooltip_text = _tr(&"ui.no_saved_game") if _continue.disabled else ""

func _show_select() -> void:
	_page = &"select"
	UiHelpers.clear(_stack)
	var chooser := AstronautSelect.new()
	_stack.add_child(chooser)
	chooser.start_requested.connect(func(ids): start_requested.emit(ids))
	_back_button = UiHelpers.button(_tr(&"ui.back"), _refresh)
	_stack.add_child(_back_button)
	_layout_card()

func _show_settings() -> void:
	_page = &"settings"
	UiHelpers.clear(_stack)
	var settings := SettingsMenu.new()
	_stack.add_child(settings)
	_back_button = UiHelpers.button(_tr(&"ui.back"), _refresh)
	_stack.add_child(_back_button)
	_layout_card()

func _on_language_changed(_code: StringName) -> void:
	if _page == &"main":
		_refresh()
	elif _back_button != null:
		_back_button.text = _tr(&"ui.back")

func _quit() -> void:
	if OS.has_feature("web"):
		_stack.add_child(UiHelpers.label(_tr(&"ui.web_quit")))
	else:
		get_tree().quit()

func show_message(value: String) -> void:
	if _stack != null:
		if not is_instance_valid(_message) or not _message.is_inside_tree():
			_message = UiHelpers.label(value)
			_stack.add_child(_message)
		_message.text = value

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and _page != &"main" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_refresh()
		get_viewport().set_input_as_handled()

func _tr(key: StringName) -> String:
	return get_tree().root.get_node("LocalizationDB").translate_key(key)

