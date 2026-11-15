extends Control

signal back_requested()

const CATALOG_PATH := "res://data/credits.json"
var _catalog: Dictionary = {}
var _canvas: Control
var _section := &"team"
var _scroll: ScrollContainer
var _content: VBoxContainer
var _team_button: Button
var _references_button: Button
var _back_button: Button
var _feedback: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiHelpers.mission_theme()
	_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_canvas = UiHelpers.create_menu_canvas(self)
	SignalBus.language_changed.connect(_on_language_changed)
	_render()

func _render() -> void:
	UiHelpers.clear(_canvas)
	UiHelpers.add_menu_background(_canvas, Vector2(-128.0, 178.0))
	var panel := Panel.new()
	panel.position = Vector2(170, 70)
	panel.size = Vector2(1580, 940)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.095, 0.085, 0.96)
	style.border_color = Color(0.88, 0.78, 0.66, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(30)
	panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(panel)
	UiHelpers.add_menu_label(_canvas, _tr(&"menu.credits"), Vector2(230, 100), Vector2(1460, 95), 64)
	_team_button = _navigation(_tr(&"credits.team"), Vector2(230, 210), Vector2(570, 88),
		_show_section.bind(&"team"), _section == &"team")
	_references_button = _navigation(_tr(&"credits.references"), Vector2(820, 210), Vector2(870, 88),
		_show_section.bind(&"references"), _section == &"references")
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(230, 325)
	_scroll.size = Vector2(1460, 550)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.scroll_deadzone = 8
	_canvas.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	_scroll.add_child(_content)
	if _section == &"team":
		_render_team()
	else:
		_render_references()
	_back_button = _navigation(_tr(&"ui.back"), Vector2(230, 900), Vector2(330, 88),
		func(): back_requested.emit())
	_feedback = UiHelpers.add_menu_label(_canvas, _tr(&"credits.browser_hint") if _section == &"references" else
		_tr(&"credits.team_hint"), Vector2(605, 907), Vector2(1085, 80), 28)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(_team_button if _section == &"team" else _references_button).grab_focus()

func _navigation(text_value: String, position_value: Vector2, size_value: Vector2,
		action: Callable, selected: bool = false) -> Button:
	var option := UiHelpers.make_menu_option(_canvas, text_value, position_value, size_value,
		38, Vector2(20, 0), action)
	UiHelpers.animate_menu_option(option, selected, true)
	var button: Button = option["button"]
	button.mouse_entered.connect(func(): UiHelpers.animate_menu_option(option, true))
	button.mouse_exited.connect(func(): UiHelpers.animate_menu_option(option, selected or button.has_focus()))
	button.focus_entered.connect(func(): UiHelpers.animate_menu_option(option, true))
	button.focus_exited.connect(func(): UiHelpers.animate_menu_option(option, selected))
	return button

func _show_section(section: StringName) -> void:
	if _section == section:
		return
	_section = section
	_render()

func _text(parent: Node, value: String, font_size: int = 32, muted: bool = false) -> Label:
	var label := UiHelpers.label(value, font_size)
	label.add_theme_font_override("font", UiHelpers.MENU_FONT)
	if muted:
		label.add_theme_color_override("font_color", Color("d7c8bb"))
	parent.add_child(label)
	return label

func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("322921")
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	_content.add_child(panel)
	return UiHelpers.column(panel)

func _render_team() -> void:
	for member: Dictionary in _catalog.get("team", []):
		var card := _card()
		card.custom_minimum_size.y = 60
		var row := UiHelpers.row(card)
		row.add_theme_constant_override("separation", 28)
		_text(row, String(member["name"]), 36)
		var role := _text(row, _tr(StringName(member["role_key"])), 30, true)
		role.size_flags_horizontal = Control.SIZE_FILL
		role.custom_minimum_size.x = 435
		role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _render_references() -> void:
	_text(_content, _tr(&"credits.science_intro"))
	for source: Dictionary in _catalog.get("references", []):
		var card := _card()
		_text(card, _tr(StringName(source["title_key"])), 38)
		_text(card, _tr(StringName(source["fact_key"])))
		_text(card, _tr(StringName(source["limit_key"])), 30, true)
		for citation: Dictionary in source.get("sources", []):
			_text(card, String(citation["provider"]) + " · " + String(citation["title"]), 28, true)
			var button := UiHelpers.button(_tr(&"credits.open_source"), _open_source.bind(String(citation["url"])))
			button.custom_minimum_size.y = 88
			button.add_theme_font_override("font", UiHelpers.MENU_FONT)
			button.add_theme_font_size_override("font_size", 32)
			button.tooltip_text = String(citation["url"])
			button.set_meta("source_url", citation["url"])
			card.add_child(button)
			_text(card, String(citation["url"]), 26, true)
	_text(_content, _tr(&"credits.science_note"), 30, true)

func _open_source(url: String) -> void:
	# Only the bundled, reviewed NASA citations may open an external browser.
	var approved := false
	for source: Dictionary in _catalog.get("references", []):
		for citation: Dictionary in source.get("sources", []):
			if citation["url"] == url and _is_nasa_url(url):
				approved = true
				break
	if not approved or OS.shell_open(url) != OK:
		_feedback.text = _tr(&"credits.link_failed")

func _is_nasa_url(url: String) -> bool:
	for host in ["www.nasa.gov", "ntrs.nasa.gov", "technology.nasa.gov", "science.nasa.gov"]:
		if url.begins_with("https://%s/" % host):
			return true
	return false

func _on_language_changed(_code: StringName) -> void:
	_render()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var viewport := get_viewport()
		back_requested.emit()
		viewport.set_input_as_handled()

func _tr(key: StringName) -> String:
	return LocalizationDB.translate_key(key)
