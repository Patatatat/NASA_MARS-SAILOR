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
	var extension_error := _validate_systems(data)
	if not extension_error.is_empty():
		return _error(extension_error)
	return {"ok": true, "error_code": "", "data": data.duplicate(true)}

static func _validate_systems(data: Dictionary) -> String:
	if not data.get("maintenance") is Dictionary:
		return "maintenance"
	var maintenance: Dictionary = data.maintenance
	for key: String in ["interval_sols", "global_gap_seconds", "max_pending", "degrade_after_sols", "shutdown_after_sols", "shutdown_duration_sols", "session_max_real_seconds", "max_attempts"]:
		if not _integer(maintenance.get(key), 1):
			return "maintenance." + key
	if maintenance.max_pending > 2 or maintenance.max_attempts > 2 or maintenance.session_max_real_seconds > 15 or maintenance.degrade_after_sols >= maintenance.shutdown_after_sols:
		return "maintenance.limits"
	for key: String in ["degraded_multiplier", "robot_difficulty_multiplier"]:
		if not _probability(maintenance.get(key)):
			return "maintenance." + key
	if not _number(maintenance.get("reactivation_mass"), 0):
		return "maintenance.reactivation_mass"
	if not _number(data.get("scientist_upgrade_duration_multiplier"), 0.001) or float(data.scientist_upgrade_duration_multiplier) > 1:
		return "scientist_upgrade_duration_multiplier"
	if not data.get("upgrades") is Dictionary:
		return "upgrades"
	for kind: String in ["solar", "reactor", "oxygen_generator", "greenhouse", "laboratory"]:
		var upgrade: Variant = data.upgrades.get(kind)
		if not upgrade is Dictionary:
			return "upgrades." + kind
		if not _integer(upgrade.get("duration_seconds"), 1):
			return "upgrades." + kind + ".duration_seconds"
		for field: String in ["mass", "power_supply", "power_demand", "air_per_sol", "food_per_sol", "water_per_sol"]:
			if not _number(upgrade.get(field), 0):
				return "upgrades." + kind + "." + field
	for section: String in ["events", "radiation", "roberts"]:
		if not data.get(section) is Dictionary:
			return section
	if not _integer(data.events.get("warning_seconds"), 1):
		return "events.warning_seconds"
	var previous_end := 0
	for kind: String in ["storm", "solar_particles"]:
		var event: Variant = data.events.get(kind)
		if not event is Dictionary:
			return "events." + kind
		if not _probability(event.get("probability")) or not _integer(event.get("start_seconds"), 1) or not _integer(event.get("duration_seconds"), 1):
			return "events." + kind
		if event.start_seconds - data.events.warning_seconds < previous_end:
			return "events.overlap_or_warning"
		previous_end = int(event.start_seconds + event.duration_seconds)
	if not _probability(data.events.storm.get("solar_multiplier")) or not _number(data.events.solar_particles.get("dose_per_sol"), 0):
		return "events.effects"
	for key: String in ["ambient_dose_per_sol", "damage_threshold", "health_loss_per_dose", "bury_mass", "bury_regolith"]:
		if not _number(data.radiation.get(key), 0):
			return "radiation." + key
	for key: String in ["medic_multiplier", "shelter_multiplier", "buried_multiplier"]:
		if not _probability(data.radiation.get(key)):
			return "radiation." + key
	if not _integer(data.radiation.get("bury_seconds"), 1):
		return "radiation.bury_seconds"
	for key: String in ["duration_sols", "power_demand", "geologist_yield_multiplier"]:
		if not _number(data.roberts.get(key), 0.001):
			return "roberts." + key
	if not _integer(data.roberts.duration_sols, 1):
		return "roberts.duration_sols"
	for key: String in ["storm_loss_probability", "geologist_risk_multiplier"]:
		if not _probability(data.roberts.get(key)):
			return "roberts." + key
	if not data.roberts.get("destinations") is Dictionary:
		return "roberts.destinations"
	for id: String in ["ice", "quarry", "wreckage"]:
		var destination: Variant = data.roberts.destinations.get(id)
		if not destination is Dictionary:
			return "roberts." + id
		var expected_resource: String = {"ice": "water", "quarry": "regolith", "wreckage": "mass"}[id]
		if destination.get("resource") != expected_resource or not _number(destination.get("amount"), 0) or not _probability(destination.get("loss_probability")):
			return "roberts." + id
	return ""

static func _integer(value: Variant, minimum: int) -> bool:
	return _number(value, minimum) and float(value) == floor(float(value))

static func _probability(value: Variant) -> bool:
	return _number(value, 0) and float(value) <= 1.0

static func _number(value: Variant, minimum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= 1000000.0

static func _error(field: String) -> Dictionary:
	return {"ok": false, "error_code": "invalid_config", "field": field}
