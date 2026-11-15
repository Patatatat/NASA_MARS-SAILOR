class_name SettingsMenu
extends Control

signal back_requested()
signal main_menu_requested()
signal save_requested()

const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080"]

var _canvas: Control
var _page: StringName = &"settings"
var _rows: Array[Dictionary] = []
var _selected_index := -1
var _in_game := false
var _settings_opened_from_pause := false
var _feedback_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiHelpers.mission_theme()
	_canvas = UiHelpers.create_menu_canvas(self)
	SignalBus.language_changed.connect(_on_language_changed)
	_render_page()

func _render_page() -> void:
	_rows.clear()
	_selected_index = -1
	_feedback_label = null
	UiHelpers.clear(_canvas)
	if _in_game:
		if _page == &"pause":
			_add_pause_backdrop(0.42)
		else:
			_add_compact_settings_backdrop()
	else:
		UiHelpers.add_menu_background(_canvas, _background_position())
	match _page:
		&"pause":
			_render_pause()
		&"settings":
			if _in_game:
				_render_compact_settings()
			else:
				_render_settings()
		&"sound":
			if _in_game:
				_render_compact_sound()
			else:
				_render_sound()
		&"language":
			if _in_game:
				_render_compact_language()
			else:
				_render_language()
		&"screen":
			if _in_game:
				_render_compact_screen()
			else:
				_render_screen()
	if _page != &"pause":
		if _in_game:
			_add_compact_back_button()
		else:
			_add_back_button()

func open_pause_menu() -> void:
	_in_game = true
	_settings_opened_from_pause = false
	_page = &"pause"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_render_page()

func open_game_settings() -> void:
	_in_game = true
	_settings_opened_from_pause = false
	_page = &"settings"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_render_page()

func _add_pause_backdrop(alpha: float) -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.012, 0.018, 0.03, alpha)
	backdrop.position = Vector2.ZERO
	backdrop.size = UiHelpers.MENU_DESIGN_SIZE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(backdrop)

func _add_overlay_panel(position_value: Vector2, size_value: Vector2, fill: Color, radius: int) -> void:
	var panel := Panel.new()
	panel.position = position_value
	panel.size = size_value
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.88, 0.78, 0.66, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(0.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(panel)

func _add_pause_panel() -> void:
	_add_overlay_panel(Vector2(670.0, 132.0), Vector2(580.0, 816.0),
		Color(80.0 / 255.0, 60.0 / 255.0, 44.0 / 255.0, 0.9), 34)
	var title := UiHelpers.add_menu_label(_canvas, _tr(&"menu.pause_title"),
		Vector2(700.0, 174.0), Vector2(520.0, 104.0), 68)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add_pause_action(_tr(&"ui.main_menu"), Vector2(725.0, 316.0), func(): main_menu_requested.emit())
	_add_pause_action(_tr(&"menu.settings"), Vector2(725.0, 447.0), _open_settings_from_pause)
	_add_pause_action(_tr(&"ui.save_game"), Vector2(725.0, 578.0), func(): save_requested.emit())
	_add_pause_action(_tr(&"ui.back"), Vector2(725.0, 709.0), func(): back_requested.emit())

func _add_pause_action(label: String, position_value: Vector2, action: Callable) -> void:
	_add_pill_button(label, position_value, Vector2(470.0, 92.0), action)

func _add_pill_button(label: String, position_value: Vector2, size_value: Vector2,
		action: Callable, font_size: int = 40, selected: bool = false) -> void:
	var button := Button.new()
	button.text = label
	button.position = position_value
	button.size = size_value
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", UiHelpers.MENU_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _pause_button_style(Color("67594f") if selected else Color("565452")))
	button.add_theme_stylebox_override("hover", _pause_button_style(Color("716e6b")))
	button.add_theme_stylebox_override("pressed", _pause_button_style(Color("454341")))
	button.add_theme_stylebox_override("focus", _pause_button_style(Color("716e6b")))
	button.pressed.connect(action)
	_canvas.add_child(button)

func _pause_button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(46)
	style.set_content_margin_all(12.0)
	return style

func _add_compact_settings_backdrop() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.008, 0.012, 0.02, 0.16)
	dimmer.position = Vector2.ZERO
	dimmer.size = UiHelpers.MENU_DESIGN_SIZE
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(dimmer)

func _render_pause() -> void:
	_add_pause_panel()

func _open_settings_from_pause() -> void:
	_settings_opened_from_pause = true
	_show_page(&"settings")

func _add_compact_panel(position_value: Vector2, size_value: Vector2) -> void:
	_add_overlay_panel(position_value, size_value,
		Color(80.0 / 255.0, 60.0 / 255.0, 44.0 / 255.0, 0.86), 34)

func _add_compact_title(text_value: String, position_value: Vector2, size_value: Vector2,
		font_size: int = 64) -> void:
	var title := UiHelpers.add_menu_label(_canvas, text_value, position_value, size_value, font_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _render_compact_settings() -> void:
	_add_compact_panel(Vector2(630.0, 130.0), Vector2(660.0, 820.0))
	_add_compact_title(_tr(&"menu.settings"), Vector2(680.0, 174.0), Vector2(560.0, 98.0))
	_add_pill_button(_tr(&"settings.section.sound"), Vector2(725.0, 310.0), Vector2(470.0, 86.0),
		func(): _show_page(&"sound"), 38)
	_add_pill_button(_tr(&"settings.section.language"), Vector2(725.0, 430.0), Vector2(470.0, 86.0),
		func(): _show_page(&"language"), 38)
	_add_pill_button(_tr(&"settings.section.screen"), Vector2(725.0, 550.0), Vector2(470.0, 86.0),
		func(): _show_page(&"screen"), 38)

func _render_compact_sound() -> void:
	_add_compact_panel(Vector2(550.0, 90.0), Vector2(820.0, 900.0))
	_add_compact_title(_tr(&"settings.sound_title"), Vector2(590.0, 128.0), Vector2(740.0, 90.0), 60)
	var settings: Dictionary = SettingsService.get_settings()
	var controls := [
		{"label": &"settings.volume", "key": "master_volume", "y": 270.0},
		{"label": &"settings.sfx", "key": "sfx_volume", "y": 425.0},
		{"label": &"settings.music", "key": "ambient_volume", "y": 580.0}
	]
	for control in controls:
		UiHelpers.add_menu_label(_canvas, _tr(control["label"]),
			Vector2(625.0, control["y"]), Vector2(670.0, 50.0), 34)
		var slider := HSlider.new()
		slider.position = Vector2(625.0, control["y"] + 57.0)
		slider.size = Vector2(670.0, 48.0)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = float(settings.get(control["key"], 0.8))
		_style_slider(slider)
		slider.value_changed.connect(_on_volume_changed.bind(String(control["key"])))
		_canvas.add_child(slider)

func _render_compact_language() -> void:
	_add_compact_panel(Vector2(610.0, 140.0), Vector2(700.0, 800.0))
	_add_compact_title(_tr(&"settings.language_title"), Vector2(660.0, 180.0), Vector2(600.0, 90.0), 60)
	var current_language := String(SettingsService.get_settings().get("language", "es"))
	_add_pill_button(_tr(&"settings.english"), Vector2(725.0, 340.0), Vector2(470.0, 88.0),
		_choose_language.bind("en"), 38, current_language == "en")
	_add_pill_button(_tr(&"settings.spanish"), Vector2(725.0, 465.0), Vector2(470.0, 88.0),
		_choose_language.bind("es"), 38, current_language == "es")

func _render_compact_screen() -> void:
	_add_compact_panel(Vector2(550.0, 90.0), Vector2(820.0, 900.0))
	_add_compact_title(_tr(&"settings.screen_title"), Vector2(590.0, 128.0), Vector2(740.0, 90.0), 60)
	var settings: Dictionary = SettingsService.get_settings()
	var fullscreen := bool(settings.get("fullscreen", false))
	var fullscreen_text := ("✓  " if fullscreen else "□  ") + _tr(&"settings.fullscreen")
	_add_pill_button(fullscreen_text, Vector2(725.0, 300.0), Vector2(470.0, 86.0),
		_toggle_fullscreen, 34, fullscreen)
	UiHelpers.add_menu_label(_canvas, _tr(&"settings.resolution"),
		Vector2(625.0, 438.0), Vector2(670.0, 54.0), 34)
	var resolution := OptionButton.new()
	resolution.position = Vector2(625.0, 500.0)
	resolution.size = Vector2(670.0, 76.0)
	resolution.add_theme_font_override("font", UiHelpers.MENU_FONT)
	resolution.add_theme_font_size_override("font_size", 34)
	resolution.add_theme_color_override("font_color", Color.WHITE)
	resolution.add_theme_color_override("font_hover_color", Color.WHITE)
	resolution.add_theme_color_override("font_pressed_color", Color.WHITE)
	var resolution_style := _pause_button_style(Color("565452"))
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		resolution.add_theme_stylebox_override(state, resolution_style.duplicate())
	for value in RESOLUTIONS:
		resolution.add_item(_format_resolution(value))
	var current_index := RESOLUTIONS.find(String(settings.get("resolution", "1920x1080")))
	resolution.select(maxi(0, current_index))
	resolution.item_selected.connect(_on_resolution_selected)
	_canvas.add_child(resolution)

func _add_compact_back_button() -> void:
	var y_position := 715.0
	match _page:
		&"sound": y_position = 825.0
		&"language": y_position = 700.0
		&"screen": y_position = 760.0
	_add_pill_button(_tr(&"ui.back"), Vector2(725.0, y_position), Vector2(470.0, 86.0),
		_back_from_header, 38)

func _background_position() -> Vector2:
	match _page:
		&"settings": return Vector2(-141.0, 162.0)
		&"sound": return Vector2(-152.0, 178.0)
		&"language": return Vector2(-106.0, 178.0)
		&"screen": return Vector2(-139.0, 178.0)
	return Vector2(-141.0, 162.0)

func _add_header(text_value: String) -> void:
	var action := Callable(self, "_back_from_header")
	var header := UiHelpers.make_menu_option(_canvas, text_value, Vector2(78.0, 69.0),
		Vector2(513.0, 109.0), 64, Vector2(7.0, 0.0), action, true)
	UiHelpers.animate_menu_option(header, false, true)
	var button: Button = header["button"]
	button.tooltip_text = _tr(&"ui.resume") if _page == &"pause" else _tr(&"ui.back")
	button.mouse_entered.connect(func(): UiHelpers.animate_menu_option(header, true))
	button.mouse_exited.connect(func(): UiHelpers.animate_menu_option(header, false))
	button.focus_entered.connect(func(): UiHelpers.animate_menu_option(header, true))
	button.focus_exited.connect(func(): UiHelpers.animate_menu_option(header, false))

func _render_settings() -> void:
	_add_header(_tr(&"menu.settings"))
	_add_option(_tr(&"settings.section.sound"), Vector2(78.0, 276.0), Vector2(513.0, 90.0),
		Vector2(59.0, 0.0), func(): _show_page(&"sound"))
	_add_option(_tr(&"settings.section.language"), Vector2(78.0, 401.0), Vector2(513.0, 90.0),
		Vector2(59.0, 0.0), func(): _show_page(&"language"))
	_add_option(_tr(&"settings.section.screen"), Vector2(78.0, 541.0), Vector2(513.0, 90.0),
		Vector2(59.0, 0.0), func(): _show_page(&"screen"))

func _render_sound() -> void:
	_add_header(_tr(&"settings.sound_title"))
	var settings: Dictionary = SettingsService.get_settings()
	var controls := [
		{"label": &"settings.volume", "key": "master_volume", "label_pos": Vector2(137.0, 282.0), "slider_pos": Vector2(403.0, 299.0)},
		{"label": &"settings.sfx", "key": "sfx_volume", "label_pos": Vector2(137.0, 417.0), "slider_pos": Vector2(296.0, 434.0)},
		{"label": &"settings.music", "key": "ambient_volume", "label_pos": Vector2(137.0, 552.0), "slider_pos": Vector2(376.0, 575.0)}
	]
	for control in controls:
		UiHelpers.add_menu_label(_canvas, _tr(control["label"]), control["label_pos"], Vector2(300.0, 90.0), 64)
		var slider := HSlider.new()
		slider.position = control["slider_pos"]
		slider.size = Vector2(664.0, 60.0)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = float(settings.get(control["key"], 0.8))
		_style_slider(slider)
		slider.value_changed.connect(_on_volume_changed.bind(String(control["key"])))
		_canvas.add_child(slider)

func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(217.0 / 255.0, 217.0 / 255.0, 217.0 / 255.0, 0.72)
	track.set_corner_radius_all(8)
	track.set_content_margin_all(0.0)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", track.duplicate())
	slider.add_theme_stylebox_override("grabber_area_highlight", track.duplicate())
	slider.add_theme_icon_override("grabber", UiHelpers.MENU_SLIDER_THUMB)
	slider.add_theme_icon_override("grabber_highlight", UiHelpers.MENU_SLIDER_THUMB)
	slider.add_theme_icon_override("grabber_disabled", UiHelpers.MENU_SLIDER_THUMB)

func _on_volume_changed(value: float, setting_key: String) -> void:
	SettingsService.apply_settings({setting_key: value})

func _render_language() -> void:
	_add_header(_tr(&"settings.language_title"))
	var current_language := String(SettingsService.get_settings().get("language", "es"))
	var choices := [
		{"code": "en", "label": &"settings.english", "outer": UiHelpers.MENU_RADIO_OUTER},
		{"code": "es", "label": &"settings.spanish", "outer": UiHelpers.MENU_RADIO_OUTER_ALT}
	]
	for index in choices.size():
		var choice: Dictionary = choices[index]
		var language_code := String(choice["code"])
		var y := 298.0 + 114.0 * index
		var option := _add_option("", Vector2(78.0, y), Vector2(600.0, 80.0), Vector2.ZERO,
			_choose_language.bind(language_code))
		var outer := TextureRect.new()
		outer.texture = choice["outer"]
		outer.position = Vector2(0.0, 15.0)
		outer.size = Vector2(60.0, 61.0)
		outer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		outer.stretch_mode = TextureRect.STRETCH_SCALE
		outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		option["row"].add_child(outer)
		if String(choice["code"]) == current_language:
			var inner := TextureRect.new()
			inner.texture = UiHelpers.MENU_RADIO_INNER
			inner.position = Vector2(13.0, 27.0)
			inner.size = Vector2(34.0, 38.0)
			inner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			inner.stretch_mode = TextureRect.STRETCH_SCALE
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			option["row"].add_child(inner)
		var label := UiHelpers.add_menu_label(option["row"], _tr(choice["label"]),
			Vector2(75.0, 0.0), Vector2(490.0, 80.0), 64)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _choose_language(code: String) -> void:
	SettingsService.apply_settings({"language": code})

func _render_screen() -> void:
	_add_header(_tr(&"settings.screen_title"))
	var settings: Dictionary = SettingsService.get_settings()
	var fullscreen_row := _add_option("", Vector2(78.0, 298.0), Vector2(600.0, 80.0), Vector2.ZERO,
		_toggle_fullscreen)
	var outer := TextureRect.new()
	outer.texture = UiHelpers.MENU_RADIO_OUTER
	outer.position = Vector2(0.0, 15.0)
	outer.size = Vector2(60.0, 61.0)
	outer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	outer.stretch_mode = TextureRect.STRETCH_SCALE
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullscreen_row["row"].add_child(outer)
	if bool(settings.get("fullscreen", false)):
		var inner := TextureRect.new()
		inner.texture = UiHelpers.MENU_RADIO_INNER
		inner.position = Vector2(13.0, 27.0)
		inner.size = Vector2(34.0, 38.0)
		inner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		inner.stretch_mode = TextureRect.STRETCH_SCALE
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fullscreen_row["row"].add_child(inner)
	var fullscreen_label := UiHelpers.add_menu_label(fullscreen_row["row"], _tr(&"settings.fullscreen"),
		Vector2(75.0, 0.0), Vector2(500.0, 80.0), 64)
	fullscreen_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	UiHelpers.add_menu_label(_canvas, _tr(&"settings.resolution"),
		Vector2(106.0, 440.0), Vector2(365.0, 85.0), 64)
	var resolution := OptionButton.new()
	resolution.position = Vector2(461.0, 450.0)
	resolution.size = Vector2(311.0, 66.0)
	resolution.add_theme_font_override("font", UiHelpers.MENU_FONT)
	resolution.add_theme_font_size_override("font_size", 36)
	resolution.add_theme_color_override("font_color", Color.WHITE)
	resolution.add_theme_color_override("font_hover_color", Color.WHITE)
	resolution.add_theme_color_override("font_pressed_color", Color.WHITE)
	resolution.add_theme_constant_override("h_separation", 8)
	var orange := StyleBoxFlat.new()
	orange.bg_color = Color(247.0 / 255.0, 117.0 / 255.0, 66.0 / 255.0, 0.38)
	orange.set_content_margin_all(8.0)
	orange.content_margin_left = 24.0
	orange.content_margin_right = 18.0
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		resolution.add_theme_stylebox_override(state, orange.duplicate())
	var blank_arrow_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	blank_arrow_image.fill(Color.TRANSPARENT)
	resolution.add_theme_icon_override("arrow", ImageTexture.create_from_image(blank_arrow_image))
	for value in RESOLUTIONS:
		resolution.add_item(_format_resolution(value))
	var current_index := RESOLUTIONS.find(String(settings.get("resolution", "1920x1080")))
	resolution.select(maxi(0, current_index))
	resolution.item_selected.connect(_on_resolution_selected)
	_canvas.add_child(resolution)
	var arrow := UiHelpers.add_menu_label(_canvas, ">", Vector2(690.0, 470.0), Vector2(77.0, 55.0), 64)
	arrow.pivot_offset = arrow.size * 0.5
	arrow.rotation_degrees = 91.37
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _add_back_button() -> void:
	var index := _rows.size()
	var back := UiHelpers.make_menu_option(_canvas, _tr(&"ui.back"), Vector2(81.0, 787.0),
		Vector2(421.0, 73.0), 40, Vector2(8.0, 0.0), _back_from_header)
	_rows.append(back)
	var button: Button = back["button"]
	button.mouse_entered.connect(_select_menu_row.bind(index))
	button.focus_entered.connect(_select_menu_row.bind(index))

func _toggle_fullscreen() -> void:
	var current := bool(SettingsService.get_settings().get("fullscreen", false))
	SettingsService.apply_settings({"fullscreen": not current})
	_render_page()

func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < RESOLUTIONS.size():
		SettingsService.apply_settings({"resolution": RESOLUTIONS[index]})
		_render_page()

func _format_resolution(value: String) -> String:
	return value.replace("x", " x ")

func _add_option(text_value: String, position_value: Vector2, size_value: Vector2,
		text_offset: Vector2, action: Callable) -> Dictionary:
	var index := _rows.size()
	var option := UiHelpers.make_menu_option(_canvas, text_value, position_value, size_value,
		64, text_offset, action)
	_rows.append(option)
	var button: Button = option["button"]
	button.mouse_entered.connect(_select_menu_row.bind(index))
	button.mouse_exited.connect(_clear_menu_row.bind(index))
	button.focus_entered.connect(_select_menu_row.bind(index))
	button.focus_exited.connect(_clear_menu_row.bind(index))
	return option

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

func show_feedback(text_value: String) -> void:
	if is_instance_valid(_feedback_label):
		_feedback_label.queue_free()
	_feedback_label = UiHelpers.add_menu_label(_canvas, text_value,
		Vector2(700.0, 704.0), Vector2(520.0, 60.0), 30)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _show_page(page: StringName) -> void:
	_page = page
	_render_page()

func _back_from_header() -> void:
	match _page:
		&"pause":
			back_requested.emit()
		&"settings":
			if _in_game:
				if _settings_opened_from_pause:
					_show_page(&"pause")
				else:
					back_requested.emit()
			else:
				back_requested.emit()
		_:
			_show_page(&"settings")

func _on_language_changed(_code: StringName) -> void:
	_render_page()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_back_from_header()
	get_viewport().set_input_as_handled()

func _tr(key: StringName) -> String:
	return get_tree().root.get_node("LocalizationDB").translate_key(key)
