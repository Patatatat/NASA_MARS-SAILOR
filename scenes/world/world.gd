class_name MartianWorld
extends Node3D

signal target_selected(target_id: StringName)
signal placement_requested(request: GameContracts.PlacementRequest)

@onready var camera_rig: CameraRig = $CameraRig
@onready var preview: PlacementPreview = $PlacementPreview
@onready var terrain_root: Node3D = $Terrain
@onready var buildings_root: Node3D = $Buildings
var building_service: BuildingService
var grid_service: GridService
var selected_id: StringName = &""
var placement_type: StringName = &""
var _last_visual_signature := ""
var _crew_visuals: Dictionary = {}
var _rocket_visuals: Dictionary = {}

func _ready() -> void:
	SignalBus.state_restored.connect(rebuild_from_state)
	SignalBus.building_changed.connect(_on_building_changed)
	SignalBus.energy_changed.connect(_on_energy_changed)
	SignalBus.research_changed.connect(_on_research_changed)
	SignalBus.crew_changed.connect(func(_id): _refresh_entities())
	SignalBus.rocket_changed.connect(func(_id, _change): _refresh_entities())
	SignalBus.tick_advanced.connect(func(_dt): _refresh_entities())
	rebuild_from_state()
	_sync_daylight()

func _process(_delta: float) -> void:
	_sync_daylight()

func _sync_daylight() -> void:
	if not is_node_ready():
		return
	var phase := float(GameClock.get_cycle_snapshot()["phase"])
	var sunlight := clampf(sin(phase * TAU) * 5.0, 0.0, 1.0)
	var sun: DirectionalLight3D = $Sun
	sun.light_energy = lerpf(0.10, 1.25, sunlight)
	sun.light_color = Color("a9c5ef").lerp(Color("fff0d3"), sunlight)
	sun.rotation_degrees.x = -10.0 - 160.0 * minf(1.0, phase * 2.0) if phase < 0.5 else -45.0
	sun.shadow_enabled = sunlight > 0.1
	var environment: Environment = $WorldEnvironment.environment
	environment.background_color = Color("080f24").lerp(Color("503426"), sunlight)
	environment.ambient_light_color = Color("809fce").lerp(Color("d1d1e6"), sunlight)
	# Keep the colony readable at night, especially on dim displays; the blue
	# ambient fill is a gameplay aid, while the direct sun and shadows fade.
	environment.ambient_light_energy = lerpf(0.75, 0.6, sunlight)

func configure(buildings: BuildingService, grid: GridService) -> void:
	building_service = buildings
	grid_service = grid
	rebuild_from_state()

func rebuild_from_state() -> void:
	if terrain_root == null or buildings_root == null:
		return
	_clear(terrain_root)
	_clear(buildings_root)
	if GameState.data.is_empty() or building_service == null or grid_service == null:
		return
	var sector_size := int(ConfigDB.balance["map"]["scan_sector_size"])
	for key in GameState.data.get("world", {}).get("revealed", {}):
		var parts := String(key).split(",")
		if parts.size() != 2:
			continue
		var sector := Vector2i(int(parts[0]), int(parts[1]))
		var tile := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(sector_size, 0.2, sector_size)
		tile.mesh = mesh
		tile.position = Vector3((sector.x + 0.5) * sector_size, -0.12, (sector.y + 0.5) * sector_size)
		var mat := StandardMaterial3D.new()
		var terrain := grid_service.terrain_at(sector * sector_size)
		mat.albedo_color = _terrain_color(terrain, sector)
		tile.material_override = mat
		terrain_root.add_child(tile)
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/initial_layout.json"))
	if layout is Dictionary:
		for patch in layout.get("terrain_patches", []):
			var values: Array = patch.get("rect", [])
			if values.size() != 4:
				continue
			var marker := MeshInstance3D.new()
			var marker_mesh := BoxMesh.new()
			marker_mesh.size = Vector3(float(values[2]), 0.04, float(values[3]))
			marker.mesh = marker_mesh
			marker.position = Vector3(float(values[0]) + float(values[2]) * 0.5, 0.02, float(values[1]) + float(values[3]) * 0.5)
			var marker_material := StandardMaterial3D.new()
			marker_material.albedo_color = Color(0.22, 0.62, 0.8) if patch.get("type") == "aquifer" else Color(0.7, 0.58, 0.34)
			marker.material_override = marker_material
			terrain_root.add_child(marker)
	for id in GameState.data.get("buildings", {}).get("instances", {}):
		_add_building_visual(StringName(id))
	if not String(selected_id).is_empty() and building_service.get_status(selected_id) == null:
		selected_id = &""
		target_selected.emit(selected_id)
	_last_visual_signature = _visual_signature()
	_refresh_entities()

func _refresh_entities() -> void:
	if not is_node_ready():
		return
	var members: Dictionary = GameState.data.get("crew", {}).get("members", {})
	for id in _crew_visuals.keys():
		if not members.has(id):
			_crew_visuals[id].queue_free()
			_crew_visuals.erase(id)
	var index := 0
	for id in members:
		if not _crew_visuals.has(id):
			var visual: Node3D = preload("res://scenes/crew/astronaut.tscn").instantiate()
			add_child(visual)
			_crew_visuals[id] = visual
		var member: Dictionary = members[id]
		var task: Dictionary = GameState.data.get("crew", {}).get("tasks", {}).get(member.get("task_id", ""), {})
		var target: Dictionary = GameState.data.get("buildings", {}).get("instances", {}).get(task.get("target_id", "base_1"), {})
		var origin: Array = target.get("origin", [14, 14])
		_crew_visuals[id].position = Vector3(float(origin[0]) + 0.5 + index % 2, 1.0, float(origin[1]) + 0.5 + index / 2)
		_crew_visuals[id].set_crew_state(member)
		index += 1
	var plans: Dictionary = GameState.data.get("rockets", {}).get("plans", {})
	for id in _rocket_visuals.keys():
		if not plans.has(id):
			_rocket_visuals[id].queue_free()
			_rocket_visuals.erase(id)
	for id in plans:
		if not _rocket_visuals.has(id):
			var visual: Node3D = preload("res://scenes/rockets/rocket.tscn").instantiate()
			add_child(visual)
			_rocket_visuals[id] = visual
		var zone: Array = plans[id].get("zone", [])
		if zone.size() == 4:
			_rocket_visuals[id].position = Vector3(float(zone[0]) + float(zone[2]) * 0.5, 0.0, float(zone[1]) + float(zone[3]) * 0.5)
		_rocket_visuals[id].set_rocket_state(plans[id])

func focus_target(target_id: StringName) -> bool:
	var status := building_service.get_status(target_id) if building_service != null else null
	if status == null:
		return false
	var item: Dictionary = GameState.data["buildings"]["instances"][String(target_id)]
	var origin: Array = item["origin"]
	var size: Array = item["size"]
	camera_rig.focus_cell(Vector2i(int(origin[0]) + int(size[0]) / 2, int(origin[1]) + int(size[1]) / 2))
	selected_id = target_id
	target_selected.emit(target_id)
	return true

func begin_placement(type_id: StringName) -> void:
	placement_type = type_id

func cancel_placement() -> void:
	placement_type = &""
	preview.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_rig.zoom_by(-3.0)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_rig.zoom_by(3.0)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_placement()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var cell := _screen_cell(event.position)
			if cell == Vector2i(-1, -1):
				return
			if not String(placement_type).is_empty():
				placement_requested.emit(GameContracts.PlacementRequest.new(placement_type, cell))
			else:
				selected_id = _building_at(cell)
				target_selected.emit(selected_id)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not String(placement_type).is_empty() and building_service != null:
		var cell := _screen_cell(event.position)
		var definition := BuildingDefinition.from_balance(placement_type)
		if cell != Vector2i(-1, -1) and definition != null:
			var valid := building_service.validate_placement(GameContracts.PlacementRequest.new(placement_type, cell)).ok
			preview.show_at(cell, definition.footprint, valid)
		else:
			preview.hide()

func _screen_cell(screen: Vector2) -> Vector2i:
	var camera: Camera3D = camera_rig.camera
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if absf(direction.y) < 0.00001:
		return Vector2i(-1, -1)
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return Vector2i(-1, -1)
	var point := origin + direction * distance
	var cell := Vector2i(floori(point.x), floori(point.z))
	return cell if grid_service != null and grid_service.is_revealed(cell) else Vector2i(-1, -1)

func _building_at(cell: Vector2i) -> StringName:
	for id in GameState.data.get("buildings", {}).get("instances", {}):
		if grid_service._rect(GameState.data["buildings"]["instances"][id]).has_point(cell):
			return StringName(id)
	return &""

func _add_building_visual(id: StringName) -> void:
	var item: Dictionary = GameState.data["buildings"]["instances"][String(id)]
	var status := building_service.get_status(id)
	var origin: Array = item["origin"]
	var size: Array = item["size"]
	var height := 0.25 if item["type"] in ["solar_panel", "tunnel", "landing_pad"] else (1.7 if item["type"] == "reactor" else 0.9)
	var visual := MeshInstance3D.new()
	visual.name = String(id)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(float(size[0]) * 0.9, height, float(size[1]) * 0.9)
	visual.mesh = mesh
	visual.position = Vector3(float(origin[0]) + float(size[0]) * 0.5, height * 0.5, float(origin[1]) + float(size[1]) * 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = _building_color(String(item["type"]))
	if status.condition == &"breached" or status.condition == &"destroyed" or item.get("crop") == "dead":
		material.albedo_color = Color(0.75, 0.12, 0.1)
	elif item.get("crop") == "wilting":
		material.albedo_color = Color(0.72, 0.52, 0.12)
	elif status.demand > 0.0 and not status.powered:
		material.albedo_color = material.albedo_color.darkened(0.55)
	visual.material_override = material
	buildings_root.add_child(visual)

func _building_color(kind: String) -> Color:
	match kind:
		"base": return Color(0.76, 0.82, 0.89)
		"isru": return Color(0.18, 0.65, 0.83)
		"greenhouse": return Color(0.25, 0.76, 0.38)
		"reactor": return Color(0.82, 0.68, 0.25)
		"solar_panel": return Color(0.13, 0.3, 0.7)
		"tunnel": return Color(0.55, 0.6, 0.64)
		"mine": return Color(0.52, 0.42, 0.33)
		"battery": return Color(0.3, 0.7, 0.74)
		_: return Color(0.68, 0.66, 0.61)

func _terrain_color(terrain: StringName, sector: Vector2i) -> Color:
	if terrain == &"aquifer":
		return Color(0.39, 0.36, 0.34)
	if terrain == &"iron_regolith":
		return Color(0.62, 0.43, 0.27)
	return Color(0.6, 0.3, 0.19) if (sector.x + sector.y) % 2 == 0 else Color(0.56, 0.27, 0.17)

func _visual_signature() -> String:
	if building_service == null or GameState.data.is_empty():
		return ""
	var chunks: Array[String] = []
	for id in GameState.data.get("buildings", {}).get("instances", {}):
		var status := building_service.get_status(StringName(id))
		chunks.append("%s:%s:%s:%s" % [id, status.powered, status.condition, status.modifiers.get("crop", "")])
	return "|".join(chunks)

func _on_energy_changed(_snapshot: GameContracts.EnergySnapshot) -> void:
	var signature := _visual_signature()
	if signature != _last_visual_signature:
		rebuild_from_state()

func _on_research_changed(_tech_id: StringName, change: StringName) -> void:
	if change == &"sector_revealed":
		rebuild_from_state()

func _on_building_changed(_id: StringName, _change: StringName) -> void:
	rebuild_from_state()

func _clear(root: Node3D) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
