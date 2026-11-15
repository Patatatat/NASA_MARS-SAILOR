class_name ProductionService
extends RefCounted

var building_service: BuildingService
var power: PowerService
var ledger: ResourceLedger

func rebuild_from_state() -> void:
	pass

func step(delta_seconds: float) -> void:
	var fraction := delta_seconds / float(ConfigDB.balance["time"]["sol_seconds_x1"])
	for id in GameState.data.get("buildings", {}).get("instances", {}):
		var item: Dictionary = GameState.data["buildings"]["instances"][id]
		var kind := String(item["type"])
		if kind == "greenhouse":
			_step_greenhouse(StringName(id), item, fraction)
			continue
		if not bool(item.get("enabled", true)) or float(item.get("health", 0.0)) <= 0.0:
			continue
		if kind == "reactor":
			if float(item.get("fuel_sols", 0.0)) > 0.0:
				item["fuel_sols"] = maxf(0.0, float(item["fuel_sols"]) - fraction)
			continue
		if not power.is_powered(StringName(id)):
			continue
		var definition: Dictionary = ConfigDB.balance["buildings"][kind]
		if kind in ["isru", "mine"]:
			var output: Dictionary = definition.get("output_per_sol", {})
			var amount := {}
			for resource_id in output:
				amount[resource_id] = float(output[resource_id]) * fraction
			ledger.add(amount, "production_%s_%s" % [kind, id])
		elif kind == "refinery":
			var input := {"iron_ore": float(definition["input_iron_ore"]) * fraction}
			if ledger.spend(input, "refinery_input_%s" % id):
				ledger.add({"iron_plates": float(definition["output_iron_plates"]) * fraction}, "production_refinery_%s" % id)

func _step_greenhouse(id: StringName, item: Dictionary, fraction: float) -> void:
	var definition: Dictionary = ConfigDB.balance["buildings"]["greenhouse"]
	if not bool(item.get("seed_planted", false)):
		return
	if not bool(item.get("enabled", true)) or float(item.get("health", 0.0)) <= 0.0 or not power.is_powered(id):
		item["unpowered_sols"] = float(item.get("unpowered_sols", 0.0)) + fraction
		if float(item["unpowered_sols"]) >= float(definition["crop_grace_without_power_sols"]):
			if item.get("crop") != "dead":
				item["crop"] = "dead"
				SignalBus.building_changed.emit(id, &"crop_dead")
		elif item.get("crop") != "wilting":
			item["crop"] = "wilting"
			SignalBus.building_changed.emit(id, &"crop_wilting")
		return
	if item.get("crop") == "dead":
		return
	item["unpowered_sols"] = 0.0
	if item.get("crop") != "healthy":
		item["crop"] = "healthy"
		SignalBus.building_changed.emit(id, &"crop_healthy")
	ledger.add({"food": float(definition["food_per_sol"]) * fraction}, "production_greenhouse_%s" % id)

func plant_seed(building_id: StringName) -> GameContracts.ValidationResult:
	var item: Dictionary = GameState.data.get("buildings", {}).get("instances", {}).get(String(building_id), {})
	if item.is_empty() or item.get("type") != "greenhouse":
		return GameContracts.failure(&"invalid_greenhouse")
	if item.get("crop") == "healthy" or item.get("crop") == "wilting":
		return GameContracts.failure(&"crop_already_planted")
	var seed_cost := float(ConfigDB.balance["buildings"]["greenhouse"]["seed_cost"])
	if not ledger.spend({"seeds": seed_cost}, "plant_%s" % building_id):
		return GameContracts.failure(&"insufficient_resources")
	item["seed_planted"] = true
	item["crop"] = "healthy"
	item["unpowered_sols"] = 0.0
	SignalBus.building_changed.emit(building_id, &"planted")
	return GameContracts.success()

func print_recipe(building_id: StringName, recipe_id: StringName) -> GameContracts.ValidationResult:
	var item: Dictionary = GameState.data.get("buildings", {}).get("instances", {}).get(String(building_id), {})
	if item.is_empty() or item.get("type") != "printer_3d" or not bool(item.get("enabled", true)) or float(item.get("health", 0.0)) <= 0.0 or not power.is_powered(building_id):
		return GameContracts.failure(&"printer_unavailable")
	var recipes: Dictionary = ConfigDB.balance["buildings"]["printer_3d"]["recipes"]
	if not recipes.has(String(recipe_id)):
		return GameContracts.failure(&"unknown_recipe")
	if not ledger.spend(recipes[String(recipe_id)], "printer_input_%s_%s" % [building_id, recipe_id]):
		return GameContracts.failure(&"insufficient_resources")
	ledger.add({String(recipe_id): 1.0}, "production_printer_%s_%s" % [building_id, recipe_id])
	return GameContracts.success()

func on_sol_ended(_sol: int) -> void:
	pass
