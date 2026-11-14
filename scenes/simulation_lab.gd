extends Control
## Banco técnico temporal; Andrés puede reemplazarlo sin tocar el dominio.

const Simulation = preload("res://domain/simulation.gd")
const Config = preload("res://domain/simulation_config.gd")
var simulation := Simulation.new()
var _status: Label
var _message: Label
var _log: TextEdit
var _catalog: OptionButton
var _cells: Array[Button] = []
var _crew_checks: Array[CheckBox] = []
var _crew_ids: Array[String] = ["engineer", "medic", "botanist", "scientist", "geologist", "technician"]
var _kinds: Array[String] = ["solar", "reactor", "oxygen_generator", "greenhouse", "laboratory"]

func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_top = 16
	root.offset_right = -20
	root.offset_bottom = -16
	add_child(root)
	var title := Label.new()
	title.text = "MarSins | Banco de simulación · balance provisional"
	root.add_child(title)
	var help := Label.new()
	help.text = "Elige 4 especialistas y reinicia. Selecciona un edificio y pulsa una celda vacía.\nPulsa un edificio para encender/apagar. Los temporizadores comienzan al iniciar."
	root.add_child(help)
	var crew_row := HBoxContainer.new()
	root.add_child(crew_row)
	var names := ["Ingeniería", "Medicina*", "Botánica", "Ciencia*", "Geología*", "Sistemas"]
	for i: int in range(_crew_ids.size()):
		var check := CheckBox.new()
		check.text = names[i]
		check.button_pressed = i in [0, 1, 2, 5]
		crew_row.add_child(check)
		_crew_checks.append(check)
	var pending := Label.new()
	pending.text = "* Efectos pendientes de radiación, mejoras y ROBERTS. Sin eventos ni mantenimiento en esta base."
	root.add_child(pending)
	var controls := HBoxContainer.new()
	root.add_child(controls)
	_add_button(controls, "Reiniciar", _reset)
	_add_button(controls, "Iniciar", func() -> void: _show_result(simulation.start_run()))
	_add_button(controls, "Pausa / continuar", func() -> void: _show_result(simulation.set_paused(not simulation.get_snapshot().get("paused", false))))
	for speed: float in [0.5, 1.0, 2.0, 4.0]:
		_add_button(controls, "×%s" % speed, func() -> void: _show_result(simulation.set_speed(speed)))
	_catalog = OptionButton.new()
	root.add_child(_catalog)
	_status = Label.new()
	root.add_child(_status)
	_message = Label.new()
	_message.text = "Listo"
	root.add_child(_message)
	var body := HBoxContainer.new()
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
	_log = TextEdit.new()
	_log.editable = false
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_log)
	var loaded := Config.load_file()
	if not loaded.ok:
		_message.text = "Error de configuración: %s" % loaded
		set_process(false)
		return
	_show_result(simulation.configure(loaded.data))
	var labels := ["Solar", "Reactor", "Generador de oxígeno", "Invernadero", "Laboratorio (ROBERTS pendiente)"]
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
	_show_result(simulation.reset_run(selected, 1))

func _cell_clicked(cell: Vector2i) -> void:
	for building: Dictionary in simulation.get_snapshot().get("buildings", []):
		if building.x == cell.x and building.y == cell.y:
			_show_result(simulation.set_enabled(building.id, not building.enabled))
			return
	_show_result(simulation.place_building(_kinds[_catalog.selected], cell))

func _show_result(result: Dictionary) -> void:
	_message.text = "OK · %s" % result.result if result.ok else "Rechazado: %s" % result.error_code

func _render(snapshot: Dictionary) -> void:
	var r: Dictionary = snapshot.resources
	var p: Dictionary = snapshot.power
	_status.text = "%s | Sol %d · %d s | ×%s | Pausa: %s\nMasa %.1f · Aire %.1f · Agua %.1f · Comida %.1f | Potencia %.1f / demanda %.1f" % [snapshot.phase, snapshot.sol, snapshot.elapsed_seconds, snapshot.speed, snapshot.paused, r.mass, r.air, r.water, r.food, p.supply, p.demand]
	for i: int in range(_cells.size()):
		_cells[i].text = "(%d, %d)" % [i % 6, int(i / 6)]
		_cells[i].tooltip_text = "Celda vacía"
	var short_names := {"habitat": "HÁBITAT", "solar": "SOLAR", "reactor": "REACTOR", "oxygen_generator": "OXÍGENO", "greenhouse": "CULTIVO", "laboratory": "LAB"}
	for b: Dictionary in snapshot.buildings:
		var button := _cells[int(b.y) * 6 + int(b.x)]
		var state := "%ds" % b.remaining_seconds if b.remaining_seconds > 0 else ("ON" if b.powered else "OFF")
		button.text = "%s\n%s" % [short_names[b.kind], state]
		button.tooltip_text = "%s · %s" % [b.id, b.warning]
	var lines: PackedStringArray = []
	for member: Dictionary in snapshot.crew:
		lines.append("%s: %.1f salud" % [member.id, member.health])
	if not snapshot.result.is_empty():
		lines.append("FINAL: %s" % snapshot.result.verdict)
	lines.append("\nÚltimos hechos:")
	for entry: Dictionary in snapshot.log.slice(maxi(0, snapshot.log.size() - 12)):
		lines.append("%ss · %s · %s" % [entry.seconds, entry.reason, entry.target])
	_log.text = "\n".join(lines)
