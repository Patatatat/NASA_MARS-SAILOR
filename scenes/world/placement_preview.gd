class_name PlacementPreview
extends Node3D

var mesh_instance: MeshInstance3D

func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	hide()

func show_at(origin: Vector2i, size: Vector2i, valid: bool) -> void:
	if mesh_instance == null:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.12, size.y)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.85, 0.45, 0.55) if valid else Color(0.95, 0.2, 0.2, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	position = Vector3(origin.x + size.x * 0.5, 0.15, origin.y + size.y * 0.5)
	show()
