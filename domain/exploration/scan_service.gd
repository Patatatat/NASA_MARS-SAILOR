class_name ScanService
extends RefCounted

var grid: GridService
var power: PowerService

func rebuild_from_state() -> void:
	pass

func validate_scan(sector: Vector2i) -> GameContracts.ValidationResult:
	var size := int(ConfigDB.balance["map"]["scan_sector_size"])
	var maximum := int(ConfigDB.balance["map"]["maximum_size"]) / size
	if sector.x < 0 or sector.y < 0 or sector.x >= maximum or sector.y >= maximum:
		return GameContracts.failure(&"outside_map")
	var revealed: Dictionary = GameState.data.get("world", {}).get("revealed", {})
	if revealed.has("%d,%d" % [sector.x, sector.y]):
		return GameContracts.failure(&"sector_already_revealed")
	var adjacent := false
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = sector + offset
		if revealed.has("%d,%d" % [neighbor.x, neighbor.y]):
			adjacent = true
			break
	if not adjacent:
		return GameContracts.failure(&"sector_not_adjacent")
	if not GameState.data.get("research", {}).get("unlocked", []).has("satellite_scan"):
		return GameContracts.failure(&"technology_locked")
	var points := float(GameState.data["research"].get("points", 0.0))
	var cost := float(ConfigDB.balance["scan"]["research_cost"])
	if points + 0.000001 < cost:
		return GameContracts.failure(&"insufficient_research")
	var energy := float(ConfigDB.balance["scan"]["energy_cost"])
	var energy_result := power.validate_energy_spend(energy)
	if not energy_result.ok:
		return energy_result
	var result := GameContracts.success()
	result.costs = {"research": cost, "stored_energy": energy}
	return result

func scan(sector: Vector2i) -> GameContracts.ValidationResult:
	var result := validate_scan(sector)
	if not result.ok:
		return result
	var energy := float(ConfigDB.balance["scan"]["energy_cost"])
	var spent := power.spend_stored_energy(energy, &"satellite_scan")
	if not spent.ok:
		return spent
	GameState.data["research"]["points"] = float(GameState.data["research"]["points"]) - float(ConfigDB.balance["scan"]["research_cost"])
	var terrain := _terrain_for_sector(sector)
	grid.set_sector_terrain(sector, terrain)
	grid.reveal_sector(sector)
	result.params = {"sector": [sector.x, sector.y], "terrain": String(terrain)}
	SignalBus.research_changed.emit(&"satellite_scan", &"sector_revealed")
	return result

func _terrain_for_sector(sector: Vector2i) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%d" % [int(GameState.data.get("seed", 0)), sector.x, sector.y])
	var roll := rng.randf()
	var cumulative := 0.0
	var weights: Dictionary = ConfigDB.balance["scan"]["terrain_weights"]
	for id in ["iron_regolith", "aquifer", "sterile"]:
		cumulative += float(weights.get(id, 0.0))
		if roll <= cumulative:
			return StringName(id)
	return &"sterile"
