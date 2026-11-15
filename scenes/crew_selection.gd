extends Control
## Escena independiente para elegir los cuatro especialistas de la partida.

const SIMULATION_SCENE := "res://scenes/simulation_lab.tscn"
const Config = preload("res://domain/simulation_config.gd")
@onready var _settings_manager: Node = get_node("/root/SettingsManager")
const SELECTED_CREW_META := "mars_selected_crew_ids"
const CREW_IDS := ["engineer", "medic", "botanist", "scientist", "geologist", "technician"]
const CREW_NAMES := ["Ingeniería", "Medicina", "Botánica", "Ciencia", "Geología", "Sistemas"]
const DEFAULT_SELECTED_CREW := ["engineer", "medic", "botanist", "technician"]

var _scenario: OptionButton
var _seed: SpinBox
var _forecast: Label
var _data: Dictionary
const SCENARIOS := ["frontier", "eclipse", "harvest"]
var _crew_checks: Array[CheckBox] = []
var _selection_label: Label
var _message_label: Label
var _continue_button: Button

func _ready() -> void:
	_style_briefing()
	_settings_manager.language_changed.connect(_on_language_changed)
	var background := ColorRect.new()
	background.color = Color("182532")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(850.0, 680.0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)

	var title := Label.new()
	title.text = "Selecciona tu tripulación"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	content.add_child(title)

	var description := Label.new()
	description.text = "Elige exactamente cuatro especialistas para iniciar la misión."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(description)
	_data = Config.load_file().data
	_scenario = OptionButton.new()
	for id: String in SCENARIOS:
		_scenario.add_item(_data.scenarios[id].name)
	content.add_child(_scenario)
	_scenario.select(maxi(0, SCENARIOS.find(str(get_tree().root.get_meta("mars_scenario", "frontier")))))
	var seed_row := HBoxContainer.new()
	content.add_child(seed_row)
	var seed_title := Label.new()
	seed_title.text = "Semilla de misión"
	seed_row.add_child(seed_title)
	_seed = SpinBox.new()
	_seed.max_value = 1000000
	_seed.value = int(get_tree().root.get_meta("mars_run_seed", 1))
	seed_row.add_child(_seed)
	var shuffle := Button.new()
	shuffle.text = "Nueva semilla"
	shuffle.pressed.connect(func() -> void: _seed.value = randi_range(0, 1000000))
	seed_row.add_child(shuffle)
	_forecast = Label.new()
	_forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_forecast)
	_scenario.item_selected.connect(func(_index: int) -> void: _preview())
	_seed.value_changed.connect(func(_value: float) -> void: _preview())
	_preview()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(grid)

	var initial_selection := _get_initial_selection()
	for index: int in range(CREW_IDS.size()):
		var check := CheckBox.new()
		check.text = CREW_NAMES[index] + "\n" + ["+20% generación eléctrica", "Menor dosis recibida", "Mayor producción de alimento", "Mejoras más rápidas", "Más regolito en expediciones", "−20% consumo del generador O₂"][index]
		check.custom_minimum_size = Vector2(270.0, 54.0)
		check.button_pressed = CREW_IDS[index] in initial_selection
		check.add_theme_font_size_override("font_size", 20)
		check.toggled.connect(_on_crew_toggled)
		grid.add_child(check)
		_crew_checks.append(check)

	_selection_label = Label.new()
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_selection_label)

	_message_label = Label.new()
	_message_label.text = "Los seis especialistas tienen efectos activos en la simulación."
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message_label)

	_continue_button = Button.new()
	_continue_button.text = "Continuar a la simulación  →"
	_continue_button.custom_minimum_size = Vector2(0.0, 52.0)
	_continue_button.pressed.connect(_enter_simulation)
	content.add_child(_continue_button)
	_update_selection_state()
	_settings_manager.translate_tree(self)

func _get_initial_selection() -> Array:
	var initial_selection: Array = DEFAULT_SELECTED_CREW.duplicate()
	var root := get_tree().root
	if root.has_meta(SELECTED_CREW_META):
		var saved: Variant = root.get_meta(SELECTED_CREW_META)
		root.remove_meta(SELECTED_CREW_META)
		if _is_valid_selection(saved):
			initial_selection = saved.duplicate()
	return initial_selection

func _is_valid_selection(value: Variant) -> bool:
	if not value is Array or value.size() != 4:
		return false
	var seen: Array[String] = []
	for crew_id: Variant in value:
		if not crew_id is String or crew_id not in CREW_IDS or crew_id in seen:
			return false
		seen.append(str(crew_id))
	return true

func _on_crew_toggled(_pressed: bool) -> void:
	_update_selection_state()

func _update_selection_state() -> void:
	var selected_count := 0
	for check: CheckBox in _crew_checks:
		if check.button_pressed:
			selected_count += 1
	_selection_label.text = "Especialistas seleccionados: %d / 4" % selected_count
	_continue_button.disabled = selected_count != 4
	_settings_manager.translate_tree(self)

func _on_language_changed() -> void:
	_settings_manager.translate_tree(self)

func _enter_simulation() -> void:
	var selected: Array[String] = []
	for index: int in range(_crew_checks.size()):
		if _crew_checks[index].button_pressed:
			selected.append(CREW_IDS[index])
	if selected.size() != 4:
		_update_selection_state()
		return
	get_tree().root.set_meta("mars_run_seed", int(_seed.value))
	get_tree().root.set_meta("mars_scenario", SCENARIOS[_scenario.selected])
	get_tree().root.set_meta(SELECTED_CREW_META, selected)
	var error_code := get_tree().change_scene_to_file(SIMULATION_SCENE)
	if error_code != OK:
		get_tree().root.remove_meta(SELECTED_CREW_META)
		_message_label.text = "No se pudo abrir la simulación (%s)" % error_string(error_code)

func _preview() -> void:
	var sim = preload("res://domain/simulation.gd").new()
	sim.configure(_data)
	sim.reset_run(DEFAULT_SELECTED_CREW, int(_seed.value), SCENARIOS[_scenario.selected])
	var snap: Dictionary = sim.get_snapshot()
	_forecast.text = "%s\nMapa %s · %s. Tormenta %d%%: sol %d. Partículas %d%%: sol %d.\nMisma semilla y mismas órdenes repiten la misión. Duración: 42 soles de 60 s." % [_data.scenarios[SCENARIOS[_scenario.selected]].description, snap.map.size, snap.map.shape, roundi(snap.forecast.storm.probability * 100), snap.forecast.storm.start_sol, roundi(snap.forecast.solar_particles.probability * 100), snap.forecast.solar_particles.start_sol]

func _style_briefing() -> void:
	var design := Theme.new()
	design.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("101e29")
	panel.border_color = Color("537581")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(16)
	panel.content_margin_left = 28
	panel.content_margin_right = 28
	panel.content_margin_top = 20
	panel.content_margin_bottom = 20
	design.set_stylebox("panel", "PanelContainer", panel)
	for type_name: String in ["Button", "OptionButton"]:
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var button := panel.duplicate() as StyleBoxFlat
			button.bg_color = Color("34545d") if state in ["hover", "pressed"] else Color("203541")
			button.content_margin_top = 8
			button.content_margin_bottom = 8
			design.set_stylebox(state, type_name, button)
	design.set_color("font_color", "Label", Color("dbe8e8"))
	theme = design
