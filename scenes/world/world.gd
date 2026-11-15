class_name MartianWorld
extends Node3D

const BUILDING_MODELS := {
	"base": preload("res://assets/3D assests/3D_assets/MainBase.glb"),
	"isru": preload("res://assets/3D assests/3D_assets/ISRU.glb"),
	"greenhouse": preload("res://assets/3D assests/3D_assets/GreenHouse.glb"),
	"solar_panel": preload("res://assets/3D assests/3D_assets/SolarPanel.glb"),
	"battery": preload("res://assets/3D assests/3D_assets/Battery.glb"),
	"laboratory": preload("res://assets/3D assests/3D_assets/Laboratory.glb"),
	"mine": preload("res://assets/3D assests/3D_assets/Mine.glb"),
	"refinery": preload("res://assets/3D assests/3D_assets/Refinery.glb"),
	"printer_3d": preload("res://assets/3D assests/3D_assets/3DPrinter.glb"),
	"reactor": preload("res://assets/3D assests/3D_assets/NuclearReactor.glb"),
	"landing_pad": preload("res://assets/3D assests/3D_assets/LandingPad.glb")
}
const TUNNEL_STRAIGHT: PackedScene = preload("res://assets/3D assests/3D_assets/TunnelStraight.glb")
const TUNNEL_CORNER: PackedScene = preload("res://assets/3D assests/3D_assets/TunnelIntersectionCorner.glb")
const TUNNEL_T: PackedScene = preload("res://assets/3D assests/3D_assets/TunnelIntersectionT.glb")
const TUNNEL_CROSS: PackedScene = preload("res://assets/3D assests/3D_assets/TunnelIntersection.glb")

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
	var building_type := String(item["type"])
	var packed_scene: PackedScene = BUILDING_MODELS.get(building_type)
	var rotation_y := 0.0
	if building_type == "tunnel":
		var tunnel_model := _tunnel_model(Vector2i(int(origin[0]), int(origin[1])))
		packed_scene = tunnel_model["scene"] as PackedScene
		rotation_y = float(tunnel_model["rotation"])
	if packed_scene != null:
		var model := packed_scene.instantiate() as Node3D
		if model != null:
			model.name = String(id)
			model.rotation.y = rotation_y
			buildings_root.add_child(model)
			if _fit_model_to_footprint(model, origin, size):
				_apply_model_status(model, status, item)
				return
			model.queue_free()
	_add_fallback_building_visual(id, item, status, origin, size)

func _fit_model_to_footprint(model: Node3D, origin: Array, size: Array) -> bool:
	var bounds := _model_bounds(model)
	if bounds.size.x <= 0.001 or bounds.size.z <= 0.001:
		return false
	var target_width := maxf(0.5, float(size[0]) * 0.9)
	var target_depth := maxf(0.5, float(size[1]) * 0.9)
	var scale_factor := minf(target_width / bounds.size.x, target_depth / bounds.size.z)
	if not is_finite(scale_factor) or scale_factor <= 0.0:
		return false
	model.scale = Vector3.ONE * scale_factor
	var local_center := Vector3(bounds.position.x + bounds.size.x * 0.5, 0.0,
		bounds.position.z + bounds.size.z * 0.5)
	var center_offset := model.transform.basis * local_center
	model.position = Vector3(float(origin[0]) + float(size[0]) * 0.5 - center_offset.x,
		0.025 - bounds.position.y * scale_factor,
		float(origin[1]) + float(size[1]) * 0.5 - center_offset.z)
	return true

func _model_bounds(model: Node3D) -> AABB:
	var combined := AABB()
	var has_point := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_bounds := mesh_instance.get_aabb()
		for x in range(2):
			for y in range(2):
				for z in range(2):
					var corner := mesh_bounds.position + Vector3(
						mesh_bounds.size.x * float(x), mesh_bounds.size.y * float(y),
						mesh_bounds.size.z * float(z))
					var local_point := model.to_local(mesh_instance.to_global(corner))
					if has_point:
						combined = combined.expand(local_point)
					else:
						combined = AABB(local_point, Vector3.ZERO)
						has_point = true
	return combined

func _apply_model_status(model: Node3D, status: BuildingStatus, item: Dictionary) -> void:
	var tint := Color(0.0, 0.0, 0.0, 0.0)
	if status.condition == &"breached" or status.condition == &"destroyed" or item.get("crop") == "dead":
		tint = Color(0.85, 0.12, 0.08, 0.42)
	elif item.get("crop") == "wilting":
		tint = Color(0.9, 0.55, 0.08, 0.35)
	elif status.demand > 0.0 and not status.powered:
		tint = Color(0.015, 0.02, 0.04, 0.48)
	if tint.a <= 0.0:
		return
	var overlay := StandardMaterial3D.new()
	overlay.albedo_color = tint
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.material_overlay = overlay

func _tunnel_model(origin: Vector2i) -> Dictionary:
	var connections := _tunnel_connections(origin)
	var scene: PackedScene = TUNNEL_STRAIGHT
	var base_directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0)]
	if connections.size() >= 4:
		scene = TUNNEL_CROSS
		base_directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	elif connections.size() == 3:
		scene = TUNNEL_T
		base_directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	elif connections.size() == 2:
		if connections[0] + connections[1] == Vector2i.ZERO:
			scene = TUNNEL_STRAIGHT
			base_directions = [Vector2i(1, 0), Vector2i(-1, 0)]
		else:
			scene = TUNNEL_CORNER
			base_directions = [Vector2i(0, -1), Vector2i(1, 0)]
	var turns := _tunnel_rotation_to_match(base_directions, connections)
	return {"scene": scene, "rotation": float(turns) * PI * 0.5}

func _tunnel_connections(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var instances: Dictionary = GameState.data.get("buildings", {}).get("instances", {})
	for direction in directions:
		var neighbor := origin + direction
		for id in instances:
			var item: Dictionary = instances[id]
			if item.get("type", "") not in ["tunnel", "base"]:
				continue
			if grid_service._rect(item).has_point(neighbor):
				result.append(direction)
				break
	return result

func _tunnel_rotation_to_match(base: Array[Vector2i], desired: Array[Vector2i]) -> int:
	if desired.is_empty():
		return 0
	for turns in range(4):
		var rotated: Array[Vector2i] = []
		for direction in base:
			var value := direction
			for _turn in range(turns):
				value = Vector2i(value.y, -value.x)
			rotated.append(value)
		var matches_all := true
		for wanted in desired:
			if not rotated.has(wanted):
				matches_all = false
				break
		if matches_all and rotated.size() == desired.size():
			return turns
	return 0

func _add_fallback_building_visual(id: StringName, item: Dictionary, status: BuildingStatus,
		origin: Array, size: Array) -> void:
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
