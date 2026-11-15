extends Control
## Banco técnico temporal; Andrés puede reemplazarlo sin tocar el dominio.

const Simulation = preload("res://domain/simulation.gd")
const HistoryPanel = preload("res://scenes/history_panel.gd")
const PreferencesPanel = preload("res://scenes/preferences_panel.gd")
@onready var _settings_manager: Node = get_node("/root/SettingsManager")
const Config = preload("res://domain/simulation_config.gd")
const CREW_SELECTION_SCENE := "res://scenes/crew_selection.tscn"
const SELECTED_CREW_META := "mars_selected_crew_ids"
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
const DEFAULT_CAMERA_SIZE := 48.0
const CAMERA_MIN_PITCH := deg_to_rad(-70.0)
const CAMERA_MAX_PITCH := deg_to_rad(-10.0)
const CAMERA_MIN_SIZE := 16.0
const CAMERA_MAX_SIZE := 80.0
const TILE_SURFACE_Y := 0.08
const SIMULATION_SPEEDS := [0.5, 1.0, 2.0, 4.0]
const BUILDING_NAMES := {
	"solar": "Solar",
	"reactor": "Reactor",
	"oxygen_generator": "Generador de oxígeno",
	"greenhouse": "Invernadero",
	"laboratory": "Laboratorio"
}

var simulation := Simulation.new()
var _building_history: HistoryPanel
var _history_generation: int = -1
var _history_building: String = ""
var _decision_panel: VBoxContainer
var _maintenance_console: VBoxContainer
var _scenario_id: String = "frontier"
var _survival_status: Label
var _terrain_generation := -1
var _rocks: Node3D
var _sun: DirectionalLight3D
var _world_environment: Environment
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
var _status: Label
var _requirements: Label
var _message: Label
var _sol_label: Label
var _log: HistoryPanel
var _resource_labels: Dictionary = {}
var _building_definitions: Dictionary = {}
var _build_menu: PanelContainer
var _build_menu_title: Label
var _build_menu_options: VBoxContainer
var _build_menu_buttons: Dictionary = {}
var _build_menu_cell: Vector2i = Vector2i(-1, -1)
var _run_button: Button
var _speed_button: Button
var _speed_menu: PanelContainer
var _camera_controls_panel: PanelContainer
var _selected_crew_ids: Array[String] = ["engineer", "medic", "botanist", "technician"]
var _kinds: Array[String] = ["solar", "reactor", "oxygen_generator", "greenhouse", "laboratory"]
var _consumption_per_crew: Dictionary = {}
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
var _camera_pitch: float = DEFAULT_CAMERA_PITCH
var _dragging_camera: bool = false
var _panning_camera: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO
var _hud_pages: Dictionary = {}
var _hud_buttons: Dictionary = {}
var _hud_drawer: PanelContainer
var _drawer_title: Label
var _crew_status: Label
var _building_toggle: Button
var _active_hud_panel: String = ""
var _summary_view: HistoryPanel
var _shown_summary_generation: int = -1
var _bury_button: Button
var _radiation_rules: Dictionary = {}
var _action_dock: PanelContainer
var _resource_hud: PanelContainer
var _sol_hud: PanelContainer

func _apply_hud_theme() -> void:
	var hud_theme := Theme.new()
	hud_theme.default_font_size = 17
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.045, 0.075, 0.10, 0.95)
	panel.border_color = Color("35505c")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(10)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	hud_theme.set_stylebox("panel", "PanelContainer", panel)
	for type_name: String in ["Button", "OptionButton"]:
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := panel.duplicate() as StyleBoxFlat
			style.bg_color = Color("254853") if state in ["hover", "pressed"] else Color("122733")
			if state == "focus":
				style.bg_color = Color(0, 0, 0, 0)
				style.border_color = Color("8fe0ce")
			hud_theme.set_stylebox(state, type_name, style)
	var field := panel.duplicate() as StyleBoxFlat
	field.bg_color = Color("0c1922")
	hud_theme.set_stylebox("normal", "TextEdit", field)
	hud_theme.set_stylebox("normal", "LineEdit", field)
	hud_theme.set_color("font_color", "Label", Color("e3eff0"))
	theme = hud_theme

func _hud_label(parent: Node) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _create_hud_workspace(parent: Control) -> void:
	_event_status = Label.new()
	_event_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_event_status.offset_left = 24
	_event_status.offset_right = -270
	_event_status.offset_top = 90
	_event_status.offset_bottom = 138
	_event_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_event_status)
	_message = Label.new()
	_message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message.offset_left = 24
	_message.offset_right = -24
	_message.offset_top = -184
	_message.offset_bottom = -144
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_message)
	var dock := PanelContainer.new()
	_action_dock = dock
	dock.name = "ActionDock"
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left = 12
	dock.offset_right = -12
	dock.offset_top = -138
	dock.offset_bottom = -84
	parent.add_child(dock)
	var dock_scroll := ScrollContainer.new()
	dock_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock.add_child(dock_scroll)
	var dock_row := HBoxContainer.new()
	dock_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_scroll.add_child(dock_row)
	_add_button(dock_row, "Construir", _begin_build_placement)
	_hud_drawer = PanelContainer.new()
	_hud_drawer.name = "HUDWorkspace"
	_hud_drawer.anchor_left = 1
	_hud_drawer.anchor_right = 1
	_hud_drawer.anchor_bottom = 1
	_hud_drawer.offset_left = -410
	_hud_drawer.offset_right = -12
	_hud_drawer.offset_top = 146
	_hud_drawer.offset_bottom = -190
	_hud_drawer.hide()
	parent.add_child(_hud_drawer)
	var drawer_content := VBoxContainer.new()
	_hud_drawer.add_child(drawer_content)
	var header := HBoxContainer.new()
	drawer_content.add_child(header)
	_drawer_title = Label.new()
	_drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_drawer_title)
	_add_button(header, "Cerrar ×", _close_hud_panel)
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_content.add_child(pages)
	var titles := {"decisions": "Decisiones", "base": "Base", "robots": "ROBERTS", "upgrades": "Mejoras", "maintenance": "Mantenimiento", "crew": "Tripulación", "history": "Historial", "summary": "Resumen", "settings": "Ajustes", "science": "Tecnología"}
	for id: String in titles:
		var button := Button.new()
		button.text = titles[id]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_toggle_hud_panel.bind(id))
		dock_row.add_child(button)
		_hud_buttons[id] = button
		var page_scroll := ScrollContainer.new()
		page_scroll.name = id
		page_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		pages.add_child(page_scroll)
		page_scroll.hide()
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 10)
		page_scroll.add_child(content)
		_hud_pages[id] = content
	_create_domain_controls(_hud_pages["base"])
	_building_toggle = Button.new()
	_building_toggle.text = "Encender / apagar edificio seleccionado"
	_building_toggle.pressed.connect(_toggle_selected_building)
	_hud_pages["base"].add_child(_building_toggle)

func _toggle_hud_panel(id: String) -> void:
	if _active_hud_panel == id:
		_close_hud_panel()
	else:
		_open_hud_panel(id)

func _begin_build_placement() -> void:
	_close_hud_panel()
	_build_menu.hide()
	_message.text = "Selecciona una celda vacía del tablero para elegir una construcción."

func _open_hud_panel(id: String) -> void:
	_build_menu.hide()
	_active_hud_panel = id
	_hud_drawer.show()
	_drawer_title.text = _hud_buttons[id].text
	for page_id: String in _hud_pages:
		_hud_pages[page_id].get_parent().visible = page_id == id
		_hud_buttons[page_id].button_pressed = page_id == id

func _close_hud_panel() -> void:
	_active_hud_panel = ""
	_hud_drawer.hide()
	for button: Button in _hud_buttons.values():
		button.button_pressed = false

func _toggle_selected_building() -> void:
	var selected := simulation.get_building_status(_inspected_id)
	if selected.ok:
		_show_result(simulation.set_enabled(_inspected_id, not selected.result.enabled))

func _update_hud_layout() -> void:
	if not is_instance_valid(_hud_drawer):
		return
	var compact := size.x < 1400
	var margin := 16.0 if compact else 24.0
	theme.default_font_size = 16 if compact else 18
	var drawer_width := clampf(size.x * 0.30, 390.0, 560.0)
	_hud_drawer.offset_left = -drawer_width - margin
	_hud_drawer.offset_right = -margin
	_hud_drawer.offset_top = margin + 150
	_hud_drawer.offset_bottom = -222
	_resource_hud.offset_left = margin
	_resource_hud.offset_right = -margin
	_resource_hud.offset_top = margin
	_resource_hud.offset_bottom = margin + 74
	_sol_hud.offset_left = -250 - margin
	_sol_hud.offset_right = -margin
	_sol_hud.offset_top = margin + 86
	_sol_hud.offset_bottom = margin + 138
	_event_status.offset_left = margin + 8
	_event_status.offset_right = -286 - margin
	_event_status.offset_top = margin + 86
	_event_status.offset_bottom = margin + 146
	_action_dock.offset_left = margin
	_action_dock.offset_right = -margin
	_action_dock.offset_top = -156
	_action_dock.offset_bottom = -94
	_message.offset_left = margin + 8
	_message.offset_right = -margin - 8
	_message.offset_top = -214
	_message.offset_bottom = -166
	_camera_controls_panel.offset_left = -300 - margin
	_camera_controls_panel.offset_right = -margin
	_camera_controls_panel.offset_top = -80
	_camera_controls_panel.offset_bottom = -16
	var time_controls: PanelContainer = get_node("HUD/SimulationControls")
	time_controls.offset_left = margin
	time_controls.offset_right = margin + 260
	time_controls.offset_top = -80
	time_controls.offset_bottom = -16
	_speed_menu.offset_left = margin + 272
	_speed_menu.offset_right = margin + 530
	_speed_menu.offset_top = -80
	_speed_menu.offset_bottom = -16
	_build_menu.position = Vector2(margin, margin + 150)

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	_settings_manager.set_fullscreen(not fullscreen)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_toggle_run_state()
			KEY_ESCAPE, KEY_TAB:
				_toggle_hud_panel("settings")
			KEY_A, KEY_LEFT:
				_rotate_camera(-PI / 4.0)
			KEY_D, KEY_RIGHT:
				_rotate_camera(PI / 4.0)
			KEY_W, KEY_UP:
				_zoom_camera(-4.0)
			KEY_S, KEY_DOWN:
				_zoom_camera(4.0)
			_:
				return
		get_viewport().set_input_as_handled()

func _on_language_changed() -> void:
	_last_rendered_snapshot.clear()
	_render(simulation.get_snapshot())

func _ready() -> void:
	_settings_manager.language_changed.connect(_on_language_changed)
	_load_selected_crew()
	_apply_hud_theme()
	var board_view := Control.new()
	board_view.name = "WorldView"
	board_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_view)
	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.stretch_shrink = 1
	_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_viewport_container.gui_input.connect(_on_viewport_gui_input)
	board_view.add_child(_viewport_container)
	_board_subviewport = SubViewport.new()
	_board_subviewport.size = Vector2i(900, 700)
	_board_subviewport.own_world_3d = true
	_board_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_board_subviewport.physics_object_picking = false
	_board_subviewport.msaa_3d = Viewport.MSAA_8X
	_viewport_container.add_child(_board_subviewport)
	_create_isometric_board(_board_subviewport)
	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_create_resource_hud(hud)
	_create_sol_hud(hud)
	_create_build_menu(hud)
	_create_camera_controls(hud)
	_create_simulation_controls(hud)
	_create_hud_workspace(hud)
	resized.connect(_update_hud_layout)
	_update_hud_layout()

	var loaded := Config.load_file()
	if not loaded.ok:
		_message.text = "Error de configuración: %s" % loaded
		set_process(false)
		return
	_show_result(simulation.configure(loaded.data))
	_consumption_per_crew = loaded.data.consumption_per_crew_per_sol.duplicate(true)
	_building_definitions = loaded.data.buildings.duplicate(true)
	_radiation_rules = loaded.data.radiation.duplicate(true)
	for selector: OptionButton in [_robot_choice, _destination_choice, _upgrade_choice]:
		selector.item_selected.connect(func(_index: int) -> void: _render_domain(simulation.get_snapshot()))
	simulation.state_updated.connect(_render)
	_reset()

func _process(delta: float) -> void:
	simulation.advance(delta)

func _create_resource_hud(parent: Control) -> void:
	var panel := PanelContainer.new()
	_resource_hud = panel
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
	for key: String in ["regolith", "energy", "air", "food"]:
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "%s: —" % _resource_name(key)
		if key == "energy":
			label.tooltip_text = "Energía almacenada / capacidad; la generación y demanda varían con el ciclo día/noche."
		elif key == "food":
			label.tooltip_text = "Reserva combinada de agua y comida para la tripulación."
		row.add_child(label)
		_resource_labels[key] = label

func _create_sol_hud(parent: Control) -> void:
	var panel := PanelContainer.new()
	_sol_hud = panel
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
	_build_menu.position = Vector2(12.0, 146.0)
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
	_camera_controls_panel.offset_left = -292.0
	_camera_controls_panel.offset_top = -76.0
	_camera_controls_panel.offset_right = -12.0
	_camera_controls_panel.offset_bottom = -12.0
	parent.add_child(_camera_controls_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_camera_controls_panel.add_child(row)
	_add_icon_button(row, "←", "Girar izquierda", func() -> void: _rotate_camera(-PI / 4.0))
	_add_icon_button(row, "→", "Girar derecha", func() -> void: _rotate_camera(PI / 4.0))
	_add_icon_button(row, "+", "Acercar", func() -> void: _zoom_camera(-4.0))
	_add_icon_button(row, "-", "Alejar", func() -> void: _zoom_camera(4.0))
	_add_icon_button(row, "⟲", "Restablecer vista", _reset_camera)

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
	_add_icon_button(row, "↻", "Reiniciar partida", _reset)
	_run_button = _add_icon_button(row, "▶", "Iniciar partida", _toggle_run_state)
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

func _toggle_run_state() -> void:
	var snapshot := simulation.get_snapshot()
	match snapshot.get("phase", ""):
		"planning":
			_show_result(simulation.start_run())
		"running":
			_show_result(simulation.set_paused(not snapshot.get("paused", false)))

func _toggle_speed_menu() -> void:
	_speed_menu.visible = not _speed_menu.visible
	_camera_controls_panel.visible = not _speed_menu.visible

func _select_speed(speed: float) -> void:
	_speed_menu.hide()
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
	_close_hud_panel()
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
		var cost := float(definition.get("regolith", 0.0))
		var duration := int(definition.get("build_seconds", 0))
		var footprint := simulation.get_building_footprint_size(kind)
		var preview := simulation.preview_placement(kind, _build_menu_cell)
		var text := "%s · %d×%d · %.0f regolito · %d s" % [BUILDING_NAMES[kind], footprint, footprint, cost, duration]
		if not preview.ok:
			text += " · %s" % _placement_error_text(preview.error_code)
		button.text = text
		button.disabled = not preview.ok

func _placement_error_text(code: String) -> String:
	var errors: Dictionary = {
		"insufficient_regolith": "regolito insuficiente",
		"reactor_too_close": "reactor muy cerca",
		"invalid_phase": "partida no disponible",
		"outside_grid": "fuera del mapa",
		"footprint_outside_grid": "espacio fuera del mapa",
		"terrain_blocked": "terreno bloqueado",
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
	var names: Dictionary = {"air": "Oxígeno", "food": "Alimento", "regolith": "Regolito", "energy": "Energía"}
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

func _rotate_camera(amount: float) -> void:
	_camera_yaw = wrapf(_camera_yaw + amount, -TAU, TAU)
	_update_camera()

func _zoom_camera(amount: float) -> void:
	if _camera == null:
		return
	_camera.size = clampf(_camera.size + amount, CAMERA_MIN_SIZE, CAMERA_MAX_SIZE)

func _reset_camera() -> void:
	_camera_yaw = DEFAULT_CAMERA_YAW
	_camera_pitch = DEFAULT_CAMERA_PITCH
	_dragging_camera = false
	_panning_camera = false
	if _camera_pivot != null:
		_camera_pivot.position = Vector3.ZERO
	if _camera != null:
		_camera.size = DEFAULT_CAMERA_SIZE
	_update_camera()

func _update_camera() -> void:
	if _camera_pivot == null:
		return
	_camera_pitch = clampf(_camera_pitch, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	_camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)

func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning_camera = event.pressed
			_dragging_camera = false
			_last_mouse_position = event.position
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_camera = event.pressed
			_panning_camera = false
			_last_mouse_position = event.position
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-4.0)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(4.0)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _speed_menu.visible:
				_speed_menu.hide()
				_camera_controls_panel.show()
			_select_cell_at(_viewport_container.get_local_mouse_position())
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _panning_camera:
		_pan_camera(_last_mouse_position, event.position)
		_last_mouse_position = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_camera:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		var movement: Vector2 = motion_event.position - _last_mouse_position
		_last_mouse_position = motion_event.position
		_camera_yaw -= movement.x * 0.01
		_camera_pitch = clampf(_camera_pitch + movement.y * 0.01, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
		_update_camera()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Soltar sobre un panel del HUD también debe terminar el arrastre.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning_camera = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_camera = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_panning_camera = false
		_dragging_camera = false

func _camera_ground_point(screen_position: Vector2) -> Variant:
	if _camera == null or _viewport_container.size.x <= 0 or _viewport_container.size.y <= 0:
		return null
	var position_in_viewport := screen_position * Vector2(_board_subviewport.size) / _viewport_container.size
	var origin := _camera.project_ray_origin(position_in_viewport)
	var direction := _camera.project_ray_normal(position_in_viewport)
	return Plane(Vector3.UP, TILE_SURFACE_Y).intersects_ray(origin, direction)

func _pan_camera(from: Vector2, to: Vector2) -> void:
	var previous: Variant = _camera_ground_point(from)
	var current: Variant = _camera_ground_point(to)
	if not previous is Vector3 or not current is Vector3:
		return
	var offset: Vector3 = previous - current
	var limit := GRID_SIZE * TILE_SPACING * 0.5
	_camera_pivot.position.x = clampf(_camera_pivot.position.x + offset.x, -limit, limit)
	_camera_pivot.position.z = clampf(_camera_pivot.position.z + offset.z, -limit, limit)

func _create_isometric_board(viewport: SubViewport) -> void:
	_board_root = Node3D.new()
	_board_root.name = "IsometricBoard"
	viewport.add_child(_board_root)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	_world_environment = environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("202b38")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce5ef")
	environment.ambient_light_energy = 0.55
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
	_sun = light
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	_board_root.add_child(light)

	_rocks = Node3D.new()
	_board_root.add_child(_rocks)
	var center_offset := float(GRID_SIZE - 1) * TILE_SPACING / 2.0
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
	_rocks = Node3D.new()
	_board_root.add_child(_rocks)
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
	_close_hud_panel()
	_inspected_id = "b1"
	_show_result(simulation.reset_run(_selected_crew_ids, int(_seed.value), _scenario_id))
	_maintenance_session = ""

func _cell_clicked(cell: Vector2i) -> void:
	for building: Dictionary in simulation.get_snapshot().get("buildings", []):
		if cell in simulation.get_building_footprint_cells(str(building.kind), Vector2i(int(building.x), int(building.y))):
			_build_menu.hide()
			_inspected_id = building.id
			_open_hud_panel("base")
			_render_domain(simulation.get_snapshot())
			return
	_show_build_menu(cell)

func _show_result(result: Dictionary) -> void:
	_message.text = "Orden aplicada." if result.ok else _error_text(result.error_code)
	_settings_manager.translate_tree(_message)

func _render(snapshot: Dictionary) -> void:
	if not _last_rendered_snapshot.is_empty() and snapshot == _last_rendered_snapshot:
		return
	_last_rendered_snapshot = snapshot.duplicate(true)
	var resources: Dictionary = snapshot.resources
	var power: Dictionary = snapshot.power
	_sun.light_color = Color("ffd6a8") if power.is_day else Color("9bbfff")
	_sun.light_energy = 1.15 if power.is_day else 0.3
	_world_environment.background_color = Color("36262b") if power.is_day else Color("101a2e")
	_world_environment.ambient_light_energy = 0.6 if power.is_day else 0.3
	_run_button.disabled = snapshot.phase == "finished"
	if snapshot.phase == "planning":
		_run_button.text = "▶"
		_run_button.tooltip_text = "Iniciar partida"
	elif snapshot.phase == "running" and snapshot.paused:
		_run_button.text = "▶"
		_run_button.tooltip_text = "Continuar simulación"
	elif snapshot.phase == "running":
		_run_button.text = "⏸"
		_run_button.tooltip_text = "Pausar simulación"
	else:
		_run_button.text = "▶"
		_run_button.tooltip_text = "Partida terminada"
	_speed_button.disabled = snapshot.phase == "finished"
	_speed_button.text = "×%.1f ▸" % snapshot.speed
	if snapshot.phase == "finished":
		_speed_menu.hide()
		_camera_controls_panel.show()
	for key: String in ["regolith", "air", "food"]:
		_resource_labels[key].text = "%s: %.1f" % [_resource_name(key), resources[key]]
	for key: String in _resource_labels:
		_resource_labels[key].modulate = Color("ff997a") if resources[key] < 20 else Color.WHITE
	_resource_labels["energy"].text = "Energía: %.1f / %.1f\nGenera %.1f · demanda %.1f" % [resources.energy, power.capacity, power.supply, power.demand]
	var phase_name: String = {"planning": "Planificación", "running": "En curso", "finished": "Finalizada"}[snapshot.phase]
	_sol_label.text = "%s · Sol %d / 42 · %s" % [phase_name, snapshot.sol, "DÍA" if power.is_day else "NOCHE"]
	if _build_menu != null and _build_menu.visible:
		_refresh_build_menu()
	_status.text = "%s | Sol %d · %d s | %s | Mapa %s %s | ×%s | Pausa: %s\nGeneración %.1f / demanda %.1f" % [snapshot.phase, snapshot.sol, snapshot.elapsed_seconds, "Día" if power.is_day else "Noche", str(snapshot.map.size), str(snapshot.map.shape), snapshot.speed, snapshot.paused, power.supply, power.demand]
	var alive := 0
	for member: Dictionary in snapshot.crew:
		if member.alive:
			alive += 1
	_requirements.text = "Requeridos por sol (%d tripulantes): Oxígeno %.1f · Alimento combinado %.1f" % [alive, _consumption_per_crew.get("air", 0.0) * alive, _consumption_per_crew.get("food", 0.0) * alive]

	_update_terrain(snapshot)
	var buildings_by_cell: Dictionary = {}
	var reserved_cells: Dictionary = {}
	var blocked_cells: Dictionary = {}
	for blocked_index: int in snapshot.map.blocked_cells:
		blocked_cells[blocked_index] = true
	for building: Dictionary in snapshot.buildings:
		buildings_by_cell[int(building.y) * GRID_SIZE + int(building.x)] = building
		var anchor := Vector2i(int(building.x), int(building.y))
		for footprint_cell: Vector2i in simulation.get_building_footprint_cells(str(building.kind), anchor):
			reserved_cells[footprint_cell.y * GRID_SIZE + footprint_cell.x] = true
	for index: int in range(_cell_nodes.size()):
		if not buildings_by_cell.has(index):
			if blocked_cells.has(index):
				_cell_materials[index].albedo_color = Color("34434d")
			elif reserved_cells.has(index):
				_cell_materials[index].albedo_color = Color("71634f")
			else:
				_cell_materials[index].albedo_color = Color("a46545").lerp(Color("c18a61"), float(posmod(index * 73 + int(snapshot.seed), 17)) / 17.0)
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
		if building.covered: state = "PROTEGIDO · 0 energía"
		elif building.repair_remaining > 0: state = "REPARANDO · %ds" % building.repair_remaining
		elif building.night_cut: state = "CORTE NOCTURNO"
		elif building.damage > 0: state += " · DAÑO %d%%" % roundi(building.damage * 100)
		elif kind == "greenhouse": state += " · CULTIVO %d%%" % roundi(building.crop_health)
		_cell_labels[index].modulate = Color("ffbe86") if building.damage > 0 or building.crop_health < 70 else Color.WHITE
		var short_names := {"habitat": "HÁBITAT", "solar": "SOLAR", "reactor": "REACTOR", "oxygen_generator": "OXÍGENO", "greenhouse": "CULTIVO", "laboratory": "LAB"}
		_cell_labels[index].text = _settings_manager.translate_text("%s N%d\n%s%s" % [short_names.get(kind, kind.to_upper()), building.level, state, " ↑%.1f" % building.upgrade_remaining_work if building.upgrade_remaining_work > 0 else ""])
		for detail: Node in _cell_visuals[index].get_children():
			if detail.name.begins_with("Plant"):
				detail.material_override.albedo_color = Color("489b67").lerp(Color("976845"), 1.0 - building.crop_health / 100.0)
		_cell_labels[index].position.y = _cell_visuals[index].scale.y * 1.15 + 0.2
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
	_render_domain(snapshot)
	if snapshot.phase == "finished" and _shown_summary_generation != snapshot.run_generation:
		_shown_summary_generation = snapshot.run_generation
		_open_hud_panel("summary")

func _create_building_label() -> Label3D:
	var label := Label3D.new()
	label.font_size = 64
	label.outline_size = 8
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
	# Small repeated details make scale and purpose readable without imported art.
	if kind == "solar":
		for x: float in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			_add_box(root, Vector3(0.012, 0.015, 0.36), Vector3(x, 0.47, 0), Color("8bb3cb"))
	elif kind == "greenhouse":
		for x: float in [-0.25, 0, 0.25]:
			for z: float in [-0.2, 0, 0.2]:
				var plant := _add_sphere(root, 0.06, 0.16, Vector3(x, 0.73, z), Color("489b67"))
				plant.name = "Plant%d" % root.get_child_count()
	else:
		for x: float in [-0.2, 0, 0.2]:
			var window := _add_box(root, Vector3(0.09, 0.1, 0.03), Vector3(x, 0.45, 0.34), Color("79d8da"))
			window.material_override.emission_enabled = true
			window.material_override.emission = Color("388c93")
		_add_cylinder(root, 0.014, 0.45, Vector3(0.18, 0.9, 0), Color("d0d7d4"))
	var model_width: float = {"habitat": 0.72, "solar": 1.32, "reactor": 0.7, "oxygen_generator": 0.62, "greenhouse": 0.82, "laboratory": 0.7}.get(kind, 1.0)
	var factor := float(simulation.get_building_footprint_size(kind)) * TILE_SPACING * 0.75 / model_width
	root.scale = Vector3.ONE * factor
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

func _create_domain_controls(_root: VBoxContainer) -> void:
	var base: VBoxContainer = _hud_pages["base"]
	_status = _hud_label(base)
	_requirements = _hud_label(base)
	_add_button(base, "Refugio / salir", func() -> void: _show_result(simulation.set_sheltered(not simulation.get_snapshot().get("sheltered", false))))
	_bury_button = _add_button(base, "Enterrar hábitat", func() -> void: _show_result(simulation.bury_habitat()))
	_inspector = _hud_label(base)
	_building_history = HistoryPanel.new()
	_building_history.custom_minimum_size.y = 180
	base.add_child(_building_history)
	_hud_label(base).text = "OBJETIVO · sobrevivir 42 soles.\n1. Construye energía, oxígeno y cultivo antes de iniciar.\n2. Atiende decisiones y mantenimiento.\n3. Recolecta, repara y reserva para la noche.\nReactor + oxígeno + cultivo cuestan 90 de regolito."
	_survival_status = _hud_label(base)
	_add_button(base, "Reparar seleccionado · 5 regolito / 30 s", func() -> void: _show_result(simulation.survival_command("repair", _inspected_id)))
	_decision_panel = preload("res://scenes/decision_panel.gd").new()
	_hud_pages["decisions"].add_child(_decision_panel)
	_decision_panel.chosen.connect(func(id: String, option: String) -> void: _show_result(simulation.choose_decision(id, option)))
	_create_science_card(_hud_pages["science"])
	var missions: VBoxContainer = _hud_pages["robots"]
	_hud_label(missions).text = "Cuadrilla exterior: 20 energía → 12 regolito tras 60 s. Añade dosis; se detiene en refugio."
	_add_button(missions, "Enviar cuadrilla exterior", func() -> void: _show_result(simulation.survival_command("salvage")))
	_robot_choice = OptionButton.new()
	_robot_choice.add_item("ROBERT 1")
	_robot_choice.add_item("ROBERT 2")
	missions.add_child(_robot_choice)
	_destination_choice = OptionButton.new()
	for destination_name: String in ["Depósito → alimento", "Cantera → regolito", "Restos → regolito"]:
		_destination_choice.add_item(destination_name)
	missions.add_child(_destination_choice)
	_add_button(missions, "Enviar · 2 potencia durante 2 soles", _send_robert)
	_robot_status = _hud_label(missions)
	var upgrades: VBoxContainer = _hud_pages["upgrades"]
	_upgrade_choice = OptionButton.new()
	upgrades.add_child(_upgrade_choice)
	_add_button(upgrades, "Mejorar a nivel 2", _upgrade)
	_upgrade_status = _hud_label(upgrades)
	var maintenance: VBoxContainer = _hud_pages["maintenance"]
	_hud_label(maintenance).text = "Intervenciones · 15 segundos reales, dos intentos. Una crisis suspende la sesión."
	_maintenance_choice = OptionButton.new()
	maintenance.add_child(_maintenance_choice)
	_add_button(maintenance, "Atender", _begin_maintenance)
	_maintenance_console = preload("res://scenes/maintenance_console.gd").new()
	maintenance.add_child(_maintenance_console)
	_maintenance_console.submitted.connect(func(success: bool) -> void: _maintenance_result(success))
	_add_button(maintenance, "Abandonar", func() -> void: _maintenance_result(false, true))
	_add_button(maintenance, "Reactivar", _reactivate)
	_maintenance_status = _hud_label(maintenance)
	var crew: VBoxContainer = _hud_pages["crew"]
	_crew_status = _hud_label(crew)
	_add_button(crew, "Cambiar tripulación", _open_crew_selection)
	var settings: VBoxContainer = _hud_pages["settings"]
	settings.add_child(PreferencesPanel.new())
	_hud_label(settings).text = "Semilla para la próxima partida"
	_seed = SpinBox.new()
	_seed.min_value = 0
	_seed.max_value = 1000000
	_seed.value = int(get_tree().root.get_meta("mars_run_seed", 1))
	_scenario_id = str(get_tree().root.get_meta("mars_scenario", "frontier"))
	settings.add_child(_seed)
	_add_button(settings, "Reiniciar partida", _reset)
	_add_button(settings, "Restablecer cámara", _reset_camera)
	_add_button(settings, "Pantalla completa · F11", _toggle_fullscreen)
	_add_button(settings, "Volver al menú (termina esta partida)", _open_main_menu)
	_hud_label(settings).text = "Celda vacía: construir. Edificio: inspeccionar.
Botón derecho: girar vista. Rueda pulsada + arrastrar: desplazar. Rueda: acercar/alejar."
	_log = HistoryPanel.new()
	_log.custom_minimum_size = Vector2(0, 320)
	_hud_pages["history"].add_child(_log)
	_summary_view = HistoryPanel.new()
	_summary_view.add_theme_color_override("font_readonly_color", Color("e3eff0"))
	_summary_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_summary_view.custom_minimum_size = Vector2(0, 340)
	_summary_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hud_pages["summary"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hud_pages["summary"].add_child(_summary_view)

func _render_run_summary(snapshot: Dictionary, reset_position: bool) -> void:
	if snapshot.run_summary.is_empty():
		_summary_view.update_history("El resumen de la misión estará disponible al finalizar la partida.", reset_position)
		return
	var report: Dictionary = snapshot.run_summary
	var verdict: String = {"relief_achieved": "Relevo logrado", "partial_defeat": "Derrota parcial", "total_defeat": "Derrota total"}[report.verdict]
	var lines: PackedStringArray = [verdict, "Tiempo: %d / %d segundos" % [report.elapsed_seconds, report.target_seconds], "", "INDICADORES DE MISIÓN"]
	var names := {"survival": "Supervivencia", "crew": "Tripulación", "sustainability": "Sostenibilidad", "resilience": "Resiliencia"}
	for id: String in names:
		lines.append("%s: %.1f%%" % [names[id], float(report.components[id]) * 100.0])
	if report.resilience.neutral_used:
		lines.append("Sin oportunidades de crisis: resiliencia neutral.")
	else:
		lines.append("Respuestas sin estado crítico: %d / %d" % [report.resilience.successful_without_critical, report.resilience.total])
	lines.append("\nTRIPULACIÓN · %d supervivientes" % report.crew.alive)
	for member: Dictionary in report.crew.members:
		lines.append("%s: %.1f salud · %.1f dosis%s" % [CREW_NAMES[member.id], member.health, member.dose, " · fallecido" if not member.alive else ""])
	lines.append("\nRESERVAS · últimos %d segundos" % report.sustainability.window_seconds)
	for resource: String in ["air", "food", "energy"]:
		var stock: Dictionary = report.sustainability.resources[resource]
		lines.append("%s: %.1f · tendencia %+.1f / sol" % [_resource_name(resource), stock.closing, stock.net_per_sol])
	lines.append("\nHECHOS DE LA MISIÓN")
	for cause: Dictionary in report.causes:
		lines.append("• " + _summary_cause_text(cause, snapshot))
	lines.append("\nDECISIONES Y CONSECUENCIAS")
	for entry: Dictionary in snapshot.log:
		if entry.reason in ["decision_taken", "decision_inaction", "storm_consequence", "flare_consequence", "crop_consequence", "repair_completed", "night_cut_ended", "salvage_returned"]:
			lines.append(_survival_fact(entry))
	_summary_view.update_history("\n".join(lines), reset_position)

func _summary_cause_text(cause: Dictionary, snapshot: Dictionary) -> String:
	var target: String = cause.target
	for building: Dictionary in snapshot.buildings:
		if building.id == target:
			target = str(BUILDING_NAMES.get(building.kind, "Hábitat"))
	match cause.kind:
		"crew_resource_deficit":
			return "Faltaron %.1f unidades de %s para la tripulación." % [cause.amount, _resource_name(cause.target).to_lower()]
		"maintenance_shutdown":
			return "%s se apagó por mantenimiento pendiente." % target
		"robert_lost":
			return "%s se perdió en una expedición%s." % [target, " expuesta a tormenta" if cause.details.storm_exposed else ""]
		"building_blocked":
			var reasons := {"power_shortage": "sin energía", "disabled": "apagado por orden del jugador"}
			return "%s estuvo %s durante %d segundos." % [target, reasons.get(cause.reason, cause.reason), cause.duration_seconds]
		"robert_returned":
			var cargo: PackedStringArray = []
			for resource: String in cause.details.cargo:
				cargo.append("%.1f %s" % [cause.details.cargo[resource], _resource_name(resource).to_lower()])
			return "%s entregó %s." % [target, ", ".join(cargo)]
		"maintenance_success":
			return "Se completó el mantenimiento de %s." % target
		"upgrade_completed":
			return "%s alcanzó el nivel 2." % target
		"habitat_buried":
			return "El enterramiento del hábitat quedó terminado."
	return "Hecho registrado: " + cause.kind

func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _open_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MenuMarsSinner.tscn")


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
		_maintenance_console.update_session(simulation.get_snapshot(), _maintenance_session)
	_show_result(result)


func _maintenance_result(success: bool, abandoned: bool = false) -> void:
	_show_result(simulation.apply_maintenance_result(_maintenance_session, success, 0.0, abandoned))


func _reactivate() -> void:
	if _maintenance_choice.selected >= 0:
		_show_result(simulation.reactivate_building(str(_maintenance_choice.get_item_metadata(_maintenance_choice.selected))))


func _error_text(code: String) -> String:
	var messages := {
		"invalid_phase": "La partida debe estar en simulación. Si terminó, reinicia e inicia otra.",
		"laboratory_not_operational": "El laboratorio debe estar terminado, encendido y con potencia. Revisa si una tormenta redujo la energía solar.",
		"insufficient_power": "Falta potencia libre para otra salida de ROBERT. Enciende una fuente o apaga un consumidor.",
		"robert_unavailable": "Este ROBERT sigue en misión o se perdió. Selecciona otro o espera el regreso.",
		"crew_sheltered": "Sal del refugio para iniciar una expedición o mejora.",
		"insufficient_regolith": "No alcanza el regolito para esta acción.",
		"insufficient_energy": "La batería no tiene energía suficiente para esta operación.",
		"crew_unavailable": "La cuadrilla está refugiada o ya trabaja en esa operación.",
		"repair_not_needed": "Este edificio no tiene daño ni cultivo que restaurar.",
		"technology_unavailable": "Selecciona un panel solar que aún no tenga LOTUS.",
		"decision_closed": "Esta decisión ya se resolvió o venció su plazo.",
		"unknown_decision": "Esta situación ya no pertenece a la misión actual.",
		"insufficient_resources": "No alcanza el regolito para proteger el hábitat.",
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


func _render_domain(snapshot: Dictionary) -> void:
	_decision_panel.update_state(snapshot)
	_maintenance_console.update_session(snapshot, _maintenance_session)
	var urgent := 0
	for situation: Dictionary in snapshot.situations:
		if situation.status == "active": urgent += 1
	_hud_buttons["decisions"].text = "Decisiones (%d)" % urgent
	_hud_buttons["decisions"].modulate = Color("ffc18b") if urgent > 0 else Color.WHITE
	_survival_status.text = "Escenario: %s · semilla %s\nPrioridad: %s · salida exterior: %ds\nSelecciona un edificio para repararlo o instalar LOTUS." % [snapshot.scenario, snapshot.seed, snapshot.priority, snapshot.salvage.remaining]
	_bury_button.text = "Enterrar hábitat · %.0f regolito" % float(_radiation_rules.get("bury_regolith", 0))
	_bury_button.tooltip_text = "Trabajo: %d segundos" % int(_radiation_rules.get("bury_seconds", 0))
	var new_run: bool = snapshot.run_generation != _history_generation
	_render_run_summary(snapshot, new_run)
	_history_generation = snapshot.run_generation
	var r: Dictionary = snapshot.resources
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
	var pending_count := 0
	for building: Dictionary in snapshot.buildings:
		if building.maintenance.state in ["requested", "degraded", "shutdown"]:
			pending_count += 1
	_hud_buttons["maintenance"].text = "Mantenimiento (%d)" % pending_count
	_hud_buttons["maintenance"].modulate = Color("ffc18b") if pending_count > 0 else Color.WHITE
	var inspection: Dictionary = simulation.get_building_status(_inspected_id)
	if inspection.ok:
		var status: Dictionary = inspection.result
		_building_toggle.disabled = status.kind == "habitat" or snapshot.phase == "finished"
		_building_toggle.text = "Apagar edificio" if status.enabled else "Encender edificio"
		_inspector.text = "Inspector %s · %s N%d · potencia %.1f / demanda %.1f · aire %.1f / comida %.1f por sol · aviso %s" % [status.id, status.kind, status.level, status.power_output, status.power_demand, status.effective_production_per_sol.air, status.effective_production_per_sol.food, status.warning]
		var history: PackedStringArray = ["Historial del edificio " + status.id]
		for entry: Dictionary in status.local_log:
			history.append("%ss · %s · %s" % [entry.seconds, entry.reason, str(entry.details)])
		for b: Dictionary in snapshot.buildings:
			if b.id == status.id:
				_inspector.text += "\nDaño %d%% · cultivo %d%% · reparación %ds · LOTUS %s" % [roundi(b.damage * 100), roundi(b.crop_health), b.repair_remaining, "instalado" if b.lotus else "sin instalar"]
		_building_history.update_history("\n".join(history), new_run or _history_building != status.id)
		_history_building = status.id
	var event_text := "ninguno"
	if not snapshot.event.is_empty():
		event_text = "%s (%s, inicio %ds, fin %ds)" % [snapshot.event.kind, snapshot.event.state, snapshot.event.start_seconds, snapshot.event.end_seconds]
	_event_status.text = "Tormenta %d%% · sol %d | Partículas %d%% · sol %d\n%s · Refugio: %s" % [roundi(snapshot.forecast.storm.probability * 100), int(snapshot.forecast.storm.start_sol), roundi(snapshot.forecast.solar_particles.probability * 100), int(snapshot.forecast.solar_particles.start_sol), event_text, "activo" if snapshot.sheltered else "inactivo"]
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
		_upgrade_status.text = "%s regolito · %s s estimados" % [upgrade.cost.regolith, upgrade.result.duration_seconds] if upgrade.ok else _error_text(upgrade.error_code)
	var lines: PackedStringArray = []
	for member: Dictionary in snapshot.crew:
		lines.append("%s: %.1f salud · %.2f dosis" % [member.id, member.health, member.dose])
	lines.append("Regolito: %.1f" % r.regolith)
	_crew_status.text = _selected_crew_summary() + "\n\n" + "\n".join(lines)
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
		lines.append(_survival_fact(entry))
	_log.update_history("\n".join(lines), new_run)
	_settings_manager.translate_tree(get_node("HUD"))

func _create_science_card(parent: VBoxContainer) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/science_sources.json"))
	var card := RichTextLabel.new()
	card.bbcode_enabled = true
	card.fit_content = true
	card.custom_minimum_size.y = 440
	parent.add_child(card)
	card.text = "[font_size=24]LOTUS · proteger también cuesta[/font_size]\n\n"
	var source: Dictionary = data.lotus
	card.append_text("%s\n\n%s\n\n%s\n\n%s\n\nProcedencia: %s · %s\nPatentes: %s\n%s\n%s\nConsultado: %s" % [source.title, source.description, source.gameplay, source.limitation, source.provider, source.reference, ", ".join(source.patents), source.holder, source.license_status, source.consulted_on])
	var link := LinkButton.new()
	link.text = "Abrir ficha oficial NASA ↗"
	link.pressed.connect(func() -> void: OS.shell_open("https://technology.nasa.gov/patent/GSC-TOPS-262"))
	parent.add_child(link)
	_add_button(parent, "Instalar en solar seleccionado · 12 regolito + 30 energía", func() -> void: _show_result(simulation.survival_command("lotus", _inspected_id)))
	_hud_label(parent).text = "30 s sin generación durante la instalación. Reduce a la mitad el daño por polvo; no elimina la pérdida de luz."

func _survival_fact(entry: Dictionary) -> String:
	var details: Dictionary = entry.get("details", {})
	var labels := {"decision_taken": "Decisión", "decision_inaction": "Sin respuesta al plazo", "storm_consequence": "Polvo: daño y tiempo protegido", "flare_consequence": "Dosis tras partículas solares", "repair_completed": "Reparación completada", "night_cut_ended": "Amanecer: producción suspendida", "salvage_returned": "Cuadrilla: material recuperado"}
	var result := ""
	match entry.reason:
		"decision_taken": result = "%s → %s" % [details.title, details.effect]
		"decision_inaction": result = "El plazo venció; el peligro continuó sin intervención."
		"storm_consequence": result = "Daño añadido %d%%; protegido %d s. Respuesta: %s." % [roundi(details.damage_added * 100), details.protected_seconds, details.decision_id]
		"crop_consequence": result = "Cultivo al %d%%; prioridad %s. Respuesta: %s." % [roundi(details.crop_health), details.priority, details.decision_id]
		"night_cut_ended": result = "Reanudado al amanecer; %d s sin producción. Respuesta: %s." % [details.production_lost_seconds, details.decision_id]
		"repair_completed": result = "Rendimiento restaurado tras completar el trabajo. Orden: %s." % details.decision_id
		"salvage_returned": result = "+%s regolito tras la salida exterior. Orden: %s." % [details.regolith, details.decision_id]
		"flare_consequence": result = "Dosis acumulada por tripulante: %s. Refugio al cierre: %s." % [str(details.doses), "sí" if details.sheltered else "no"]
		_: result = str(details)
	return "%ss · %s · %s · %s" % [entry.seconds, labels.get(entry.reason, entry.reason), entry.target, result]

func _update_terrain(snapshot: Dictionary) -> void:
	if _terrain_generation == snapshot.run_generation:
		return
	_terrain_generation = snapshot.run_generation
	for child: Node in _rocks.get_children():
		_rocks.remove_child(child)
		child.queue_free()
	for index: int in range(_cell_nodes.size()):
		_cell_nodes[index].visible = index not in snapshot.map.outside_cells
	for index: int in snapshot.map.obstacle_cells:
		var rock := _add_sphere(_rocks, TILE_SIZE * 0.4, TILE_SIZE * 0.65, _cell_nodes[index].position + Vector3(0, 0.3, 0), Color("79574b"))
		rock.rotation_degrees = Vector3(13, index * 37 % 360, 18)
		rock.scale = Vector3(1, 0.7 + float(index % 4) * 0.15, 0.9)
