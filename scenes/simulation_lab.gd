extends Control
## Banco técnico temporal; Andrés puede reemplazarlo sin tocar el dominio.

const Simulation = preload("res://domain/simulation.gd")
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
const DEFAULT_CAMERA_SIZE := 64.0
const CAMERA_MIN_PITCH := deg_to_rad(-70.0)
const CAMERA_MAX_PITCH := deg_to_rad(-10.0)
const CAMERA_MIN_SIZE := 16.0
const CAMERA_MAX_SIZE := 80.0
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
var _status: Label
var _requirements: Label
var _message: Label
var _sol_label: Label
var _log: TextEdit
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
	help.text = "La tripulación se elige en su escena y puedes cambiarla con el botón superior. Pulsa una celda vacía para abrir construcciones.\nLas celdas oscurecidas forman el espacio reservado de cada edificio.\nPulsa un edificio para encender/apagar. Los temporizadores comienzan al iniciar.\nVista: arrastra con el botón derecho, usa la rueda o los iconos abajo a la derecha."
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
	var pending := Label.new()
	pending.text = "* Efectos pendientes de radiación, mejoras y ROBERTS. Sin eventos ni mantenimiento en esta base."
	root.add_child(pending)

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

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(330, 0)
	info.size_flags_horizontal = Control.SIZE_SHRINK_END
	body.add_child(info)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_status)
	_requirements = Label.new()
	_requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_requirements)
	_message = Label.new()
	_message.text = "Listo"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_message)
	_log = TextEdit.new()
	_log.editable = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(_log)

	var loaded := Config.load_file()
	if not loaded.ok:
		_message.text = "Error de configuración: %s" % loaded
		set_process(false)
		return
	_show_result(simulation.configure(loaded.data))
	_consumption_per_crew = loaded.data.consumption_per_crew_per_sol.duplicate(true)
	_building_definitions = loaded.data.buildings.duplicate(true)
	simulation.state_updated.connect(_render)
	_reset()

func _process(delta: float) -> void:
	simulation.advance(delta)

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
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_camera = event.pressed
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
	elif event is InputEventMouseMotion and _dragging_camera:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		var movement: Vector2 = motion_event.position - _last_mouse_position
		_last_mouse_position = motion_event.position
		_camera_yaw -= movement.x * 0.01
		_camera_pitch = clampf(_camera_pitch + movement.y * 0.01, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
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
	_show_result(simulation.reset_run(_selected_crew_ids, 1))

func _cell_clicked(cell: Vector2i) -> void:
	for building: Dictionary in simulation.get_snapshot().get("buildings", []):
		if building.x == cell.x and building.y == cell.y:
			_build_menu.hide()
			_show_result(simulation.set_enabled(building.id, not building.enabled))
			return
	_show_build_menu(cell)

func _show_result(result: Dictionary) -> void:
	_message.text = "OK · %s" % result.result if result.ok else "Rechazado: %s" % result.error_code

func _render(snapshot: Dictionary) -> void:
	if not _last_rendered_snapshot.is_empty() and snapshot == _last_rendered_snapshot:
		return
	_last_rendered_snapshot = snapshot
	var resources: Dictionary = snapshot.resources
	var power: Dictionary = snapshot.power
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
	for key: String in ["mass", "air", "water", "food"]:
		_resource_labels[key].text = "%s: %.1f" % [_resource_name(key), resources[key]]
	_resource_labels["energy"].text = "Energía: %.1f / %.1f" % [power.supply, power.demand]
	_sol_label.text = "Soles transcurridos: %d" % int(snapshot.get("completed_sols", 0))
	if _build_menu != null and _build_menu.visible:
		_refresh_build_menu()
	_status.text = "%s | Sol %d · %d s | ×%s | Pausa: %s\nPotencia %.1f / demanda %.1f" % [snapshot.phase, snapshot.sol, snapshot.elapsed_seconds, snapshot.speed, snapshot.paused, power.supply, power.demand]
	var alive := 0
	for member: Dictionary in snapshot.crew:
		if member.alive:
			alive += 1
	_requirements.text = "Requeridos por sol (%d tripulantes): Aire %.1f · Agua %.1f · Comida %.1f" % [alive, _consumption_per_crew.get("air", 0.0) * alive, _consumption_per_crew.get("water", 0.0) * alive, _consumption_per_crew.get("food", 0.0) * alive]

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
	var lines: PackedStringArray = []
	for member: Dictionary in snapshot.crew:
		lines.append("%s: %.1f salud" % [member.id, member.health])
	if not snapshot.result.is_empty():
		lines.append("FINAL: %s" % snapshot.result.verdict)
	lines.append("\nÚltimos hechos:")
	for entry: Dictionary in snapshot.log.slice(maxi(0, snapshot.log.size() - 12)):
		lines.append("%ss · %s · %s" % [entry.seconds, entry.reason, entry.target])
	_log.text = "\n".join(lines)

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
