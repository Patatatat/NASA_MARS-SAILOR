extends Node

var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var menu: MainMenu

func _ready() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("FAIL: ", message)

func settle() -> void:
	for frame in 6:
		await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout

func click(control: Control) -> void:
	await settle()
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

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_viewport().push_input(event, true)
	await settle()

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var path := "user://credits-%s.png" % label
	get_viewport().get_texture().get_image().save_png(path)
	captures.append(path)

func run() -> void:
	SettingsService.apply_settings({"fullscreen": false, "resolution": "1920x1080", "language": "es"})
	menu = preload("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await settle()
	await click(menu._rows[3]["button"])
	check(menu._page == &"credits" and not menu._canvas.visible, "mouse opens dedicated credits window")
	var credits = menu._credits_menu
	menu._show_credits()
	check(menu._credits_menu == credits, "repeated activation cannot duplicate credits")
	check(credits._section == &"team", "development team is first section")
	var expected := ["Emiliano Rafael Mendoza Nava", "Alejandro Maximiliano Luque Varela",
		"Guillermo Alonso Servin Valenzuela", "Iris Anai Chavez Lucero", "Andrés Guluarte Quintero"]
	var roles := ["Programador principal", "Compositor de audio", "Artista 3D", "Artista UI", "Programador secundario"]
	var labels: Array[Node] = credits._content.find_children("*", "Label", true, false)
	for index in expected.size():
		check(labels[index * 2].text == expected[index], "member name and order preserved " + str(index))
		check(labels[index * 2 + 1].text == roles[index], "member role preserved " + str(index))
	check(credits._catalog.references.size() == 11, "all eleven building entries from artist document")
	for source: Dictionary in credits._catalog.references:
		for citation: Dictionary in source.sources:
			check(credits._is_nasa_url(citation.url), "official NASA-hosted source " + source.id)
		for field in ["title_key", "fact_key", "limit_key"]:
			check(LocalizationDB.has_key_in_both(StringName(source[field])), "citation translated " + source[field])
		for building in source.buildings:
			check(ConfigDB.balance.buildings.has(building), "reference maps to an existing building " + building)
	await capture("team-es")
	await click(credits._references_button)
	check(credits._section == &"references", "mouse opens science references")
	var links: Array[Node] = credits._content.find_children("*", "Button", true, false)
	check(links.size() == 15, "all fifteen verified citations have their own source link")
	for link in links:
		check(link.get_meta("source_url") == link.tooltip_text and link.pressed.get_connections().any(
			func(connection): return (connection.callable.get_method() == &"_open_source" and
				connection.callable.get_bound_arguments() == [link.tooltip_text])),
			"source button is wired to displayed official URL")
	await capture("references-es")
	links[-1].grab_focus()
	await settle()
	check(credits._scroll.scroll_vertical > 0, "keyboard focus scrolls to last reference")
	# Allow two logical pixels for integer scroll offsets under fractional canvas scaling.
	check(credits._scroll.get_global_rect().grow(2).encloses(links[-1].get_global_rect()), "last citation link reachable")
	await capture("references-last-es")
	credits._open_source("https://example.com/unlisted")
	check(credits._feedback.text == LocalizationDB.translate_key(&"credits.link_failed"), "unlisted source rejected without opening browser")
	await click(credits._back_button)
	check(menu._page == &"main" and menu._canvas.visible, "back returns to main menu")
	check(get_viewport().gui_get_focus_owner() == menu._rows[3]["button"], "back restores focus to Credits")
	await key(KEY_ENTER)
	check(menu._page == &"credits", "keyboard reopens Credits")
	credits = menu._credits_menu
	check(credits._section == &"team", "reopen starts at team")
	await key(KEY_ESCAPE)
	check(menu._page == &"main" and not is_instance_valid(menu._credits_menu), "Escape closes and removes window")
	for window_size in [Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(3840, 2160), Vector2i(3440, 1440)]:
		get_window().size = window_size
		await settle()
		menu._show_credits()
		credits = menu._credits_menu
		for language in ["es", "en"]:
			SettingsService.apply_settings({"language": language})
			await settle()
			check(menu._page == &"credits", "language change keeps window open")
			for section in [&"team", &"references"]:
				credits._show_section(section)
				await settle()
				var frame := get_viewport().get_visible_rect()
				for control in [credits._team_button, credits._references_button, credits._back_button, credits._scroll]:
					check(frame.grow(1).encloses(control.get_global_rect()), "layout fits %s %s %s" % [window_size, language, section])
					if control is Button:
						check(control.get_global_rect().size.y * get_window().size.y / frame.size.y >= 43.5, "navigation target at least 44 pixels")
				check(credits._scroll.get_h_scroll_bar().max_value <= credits._scroll.size.x + 1, "no horizontal overflow")
				if section == &"team":
					for label: Label in credits._content.find_children("*", "Label", true, false):
						check(credits._scroll.get_global_rect().grow(1).encloses(label.get_global_rect()), "all members visible " + label.text)
				await capture("%s-%dx%d-%s" % [section, window_size.x, window_size.y, language])
		await key(KEY_ESCAPE)
	check(GameState.data.is_empty(), "credits never creates or modifies gameplay")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "captures": captures}
	var output := FileAccess.open("user://credits-result.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("CREDITS QA: ", JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
