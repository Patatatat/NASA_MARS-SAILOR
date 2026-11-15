class_name GameContracts
extends RefCounted

class ValidationResult extends RefCounted:
	var ok: bool
	var error_code: StringName
	var message_key: StringName
	var params: Dictionary
	var costs: Dictionary
	var warnings: Array[StringName]

	func _init(valid: bool = true, code: StringName = &"", values: Dictionary = {}) -> void:
		ok = valid
		error_code = code
		message_key = &"" if valid else StringName("error.%s" % code)
		params = values.duplicate(true)
		costs = {}
		warnings = []

static func success() -> ValidationResult:
	return ValidationResult.new()

static func failure(code: StringName, params: Dictionary = {}) -> ValidationResult:
	return ValidationResult.new(false, code, params)

class EnergySnapshot extends RefCounted:
	var generation: float = 0.0
	var demand: float = 0.0
	var stored: float = 0.0
	var capacity: float = 0.0
	var by_building: Dictionary = {}

	func as_dict() -> Dictionary:
		return {"generation": generation, "demand": demand, "stored": stored,
			"capacity": capacity, "by_building": by_building.duplicate(true)}

class PlacementRequest extends RefCounted:
	var building_type: StringName
	var origin: Vector2i
	var rotation_quarters: int

	func _init(type_id: StringName = &"", cell: Vector2i = Vector2i.ZERO, rotation: int = 0) -> void:
		building_type = type_id
		origin = cell
		rotation_quarters = rotation

class PlacementResult extends ValidationResult:
	var cells: Array[Vector2i] = []
	var required_connections: Array[StringName] = []
