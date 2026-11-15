extends Node

var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var resolutions: Array[Dictionary] = []
var menu: MainMenu
var submitted: Array = []

func _ready() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("FAIL: ", message)

func settle() -> void:
	for frame in 5:
		await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout

func find_button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if node.text == text:
			return node
	return null

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		get_viewport().push_input(event, true)
	await settle()

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var path := "user://menu-%s.png" % label
	get_viewport().get_texture().get_image().save_png(path)
	captures.append(path)

func key(code: Key, target: Viewport = get_viewport()) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		target.push_input(event, true)
	await settle()

func check_controls(label: String) -> void:
	var frame := get_viewport().get_visible_rect()
	var pixel_scale := float(get_window().size.y) / frame.size.y
	if menu._page == &"select":
		var marks := menu.find_children("SIMark", "Label", true, false)
		check(marks.size() == 3, label + ": every visible portrait has an S.I. mark")
		for mark: Label in marks:
			check(mark.text == "S.I." and mark.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				label + ": watermark is labelled and does not intercept selection")
			check(mark.get_parent().get_global_rect().encloses(mark.get_global_rect()), label + ": watermark fits image")
	for control in menu.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree() or not (control is BaseButton or control is Slider):
			continue
		var rect: Rect2 = control.get_global_rect()
		check(frame.grow(1.0).encloses(rect), label + ": control remains inside viewport " + String(control.name))
		check(rect.size.y * pixel_scale >= 43.5, label + ": click target is at least 44 pixels " + String(control.name))

func run() -> void:
	SettingsService.apply_settings({"fullscreen": false, "resolution": "1600x900", "language": "es"})
	menu = preload("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	menu.start_requested.connect(func(ids): submitted.append(ids))
	await settle()
	check(GameState.data.is_empty(), "suite never creates a gameplay session")
	check(menu._continue_button.disabled, "continue disabled without an autosave")
	check(find_button(menu, "Salir") != null, "quit action is labelled Salir rather than Volver")
	await capture("main")
	await click(find_button(menu, "Ajustes"))
	check(menu._page == &"settings", "real mouse opens settings")
	menu._show_settings()
	await settle()
	var settings := menu._settings_menu
	check(menu.find_children("*", "Control", false, false).filter(func(node): return node is SettingsMenu).size() == 1, "repeated settings activation cannot stack overlays")
	settings._show_page(&"sound")
	await settle()
	var sliders := settings.find_children("*", "HSlider", true, false)
	check(sliders.size() == 3, "sound has three sliders")
	for slider: HSlider in sliders:
		check(slider.get_theme_stylebox("slider").get_minimum_size().y >= 8.0, "volume track has visible thickness")
		slider.value = 0.37
		await settle()
		var labels := settings.find_children("*", "Label", true, false)
		check(labels.any(func(label): return label.text == "37%"), "volume percentage updates live")
	var master: HSlider = sliders[0]
	master.grab_focus()
	await key(KEY_RIGHT)
	check(is_equal_approx(master.value, 0.38), "keyboard arrow changes volume by one percent")
	master.value = 0.37
	await click(master)
	check(master.value > 0.45 and master.value < 0.55, "mouse changes volume using the visible track")
	master.value = 0.37
	check(is_equal_approx(SettingsService.get_settings()["master_volume"], 0.37), "volume persists through UI")
	await capture("sound")
	settings._show_page(&"screen")
	await settle()
	for index in SettingsMenu.RESOLUTIONS.size():
		var dropdown: OptionButton = settings.find_children("*", "OptionButton", true, false)[0]
		await click(dropdown)
		check(dropdown.get_popup().visible, "real mouse opens resolution choices")
		# Activate through the popup's public selection signal, exercising its wiring.
		dropdown.get_popup().hide()
		dropdown.get_popup().index_pressed.emit(index)
		await settle()
		var parts: PackedStringArray = SettingsMenu.RESOLUTIONS[index].split("x")
		check(get_window().size == Vector2i(int(parts[0]), int(parts[1])), "window changes to " + SettingsMenu.RESOLUTIONS[index])
		check(get_window().content_scale_size == Vector2i(1280, 720), "resolution preserves the project's logical viewport")
	await click(settings._rows[0]["button"])
	check(get_window().mode == Window.MODE_FULLSCREEN, "fullscreen changes the native window mode")
	await capture("fullscreen")
	settings._on_resolution_selected(0)
	await settle()
	check(get_window().mode == Window.MODE_FULLSCREEN, "resolution change keeps fullscreen active")
	await click(settings._rows[0]["button"])
	check(get_window().mode == Window.MODE_WINDOWED and get_window().size == Vector2i(1280, 720), "exiting fullscreen restores selected window size")
	await capture("screen")
	settings._show_page(&"language")
	settings._choose_language("en")
	await settle()
	check(LocalizationDB.language == &"en" and settings._page == &"language", "language switches without losing the settings page")
	settings._choose_language("es")
	settings._back_from_header()
	settings._back_from_header()
	await settle()
	check(menu._page == &"main" and menu._canvas.visible, "back returns to the main menu")
	await key(KEY_ESCAPE)
	check(is_instance_valid(menu) and menu._page == &"main", "Escape on the main menu does not quit unexpectedly")
	await click(menu._new_game_button)
	await settle()
	var chooser := menu._chooser
	var card: Button
	# Find cards by their size, independent of child order or translated text.
	for node in chooser._content.get_children():
		if node is Button and node.size == AstronautSelect.CARD_SIZE:
			card = node
			break
	card.grab_focus()
	await click(card.find_child("SIMark", true, false))
	check(chooser.selected.size() == 1, "real mouse input selects a portrait")
	check(get_viewport().gui_get_focus_owner() != null and get_viewport().gui_get_focus_owner().is_inside_tree(), "selection preserves keyboard focus after rebuilding cards")
	await key(KEY_ENTER)
	check(chooser.selected.is_empty(), "Enter deselects the focused portrait")
	await key(KEY_ENTER)
	check(chooser.selected.size() == 1, "Enter can select the same portrait again without refocusing")
	chooser.add_profile(&"medic")
	chooser.add_profile(&"botanist_a")
	await click(chooser._content.get_node("PageButton"))
	check(chooser.selected.size() == 3 and chooser._start_button.disabled, "page change retains selection and requires four crew")
	chooser.add_profile(&"scientist_a")
	chooser.add_profile(&"engineer_b")
	check(chooser.selected.size() == 4, "selection cannot exceed four")
	chooser.add_profile(&"medic")
	check(chooser.selected.size() == 4, "selection cannot duplicate an astronaut")
	chooser._toggle_profile(&"scientist_a")
	check(chooser.selected.size() == 3 and chooser._start_button.disabled, "deselecting disables start")
	chooser._toggle_profile(&"scientist_b")
	await settle()
	await capture("crew")
	await click(chooser._start_button)
	check(submitted.size() == 1 and submitted[0].size() == 4, "start emits exactly four chosen profiles without running gameplay")
	check(GameState.data.is_empty(), "menu test leaves gameplay untouched")
	# Layout and keyboard navigation are checked without instantiating MissionMain.
	for window_size in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)]:
		get_window().size = window_size
		await settle()
		check(get_window().size == window_size, "native audit window reaches " + str(window_size))
		resolutions.append({"requested": [window_size.x, window_size.y], "actual": [get_window().size.x, get_window().size.y]})
		for language in ["es", "en"]:
			SettingsService.apply_settings({"language": language})
			menu.show_main_menu()
			await settle()
			check_controls("main %s %s" % [window_size, language])
			menu._show_settings()
			settings = menu._settings_menu
			for page in [&"settings", &"sound", &"language", &"screen"]:
				settings._show_page(page)
				await settle()
				check_controls("%s %s %s" % [page, window_size, language])
			menu.show_main_menu()
			menu._show_select()
			await settle()
			check_controls("crew page 1 %s %s" % [window_size, language])
			menu._chooser._change_page()
			await settle()
			check_controls("crew page 2 %s %s" % [window_size, language])
			await key(KEY_ESCAPE)
			check(menu._page == &"main", "Escape returns from selection " + language)
	# Read valid preferences back from disk before trying a corrupt configuration.
	var expected := SettingsService.get_settings()
	SettingsService._current = SettingsService.DEFAULTS.duplicate(true)
	SettingsService._load_user_settings()
	check(SettingsService.get_settings() == expected, "preferences survive a fresh read from disk")
	for invalid in [{"master_volume": NAN}, {"sfx_volume": INF}, {"language": 42}, {"resolution": []}, {"fullscreen": 1}]:
		check(not SettingsService.apply_settings(invalid).ok, "invalid preference is rejected atomically " + str(invalid))
	check(SettingsService.get_settings() == expected, "rejected preferences leave current values intact")
	# Invalid local configuration must not reach the UI or native window.
	var config := ConfigFile.new()
	config.set_value("settings", "values", {"master_volume": NAN, "ui_scale": -4.0, "language": "invalid", "resolution": "-1x0", "fullscreen": "yes"})
	config.save(SettingsService.USER_SETTINGS_PATH)
	SettingsService._load_user_settings()
	check(is_finite(float(SettingsService._current["master_volume"])), "corrupt saved volume cannot load NaN")
	check(SettingsService._current["ui_scale"] in [1.0, 1.15, 1.25], "corrupt saved UI scale is ignored")
	check(SettingsService._current["fullscreen"] is bool, "corrupt fullscreen type is ignored")
	check(SettingsService.RESOLUTIONS.has(SettingsService._current["resolution"]), "corrupt saved resolution is ignored")
	SettingsService._current = SettingsService.DEFAULTS.duplicate(true)
	SettingsService.apply_settings({"fullscreen": false, "resolution": "1600x900"})
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "captures": captures, "resolutions": resolutions}
	var output := FileAccess.open("user://menu-result.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("MENU QA: ", JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
