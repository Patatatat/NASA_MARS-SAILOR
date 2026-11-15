class_name LifeSupportService
extends RefCounted

var ledger: ResourceLedger
var crew_service
var tunnel_network

func step(delta_seconds: float) -> void:
	var crew: Array = crew_service.get_snapshot() if crew_service != null else []
	var per_sol: Dictionary = ConfigDB.balance["astronaut"]["consumption_per_sol"]
	var fraction := delta_seconds / float(ConfigDB.balance["time"]["sol_seconds_x1"])
	var living: Array[String] = []
	for astronaut in crew:
		if astronaut is Dictionary and bool(astronaut.get("alive", false)):
			living.append(String(astronaut.get("id", "")))
	var supply: Dictionary = {}
	var shortages: Dictionary = {}
	for crew_id in living:
		supply[crew_id] = {"oxygen": true, "water": true, "food": true}
	for resource in ["oxygen", "water", "food"]:
		var need := living.size() * float(per_sol.get(resource, 0.0)) * fraction
		var paid := minf(need, ledger.get_amount(StringName(resource)))
		if paid > 0.0:
			ledger.spend({resource: paid}, "life_support")
		if paid + 0.000001 < need:
			shortages[resource] = need - paid
			for crew_id in living:
				supply[crew_id][resource] = false
	var tunnel: Dictionary = tunnel_network.get_snapshot() if tunnel_network != null else {}
	var leak_rate := maxf(0.0, float(tunnel.get("oxygen_leak_per_sol", 0.0)))
	var leak := minf(ledger.get_amount(&"oxygen"), leak_rate * fraction)
	if leak > 0.0:
		ledger.spend({"oxygen": leak}, "tunnel_leak")
	GameState.data["life_support"] = {"supply": supply, "shortages": shortages,
		"living_count": living.size(), "oxygen_leak_per_sol": leak_rate}

func get_crew_supply(crew_id: StringName) -> Dictionary:
	return GameState.data.get("life_support", {}).get("supply", {}).get(String(crew_id), {}).duplicate(true)

func get_status() -> Dictionary:
	return GameState.data.get("life_support", {}).duplicate(true)

func rebuild_from_state() -> void:
	pass
