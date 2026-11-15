class_name AstronautSelect
extends PanelContainer

signal start_requested(profiles: Array[StringName])

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const CARD_SIZE := Vector2(492.0, 696.0)
const CARD_X := [96.0, 708.0, 1320.0]
const CARD_Y := 222.0
const PAGE_COUNT := 2

var selected: Array[StringName] = []
var _page := 0
var _content: Control
var _counter: Label
var _start_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiHelpers.mission_theme()
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty_style)
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)
	SignalBus.language_changed.connect(refresh)
	refresh()

func refresh(_language: StringName = &"") -> void:
	if not is_instance_valid(_content):
		return
	var focus := get_viewport().gui_get_focus_owner()
	var focus_name := String(focus.name) if focus != null and is_ancestor_of(focus) else ""
	UiHelpers.clear(_content)
	_draw_background_and_title()
	_draw_cards()
	_draw_footer()
	if not focus_name.is_empty():
		var replacement := _content.get_node_or_null(NodePath(focus_name)) as Control
		if replacement == null:
			replacement = _content.get_node("PageButton")
		replacement.grab_focus()

func add_profile(id: StringName) -> void:
	if selected.size() < 4 and _is_selectable(id) and not selected.has(id):
		selected.append(id)
		refresh()

func remove_last() -> void:
	if not selected.is_empty():
		selected.pop_back()
		refresh()

func _draw_background_and_title() -> void:
	var background := ColorRect.new()
	background.color = Color("0b0e18")
	background.size = DESIGN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(background)

	var title_strip := Panel.new()
	title_strip.position = Vector2(54.0, 54.0)
	title_strip.size = Vector2(900.0, 104.0)
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color("17131b")
	strip_style.border_color = Color("8a4b45")
	strip_style.border_width_left = 3
	strip_style.set_content_margin_all(0.0)
	title_strip.add_theme_stylebox_override("panel", strip_style)
	title_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(title_strip)

	var title := _label(_tr(&"setup.select_crew.title"), 58)
	title.position = Vector2(6.0, 7.0)
	title.size = Vector2(820.0, 90.0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_strip.add_child(title)
	var disclosure := _label(_tr(&"ui.si_disclosure"), 24)
	disclosure.position = Vector2(96, 172)
	disclosure.size = Vector2(1716, 38)
	_content.add_child(disclosure)

func _draw_cards() -> void:
	var profiles := _page_profiles()
	for index in profiles.size():
		_create_card(profiles[index], Vector2(CARD_X[index], CARD_Y))

func _page_profiles() -> Array[Dictionary]:
	var first_page: Array[Dictionary] = [
		{"id": &"engineer_a", "name": &"crew.name.kalpana", "role": &"crew.role.engineer", "portrait": "res://assets/tripulacion/assents/Designer (3).png", "region": Rect2(0.0, 0.0, 1024.0, 1536.0)},
		{"id": &"medic", "name": &"crew.name.mae", "role": &"crew.role.doctor", "portrait": "res://assets/tripulacion/assents/Designer (4).png", "region": Rect2(1024.0, 0.0, 512.0, 1024.0)},
		{"id": &"botanist_a", "name": &"crew.name.gioia", "role": &"crew.role.botany", "portrait": "res://assets/tripulacion/assents/Designer (4).png", "region": Rect2(512.0, 0.0, 512.0, 1024.0)}
	]
	var second_page: Array[Dictionary] = [
		{"id": &"scientist_a", "name": &"crew.name.jose", "role": &"crew.role.scientist", "portrait": "res://assets/tripulacion/assents/Designer (4).png", "region": Rect2(0.0, 0.0, 512.0, 1024.0)},
		{"id": &"scientist_b", "name": &"crew.name.harrison", "role": &"crew.role.geologist", "portrait": "res://assets/tripulacion/assents/Designer (6).png", "region": Rect2(0.0, 0.0, 554.0, 1024.0)},
		{"id": &"engineer_b", "name": &"crew.name.franklin", "role": &"crew.role.systems", "portrait": "res://assets/tripulacion/assents/Designer (6).png", "region": Rect2(554.0, 0.0, 554.0, 1024.0)}
	]
	return first_page if _page == 0 else second_page

func _create_card(profile: Dictionary, position_value: Vector2) -> void:
	var id: StringName = profile["id"]
	var is_selected := selected.has(id)
	var card := Button.new()
	card.name = "Card_" + String(id)
	card.position = position_value
	card.size = CARD_SIZE
	card.text = ""
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = _tr(StringName("profile.tip.%s" % id))
	card.add_theme_stylebox_override("normal", _card_style(is_selected, false))
	card.add_theme_stylebox_override("hover", _card_style(is_selected, true))
	card.add_theme_stylebox_override("pressed", _card_style(true, true))
	card.add_theme_stylebox_override("focus", _card_style(is_selected, true))
	card.pressed.connect(_toggle_profile.bind(id))
	_content.add_child(card)

	var portrait := TextureRect.new()
	portrait.position = Vector2(28.0, 16.0)
	portrait.size = Vector2(436.0, 426.0)
	portrait.texture = _atlas_texture(String(profile["portrait"]), profile["region"])
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(portrait)
	UiHelpers.add_si_mark(portrait, 28)

	var role_text := _tr(StringName(profile["role"]))
	var role_width := 220.0 if role_text.length() < 16 else 330.0
	var badge := Panel.new()
	badge.position = Vector2((CARD_SIZE.x - role_width) * 0.5, 450.0)
	badge.size = Vector2(role_width, 50.0)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("984a2a")
	badge_style.set_corner_radius_all(25)
	badge_style.set_content_margin_all(4.0)
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)
	var role := _label(role_text, 30)
	role.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(role)

	var name_label := _label(_tr(StringName(profile["name"])), 36)
	name_label.position = Vector2(20.0, 506.0)
	name_label.size = Vector2(CARD_SIZE.x - 40.0, 54.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(name_label)

	var description_panel := Panel.new()
	description_panel.position = Vector2(44.0, 568.0)
	description_panel.size = Vector2(CARD_SIZE.x - 88.0, 112.0)
	var description_style := StyleBoxFlat.new()
	description_style.bg_color = Color("343747")
	description_style.set_corner_radius_all(20)
	description_style.set_content_margin_all(12.0)
	description_panel.add_theme_stylebox_override("panel", description_style)
	description_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(description_panel)
	var description := _label(_tr(StringName("profile.tip.%s" % id)), 25)
	description.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_panel.add_child(description)

	if is_selected:
		var check := _label("✓", 34)
		check.position = Vector2(CARD_SIZE.x - 60.0, 12.0)
		check.size = Vector2(42.0, 48.0)
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.add_theme_color_override("font_color", Color("ffd3b3"))
		card.add_child(check)

func _draw_footer() -> void:
	_counter = _label(_tr(&"setup.select_crew.counter", {"selected": selected.size()}), 27)
	_counter.position = Vector2(620.0, 920.0)
	_counter.size = Vector2(680.0, 38.0)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_content.add_child(_counter)

	var help := _label(_tr(&"ui.crew_select_help"), 20)
	help.position = Vector2(510.0, 955.0)
	help.size = Vector2(900.0, 30.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(help)

	_start_button = Button.new()
	_start_button.text = _tr(&"setup.select_crew.start")
	_start_button.position = Vector2(710.0, 990.0)
	_start_button.size = Vector2(500.0, 88.0)
	_start_button.disabled = selected.size() != 4
	_start_button.tooltip_text = _tr(&"setup.select_crew.required") if _start_button.disabled else _tr(&"ui.start_ready")
	_start_button.add_theme_font_override("font", UiHelpers.MENU_FONT)
	_start_button.add_theme_font_size_override("font_size", 32)
	_start_button.add_theme_stylebox_override("normal", _action_style(false))
	_start_button.add_theme_stylebox_override("hover", _action_style(true))
	_start_button.add_theme_stylebox_override("pressed", _action_style(true))
	_start_button.add_theme_stylebox_override("disabled", _action_style(false, true))
	_start_button.pressed.connect(_start)
	_content.add_child(_start_button)

	var page_button := Button.new()
	page_button.name = "PageButton"
	page_button.text = "→" if _page == 0 else "←"
	page_button.position = Vector2(1770.0, 934.0)
	page_button.size = Vector2(88.0, 88.0)
	page_button.add_theme_font_override("font", UiHelpers.MENU_FONT)
	page_button.add_theme_font_size_override("font_size", 54)
	page_button.add_theme_stylebox_override("normal", _circle_style(false))
	page_button.add_theme_stylebox_override("hover", _circle_style(true))
	page_button.add_theme_stylebox_override("pressed", _circle_style(true))
	page_button.pressed.connect(_change_page)
	_content.add_child(page_button)
	var page_caption := _label(_tr(&"ui.crew_see_more") if _page == 0 else _tr(&"ui.crew_see_previous"), 21)
	page_caption.position = Vector2(1660.0, 1030.0)
	page_caption.size = Vector2(260.0, 30.0)
	page_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(page_caption)

func _toggle_profile(id: StringName) -> void:
	if selected.has(id):
		selected.erase(id)
	elif selected.size() < 4 and _is_selectable(id):
		selected.append(id)
	refresh()

func _change_page() -> void:
	_page = (_page + 1) % PAGE_COUNT
	refresh()

func _start() -> void:
	if selected.size() == 4:
		start_requested.emit(selected.duplicate())

func _is_selectable(id: StringName) -> bool:
	return id in [&"engineer_a", &"medic", &"botanist_a", &"scientist_a", &"scientist_b", &"engineer_b"]

func _atlas_texture(path: String, region: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = load(path) as Texture2D
	result.region = region
	result.filter_clip = true
	return result

func _card_style(is_selected: bool, hovered: bool) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color("1a2030")
	result.border_color = Color("bd6845") if is_selected else (Color("78869d") if hovered else Color("222838"))
	result.set_border_width_all(4 if is_selected else (2 if hovered else 1))
	result.set_corner_radius_all(44)
	result.set_content_margin_all(0.0)
	return result

func _action_style(hovered: bool, disabled: bool = false) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color("984a2a") if hovered else Color("743e32")
	if disabled:
		result.bg_color = Color("303342")
	result.set_corner_radius_all(16)
	result.set_content_margin_all(12.0)
	return result

func _circle_style(hovered: bool) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color("353744") if hovered else Color("242631")
	result.set_corner_radius_all(38)
	result.set_content_margin_all(0.0)
	return result

func _label(value: String, font_size: int) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_override("font", UiHelpers.MENU_FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Color("f1edf1"))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _tr(key: StringName, params: Dictionary = {}) -> String:
	return get_tree().root.get_node("LocalizationDB").translate_key(key, params)
