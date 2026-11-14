extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/crew_selection.tscn")
	await process_frame
	await process_frame
	var selection = current_scene
	_check(not selection._continue_button.disabled, "cuatro especialistas permiten continuar")
	selection._crew_checks[0].button_pressed = false
	_check(selection._continue_button.disabled, "tres especialistas bloquean inicio")
	selection._crew_checks[0].button_pressed = true
	selection._crew_checks[3].button_pressed = true
	_check(selection._continue_button.disabled, "cinco especialistas bloquean inicio")
	selection._crew_checks[3].button_pressed = false
	selection._enter_simulation()
	await process_frame
	await process_frame
	var lab = current_scene
	lab.set_process(false)
	_check(lab._cell_nodes.size() == 1024, "tablero 32 por 32")
	_check(lab.simulation.get_snapshot().crew.size() == 4, "selección llega al dominio")
	lab._show_build_menu(Vector2i(18, 15))
	lab._place_selected_building("reactor")
	lab._show_build_menu(Vector2i(4, 1))
	lab._place_selected_building("laboratory")
	lab._show_build_menu(Vector2i(7, 1))
	lab._place_selected_building("oxygen_generator")
	_check(lab.simulation.get_snapshot().resources.mass == 15, "menú cobra 45 + 20 + 20 una vez")
	lab._cell_clicked(Vector2i(17, 14))
	_check(lab._inspected_id == "b2" and not lab.simulation.get_snapshot().buildings[1].enabled, "clic en borde de huella selecciona reactor")
	lab._cell_clicked(Vector2i(17, 14))
	_check(lab.simulation.get_snapshot().buildings[1].enabled, "clic vuelve a habilitar reactor")
	lab._toggle_run_state()
	lab.simulation.advance(10)
	_check(lab.simulation.get_snapshot().phase == "running", "control inicia partida")
	lab._send_robert()
	_check(lab.simulation.get_snapshot().roberts[0].state == "on_mission", "panel envía ROBERT")
	lab._upgrade_choice.select(1)
	lab._upgrade()
	_check(lab.simulation.get_snapshot().buildings[2].upgrade_remaining_work > 0, "panel inicia mejora laboratorio")
	lab.simulation.advance(20)
	_check(lab.simulation.get_snapshot().buildings[2].level == 2, "mejora llega al snapshot")
	# Laboratorio y generador mantienen soporte durante ambos eventos.
	# El primer aviso se pospone hasta terminar la tormenta a los 125 s.
	lab.simulation.advance(95)
	lab._begin_maintenance()
	_check(not lab._maintenance_session.is_empty(), "panel abre sesión real de mantenimiento")
	lab._maintenance_result(true)
	_check(lab.simulation.get_snapshot().buildings[1].maintenance.state == "healthy", "resultado de prueba llega al dominio")
	_check(not lab.simulation.get_snapshot().sol_reports.is_empty(), "informes por sol presentes")
	lab._toggle_run_state()
	var before: int = lab.simulation.get_snapshot().elapsed_seconds
	lab.simulation.advance(10)
	_check(lab.simulation.get_snapshot().elapsed_seconds == before, "control pausa economía")
	lab._toggle_run_state()
	lab.simulation.advance(300)
	_check(lab.simulation.get_snapshot().phase == "finished" and lab._run_button.disabled, "final desactiva iniciar")
	lab._reset()
	_check(lab.simulation.get_snapshot().phase == "planning" and lab.simulation.get_snapshot().buildings.size() == 1, "reiniciar limpia partida")
	lab._open_crew_selection()
	await process_frame
	await process_frame
	selection = current_scene
	_check(not selection._continue_button.disabled, "volver conserva cuatro seleccionados")
	selection._enter_simulation()
	await process_frame
	await process_frame
	lab = current_scene
	lab.set_process(false)
	_check(lab.simulation.get_snapshot().elapsed_seconds == 0, "nueva escena crea simulación limpia")
	print("UI_INTEGRATION_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
