extends Control
## Banco técnico temporal; Andrés puede reemplazarlo sin tocar el dominio.

const Simulation = preload("res://domain/simulation.gd")
const Config = preload("res://domain/simulation_config.gd")
const HistoryPanel = preload("res://scenes/history_panel.gd")
const CREW_SELECTION_SCENE := "res://scenes/crew_selection.tscn"
const SELECTED_CREW_META := "mars_selected_crew_ids"
const SOUND_VALUES_META := "mars_sound_percentages"
const DEFAULT_SOUND_VALUES: Dictionary = {"master": 0, "music": 0, "sfx": 0}
const CREW_IDS := ["engineer", "medic", "botanist", "scientist", "geologist", "technician"]
const CREW_NAMES := {
	"engineer": "Ingeniería",
	"medic": "Medicina",
	"botanist": "Botánica",
	"scientist": "Ciencia",
	"geologist": "Geología",
	"technician": "Sistemas"
}
const DEFAULT_SELECTED_CREW := ["engineer", "medic", "botanist", "technician"]
const GRID_SIZE := 32
const TILE_SPACING := 1.5
const TILE_SIZE := 1.42
const DEFAULT_CAMERA_YAW := PI / 4.0
const DEFAULT_CAMERA_PITCH := deg_to_rad(-35.264)
const DEFAULT_CAMERA_SIZE := 64.0
const CAMERA_MIN_SIZE := 16.0
const CAMERA_MAX_SIZE := 80.0
const CAMERA_ZOOM_STEP: float = (CAMERA_MAX_SIZE - CAMERA_MIN_SIZE) * 0.25
const TILE_SURFACE_Y := 0.08
const BOARD_RENDER_SCALE := 2.0
const SIMULATION_SPEEDS := [0.5, 1.0, 2.0, 4.0]
const BUILDING_NAMES := {
	"solar": "Solar",
	"reactor": "Reactor",
	"oxygen_generator": "Generador de oxígeno",
	"greenhouse": "Invernadero",
	"laboratory": "Laboratorio"
}

var simulation := Simulation.new()
var _message: Label
var _sol_label: Label
var _log: HistoryPanel
var _building_history: HistoryPanel
var _history_generation: int = -1
var _history_building: String = ""
var _robot_choice: OptionButton
var _destination_choice: OptionButton
var _event_status: Label
var _robot_status: Label
var _shelter_button: Button
var _bury_button: Button
var _upgrade_choice: OptionButton
var _upgrade_status: Label
var _maintenance_choice: OptionButton
var _maintenance_status: Label
var _maintenance_session: String = ""
var _inspected_id: String = "b1"
var _inspector: Label
var _inspected_power_button: Button
var _report_status: Label
var _resource_labels: Dictionary = {}
var _building_definitions: Dictionary = {}
var _build_menu: PanelContainer
var _build_menu_title: Label
var _build_menu_options: VBoxContainer
var _build_menu_buttons: Dictionary = {}
var _build_menu_cell: Vector2i = Vector2i(-1, -1)
var _run_button: Button
var _sound_button: Button
var _speed_button: Button
var _speed_menu: PanelContainer
var _sound_menu: PanelContainer
var _sound_option_title: Label
var _sound_sliders: Array[HSlider] = []
var _sound_slider_index: int = 0
var _camera_controls_panel: PanelContainer
var _zoom_label: Label
var _selected_crew_ids: Array[String] = ["engineer", "medic", "botanist", "technician"]
var _kinds: Array[String] = ["solar", "reactor", "oxygen_generator", "greenhouse", "laboratory"]
var _board_root: Node3D
var _viewport_container: SubViewportContainer
var _board_subviewport: SubViewport
var _cell_nodes: Array[Node3D] = []
var _cell_materials: Array[StandardMaterial3D] = []
var _cell_labels: Array[Label3D] = []
var _cell_visuals: Array = []
var _cell_visual_kinds: Array[String] = []
var _last_rendered_snapshot: Dictionary = {}
var _camera_pivot: Node3D
var _camera: Camera3D
var _camera_yaw: float = DEFAULT_CAMERA_YAW
var _dragging_camera: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_load_selected_crew()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_top = 16
	root.offset_right = -20
	root.offset_bottom = -16
	add_child(root)

	var title := Label.new()
	title.text = "MarSins | Banco de simulación · tablero 3D isométrico"
	root.add_child(title)
	var help := Label.new()
	help.text = "La tripulación se elige en su escena y puedes cambiarla con el botón superior. Pulsa una celda vacía para abrir construcciones.\nLas celdas oscurecidas forman el espacio reservado de cada edificio. Pulsa una huella ocupada para inspeccionarla y encender/apagar.\nCámara: A/D o ←/→ giran; W/S o ↑/↓ acercan/alejan. También puedes arrastrar con el botón derecho o usar la rueda.\nEspacio inicia/pausa, Esc o Tab abre el sonido, y R reinicia."
	root.add_child(help)

	var crew_row := HBoxContainer.new()
	root.add_child(crew_row)
	var crew_summary := Label.new()
	crew_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_summary.text = _selected_crew_summary()
	crew_row.add_child(crew_summary)
	var change_crew_button := Button.new()
	change_crew_button.text = "Cambiar tripulación"
	change_crew_button.tooltip_text = "Volver a la selección de personajes"
	change_crew_button.pressed.connect(_open_crew_selection)
	crew_row.add_child(change_crew_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var board_view := Control.new()
	board_view.custom_minimum_size = Vector2(610, 500)
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(board_view)
	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_viewport_container.gui_input.connect(_on_viewport_gui_input)
	_viewport_container.resized.connect(_sync_board_resolution)
	board_view.add_child(_viewport_container)
	_board_subviewport = SubViewport.new()
	_board_subviewport.size = Vector2i(900, 700)
	_board_subviewport.own_world_3d = true
	_board_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_board_subviewport.physics_object_picking = false
	_board_subviewport.msaa_3d = Viewport.MSAA_4X
	_viewport_container.add_child(_board_subviewport)
	_create_isometric_board(_board_subviewport)
	call_deferred("_sync_board_resolution")
	_create_resource_hud(board_view)
	_create_sol_hud(board_view)
	_create_build_menu(board_view)
	_create_camera_controls(board_view)
	_create_simulation_controls(board_view)

	var info_scroll := ScrollContainer.new()
	info_scroll.name = "SimulationInfoScroll"
	info_scroll.custom_minimum_size = Vector2(340.0, 0.0)
	info_scroll.size_flags_horizontal = Control.SIZE_SHRINK_END
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(info_scroll)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 330.0
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.add_child(info)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.hide()
	info.add_child(_message)
	_create_feature_controls(info)
	_add_section_title(info, "Inspector del edificio")
	_inspector = Label.new()
	_inspector.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_inspector)
	_inspected_power_button = Button.new()
	_inspected_power_button.text = "Encender / apagar edificio"
	_inspected_power_button.pressed.connect(_toggle_inspected_building)
	info.add_child(_inspected_power_button)
	_building_history = HistoryPanel.new()
	_building_history.name = "BuildingHistory"
	_building_history.custom_minimum_size.y = 110.0
	info.add_child(_building_history)
	_add_section_title(info, "Tripulación e historial")
	_log = HistoryPanel.new()
	_log.name = "EventHistory"
	_log.custom_minimum_size.y = 190.0
	info.add_child(_log)

	var loaded := Config.load_file()
	if not loaded.ok:
		_message.text = "Error de configuración: %s" % loaded
		_message.show()
		set_process(false)
		return
	_show_result(simulation.configure(loaded.data))
	_building_definitions = loaded.data.buildings.duplicate(true)
	simulation.state_updated.connect(_render)
	_reset()

func _add_section_title(parent: VBoxContainer, title_text: String) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 16)
	parent.add_child(title)

func _create_feature_controls(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Eventos · radiación · refugio")
	_event_status = Label.new()
	_event_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_event_status)
	var shelter_row := HBoxContainer.new()
	parent.add_child(shelter_row)
	_shelter_button = Button.new()
	_shelter_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shelter_button.pressed.connect(_toggle_shelter)
	shelter_row.add_child(_shelter_button)
	_bury_button = Button.new()
	_bury_button.text = "Enterrar hábitat"
	_bury_button.tooltip_text = "Cuesta 10 masa y 20 regolito; el trabajo tarda 25 segundos"
	_bury_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bury_button.pressed.connect(func() -> void: _show_result(simulation.bury_habitat()))
	shelter_row.add_child(_bury_button)

	_add_section_title(parent, "Expediciones ROBERT")
	var mission_row := HBoxContainer.new()
	parent.add_child(mission_row)
	_robot_choice = OptionButton.new()
	_robot_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_robot_choice.add_item("ROBERT 1")
	_robot_choice.add_item("ROBERT 2")
	_robot_choice.select(0)
	mission_row.add_child(_robot_choice)
	_destination_choice = OptionButton.new()
	_destination_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var destination_ids := ["ice", "quarry", "wreckage"]
	var destination_names := ["Hielo → agua", "Cantera → regolito", "Restos → masa"]
	for index: int in range(destination_names.size()):
		var destination_name: String = destination_names[index]
		_destination_choice.add_item(destination_name)
		_destination_choice.set_item_metadata(_destination_choice.item_count - 1, destination_ids[index])
	_destination_choice.select(0)
	mission_row.add_child(_destination_choice)
	var send_button := Button.new()
	send_button.text = "Enviar"
	send_button.tooltip_text = "Enviar el ROBERT seleccionado a la expedición"
	send_button.pressed.connect(_send_robert)
	mission_row.add_child(send_button)
	_robot_status = Label.new()
	_robot_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_robot_status)

	_add_section_title(parent, "Mejoras")
	var upgrade_row := HBoxContainer.new()
	parent.add_child(upgrade_row)
	_upgrade_choice = OptionButton.new()
	_upgrade_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_row.add_child(_upgrade_choice)
	var upgrade_button := Button.new()
	upgrade_button.text = "Mejorar"
	upgrade_button.pressed.connect(_start_selected_upgrade)
	upgrade_row.add_child(upgrade_button)
	_upgrade_status = Label.new()
	_upgrade_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_upgrade_status)

	_add_section_title(parent, "Mantenimiento · controles provisionales")
	var maintenance_choice_row := HBoxContainer.new()
	parent.add_child(maintenance_choice_row)
	_maintenance_choice = OptionButton.new()
	_maintenance_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	maintenance_choice_row.add_child(_maintenance_choice)
	var attend_button := Button.new()
	attend_button.text = "Atender"
	attend_button.pressed.connect(_begin_maintenance)
	maintenance_choice_row.add_child(attend_button)
	var maintenance_result_row := HBoxContainer.new()
	parent.add_child(maintenance_result_row)
	var success_button := Button.new()
	success_button.text = "Probar éxito"
	success_button.tooltip_text = "Resultado temporal; falta integrar el minijuego de mantenimiento"
	success_button.pressed.connect(func() -> void: _apply_maintenance_result(true))
	maintenance_result_row.add_child(success_button)
	var failure_button := Button.new()
	failure_button.text = "Probar fallo"
	failure_button.tooltip_text = "Resultado temporal; falta integrar el minijuego de mantenimiento"
	failure_button.pressed.connect(func() -> void: _apply_maintenance_result(false))
	maintenance_result_row.add_child(failure_button)
	var abandon_button := Button.new()
	abandon_button.text = "Abandonar"
	abandon_button.pressed.connect(func() -> void: _apply_maintenance_result(false, true))
	maintenance_result_row.add_child(abandon_button)
	var reactivate_button := Button.new()
	reactivate_button.text = "Reactivar"
	reactivate_button.pressed.connect(_reactivate_selected_building)
	maintenance_result_row.add_child(reactivate_button)
	_maintenance_status = Label.new()
	_maintenance_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_maintenance_status)

	_add_section_title(parent, "Informe por sol")
	_report_status = Label.new()
	_report_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_report_status)

func _process(delta: float) -> void:
	simulation.advance(delta)

func _send_robert() -> void:
	if _robot_choice == null or _destination_choice == null or _destination_choice.selected < 0:
		return
	var robert_id := "robert_%d" % (_robot_choice.selected + 1)
	var destination_id := str(_destination_choice.get_item_metadata(_destination_choice.selected))
	_show_result(simulation.send_robert(robert_id, destination_id))

func _toggle_shelter() -> void:
	var snapshot: Dictionary = simulation.get_snapshot()
	_show_result(simulation.set_sheltered(not bool(snapshot.get("sheltered", false))))

func _start_selected_upgrade() -> void:
	var building_id := _selected_option_id(_upgrade_choice)
	if building_id.is_empty():
		_show_message("Selecciona un edificio construido para mejorar.")
		return
	_show_result(simulation.start_upgrade(building_id))

func _begin_maintenance() -> void:
	var building_id := _selected_option_id(_maintenance_choice)
	if building_id.is_empty():
		_show_message("Construye un reactor o generador de oxígeno antes de atender mantenimiento.")
		return
	var result: Dictionary = simulation.begin_maintenance(building_id)
	if result.ok:
		_maintenance_session = str(result.result.get("id", ""))
	_show_result(result)

func _apply_maintenance_result(success: bool, abandoned: bool = false) -> void:
	if _maintenance_session.is_empty():
		_show_message("Primero pulsa Atender para iniciar una sesión de mantenimiento.")
		return
	var result: Dictionary = simulation.apply_maintenance_result(_maintenance_session, success, 0.0, abandoned)
	if result.ok:
		_maintenance_session = ""
	_show_result(result)

func _reactivate_selected_building() -> void:
	var building_id := _selected_option_id(_maintenance_choice)
	if building_id.is_empty():
		_show_message("Selecciona un reactor o generador de oxígeno.")
		return
	_show_result(simulation.reactivate_building(building_id))

func _toggle_inspected_building() -> void:
	for building: Dictionary in simulation.get_snapshot().get("buildings", []):
		if str(building.id) == _inspected_id:
			_show_result(simulation.set_enabled(_inspected_id, not bool(building.enabled)))
			return

func _selected_option_id(option: OptionButton) -> String:
	if option == null or option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))

func _show_message(message: String) -> void:
	_message.text = message
	_message.show()

func _sync_board_resolution() -> void:
	if _viewport_container == null or _board_subviewport == null:
		return
	var display_size := _viewport_container.size
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return
	var target_size := Vector2i(
		maxi(1, roundi(display_size.x * BOARD_RENDER_SCALE)),
		maxi(1, roundi(display_size.y * BOARD_RENDER_SCALE))
	)
	if _board_subviewport.size != target_size:
		_board_subviewport.size = target_size

func _create_resource_hud(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "ResourceHUD"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = -12
	panel.offset_bottom = 72
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	for key: String in ["mass", "air", "water", "food", "energy"]:
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "%s: —" % _resource_name(key)
		if key == "energy":
			label.tooltip_text = "Suministro eléctrico disponible / demanda eléctrica"
		row.add_child(label)
		_resource_labels[key] = label

func _create_sol_hud(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "SolHUD"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -242.0
	panel.offset_top = 82.0
	panel.offset_right = -12.0
	panel.offset_bottom = 126.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	_sol_label = Label.new()
	_sol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sol_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sol_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sol_label.text = "Soles transcurridos: 0"
	panel.add_child(_sol_label)

func _create_build_menu(parent: Control) -> void:
	_build_menu = PanelContainer.new()
	_build_menu.name = "BuildMenu"
	_build_menu.position = Vector2(12.0, 86.0)
	_build_menu.custom_minimum_size = Vector2(300.0, 0.0)
	_build_menu.visible = false
	parent.add_child(_build_menu)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_build_menu.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_build_menu_title = Label.new()
	_build_menu_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_menu_title.text = "Construir"
	header.add_child(_build_menu_title)
	var close_button := Button.new()
	close_button.text = "Cerrar"
	close_button.pressed.connect(func() -> void: _build_menu.hide())
	header.add_child(close_button)
	_build_menu_options = VBoxContainer.new()
	content.add_child(_build_menu_options)
	for kind: String in _kinds:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_place_selected_building.bind(kind))
		_build_menu_options.add_child(button)
		_build_menu_buttons[kind] = button

func _create_camera_controls(parent: Control) -> void:
	_camera_controls_panel = PanelContainer.new()
	_camera_controls_panel.name = "CameraControls"
	_camera_controls_panel.anchor_left = 1.0
	_camera_controls_panel.anchor_right = 1.0
	_camera_controls_panel.anchor_top = 1.0
	_camera_controls_panel.anchor_bottom = 1.0
	_camera_controls_panel.offset_left = -340.0
	_camera_controls_panel.offset_top = -76.0
	_camera_controls_panel.offset_right = -12.0
	_camera_controls_panel.offset_bottom = -12.0
	parent.add_child(_camera_controls_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_camera_controls_panel.add_child(row)
	_add_icon_button(row, "←", "Girar izquierda (A / ←)", func() -> void: _rotate_camera(-PI / 4.0))
	_add_icon_button(row, "→", "Girar derecha (D / →)", func() -> void: _rotate_camera(PI / 4.0))
	_add_icon_button(row, "+", "Acercar (W / ↑)", func() -> void: _zoom_camera(-CAMERA_ZOOM_STEP))
	_zoom_label = Label.new()
	_zoom_label.name = "ZoomPercentage"
	_zoom_label.custom_minimum_size = Vector2(48.0, 44.0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_label.tooltip_text = "Nivel de acercamiento"
	row.add_child(_zoom_label)
	_add_icon_button(row, "-", "Alejar (S / ↓)", func() -> void: _zoom_camera(CAMERA_ZOOM_STEP))
	_add_icon_button(row, "⟲", "Restablecer vista", _reset_camera)
	_update_zoom_percentage()

func _create_simulation_controls(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "SimulationControls"
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 12.0
	panel.offset_top = -76.0
	panel.offset_right = 272.0
	panel.offset_bottom = -12.0
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	_add_icon_button(row, "↻", "Reiniciar partida (R)", _reset)
	_run_button = _add_icon_button(row, "▶", "Iniciar partida", _toggle_run_state)
	_sound_button = _add_icon_button(row, "⚙", "Opciones de sonido (Esc / Tab)", _toggle_sound_menu)
	_speed_button = Button.new()
	_speed_button.text = "×1.0 ▸"
	_speed_button.tooltip_text = "Velocidad de simulación"
	_speed_button.custom_minimum_size = Vector2(82.0, 44.0)
	_speed_button.pressed.connect(_toggle_speed_menu)
	row.add_child(_speed_button)

	_speed_menu = PanelContainer.new()
	_speed_menu.name = "SpeedMenu"
	_speed_menu.anchor_top = 1.0
	_speed_menu.anchor_bottom = 1.0
	_speed_menu.offset_left = 284.0
	_speed_menu.offset_top = -76.0
	_speed_menu.offset_right = 530.0
	_speed_menu.offset_bottom = -12.0
	_speed_menu.visible = false
	parent.add_child(_speed_menu)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 5)
	_speed_menu.add_child(speed_row)
	for speed: float in SIMULATION_SPEEDS:
		var speed_option := Button.new()
		speed_option.text = "×%.1f" % speed
		speed_option.tooltip_text = "Velocidad ×%.1f" % speed
		speed_option.custom_minimum_size = Vector2(52.0, 44.0)
		speed_option.pressed.connect(_select_speed.bind(speed))
		speed_row.add_child(speed_option)
	_create_sound_menu(parent)

func _create_sound_menu(parent: Control) -> void:
	_sound_menu = PanelContainer.new()
	_sound_menu.name = "SoundOptions"
	_sound_menu.anchor_top = 1.0
	_sound_menu.anchor_bottom = 1.0
	_sound_menu.offset_left = 12.0
	_sound_menu.offset_top = -242.0
	_sound_menu.offset_right = 322.0
	_sound_menu.offset_bottom = -82.0
	_sound_menu.visible = false
	_sound_menu.z_index = 10
	parent.add_child(_sound_menu)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_sound_menu.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var header_balance := Control.new()
	header_balance.custom_minimum_size = Vector2(28.0, 0.0)
	header.add_child(header_balance)
	var navigation := HBoxContainer.new()
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(navigation)
	var previous_button := Button.new()
	previous_button.text = "‹"
	previous_button.tooltip_text = "Enfocar el control de volumen anterior"
	previous_button.custom_minimum_size = Vector2(36.0, 32.0)
	previous_button.add_theme_font_size_override("font_size", 22)
	previous_button.pressed.connect(_focus_sound_slider.bind(-1))
	navigation.add_child(previous_button)
	_sound_option_title = Label.new()
	_sound_option_title.text = "Sonido"
	_sound_option_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sound_option_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sound_option_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	navigation.add_child(_sound_option_title)
	var next_button := Button.new()
	next_button.text = "›"
	next_button.tooltip_text = "Enfocar el siguiente control de volumen"
	next_button.custom_minimum_size = Vector2(36.0, 32.0)
	next_button.add_theme_font_size_override("font_size", 22)
	next_button.pressed.connect(_focus_sound_slider.bind(1))
	navigation.add_child(next_button)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Cerrar opciones de sonido"
	close_button.pressed.connect(_toggle_sound_menu)
	header.add_child(close_button)
	_sound_sliders.clear()
	var saved_values := _get_sound_values()
	_add_sound_slider_row(content, "master", "Master", saved_values)
	_add_sound_slider_row(content, "music", "Music", saved_values)
	_add_sound_slider_row(content, "sfx", "SFX", saved_values)

func _focus_sound_slider(direction: int) -> void:
	if _sound_sliders.is_empty():
		return
	_sound_slider_index = posmod(_sound_slider_index + direction, _sound_sliders.size())
	_sound_sliders[_sound_slider_index].grab_focus()

func _add_sound_slider_row(parent: VBoxContainer, volume_key: String, title: String, values: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(55.0, 0.0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.name = "%sVolumeSlider" % title
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = float(values.get(volume_key, 0))
	row.add_child(slider)
	var percentage_label := Label.new()
	percentage_label.custom_minimum_size = Vector2(42.0, 0.0)
	percentage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percentage_label.text = "%d%%" % roundi(slider.value)
	row.add_child(percentage_label)
	_sound_sliders.append(slider)
	slider.value_changed.connect(_on_sound_value_changed.bind(volume_key, percentage_label))

func _get_sound_values() -> Dictionary:
	var saved_values: Variant = get_tree().root.get_meta(SOUND_VALUES_META, DEFAULT_SOUND_VALUES)
	var values: Dictionary = DEFAULT_SOUND_VALUES.duplicate(true)
	if saved_values is Dictionary:
		for key: String in values.keys():
			values[key] = clampi(roundi(float(saved_values.get(key, values[key]))), 0, 100)
	return values

func _on_sound_value_changed(value: float, volume_key: String, percentage_label: Label) -> void:
	var percentage := clampi(roundi(value), 0, 100)
	percentage_label.text = "%d%%" % percentage
	var values := _get_sound_values()
	values[volume_key] = percentage
	get_tree().root.set_meta(SOUND_VALUES_META, values)

func _toggle_sound_menu() -> void:
	if _sound_menu == null:
		return
	if not _sound_menu.visible and _speed_menu.visible:
		_speed_menu.hide()
		_camera_controls_panel.show()
	_sound_menu.visible = not _sound_menu.visible

func _toggle_run_state() -> void:
	var snapshot := simulation.get_snapshot()
	match snapshot.get("phase", ""):
		"planning":
			_show_result(simulation.start_run())
		"running":
			_show_result(simulation.set_paused(not snapshot.get("paused", false)))

func _toggle_speed_menu() -> void:
	_sound_menu.hide()
	_speed_menu.visible = not _speed_menu.visible
	_camera_controls_panel.visible = not _speed_menu.visible

func _select_speed(speed: float) -> void:
	_speed_menu.hide()
	_sound_menu.hide()
	_camera_controls_panel.show()
	_show_result(simulation.set_speed(speed))

func _add_icon_button(parent: Node, icon: String, tooltip: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = icon
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(46.0, 44.0)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _show_build_menu(cell: Vector2i) -> void:
	_build_menu_cell = cell
	_build_menu_title.text = "Construir en (%d, %d)" % [cell.x, cell.y]
	_build_menu.show()
	_refresh_build_menu()

func _refresh_build_menu() -> void:
	if _build_menu_cell.x < 0:
		return
	for kind: String in _kinds:
		var button: Button = _build_menu_buttons[kind]
		var definition: Dictionary = _building_definitions.get(kind, {})
		var cost := float(definition.get("mass", 0.0))
		var duration := int(definition.get("build_seconds", 0))
		var footprint := simulation.get_building_footprint_size(kind)
		var preview := simulation.preview_placement(kind, _build_menu_cell)
		var text := "%s · %d×%d · %.0f masa · %d s" % [BUILDING_NAMES[kind], footprint, footprint, cost, duration]
		if not preview.ok:
			text += " · %s" % _placement_error_text(preview.error_code)
		button.text = text
		button.disabled = not preview.ok

func _placement_error_text(code: String) -> String:
	var errors: Dictionary = {
		"insufficient_mass": "masa insuficiente",
		"reactor_too_close": "reactor muy cerca",
		"invalid_phase": "partida no disponible",
		"outside_grid": "fuera del mapa",
		"footprint_outside_grid": "espacio fuera del mapa",
		"occupied_footprint": "espacio ocupado",
		"invalid_building": "no disponible"
	}
	return str(errors.get(code, code))

func _place_selected_building(kind: String) -> void:
	var result := simulation.place_building(kind, _build_menu_cell)
	_show_result(result)
	if result.ok:
		_build_menu.hide()
	else:
		_refresh_build_menu()

func _resource_name(key: String) -> String:
	var names: Dictionary = {"mass": "Masa", "air": "Aire", "water": "Agua", "food": "Comida", "energy": "Energía"}
	return str(names.get(key, key.capitalize()))

func _load_selected_crew() -> void:
	var root := get_tree().root
	if not root.has_meta(SELECTED_CREW_META):
		return
	var saved: Variant = root.get_meta(SELECTED_CREW_META)
	root.remove_meta(SELECTED_CREW_META)
	if not saved is Array or saved.size() != 4:
		return
	var validated: Array[String] = []
	for crew_id: Variant in saved:
		if not crew_id is String or crew_id not in CREW_IDS or crew_id in validated:
			return
		validated.append(str(crew_id))
	_selected_crew_ids = validated

func _selected_crew_summary() -> String:
	var selected_names: PackedStringArray = []
	for crew_id: String in _selected_crew_ids:
		selected_names.append(str(CREW_NAMES.get(crew_id, crew_id)))
	return "Tripulación: %s" % " · ".join(selected_names)

func _open_crew_selection() -> void:
	get_tree().root.set_meta(SELECTED_CREW_META, _selected_crew_ids.duplicate())
	var error_code := get_tree().change_scene_to_file(CREW_SELECTION_SCENE)
	if error_code != OK:
		get_tree().root.remove_meta(SELECTED_CREW_META)
		_message.text = "No se pudo abrir la selección de tripulación (%s)" % error_string(error_code)
		_message.show()

func _rotate_camera(amount: float) -> void:
	_camera_yaw = wrapf(_camera_yaw + amount, -TAU, TAU)
	_update_camera()

func _zoom_camera(amount: float) -> void:
	if _camera == null:
		return
	_camera.size = clampf(_camera.size + amount, CAMERA_MIN_SIZE, CAMERA_MAX_SIZE)
	_update_zoom_percentage()

func _update_zoom_percentage() -> void:
	if _zoom_label == null:
		return
	if _camera == null:
		_zoom_label.text = "0%"
		return
	var zoom_range: float = CAMERA_MAX_SIZE - CAMERA_MIN_SIZE
	var zoom_progress: float = (CAMERA_MAX_SIZE - _camera.size) / zoom_range
	var percentage := clampi(roundi(zoom_progress * 100.0), 0, 100)
	_zoom_label.text = "%d%%" % percentage

func _reset_camera() -> void:
	_camera_yaw = DEFAULT_CAMERA_YAW
	if _camera != null:
		_camera.size = DEFAULT_CAMERA_SIZE
	_update_zoom_percentage()
	_update_camera()

func _update_camera() -> void:
	if _camera_pivot == null:
		return
	_camera_pivot.rotation = Vector3(DEFAULT_CAMERA_PITCH, _camera_yaw, 0.0)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return
	var overlay_open: bool = _sound_menu.visible or _speed_menu.visible or _build_menu.visible
	match key_event.keycode:
		KEY_ESCAPE, KEY_TAB:
			_toggle_sound_menu()
		KEY_SPACE:
			_toggle_run_state()
		KEY_R:
			_reset()
		KEY_A, KEY_LEFT:
			if overlay_open:
				return
			_rotate_camera(-PI / 4.0)
		KEY_D, KEY_RIGHT:
			if overlay_open:
				return
			_rotate_camera(PI / 4.0)
		KEY_W, KEY_UP:
			if overlay_open:
				return
			_zoom_camera(-CAMERA_ZOOM_STEP)
		KEY_S, KEY_DOWN:
			if overlay_open:
				return
			_zoom_camera(CAMERA_ZOOM_STEP)
		_:
			return
	get_viewport().set_input_as_handled()

func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_camera = event.pressed
			_last_mouse_position = event.position
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-CAMERA_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(CAMERA_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _speed_menu.visible:
				_speed_menu.hide()
				_camera_controls_panel.show()
			if _sound_menu.visible:
				_sound_menu.hide()
			_select_cell_at(_viewport_container.get_local_mouse_position())
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_camera:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		var movement: Vector2 = motion_event.position - _last_mouse_position
		_last_mouse_position = motion_event.position
		_camera_yaw -= movement.x * 0.01
		_update_camera()
		get_viewport().set_input_as_handled()

func _create_isometric_board(viewport: SubViewport) -> void:
	_board_root = Node3D.new()
	_board_root.name = "IsometricBoard"
	viewport.add_child(_board_root)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("202b38")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce5ef")
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	_board_root.add_child(environment_node)

	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_board_root.add_child(_camera_pivot)
	_camera = Camera3D.new()
	_camera.name = "IsometricCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = DEFAULT_CAMERA_SIZE
	_camera.position = Vector3(0.0, 0.0, 70.0)
	_camera_pivot.add_child(_camera)
	_camera.make_current()
	_update_camera()

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	_board_root.add_child(light)

	var center_offset := float(GRID_SIZE - 1) * TILE_SPACING / 2.0
	var board_extent := GRID_SIZE * TILE_SPACING + 0.5
	_add_box(_board_root, Vector3(board_extent, 0.16, board_extent), Vector3(0.0, -0.18, 0.0), Color("303d49"))
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(TILE_SIZE, 0.16, TILE_SIZE)
	for y: int in range(GRID_SIZE):
		for x: int in range(GRID_SIZE):
			var cell_node := Node3D.new()
			cell_node.name = "Cell_%d_%d" % [x, y]
			cell_node.position = Vector3(x * TILE_SPACING - center_offset, 0.0, y * TILE_SPACING - center_offset)
			var tile := MeshInstance3D.new()
			tile.mesh = tile_mesh
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := _make_material(Color("b9a783") if (x + y) % 2 == 0 else Color("a99169"))
			tile.material_override = material
			cell_node.add_child(tile)
			_board_root.add_child(cell_node)
			_cell_nodes.append(cell_node)
			_cell_materials.append(material)
			_cell_labels.append(null)
			_cell_visuals.append(null)
			_cell_visual_kinds.append("")

func _select_cell_at(mouse_position: Vector2) -> void:
	if _camera == null or _board_subviewport == null or _viewport_container == null:
		return
	if _viewport_container.size.x <= 0.0 or _viewport_container.size.y <= 0.0:
		return
	var viewport_position := mouse_position * Vector2(_board_subviewport.size) / _viewport_container.size
	var ray_origin := _camera.project_ray_origin(viewport_position)
	var ray_direction := _camera.project_ray_normal(viewport_position)
	if absf(ray_direction.y) < 0.000001:
		return
	var distance: float = (TILE_SURFACE_Y - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return
	var hit := ray_origin + ray_direction * distance
	var center_offset := float(GRID_SIZE - 1) * TILE_SPACING / 2.0
	var cell_x := int(round((hit.x + center_offset) / TILE_SPACING))
	var cell_y := int(round((hit.z + center_offset) / TILE_SPACING))
	if cell_x < 0 or cell_y < 0 or cell_x >= GRID_SIZE or cell_y >= GRID_SIZE:
		return
	var center_x := float(cell_x) * TILE_SPACING - center_offset
	var center_z := float(cell_y) * TILE_SPACING - center_offset
	if absf(hit.x - center_x) > TILE_SIZE / 2.0 or absf(hit.z - center_z) > TILE_SIZE / 2.0:
		return
	_cell_clicked(Vector2i(cell_x, cell_y))

func _reset() -> void:
	_reset_camera()
	_maintenance_session = ""
	_inspected_id = "b1"
	_history_building = ""
	_last_rendered_snapshot.clear()
	_show_result(simulation.reset_run(_selected_crew_ids, 1))

func _cell_clicked(cell: Vector2i) -> void:
	for building: Dictionary in simulation.get_snapshot().get("buildings", []):
		var anchor := Vector2i(int(building.x), int(building.y))
		if cell in simulation.get_building_footprint_cells(str(building.kind), anchor):
			_inspected_id = str(building.id)
			_build_menu.hide()
			_show_result(simulation.set_enabled(building.id, not building.enabled))
			_last_rendered_snapshot.clear()
			_render(simulation.get_snapshot())
			return
	_show_build_menu(cell)

func _show_result(result: Dictionary) -> void:
	if result.ok:
		_message.text = ""
		_message.hide()
	else:
		_message.text = _error_text(str(result.get("error_code", "unknown_error")))
		_message.show()

func _error_text(code: String) -> String:
	var messages: Dictionary = {
		"invalid_phase": "Esta acción no está disponible en esta fase de la partida.",
		"invalid_building": "Ese tipo de construcción no está disponible.",
		"outside_grid": "La casilla está fuera del tablero.",
		"footprint_outside_grid": "La huella completa del edificio sale del tablero.",
		"occupied_footprint": "Parte de esa huella ya está ocupada por otro edificio.",
		"reactor_too_close": "El reactor debe estar al menos a dos casillas del hábitat.",
		"unknown_robert": "No se encontró ese ROBERT.",
		"unknown_destination": "No se encontró ese destino de expedición.",
		"laboratory_not_operational": "El laboratorio debe estar terminado, encendido y con potencia.",
		"insufficient_power": "No hay suficiente potencia libre.",
		"robert_unavailable": "Este ROBERT está en misión o se perdió.",
		"crew_sheltered": "Sal del refugio antes de iniciar una expedición o mejora.",
		"insufficient_mass": "No hay suficiente masa para esta acción.",
		"max_level": "Este edificio ya está en nivel 2.",
		"upgrade_in_progress": "Este edificio ya tiene una mejora en curso.",
		"building_under_construction": "Espera a que termine la construcción.",
		"upgrade_not_supported": "El hábitat se protege mediante Enterrar y no admite mejora.",
		"maintenance_not_pending": "Este edificio no tiene mantenimiento pendiente.",
		"maintenance_suspended": "La sesión se suspendió por una crisis o por el refugio.",
		"maintenance_attempts_exhausted": "Se agotaron los intentos o el tiempo disponible.",
		"maintenance_cooling_down": "Espera a que termine el enfriamiento para reactivar.",
		"maintenance_not_shutdown": "Este edificio no está apagado por mantenimiento.",
		"maintenance_session_active": "Ya hay una sesión de este edificio abierta.",
		"another_maintenance_active": "Termina la otra sesión de mantenimiento antes de abrir esta.",
		"maintenance_result_already_closed": "Esta sesión ya se cerró o venció.",
		"unknown_maintenance_session": "No hay una sesión de mantenimiento vigente.",
		"burial_already_started": "El enterramiento del hábitat ya comenzó.",
		"insufficient_resources": "Falta masa o regolito para enterrar el hábitat.",
		"habitat_required": "El hábitat principal no se puede apagar."
	}
	return str(messages.get(code, "Acción rechazada: " + code))

func _render(snapshot: Dictionary) -> void:
	if not _last_rendered_snapshot.is_empty() and snapshot == _last_rendered_snapshot:
		return
	_last_rendered_snapshot = snapshot.duplicate(true)
	var new_run := int(snapshot.get("run_generation", -1)) != _history_generation
	_history_generation = int(snapshot.get("run_generation", -1))
	var resources: Dictionary = snapshot.resources
	var power: Dictionary = snapshot.power
	_run_button.disabled = snapshot.phase == "finished"
	if snapshot.phase == "planning":
		_run_button.text = "▶"
		_run_button.tooltip_text = "Iniciar partida (Espacio)"
	elif snapshot.phase == "running" and snapshot.paused:
		_run_button.text = "▶"
		_run_button.tooltip_text = "Continuar simulación (Espacio)"
	elif snapshot.phase == "running":
		_run_button.text = "⏸"
		_run_button.tooltip_text = "Pausar simulación (Espacio)"
	else:
		_run_button.text = "▶"
		_run_button.tooltip_text = "Partida terminada · R para reiniciar"
	_speed_button.disabled = snapshot.phase == "finished"
	_speed_button.text = "×%.1f ▸" % snapshot.speed
	if snapshot.phase == "finished":
		_speed_menu.hide()
		_camera_controls_panel.show()
	for key: String in ["mass", "air", "water", "food"]:
		_resource_labels[key].text = "%s: %.1f" % [_resource_name(key), resources[key]]
	_resource_labels["energy"].text = "Energía: %.1f / %.1f" % [power.supply, power.demand]
	_sol_label.text = "Soles transcurridos: %d" % int(snapshot.get("completed_sols", 0))
	if _build_menu != null and _build_menu.visible:
		_refresh_build_menu()
	var buildings_by_cell: Dictionary = {}
	var reserved_cells: Dictionary = {}
	for building: Dictionary in snapshot.buildings:
		buildings_by_cell[int(building.y) * GRID_SIZE + int(building.x)] = building
		var anchor := Vector2i(int(building.x), int(building.y))
		for footprint_cell: Vector2i in simulation.get_building_footprint_cells(str(building.kind), anchor):
			reserved_cells[footprint_cell.y * GRID_SIZE + footprint_cell.x] = true
	for index: int in range(_cell_nodes.size()):
		if not buildings_by_cell.has(index):
			if reserved_cells.has(index):
				_cell_materials[index].albedo_color = Color("71634f")
			else:
				_cell_materials[index].albedo_color = Color("b9a783") if (index % GRID_SIZE + int(index / GRID_SIZE)) % 2 == 0 else Color("a99169")
			if _cell_labels[index] != null:
				_cell_labels[index].queue_free()
				_cell_labels[index] = null
			if _cell_visuals[index] != null:
				_cell_visuals[index].queue_free()
				_cell_visuals[index] = null
				_cell_visual_kinds[index] = ""
			continue

		var building: Dictionary = buildings_by_cell[index]
		var kind: String = building.kind
		if _cell_visuals[index] == null or _cell_visual_kinds[index] != kind:
			if _cell_visuals[index] != null:
				_cell_visuals[index].queue_free()
			var visual := _create_building_visual(kind)
			visual.position = Vector3(0.0, 0.09, 0.0)
			_cell_nodes[index].add_child(visual)
			_cell_visuals[index] = visual
			_cell_visual_kinds[index] = kind

		if _cell_labels[index] == null:
			var label := _create_building_label()
			_cell_nodes[index].add_child(label)
			_cell_labels[index] = label
		var state := "%ds" % building.remaining_seconds if building.remaining_seconds > 0 else ("ON" if building.powered else "OFF")
		var short_names := {"habitat": "HÁBITAT", "solar": "SOLAR", "reactor": "REACTOR", "oxygen_generator": "OXÍGENO", "greenhouse": "CULTIVO", "laboratory": "LAB"}
		_cell_labels[index].text = "%s\n%s" % [short_names.get(kind, kind.to_upper()), state]
		_cell_labels[index].position.y = 1.05
		if building.warning != "":
			_cell_materials[index].albedo_color = Color("c76d58")
		elif building.remaining_seconds > 0:
			_cell_materials[index].albedo_color = Color("d19b4a")
		elif not building.enabled:
			_cell_materials[index].albedo_color = Color("646c74")
		elif building.powered:
			_cell_materials[index].albedo_color = Color("78a96e")
		else:
			_cell_materials[index].albedo_color = Color("958c7d")
	_render_feature_panels(snapshot, new_run)
	var lines: PackedStringArray = []
	for member: Dictionary in snapshot.crew:
		lines.append("%s: %.1f salud · dosis %.2f" % [member.id, member.health, member.get("dose", 0.0)])
	lines.append("Regolito: %.1f" % float(resources.get("regolith", 0.0)))
	for robot: Dictionary in snapshot.get("roberts", []):
		if robot.state == "on_mission":
			lines.append("%s: en misión → %s · faltan %ds · soporte %s" % [robot.id, robot.destination, maxi(0, int(robot.return_seconds) - int(snapshot.elapsed_seconds)), robot.get("powered", false)])
		else:
			lines.append("%s: %s" % [robot.id, "disponible" if robot.state == "available" else "perdido"])
	if not snapshot.result.is_empty():
		lines.append("FINAL: %s" % snapshot.result.verdict)
	if not snapshot.get("sol_reports", []).is_empty():
		var report: Dictionary = snapshot.sol_reports[-1]
		lines.append("Último informe · Sol %s%s: variación %s · bloqueos %s" % [report.get("sol", "?"), " parcial" if report.get("partial", false) else "", str(report.get("delta", {})), str(report.get("blocked_seconds", {}))])
	lines.append("\nÚltimos hechos:")
	for entry: Dictionary in snapshot.log:
		lines.append("%ss · %s · %s" % [entry.seconds, entry.reason, entry.target])
	_log.update_history("\n".join(lines), new_run)

func _render_feature_panels(snapshot: Dictionary, new_run: bool) -> void:
	var forecast: Dictionary = snapshot.get("forecast", simulation.get_forecast())
	var current_event: Dictionary = snapshot.get("event", {})
	var event_text := "sin evento activo"
	if not current_event.is_empty():
		event_text = "%s · %s · %d–%d s" % [current_event.get("kind", "evento"), current_event.get("state", ""), current_event.get("start_seconds", 0), current_event.get("end_seconds", 0)]
	var storm_probability := roundi(float(forecast.get("storm", {}).get("probability", 0.0)) * 100.0)
	var particles_probability := roundi(float(forecast.get("solar_particles", {}).get("probability", 0.0)) * 100.0)
	var crew_dose := 0.0
	for member: Dictionary in snapshot.get("crew", []):
		crew_dose += float(member.get("dose", 0.0))
	_event_status.text = "Pronóstico: tormenta %d%% · partículas solares %d%%\nEvento: %s\nRefugio: %s · hábitat: %s · dosis del equipo: %.2f" % [storm_probability, particles_probability, event_text, "activo" if snapshot.get("sheltered", false) else "inactivo", snapshot.get("burial", {}).get("state", "superficie"), crew_dose]
	_shelter_button.text = "Salir del refugio" if snapshot.get("sheltered", false) else "Entrar al refugio"
	_shelter_button.disabled = snapshot.get("phase") != "running"
	var burial_state: String = str(snapshot.get("burial", {}).get("state", "surface"))
	_bury_button.disabled = snapshot.get("phase") != "running" or burial_state != "surface"
	_bury_button.text = "Enterrar hábitat" if burial_state == "surface" else ("Enterrando · %ss" % snapshot.get("burial", {}).get("remaining_seconds", 0) if burial_state == "building" else "Hábitat enterrado")

	var selected_robert_id := "robert_%d" % (_robot_choice.selected + 1)
	var destination_id := str(_destination_choice.get_item_metadata(_destination_choice.selected)) if _destination_choice.selected >= 0 else "ice"
	var preview: Dictionary = simulation.preview_robert(selected_robert_id, destination_id)
	var robot_lines: PackedStringArray = []
	for robot: Dictionary in snapshot.get("roberts", []):
		if robot.state == "on_mission":
			robot_lines.append("%s: misión a %s, retorno en %ds" % [robot.id, robot.destination, maxi(0, int(robot.return_seconds) - int(snapshot.elapsed_seconds))])
		else:
			robot_lines.append("%s: %s" % [robot.id, "disponible" if robot.state == "available" else "perdido"])
	if preview.ok:
		_destination_choice.tooltip_text = "Carga prevista: %s %s · riesgo actual %.1f%%; puede cambiar con tormentas" % [preview.result.amount, preview.result.resource, float(preview.result.loss_probability) * 100.0]
		_robot_status.text = "%s\nVista previa: %s %s · riesgo %.1f%%" % [" · ".join(robot_lines), preview.result.amount, preview.result.resource, float(preview.result.loss_probability) * 100.0]
	else:
		_destination_choice.tooltip_text = _error_text(str(preview.get("error_code", "invalid_phase")))
		_robot_status.text = "%s\nSalida bloqueada: %s" % [" · ".join(robot_lines), _error_text(str(preview.get("error_code", "invalid_phase")))]

	var selected_upgrade_id := _selected_option_id(_upgrade_choice)
	_upgrade_choice.clear()
	var selected_upgrade_index := -1
	for building: Dictionary in snapshot.get("buildings", []):
		if building.kind == "habitat":
			continue
		_upgrade_choice.add_item("%s · %s N%d" % [building.id, BUILDING_NAMES.get(building.kind, building.kind), building.level])
		var index := _upgrade_choice.item_count - 1
		_upgrade_choice.set_item_metadata(index, building.id)
		if building.id == selected_upgrade_id or (selected_upgrade_id.is_empty() and building.id == _inspected_id):
			selected_upgrade_index = index
	if selected_upgrade_index < 0 and _upgrade_choice.item_count > 0:
		selected_upgrade_index = 0
	if selected_upgrade_index >= 0:
		_upgrade_choice.select(selected_upgrade_index)
	_upgrade_status.text = "Construye un edificio para ver su costo y duración de mejora."
	if _upgrade_choice.selected >= 0:
		var upgrade: Dictionary = simulation.preview_upgrade(_selected_option_id(_upgrade_choice))
		if upgrade.ok:
			_upgrade_status.text = "Costo: %.0f masa · trabajo: %s s (estimado con la tripulación actual)." % [upgrade.cost.mass, upgrade.result.duration_seconds]
		else:
			_upgrade_status.text = _error_text(str(upgrade.error_code))

	var selected_maintenance_id := _selected_option_id(_maintenance_choice)
	_maintenance_choice.clear()
	var maintenance_lines: PackedStringArray = []
	var maintenance_index := -1
	for building: Dictionary in snapshot.get("buildings", []):
		if building.kind not in ["reactor", "oxygen_generator"]:
			continue
		_maintenance_choice.add_item("%s · %s" % [building.id, BUILDING_NAMES.get(building.kind, building.kind)])
		var index := _maintenance_choice.item_count - 1
		_maintenance_choice.set_item_metadata(index, building.id)
		if building.id == selected_maintenance_id or (selected_maintenance_id.is_empty() and building.id == _inspected_id):
			maintenance_index = index
		maintenance_lines.append("%s: %s · edad %ds · intentos %d" % [building.id, building.maintenance.state, building.maintenance.age_seconds, building.maintenance.attempts])
	if maintenance_index < 0 and _maintenance_choice.item_count > 0:
		maintenance_index = 0
	if maintenance_index >= 0:
		_maintenance_choice.select(maintenance_index)
	_maintenance_status.text = " | ".join(maintenance_lines) if not maintenance_lines.is_empty() else "Construye un reactor u oxigenador para habilitar mantenimiento."

	var inspection: Dictionary = simulation.get_building_status(_inspected_id)
	if inspection.ok:
		var status: Dictionary = inspection.result
		_inspector.text = "%s · %s · Nivel %d\nPotencia: %.1f / demanda %.1f\nAire %.1f y comida %.1f por sol · agua %.1f por sol\nEstado: %s · aviso: %s" % [status.id, BUILDING_NAMES.get(status.kind, status.kind), status.level, status.power_output, status.power_demand, status.effective_production_per_sol.air, status.effective_production_per_sol.food, status.water_demand_per_sol, "energizado" if status.powered else "sin potencia", status.warning if status.warning != "" else "ninguno"]
		_inspected_power_button.disabled = status.kind == "habitat" or snapshot.get("phase") == "finished"
		_inspected_power_button.text = "Apagar %s" % BUILDING_NAMES.get(status.kind, status.kind) if status.enabled else "Encender %s" % BUILDING_NAMES.get(status.kind, status.kind)
		var history: PackedStringArray = ["Historial: %s" % status.id]
		for entry: Dictionary in status.local_log:
			history.append("%ss · %s · %s" % [entry.seconds, entry.reason, str(entry.details)])
		_building_history.update_history("\n".join(history), new_run or _history_building != status.id)
		_history_building = status.id
	else:
		_inspector.text = "Selecciona una construcción en el tablero para ver sus datos."
		_inspected_power_button.disabled = true
		_inspected_power_button.text = "Sin edificio seleccionado"
		_building_history.update_history("Selecciona una construcción para consultar sus últimos hechos.", new_run)

	var reports: Array = snapshot.get("sol_reports", [])
	if reports.is_empty():
		_report_status.text = "Aún no hay un sol completo; el informe se actualiza al final de cada sol."
	else:
		var report_lines: PackedStringArray = []
		for report: Dictionary in reports:
			report_lines.append("Sol %s%s · Δ reservas %s\nProducción %s · consumo %s · importaciones %s\nDéficits %s · bloqueos %s" % [report.get("sol", "?"), " (parcial)" if report.get("partial", false) else "", str(report.get("delta", {})), str(report.get("production", {})), str(report.get("consumption", {})), str(report.get("imports", {})), str(report.get("deficits", {})), str(report.get("blocked_seconds", {}))])
		_report_status.text = "\n\n".join(report_lines)

func _create_building_label() -> Label3D:
	var label := Label3D.new()
	label.font_size = 96
	label.outline_size = 12
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color("f7f3e9")
	label.outline_modulate = Color("26313a")
	label.position = Vector3(0.0, 1.05, 0.0)
	return label

func _create_building_visual(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % kind
	match kind:
		"habitat":
			_add_cylinder(root, 0.36, 0.52, Vector3(0.0, 0.37, 0.0), Color("d6c8a8"))
			_add_sphere(root, 0.36, 0.4, Vector3(0.0, 0.73, 0.0), Color("e5dbc2"))
			_add_box(root, Vector3(0.15, 0.25, 0.08), Vector3(0.0, 0.27, 0.36), Color("526574"))
		"solar":
			_add_box(root, Vector3(0.1, 0.28, 0.1), Vector3(0.0, 0.23, 0.0), Color("6f7378"))
			var panel_a := _add_box(root, Vector3(0.82, 0.06, 0.4), Vector3(-0.25, 0.43, 0.0), Color("365b81"))
			panel_a.rotation_degrees.x = -16.0
			var panel_b := _add_box(root, Vector3(0.82, 0.06, 0.4), Vector3(0.25, 0.43, 0.0), Color("426f98"))
			panel_b.rotation_degrees.x = -16.0
		"reactor":
			_add_box(root, Vector3(0.7, 0.18, 0.7), Vector3(0.0, 0.18, 0.0), Color("777b83"))
			_add_cylinder(root, 0.28, 0.56, Vector3(0.0, 0.55, 0.0), Color("c5794f"))
			_add_cylinder(root, 0.16, 0.12, Vector3(0.0, 0.89, 0.0), Color("e0b76c"))
		"oxygen_generator":
			_add_box(root, Vector3(0.62, 0.55, 0.58), Vector3(0.0, 0.38, 0.0), Color("78aeb5"))
			_add_cylinder(root, 0.12, 0.62, Vector3(0.22, 0.83, 0.16), Color("d4e2df"))
			_add_box(root, Vector3(0.22, 0.12, 0.08), Vector3(0.0, 0.45, 0.31), Color("426c73"))
		"greenhouse":
			_add_box(root, Vector3(0.78, 0.44, 0.72), Vector3(0.0, 0.34, 0.0), Color("789b68"))
			_add_box(root, Vector3(0.82, 0.08, 0.78), Vector3(0.0, 0.61, 0.0), Color("b9cc9b"))
			for x: float in [-0.22, 0.0, 0.22]:
				_add_box(root, Vector3(0.07, 0.3, 0.07), Vector3(x, 0.69, 0.0), Color("4e7549"))
		"laboratory":
			_add_box(root, Vector3(0.7, 0.52, 0.66), Vector3(0.0, 0.36, 0.0), Color("8292a0"))
			_add_box(root, Vector3(0.48, 0.12, 0.48), Vector3(0.0, 0.68, 0.0), Color("c5d3d8"))
	return root

func _add_box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance

func _add_cylinder(parent: Node3D, radius: float, height: float, position: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance

func _add_sphere(parent: Node3D, radius: float, height: float, position: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
