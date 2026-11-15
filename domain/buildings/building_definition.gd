class_name BuildingDefinition
extends RefCounted

var type_id: StringName
var footprint: Vector2i
var cost: Dictionary
var connection_rule: StringName
var terrain_rule: StringName
var power_demand: float
var production_recipe: Dictionary
var visual_id: StringName

static func from_balance(id: StringName) -> BuildingDefinition:
	var source: Dictionary = ConfigDB.balance.get("buildings", {}).get(String(id), {})
	if source.is_empty():
		return null
	var definition := BuildingDefinition.new()
	definition.type_id = id
	var size: Array = source.get("size", [1, 1])
	definition.footprint = Vector2i(int(size[0]), int(size[1]))
	definition.cost = source.get("cost", {}).duplicate(true)
	definition.connection_rule = &"proximity" if id in [&"isru", &"solar_panel", &"battery", &"mine", &"reactor"] else &"tunnel"
	definition.terrain_rule = &"aquifer" if bool(source.get("requires_aquifer", false)) else (&"iron_regolith" if bool(source.get("requires_mineral", false)) else &"any")
	definition.power_demand = float(source.get("power", 0.0))
	definition.production_recipe = source.get("recipes", source.get("output_per_sol", {})).duplicate(true)
	definition.visual_id = id
	return definition
