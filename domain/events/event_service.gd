class_name EventService
extends RefCounted

var building_service
var report

func rebuild_from_state() -> void:
	_sync_flags()

func get_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in GameState.data.get("events", {}).get("items", {}).values():
		result.append(event.duplicate(true))
	return result

func set_event_enabled(event_id: StringName, enabled: bool) -> GameContracts.ValidationResult:
	if event_id not in [&"tunnel_breach", &"dust_storm", &"solar_flare", &"random_events"]:
		return GameContracts.failure(&"unknown_event")
	GameState.data["events"].get_or_add("enabled", {})[String(event_id)] = enabled
	return GameContracts.success()

func trigger_event(event_id: StringName) -> GameContracts.ValidationResult:
	if event_id not in [&"tunnel_breach", &"dust_storm", &"solar_flare"]:
		return GameContracts.failure(&"unknown_event")
	var sol := int(GameState.data["clock"]["sol"])
	return _activate(event_id, sol, _duration(event_id))

func clear_event(event_id: StringName) -> GameContracts.ValidationResult:
	var items: Dictionary = GameState.data.get("events", {}).get("items", {})
	var item: Dictionary = items.get(String(event_id), {})
	if item.is_empty() or item.get("phase") == "ended":
		return GameContracts.failure(&"event_not_active")
	item["phase"] = "ended"
	_sync_flags()
	SignalBus.event_changed.emit(event_id, &"ended")
	return GameContracts.success()

func on_sol_started(sol: int) -> void:
	var state: Dictionary = GameState.data["events"]
	state.get_or_add("items", {})
	state.get_or_add("enabled", {})
	for id in state["items"].keys():
		var item: Dictionary = state["items"][id]
		if item.get("phase") == "active" and sol >= int(item.get("end_sol", 999)):
			clear_event(StringName(id))
		elif item.get("phase") == "warning" and sol >= int(item.get("start_sol", 999)):
			_activate(StringName(id), sol, int(item.get("duration", 1)))
	if sol == 6 and _enabled(&"tunnel_breach"):
		_activate(&"tunnel_breach", sol, 1)
	if sol == 11 and _enabled(&"dust_storm"):
		_warn(&"dust_storm", 12, 4)
	if sol == 14 and _enabled(&"solar_flare"):
		_warn(&"solar_flare", 16, 2)
	if sol >= int(ConfigDB.balance["events"]["random_events_start_sol"]) and _enabled(&"random_events") and not _has_active_hazard() and not state["items"].has("random_%d" % sol):
		var roll := _next_roll()
		if roll < 0.2:
			var kind := &"dust_storm" if roll < 0.1 else &"solar_flare"
			var warning := int(ConfigDB.balance["events"][String(kind)]["warning_sols"])
			_warn(StringName("random_%d" % sol), sol + warning, _duration(kind), kind)
	_sync_flags()

func on_sol_ended(_sol: int) -> void:
	pass

func step(delta_seconds: float) -> void:
	if not bool(GameState.data.get("events", {}).get("dust_storm_active", false)) or building_service == null:
		return
	var amount := float(ConfigDB.balance["events"]["dust_storm"]["panel_dust_per_sol"]) * delta_seconds / float(ConfigDB.balance["time"]["sol_seconds_x1"])
	for status in building_service.get_all_statuses():
		if status.type == &"solar_panel":
			building_service.apply_panel_dust(status.building_id, amount)

func _warn(id: StringName, start: int, duration: int, kind: StringName = &"") -> void:
	var type_id := kind if kind != &"" else id
	GameState.data["events"]["items"][String(id)] = {"id": String(id), "type": String(type_id),
		"phase": "warning", "start_sol": start, "end_sol": start + duration,
		"duration": duration, "source_id": "", "target_ids": [], "modifiers": {}}
	SignalBus.event_changed.emit(id, &"warning")

func _activate(id: StringName, sol: int, duration: int) -> GameContracts.ValidationResult:
	var state: Dictionary = GameState.data["events"]
	state.get_or_add("items", {})
	state.get_or_add("enabled", {})
	var kind := String(state["items"].get(String(id), {}).get("type", String(id)))
	if not _enabled(StringName(kind)):
		return GameContracts.failure(&"event_disabled")
	if _has_active_hazard() and kind != "tunnel_breach":
		return GameContracts.failure(&"event_limit")
	if state["items"].has(String(id)) and state["items"][String(id)].get("phase") in ["active", "ended"]:
		return GameContracts.failure(&"event_already_triggered")
	var targets: Array[String] = []
	if kind == "tunnel_breach":
		var tunnels: Array[String] = []
		for building_id in GameState.data.get("buildings", {}).get("instances", {}):
			if GameState.data["buildings"]["instances"][building_id].get("type") == "tunnel":
				tunnels.append(building_id)
		tunnels.sort()
		if not tunnels.is_empty() and building_service != null:
			var target := tunnels[0]
			building_service.apply_damage(StringName(target), 30.0, &"micrometeorite")
			targets.append(target)
	state["items"][String(id)] = {"id": String(id), "type": kind, "phase": "active",
		"start_sol": sol, "end_sol": sol + duration, "duration": duration,
		"source_id": "", "target_ids": targets, "modifiers": {}}
	_sync_flags()
	SignalBus.event_changed.emit(id, &"active")
	_record_fact(id, kind, targets)
	return GameContracts.success()

func _sync_flags() -> void:
	var events: Dictionary = GameState.data.get("events", {})
	events["dust_storm_active"] = false
	events["solar_flare_active"] = false
	for item in events.get("items", {}).values():
		if item.get("phase") == "active":
			if item.get("type") == "dust_storm":
				events["dust_storm_active"] = true
			if item.get("type") == "solar_flare":
				events["solar_flare_active"] = true

func _has_active_hazard() -> bool:
	for item in GameState.data.get("events", {}).get("items", {}).values():
		if item.get("phase") == "active" and item.get("type") in ["dust_storm", "solar_flare"]:
			return true
	return false

func _enabled(id: StringName) -> bool:
	return bool(GameState.data.get("events", {}).get("enabled", {}).get(String(id), true))

func _duration(id: StringName) -> int:
	if id == &"tunnel_breach":
		return 1
	var values: Array = ConfigDB.balance["events"][String(id)].get("duration_sols", [1])
	return int(values[values.size() - 1])

func _next_roll() -> float:
	var state := int(GameState.data.get("rng_state", 1))
	state = (state * 1103515245 + 12345) & 0x7fffffff
	GameState.data["rng_state"] = state
	return float(state) / 2147483647.0

func _record_fact(id: StringName, kind: String, targets: Array[String]) -> void:
	if report == null:
		return
	var clock: Dictionary = GameState.data["clock"]
	report.record_fact({"reason_id": String(id), "source_id": "", "target_id": targets[0] if not targets.is_empty() else "",
		"sol": int(clock["sol"]), "sim_time": float(clock["elapsed"]),
		"message_key": "event.%s.active" % kind, "params": {}, "impact": {"target_ids": targets}})
