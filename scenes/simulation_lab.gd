extends Control
## Banco técnico temporal; Andrés puede reemplazarlo sin tocar el dominio.

const Simulation = preload("res://domain/simulation.gd")
const Config = preload("res://domain/simulation_config.gd")
const HistoryPanel = preload("res://scenes/history_panel.gd")
var simulation := Simulation.new()
var _status: Label
var _message: Label
var _log: HistoryPanel
var _building_history: HistoryPanel
var _history_generation: int = -1
var _history_building: String = ""
var _catalog: OptionButton
var _cells: Array[Button] = []
var _crew_checks: Array[CheckBox] = []
var _seed: SpinBox
var _robot_choice: OptionButton
var _destination_choice: OptionButton
var _event_status: Label
var _robot_status: Label
var _upgrade_choice: OptionButton
var _upgrade_status: Label
var _maintenance_choice: OptionButton
var _maintenance_status: Label
var _maintenance_session: String = ""
var _inspected_id: String = "b1"
var _inspector: Label
var _crew_ids: Array[String] = ["engineer", "medic", "botanist", "scientist", "geologist", "technician"]
var _kinds: Array[String] = ["solar", "reactor", "oxygen_generator", "greenhouse", "laboratory"]

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 20
	scroll.offset_top = 16
	scroll.offset_right = -20
	scroll.offset_bottom = -16
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)
	var title := Label.new()
	title.text = "MarSins | Banco de simulación · balance provisional"
	root.add_child(title)
	var help := Label.new()
	help.text = "Elige 4 especialistas y reinicia. Selecciona un edificio y pulsa una celda vacía.\nPulsa un edificio para encender/apagar. Los temporizadores comienzan al iniciar."
	root.add_child(help)
	var crew_row := HBoxContainer.new()
	root.add_child(crew_row)
	var names := ["Ingeniería", "Medicina", "Botánica", "Ciencia", "Geología", "Sistemas"]
	for i: int in range(_crew_ids.size()):
		var check := CheckBox.new()
		check.text = names[i]
		check.button_pressed = i in [0, 1, 2, 5]
		crew_row.add_child(check)
		_crew_checks.append(check)
	var pending := Label.new()
	pending.text = "Ciencia acelera mejoras. Resultados de mantenimiento simulados en este banco técnico."
	root.add_child(pending)
	var controls := HBoxContainer.new()
	root.add_child(controls)
	_add_button(controls, "Reiniciar", _reset)
	_add_button(controls, "Iniciar", func() -> void: _show_result(simulation.start_run()))
	_add_button(controls, "Pausa / continuar", func() -> void: _show_result(simulation.set_paused(not simulation.get_snapshot().get("paused", false))))
	for speed: float in [0.5, 1.0, 2.0, 4.0]:
		_add_button(controls, "×%s" % speed, func() -> void: _show_result(simulation.set_speed(speed)))
	_seed = SpinBox.new()
	_seed.min_value = 0
	_seed.max_value = 1000000
	_seed.value = 1
	_seed.prefix = "Semilla "
	controls.add_child(_seed)
	var missions := HBoxContainer.new()
	root.add_child(missions)
	_robot_choice = OptionButton.new()
	_robot_choice.add_item("ROBERT 1")
	_robot_choice.add_item("ROBERT 2")
	missions.add_child(_robot_choice)
	_destination_choice = OptionButton.new()
	for name: String in ["Hielo → agua", "Cantera → regolito", "Restos → masa"]:
		_destination_choice.add_item(name)
	missions.add_child(_destination_choice)
	_add_button(missions, "Enviar (2 potencia, 2 soles)", _send_robert)
	_add_button(missions, "Refugio / salir", func() -> void: _show_result(simulation.set_sheltered(not simulation.get_snapshot().get("sheltered", false))))
	_add_button(missions, "Enterrar (10 masa + 20 regolito)", func() -> void: _show_result(simulation.bury_habitat()))
	_robot_status = Label.new()
	_robot_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_robot_status)
	var upgrades := HBoxContainer.new()
	root.add_child(upgrades)
	_upgrade_choice = OptionButton.new()
	upgrades.add_child(_upgrade_choice)
	_add_button(upgrades, "Mejorar a nivel 2", _upgrade)
	_upgrade_status = Label.new()
	_upgrade_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades.add_child(_upgrade_status)
	var maintenance_row := HBoxContainer.new()
	root.add_child(maintenance_row)
	_maintenance_choice = OptionButton.new()
	maintenance_row.add_child(_maintenance_choice)
	_add_button(maintenance_row, "Atender", _begin_maintenance)
	_add_button(maintenance_row, "Prueba: éxito", func() -> void: _maintenance_result(true))
	_add_button(maintenance_row, "Prueba: fallo", func() -> void: _maintenance_result(false))
	_add_button(maintenance_row, "Abandonar", func() -> void: _maintenance_result(false, true))
	_add_button(maintenance_row, "Reactivar", _reactivate)
	_maintenance_status = Label.new()
	_maintenance_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_maintenance_status)
	_inspector = Label.new()
	_inspector.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_inspector)
	_building_history = HistoryPanel.new()
	_building_history.custom_minimum_size.y = 140
	root.add_child(_building_history)
	_event_status = Label.new()
	_event_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_event_status)
	_catalog = OptionButton.new()
	root.add_child(_catalog)
	_status = Label.new()
	root.add_child(_status)
	_message = Label.new()
	_message.text = "Listo"
	root.add_child(_message)
	var body := HBoxContainer.new()
	body.custom_minimum_size.y = 360
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 6
	body.add_child(grid)
	for y: int in range(6):
		for x: int in range(6):
			var cell := Vector2i(x, y)
			var button := Button.new()
			button.custom_minimum_size = Vector2(96, 56)
			button.pressed.connect(func() -> void: _cell_clicked(cell))
			grid.add_child(button)
			_cells.append(button)
	_log = HistoryPanel.new()
	_log.custom_minimum_size = Vector2(300, 360)
	body.add_child(_log)
	var loaded := Config.load_file()
	if not loaded.ok:
		_message.text = "Error de configuración: %s" % loaded
		set_process(false)
		return
	_show_result(simulation.configure(loaded.data))
	var labels := ["Solar", "Reactor", "Generador de oxígeno", "Invernadero", "Laboratorio"]
	for i: int in range(_kinds.size()):
		var definition: Dictionary = loaded.data.buildings[_kinds[i]]
		_catalog.add_item("%s · %s masa · %s s" % [labels[i], definition.mass, definition.build_seconds])
	simulation.state_updated.connect(_render)
	_reset()

func _process(delta: float) -> void:
	simulation.advance(delta)

func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)

func _reset() -> void:
	var selected: Array = []
	for i: int in range(_crew_checks.size()):
		if _crew_checks[i].button_pressed:
			selected.append(_crew_ids[i])
	_show_result(simulation.reset_run(selected, int(_seed.value)))
	_maintenance_session = ""

func _send_robert() -> void:
	var destination: String = ["ice", "quarry", "wreckage"][_destination_choice.selected]
	_show_result(simulation.send_robert("robert_%d" % (_robot_choice.selected + 1), destination))

func _upgrade() -> void:
	if _upgrade_choice.selected < 0:
		_message.text = "Selecciona un edificio construido para mejorar."
		return
	_show_result(simulation.start_upgrade(str(_upgrade_choice.get_item_metadata(_upgrade_choice.selected))))

func _begin_maintenance() -> void:
	if _maintenance_choice.selected < 0:
		return
	var result: Dictionary = simulation.begin_maintenance(str(_maintenance_choice.get_item_metadata(_maintenance_choice.selected)))
	if result.ok:
		_maintenance_session = result.result.id
	_show_result(result)

func _maintenance_result(success: bool, abandoned: bool = false) -> void:
	_show_result(simulation.apply_maintenance_result(_maintenance_session, success, 0.0, abandoned))

func _reactivate() -> void:
	if _maintenance_choice.selected >= 0:
		_show_result(simulation.reactivate_building(str(_maintenance_choice.get_item_metadata(_maintenance_choice.selected))))

func _cell_clicked(cell: Vector2i) -> void:
	for building: Dictionary in simulation.get_snapshot().get("buildings", []):
		if building.x == cell.x and building.y == cell.y:
			_inspected_id = building.id
			_show_result(simulation.set_enabled(building.id, not building.enabled))
			_render(simulation.get_snapshot())
			return
	_show_result(simulation.place_building(_kinds[_catalog.selected], cell))

func _show_result(result: Dictionary) -> void:
	_message.text = "OK · %s" % result.result if result.ok else _error_text(result.error_code)

func _error_text(code: String) -> String:
	var messages := {
		"invalid_phase": "La partida debe estar en simulación. Si terminó, reinicia e inicia otra.",
		"laboratory_not_operational": "El laboratorio debe estar terminado, encendido y con potencia. Revisa si una tormenta redujo la energía solar.",
		"insufficient_power": "Falta potencia libre para otra salida de ROBERT. Enciende una fuente o apaga un consumidor.",
		"robert_unavailable": "Este ROBERT sigue en misión o se perdió. Selecciona otro o espera el regreso.",
		"crew_sheltered": "Sal del refugio para iniciar una expedición o mejora.",
		"insufficient_mass": "No alcanza la masa para esta acción.",
		"max_level": "Este edificio ya está en nivel 2.",
		"upgrade_in_progress": "Este edificio ya tiene una mejora en curso.",
		"building_under_construction": "Espera a que termine la construcción.",
		"upgrade_not_supported": "El hábitat se protege mediante Enterrar; no tiene mejora de nivel 2.",
		"maintenance_not_pending": "Este edificio no tiene un aviso de mantenimiento pendiente.",
		"maintenance_suspended": "Sesión suspendida por crisis o refugio. Continúa cuando termine.",
		"maintenance_attempts_exhausted": "Se agotaron los dos intentos o los 15 segundos de sesión.",
		"maintenance_cooling_down": "Espera a que termine el enfriamiento antes de reactivar.",
		"maintenance_not_shutdown": "Este edificio no está apagado por mantenimiento.",
		"maintenance_session_active": "Esta sesión ya está abierta.",
		"another_maintenance_active": "Termina la sesión de otro edificio antes de abrir esta.",
		"maintenance_result_already_closed": "Este resultado ya se cerró o venció.",
		"unknown_maintenance_session": "No hay una sesión vigente con ese identificador."
	}
	return messages.get(code, "Rechazado: " + code)

func _render(snapshot: Dictionary) -> void:
	var new_run: bool = snapshot.run_generation != _history_generation
	_history_generation = snapshot.run_generation
	var r: Dictionary = snapshot.resources
	var p: Dictionary = snapshot.power
	var previous_maintenance := str(_maintenance_choice.get_item_metadata(_maintenance_choice.selected)) if _maintenance_choice.selected >= 0 else ""
	_maintenance_choice.clear()
	var maintenance_lines: PackedStringArray = []
	for building: Dictionary in snapshot.buildings:
		if building.kind not in ["reactor", "oxygen_generator"]:
			continue
		_maintenance_choice.add_item("%s %s" % [building.id, building.kind])
		var index := _maintenance_choice.item_count - 1
		_maintenance_choice.set_item_metadata(index, building.id)
		if building.id == previous_maintenance:
			_maintenance_choice.select(index)
		maintenance_lines.append("%s: %s · edad %ds · intentos %d · sesión %s" % [building.id, building.maintenance.state, building.maintenance.age_seconds, building.maintenance.attempts, building.maintenance.session.get("state", "sin abrir")])
	_maintenance_status.text = "Mantenimiento: " + " | ".join(maintenance_lines)
	var inspection: Dictionary = simulation.get_building_status(_inspected_id)
	if inspection.ok:
		var status: Dictionary = inspection.result
		_inspector.text = "Inspector %s · %s N%d · potencia %.1f / demanda %.1f · aire %.1f / comida %.1f por sol · aviso %s" % [status.id, status.kind, status.level, status.power_output, status.power_demand, status.effective_production_per_sol.air, status.effective_production_per_sol.food, status.warning]
		var history: PackedStringArray = ["Historial del edificio " + status.id]
		for entry: Dictionary in status.local_log:
			history.append("%ss · %s · %s" % [entry.seconds, entry.reason, str(entry.details)])
		_building_history.update_history("\n".join(history), new_run or _history_building != status.id)
		_history_building = status.id
	var event_text := "ninguno"
	if not snapshot.event.is_empty():
		event_text = "%s (%s, inicio %ds, fin %ds)" % [snapshot.event.kind, snapshot.event.state, snapshot.event.start_seconds, snapshot.event.end_seconds]
	_event_status.text = "Pronóstico: tormenta %d%% · partículas %d%% | Evento: %s | Refugio: %s | Hábitat: %s" % [roundi(snapshot.forecast.storm.probability * 100), roundi(snapshot.forecast.solar_particles.probability * 100), event_text, snapshot.sheltered, snapshot.burial.state]
	var destination: String = ["ice", "quarry", "wreckage"][_destination_choice.selected]
	var preview: Dictionary = simulation.preview_robert("robert_%d" % (_robot_choice.selected + 1), destination)
	_destination_choice.tooltip_text = "Carga %s %s · riesgo actual %.1f%% (puede subir por tormenta)" % [preview.result.amount, preview.result.resource, preview.result.loss_probability * 100] if preview.ok else _error_text(preview.error_code)
	_robot_status.text = "ROBERT seleccionado: listo para enviar otra misión." if preview.ok else "Salida bloqueada: " + _error_text(preview.error_code)
	var selected_id := str(_upgrade_choice.get_item_metadata(_upgrade_choice.selected)) if _upgrade_choice.selected >= 0 else ""
	_upgrade_choice.clear()
	for building: Dictionary in snapshot.buildings:
		if building.kind == "habitat":
			continue
		_upgrade_choice.add_item("%s · %s N%d" % [building.id, building.kind, building.level])
		var index := _upgrade_choice.item_count - 1
		_upgrade_choice.set_item_metadata(index, building.id)
		if building.id == selected_id:
			_upgrade_choice.select(index)
	_upgrade_status.text = "Construye un edificio para mejorar."
	if _upgrade_choice.selected >= 0:
		var upgrade: Dictionary = simulation.preview_upgrade(str(_upgrade_choice.get_item_metadata(_upgrade_choice.selected)))
		_upgrade_status.text = "%s masa · %s s estimados" % [upgrade.cost.mass, upgrade.result.duration_seconds] if upgrade.ok else _error_text(upgrade.error_code)
	_status.text = "%s | Sol %d · %d s | ×%s | Pausa: %s\nMasa %.1f · Aire %.1f · Agua %.1f · Comida %.1f | Potencia %.1f / demanda %.1f" % [snapshot.phase, snapshot.sol, snapshot.elapsed_seconds, snapshot.speed, snapshot.paused, r.mass, r.air, r.water, r.food, p.supply, p.demand]
	for i: int in range(_cells.size()):
		_cells[i].text = "(%d, %d)" % [i % 6, int(i / 6)]
		_cells[i].tooltip_text = "Celda vacía"
	var short_names := {"habitat": "HÁBITAT", "solar": "SOLAR", "reactor": "REACTOR", "oxygen_generator": "OXÍGENO", "greenhouse": "CULTIVO", "laboratory": "LAB"}
	for b: Dictionary in snapshot.buildings:
		var button := _cells[int(b.y) * 6 + int(b.x)]
		var state := "%ds" % b.remaining_seconds if b.remaining_seconds > 0 else ("ON" if b.powered else "OFF")
		var progress := " ↑%.1f" % b.upgrade_remaining_work if b.upgrade_remaining_work > 0 else ""
		button.text = "%s N%d\n%s%s" % [short_names[b.kind], b.level, state, progress]
		button.tooltip_text = "%s · %s" % [b.id, b.warning]
	var lines: PackedStringArray = []
	for member: Dictionary in snapshot.crew:
		lines.append("%s: %.1f salud · %.2f dosis" % [member.id, member.health, member.dose])
	lines.append("Regolito: %.1f" % r.regolith)
	for robot: Dictionary in snapshot.roberts:
		if robot.state == "on_mission":
			lines.append("%s: en misión → %s · faltan %ds · soporte %s" % [robot.id, robot.destination, maxi(0, robot.return_seconds - snapshot.elapsed_seconds), robot.powered])
		else:
			lines.append("%s: %s" % [robot.id, "disponible" if robot.state == "available" else "perdido"])
	if not snapshot.result.is_empty():
		lines.append("FINAL: %s" % snapshot.result.verdict)
	if not snapshot.sol_reports.is_empty():
		var report: Dictionary = snapshot.sol_reports[-1]
		lines.append("Último sol %s: variación %s\nBloqueos medidos: %s" % [report.sol, str(report.delta), str(report.blocked_seconds)])
	lines.append("\nHistorial de eventos:")
	for entry: Dictionary in snapshot.log:
		lines.append("%ss · %s · %s" % [entry.seconds, entry.reason, entry.target])
	_log.update_history("\n".join(lines), new_run)
