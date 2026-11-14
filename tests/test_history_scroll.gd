extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var lab: Control = load("res://scenes/simulation_lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab._open_hud_panel("history")
	await process_frame
	await process_frame
	var snapshot: Dictionary = lab.simulation.get_snapshot()
	for i: int in range(120):
		snapshot.log.append({"id": "test%d" % i, "seconds": i, "reason": "test_event", "target": "b1", "details": {}})
	lab._render(snapshot)
	await process_frame
	await process_frame
	lab._log.scroll_vertical = 5.0
	var previous: float = lab._log.scroll_vertical
	_check(previous > 0, "el panel tiene contenido desplazable")
	snapshot.log.append({"id": "new_event", "seconds": 121, "reason": "new_event", "target": "b1", "details": {}})
	lab._render(snapshot)
	await process_frame
	await process_frame
	_check(absf(lab._log.scroll_vertical - previous) < 0.01, "un evento nuevo conserva la posición de lectura")
	lab._render(snapshot)
	await process_frame
	_check(absf(lab._log.scroll_vertical - previous) < 0.01, "refrescar el mismo estado no reinicia scroll")
	_check(lab._log.get_line_count() >= 120, "se conserva el historial completo, no solo doce hechos")
	var building_lines: PackedStringArray = []
	lab._open_hud_panel("base")
	for i: int in range(80):
		building_lines.append("hecho del edificio %d" % i)
	lab._building_history.update_history("\n".join(building_lines))
	await process_frame
	lab._building_history.scroll_vertical = 8.0
	var building_previous: float = lab._building_history.scroll_vertical
	_check(building_previous > 0, "historial de edificio tiene scroll propio")
	building_lines.append("nuevo hecho")
	lab._building_history.update_history("\n".join(building_lines))
	await process_frame
	_check(absf(lab._building_history.scroll_vertical - building_previous) < 0.01, "historial de edificio conserva posición")
	_check(not lab._log.mouse_force_pass_scroll_events and not lab._building_history.mouse_force_pass_scroll_events, "rueda del historial no se propaga al scroll exterior")
	lab.simulation.reset_run(["engineer", "medic", "botanist", "technician"], 1)
	await process_frame
	_check(lab._log.scroll_vertical == 0, "una partida nueva limpia posición anterior")
	lab.queue_free()
	await process_frame
	print("UI_HISTORY_TESTS: %d failures" % failures)
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
