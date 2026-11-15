class_name TunnelNetwork
extends RefCounted

static func has_tunnel_port(item: Dictionary) -> bool:
	return item.get("type", "") in ["base", "tunnel", "isru", "greenhouse", "laboratory", "refinery", "printer_3d", "landing_pad"]

static func is_open(item: Dictionary) -> bool:
	return has_tunnel_port(item) and item.get("condition", "normal") not in ["breached", "destroyed"] and not bool(item.get("isolated", false)) and bool(item.get("enabled", true)) and float(item.get("health", 100.0)) > 0.0

static func topology(instances: Dictionary) -> Dictionary:
	var occupied: Dictionary = {}
	var neighbors: Dictionary = {}
	for id in instances:
		var item: Dictionary = instances[id]
		if not has_tunnel_port(item):
			continue
		neighbors[id] = []
		var rect := _rect(item)
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				occupied[Vector2i(x, y)] = id
	for cell: Vector2i in occupied:
		var id: String = occupied[cell]
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var other: String = occupied.get(cell + direction, "")
			if not other.is_empty() and other != id and not neighbors[id].has(other):
				neighbors[id].append(other)
	var connected: Dictionary = {}
	var queue: Array[String] = []
	for id in neighbors:
		if instances[id].get("type") == "base" and is_open(instances[id]):
			connected[id] = true
			queue.append(id)
	var cursor := 0
	while cursor < queue.size():
		var id := queue[cursor]
		cursor += 1
		for other: String in neighbors[id]:
			if not connected.has(other) and is_open(instances[other]):
				connected[other] = true
				queue.append(other)
	return {"neighbors": neighbors, "connected": connected}

static func _rect(item: Dictionary) -> Rect2i:
	var origin: Array = item.get("origin", [0, 0])
	var size: Array = item.get("size", [1, 1])
	return Rect2i(int(origin[0]), int(origin[1]), int(size[0]), int(size[1]))

func rebuild_from_state() -> void:
	pass

func get_snapshot() -> Dictionary:
	var components: Array[Dictionary] = []
	var links: Array[Dictionary] = []
	var leaks: Array[Dictionary] = []
	var total := 0.0
	var instances: Dictionary = GameState.data.get("buildings", {}).get("instances", {})
	var graph := topology(instances)
	for id in instances:
		var item: Dictionary = instances[id]
		if item.get("type") != "tunnel":
			continue
		var loss := 0.0
		if item.get("condition") == "breached" and not bool(item.get("isolated", false)):
			for neighbor: String in graph["neighbors"].get(id, []):
				if graph["connected"].has(neighbor):
					loss = float(ConfigDB.balance["events"]["tunnel_breach"]["oxygen_loss_per_sol"])
					break
			if loss > 0.0:
				leaks.append({"building_id": id, "oxygen_loss_per_sol": loss})
				total += loss
		components.append({"building_id": id, "condition": item.get("condition", "normal"), "isolated": bool(item.get("isolated", false))})
		links.append({"building_id": id, "connected": graph["connected"].has(id), "neighbors": graph["neighbors"].get(id, []).duplicate()})
	return {"components": components, "links": links, "leaks": leaks, "oxygen_leak_per_sol": total}
