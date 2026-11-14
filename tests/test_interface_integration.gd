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
	lab._open_hud_panel("summary")
	lab.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for dimensions: Vector2 in [Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080)]:
		lab.size = dimensions
		await process_frame
		await process_frame
		var bounds := Rect2(Vector2.ZERO, dimensions)
		_check(bounds.encloses(lab._hud_drawer.get_rect()), "panel dentro de pantalla " + str(dimensions))
		_check(bounds.encloses(lab._action_dock.get_rect()), "acciones dentro de pantalla " + str(dimensions))
		_check(not lab._hud_drawer.get_rect().intersects(lab._action_dock.get_rect()), "panel no tapa barra de acciones " + str(dimensions))
		_check(not lab._action_dock.get_rect().intersects(lab._camera_controls_panel.get_rect()), "cámara separada de acciones " + str(dimensions))
		_check(lab._viewport_container.size == dimensions, "tablero sigue tamaño disponible " + str(dimensions))
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	lab._close_hud_panel()
	_check(lab._cell_nodes.size() == 1024, "tablero 32 por 32")
	_check(lab.simulation.get_snapshot().crew.size() == 4, "selección llega al dominio")
	var initial_yaw: float = lab._camera_yaw
	var initial_size: float = lab._camera.size
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	middle.position = Vector2(500, 300)
	lab._on_viewport_gui_input(middle)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(560, 340)
	lab._on_viewport_gui_input(motion)
	_check(lab._camera_pivot.position.length() > 0.1, "rueda pulsada arrastra cámara sobre el tablero")
	_check(lab._camera_yaw == initial_yaw and lab._camera.size == initial_size, "desplazar no gira ni cambia zoom")
	_check(lab._camera_pivot.position.y == 0, "desplazamiento permanece en plano horizontal")
	await process_frame
	var tile_position: Vector3 = lab._cell_nodes[10 * 32 + 10].global_position
	tile_position.y = lab.TILE_SURFACE_Y
	var screen_position: Vector2 = lab._camera.unproject_position(tile_position) * lab._viewport_container.size / Vector2(lab._board_subviewport.size)
	lab._select_cell_at(screen_position)
	_check(lab._build_menu_cell == Vector2i(10, 10), "selección de celda sigue alineada después de desplazar")
	middle.pressed = false
	lab._input(middle)
	var stopped_position: Vector3 = lab._camera_pivot.position
	motion.position = Vector2(600, 400)
	lab._on_viewport_gui_input(motion)
	_check(lab._camera_pivot.position == stopped_position, "soltar rueda sobre HUD termina desplazamiento")
	middle.pressed = true
	lab._on_viewport_gui_input(middle)
	lab._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(not lab._panning_camera, "perder foco libera arrastre")
	lab._reset_camera()
	_check(lab._camera_pivot.position == Vector3.ZERO and lab._camera.size == lab.DEFAULT_CAMERA_SIZE, "restablecer vista recupera centro y zoom")
	_check(lab._board_subviewport.size == Vector2i(lab._viewport_container.size), "3D se renderiza a resolución nativa del área visible")
	_check(lab._cell_visuals[15 * 32 + 15].scale.x > 1, "hábitat aprovecha tamaño de su huella")
	lab._show_build_menu(Vector2i(18, 15))
	lab._place_selected_building("reactor")
	lab._show_build_menu(Vector2i(4, 1))
	lab._place_selected_building("laboratory")
	lab._show_build_menu(Vector2i(7, 1))
	lab._place_selected_building("oxygen_generator")
	_check(lab.simulation.get_snapshot().resources.mass == 15, "menú cobra 45 + 20 + 20 una vez")
	lab._cell_clicked(Vector2i(17, 14))
	_check(lab._inspected_id == "b2" and lab.simulation.get_snapshot().buildings[1].enabled and lab._active_hud_panel == "base", "clic inspecciona reactor sin apagarlo")
	lab._toggle_selected_building()
	_check(not lab.simulation.get_snapshot().buildings[1].enabled, "acción explícita apaga reactor")
	lab._toggle_selected_building()
	_check(lab.simulation.get_snapshot().buildings[1].enabled, "acción explícita habilita reactor")
	_check(lab._viewport_container.size == lab.size, "vista 3D ocupa toda la pantalla")
	lab._open_hud_panel("robots")
	_check(lab._hud_pages.robots.get_parent().visible and not lab._hud_pages.base.get_parent().visible, "solo un panel HUD visible")
	lab._close_hud_panel()
	_check(not lab._hud_drawer.visible, "cerrar panel devuelve toda la vista al tablero")
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
	_check(lab._active_hud_panel == "summary" and not lab._summary_view.text.is_empty(), "final abre resumen integrado en HUD")
	_check(lab.simulation.get_run_summary().ok, "resumen final disponible para pantalla de Andrés")
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
