class_name RocketPlan
extends RefCounted

var id: StringName
var arrival_sol: int
var manifest: Dictionary
var mass_limit: float
var confirmed: bool
var zone: Array
var landed: bool
var cargo_transferred: bool
var disposition: StringName

static func from_dict(value: Dictionary) -> RocketPlan:
	var result := RocketPlan.new()
	result.id = StringName(value.get("id", ""))
	result.arrival_sol = int(value.get("arrival_sol", 0))
	result.manifest = value.get("manifest", {}).duplicate(true)
	result.mass_limit = float(value.get("mass_limit", 0.0))
	result.confirmed = bool(value.get("confirmed", false))
	result.zone = value.get("zone", []).duplicate(true)
	result.landed = bool(value.get("landed", false))
	result.cargo_transferred = bool(value.get("cargo_transferred", false))
	result.disposition = StringName(value.get("disposition", "available"))
	return result
