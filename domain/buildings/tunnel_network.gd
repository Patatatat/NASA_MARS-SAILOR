class_name TunnelNetwork
extends RefCounted

func rebuild_from_state() -> void:
	pass

func get_snapshot() -> Dictionary:
	var components: Array[Dictionary] = []
	var links: Array[Dictionary] = []
	var leaks: Array[Dictionary] = []
	var total := 0.0
	var instances: Dictionary = GameState.data.get("buildings", {}).get("instances", {})
	for id in instances:
		var item: Dictionary = instances[id]
		if item.get("type") != "tunnel":
			continue
		var loss := 0.0
		if item.get("condition") == "breached" and not bool(item.get("isolated", false)):
			loss = float(ConfigDB.balance["events"]["tunnel_breach"]["oxygen_loss_per_sol"])
			leaks.append({"building_id": id, "oxygen_loss_per_sol": loss})
			total += loss
		components.append({"building_id": id, "condition": item.get("condition", "normal"), "isolated": bool(item.get("isolated", false))})
		links.append({"building_id": id, "connected": item.get("condition") != "breached" and not bool(item.get("isolated", false))})
	return {"components": components, "links": links, "leaks": leaks, "oxygen_leak_per_sol": total}
