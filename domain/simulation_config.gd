extends RefCounted
## Validación de la configuración inicial. No consume los JSON históricos.

const RESOURCES := ["mass", "regolith", "air", "water", "food"]
const BUILDINGS := ["habitat", "solar", "reactor", "oxygen_generator", "greenhouse", "laboratory"]
const FIELDS := ["mass", "build_seconds", "power_supply", "power_demand", "air_per_sol", "food_per_sol", "water_per_sol"]

static func load_file(path: String = "res://data/balance.json") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error_code": "config_missing"}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "error_code": "config_json"}
	return validate(parser.data)

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _error("root")
	var data: Dictionary = value
	for key: String in ["schema_version", "grid_size", "sol_seconds", "target_sols"]:
		if not _number(data.get(key), 1.0) or float(data[key]) != floor(float(data[key])):
			return _error(key)
	if data.schema_version != 1 or data.grid_size != 6 or data.sol_seconds > 3600 or data.target_sols > 100:
		return _error("schema_or_limits")
	for key: String in ["health_loss_per_missing_unit", "engineer_multiplier", "botanist_multiplier", "technician_multiplier"]:
		if not _number(data.get(key), 0.0):
			return _error(key)
	for section: String in ["initial", "consumption_per_crew_per_sol", "buildings"]:
		if not data.get(section) is Dictionary:
			return _error(section)
	for key: String in RESOURCES:
		if not _number(data.initial.get(key), 0.0):
			return _error("initial." + key)
	for key: String in ["air", "water", "food"]:
		if not _number(data.consumption_per_crew_per_sol.get(key), 0.0):
			return _error("consumption." + key)
	for id: String in BUILDINGS:
		if not data.buildings.get(id) is Dictionary:
			return _error("buildings." + id)
		for field: String in FIELDS:
			if not _number(data.buildings[id].get(field), 0.0):
				return _error(id + "." + field)
		if data.buildings[id].build_seconds != floor(float(data.buildings[id].build_seconds)):
			return _error(id + ".build_seconds")
	return {"ok": true, "error_code": "", "data": data.duplicate(true)}

static func _number(value: Variant, minimum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= 1000000.0

static func _error(field: String) -> Dictionary:
	return {"ok": false, "error_code": "invalid_config", "field": field}
