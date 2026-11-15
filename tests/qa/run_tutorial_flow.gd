extends Node

var main: MissionMain
var failures: Array[String] = []
var checks := 0
var captures: Array[String] = []
var visited: Array[String] = []

func _ready() -> void:
	main = preload("res://scenes/integration/main.tscn").instantiate()
	add_child(main)
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)

func settle() -> void:
	for frame in 4:
		await get_tree().process_frame

func goal() -> String:
	return String(main.dialogue.get_tutorial_step().get("id", ""))

func expect(id: String) -> void:
	check(goal() == id, "expected goal %s, got %s" % [id, goal()])
	if not visited.has(goal()):
		visited.append(goal())

func find_button(root: Node, text: String) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree():
			return button
	return null

func click(control: Control) -> void:
	await settle()
	if not is_instance_valid(control):
		check(false, "click target exists")
		return
	var scroll := control.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll is ScrollContainer:
		scroll.ensure_control_visible(control)
		await settle()
	var point := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var input := InputEventMouseButton.new()
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = pressed
		input.position = point
		get_viewport().push_input(input, true)
	await settle()

func press(root: Node, key: StringName) -> void:
	await settle()
	var button := find_button(root, LocalizationDB.translate_key(key))
	check(button != null, "button visible: " + String(key))
	if button != null:
		check(not button.disabled, "button enabled: " + String(key))
		await click(button)

func choose(root: Node, metadata: String) -> void:
	await settle()
	for picker in root.find_children("*", "OptionButton", true, false):
		for index in picker.item_count:
			if String(picker.get_item_metadata(index)) == metadata:
				picker.select(index)
				picker.item_selected.emit(index)
				await settle()
				return
	check(false, "option exists: " + metadata)

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var path := "user://tutorial-%s.png" % label
	get_viewport().get_texture().get_image().save_png(path)
	captures.append(path)
	if main.hud._guide.visible:
		check(main.hud.get_global_rect().grow(1.0).encloses(main.hud._guide.get_global_rect()), "robot card fits viewport: " + label)
		var mark := main.hud._guide.find_child("SIMark", true, false) as Label
		check(mark != null and mark.text == "S.I.", "robot carries S.I. mark: " + label)
		if mark != null:
			check(mark.get_parent().get_global_rect().encloses(mark.get_global_rect()), "robot mark fits portrait: " + label)

func reveal_goal() -> void:
	main.dialogue.recall_tutorial()
	await settle()

func place_goal(id: String) -> void:
	expect(id)
	await reveal_goal()
	await press(main.hud._guide, &"onboarding.focus")
	check(not main.hud._guide.visible, "build guidance leaves the placement controls usable")
	await click(main.hud._workspace._place_button)
	check(main.world.placement_type == &"" and not main.hud._workspace._coordinates_open, "successful guided placement exits placement mode")

func resume() -> void:
	if GameClock.get_snapshot().get("paused", false):
		await click(main.hud._time._pause)

func advance_until_pause(max_seconds: float = 120.0) -> void:
	var elapsed := 0.0
	while elapsed < max_seconds and not GameClock.get_snapshot().get("paused", false) and GameState.is_running():
		main.session.update(0.1)
		elapsed += 0.1
	await settle()

func assign_pair() -> void:
	await reveal_goal()
	await press(main.hud._guide, &"onboarding.focus")
	await choose(main.hud._workspace, "crew_4")
	await press(main.hud._workspace, &"ui.assign_worker")
	await choose(main.hud._workspace, "crew_1")
	await press(main.hud._workspace, &"ui.assign_worker")

func run() -> void:
	SettingsService.apply_settings({"show_tutorial": true, "language": "es"})
	main._start_new([&"engineer_a", &"medic", &"botanist_a", &"scientist_a"])
	await settle()
	expect("welcome")
	await capture("welcome")
	await press(main.hud._guide, &"onboarding.learn")
	expect("supplies")
	check(GameClock.get_snapshot()["paused"], "opting into the guide pauses for explanations")
	var time_before: float = GameClock.get_snapshot()["elapsed"]
	main.session.update(4.0)
	check(GameClock.get_snapshot()["elapsed"] == time_before, "reading time does not consume supplies")
	await press(main.hud._guide, &"onboarding.focus")
	check(main.hud._workspace.active_tab == &"resources", "robot opens the resources panel")
	await press(main.hud._guide, &"onboarding.next")
	expect("energy")
	await press(main.hud._guide, &"onboarding.next")
	expect("tunnel")
	await press(main.hud._guide, &"onboarding.act")
	expect("tunnel")
	check(not GameState.data["tutorial"]["completed"].has("tunnel"), "dismissing instructions does not complete construction")
	await click(main.hud._tutorial_button)
	check(main.hud._guide.visible, "footer recalls the unfinished objective")
	var before_spending := SaveService.export_state()
	check(main.ledger.spend({"iron_plates": main.ledger.get_amount(&"iron_plates")}, "tutorial-budget-test"), "test spending is applied through the ledger")
	check(main.dialogue.get_display_notice().get("message_key") == "onboarding.no_budget.body", "missing materials produce a recovery plan instead of a false green light")
	await press(main.hud._guide, &"onboarding.focus")
	check(main.hud._workspace.active_tab == &"rocket", "budget recovery opens rocket planning")
	check(main.ledger.get_amount(&"iron_plates") == 0.0, "guidance never grants free materials")
	check(SaveService.import_state(before_spending) == OK, "budget test restores the real mission checkpoint")
	await place_goal("tunnel")
	await place_goal("laboratory")
	expect("solar_research")
	var lab: StringName = &""
	for status in main.building.get_all_statuses():
		if status.type == &"laboratory":
			lab = status.building_id
	check(main.power.is_powered(lab), "paused construction updates laboratory power immediately")
	await press(main.hud._guide, &"onboarding.focus")
	await press(main.hud._workspace, &"action.research")
	expect("solar_workers")
	await capture("research-workers")
	await assign_pair()
	expect("solar_wait")
	var queued := StringName(GameState.data["crew"]["members"]["crew_1"]["task_id"])
	main.crew.cancel_task(queued)
	check(main.dialogue.get_display_notice().get("message_key") == "onboarding.reassign.body", "cancelled work produces a useful recovery instruction")
	await press(main.hud._guide, &"onboarding.focus")
	await choose(main.hud._workspace, "crew_1")
	await press(main.hud._workspace, &"ui.assign_worker")
	var saved := SaveService.export_state()
	check(saved["tutorial"].get("guided", false) and not saved["tutorial"].get("skipped", false), "checkpoint keeps the guide active")
	check(SaveService.save_to_slot(&"tutorial_checkpoint") == OK, "tutorial checkpoint can be saved")
	main.dialogue.skip_tutorial()
	check(SaveService.import_state(saved) == OK, "tutorial checkpoint restores")
	expect("solar_wait")
	var bad := saved.duplicate(true)
	bad["tutorial"]["guided"] = "yes"
	check(SaveService.import_state(bad) == ERR_INVALID_DATA, "malformed tutorial flags are rejected")
	await reveal_goal()
	await press(main.hud._guide, &"onboarding.act")
	await resume()
	# A large frame must stop exactly at a new tutorial pause, without time backlog.
	main.session.update(90.0)
	await settle()
	expect("solar_panel")
	check(GameClock.get_snapshot()["sol"] == 1, "large update cannot run through a guided pause")
	check(is_zero_approx(main.session.runner.accumulator), "paused tutorial leaves no fast-forward backlog")
	await place_goal("solar_panel")
	expect("day_night")
	check(main.ledger.get_amount(&"iron_plates") == 5.0, "initial construction budget matches the explanation")
	await press(main.hud._guide, &"onboarding.next")
	expect("landing_zone")
	await press(main.hud._guide, &"onboarding.focus")
	await press(main.hud._workspace, &"ui.reserve_zone")
	expect("rocket_manifest")
	await press(main.hud._guide, &"onboarding.focus")
	for item in ["nuclear_core", "spare_parts", "seeds"]:
		for label in main.hud._workspace._body.find_children("*", "Label", true, false):
			if label.text == LocalizationDB.translate_key(StringName("resource.%s" % item)):
				for control in label.get_parent().get_children():
					if control is SpinBox:
						control.value = 1.0
	await settle()
	await click(main.hud._workspace._manifest_confirm)
	expect("rocket_arrival")
	await capture("waiting-for-rocket")
	await press(main.hud._guide, &"onboarding.act")
	await resume()
	await advance_until_pause(400.0)
	check(GameClock.get_snapshot()["sol"] == 6, "beginner is stopped at the first emergency")
	check(main.dialogue.get_display_notice().get("message_key") == "onboarding.breach.body", "first breach explains isolation and real repair")
	await capture("first-emergency")
	await press(main.hud._guide, &"ui.focus")
	await press(main.hud._inspector, &"ui.action.isolate")
	check(main.tunnel.get_snapshot()["oxygen_leak_per_sol"] == 0.0, "isolating immediately stops the leak")
	await press(main.hud._guide, &"ui.focus")
	await choose(main.hud._inspector, "spare_parts")
	await choose(main.hud._inspector, "crew_1")
	await press(main.hud._inspector, &"ui.repair_selected")
	await resume()
	await advance_until_pause(100.0)
	expect("salvage")
	check(main.building.get_status(&"tunnel_1").condition == &"normal", "crew completes repair before the first rocket")
	await press(main.hud._guide, &"onboarding.focus")
	await press(main.hud._workspace, &"action.salvage_rocket")
	expect("battery_research")
	check(main.ledger.get_amount(&"iron_plates") == 17.0, "salvage provides the missing battery budget")
	await press(main.hud._guide, &"onboarding.focus")
	check(main.hud._workspace._research_choice == "battery", "battery goal selects the correct technology")
	await press(main.hud._workspace, &"action.research")
	expect("battery_workers")
	await assign_pair()
	expect("battery_wait")
	await press(main.hud._guide, &"onboarding.act")
	await resume()
	await advance_until_pause(120.0)
	await place_goal("battery")
	expect("finish")
	await capture("finish")
	await press(main.hud._guide, &"onboarding.finish")
	check(goal().is_empty(), "all guided goals complete")
	check(main.crew.get_snapshot().filter(func(member): return member.get("alive", false)).size() == 4, "the beginner route preserves all four crew")
	check(main.ledger.get_amount(&"iron_plates") == 9.0, "the route leaves a material reserve")
	check(main.building.get_power_inputs()["battery_capacity"] == 24.0, "battery is functional")
	var finished_state := SaveService.export_state()
	check(GameClock.advance_to_sol(13).ok, "continuing the learned route reaches the fuel warning")
	check(main.dialogue.get_entries().any(func(entry): return entry.get("id") == "lesson_refuel" and entry.get("message_key") == "onboarding.refuel.body"), "robot explains actual refueling before the reactor runs out")
	check(main.crew.assign_building_action(&"crew_2", &"reactor_1", &"refuel").ok, "refueling is a real crew task")
	main.session.update(30.0)
	check(float(main.building.get_status(&"reactor_1").modifiers["fuel_sols"]) > 12.0, "the assigned worker refuels the reactor")
	check(main.dialogue.get_entries().any(func(entry): return entry.get("id") == "lesson_refuel" and entry.get("resolved", false)), "successful refueling resolves its lesson")
	check(SaveService.import_state(finished_state) == OK, "later-fuel test returns to the completed beginner checkpoint")
	# Replaying does not build anything or erase the colony; completed actions are recognized.
	var count := main.building.get_all_statuses().size()
	main.dialogue.reactivate_tutorial()
	expect("supplies")
	check(main.building.get_all_statuses().size() == count, "resuming a finished guide restarts explanations without erasing the colony")
	main.dialogue.restart_tutorial()
	expect("welcome")
	main.dialogue.reactivate_tutorial()
	main.dialogue.acknowledge(&"tutorial_supplies")
	main.dialogue.acknowledge(&"tutorial_energy")
	expect("day_night")
	check(main.building.get_all_statuses().size() == count, "replaying recognizes existing buildings without duplication")
	main.dialogue.add_fact(&"test_critical", &"critical", &"event.tunnel_breach")
	check(main.dialogue.get_display_notice().get("id") == "test_critical", "critical alerts preempt the tutorial")
	main.dialogue.acknowledge(&"test_critical")
	check(main.dialogue.get_display_notice().get("id") == "tutorial_day_night", "acknowledged hazard cannot hide remaining lessons")
	main.dialogue.resolve(&"test_critical")
	# Layout matrix for real robot text and controls.
	for resolution in [Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(3840, 2160), Vector2i(3440, 1440)]:
		get_window().size = resolution
		for language in ["es", "en"]:
			SettingsService.apply_settings({"language": language})
			main.dialogue.recall_tutorial()
			await settle()
			main.hud._layout_guide()
			await capture("layout-%dx%d-%s" % [resolution.x, resolution.y, language])
			var alert_id := StringName("layout_alert_%dx%d_%s" % [resolution.x, resolution.y, language])
			main.dialogue.add_fact(alert_id, &"critical", &"onboarding.breach.body")
			await capture("alert-%dx%d-%s" % [resolution.x, resolution.y, language])
			main.dialogue.resolve(alert_id)
	main.dialogue.skip_tutorial()
	check(not GameClock.get_snapshot()["paused"], "skipping releases a pause owned by the guide")
	get_window().size = Vector2i(960, 540)
	SettingsService.apply_settings({"ui_scale": 1.25})
	main.dialogue.reactivate_tutorial()
	await capture("large-ui-960x540")
	main.dialogue.skip_tutorial()
	SettingsService.apply_settings({"ui_scale": 1.0})
	GameClock.set_paused(true)
	main.dialogue.reactivate_tutorial()
	main.dialogue.skip_tutorial()
	check(GameClock.get_snapshot()["paused"], "skipping preserves a pause made by the player")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "visited": visited, "captures": captures, "sol": GameClock.get_snapshot()["sol"]}
	var output := FileAccess.open("user://tutorial-result.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("TUTORIAL QA: ", JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
