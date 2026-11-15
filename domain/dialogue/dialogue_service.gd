class_name DialogueService
extends RefCounted

const KINDS := [&"critical", &"tutorial", &"operational", &"ambient", &"science"]
var events: EventService
var buildings: BuildingService

func configure(event_service: EventService = null, building_service: BuildingService = null) -> void:
	events = event_service
	buildings = building_service
	if not SignalBus.sol_started.is_connected(_on_sol_started):
		SignalBus.sol_started.connect(_on_sol_started)
	if not SignalBus.building_changed.is_connected(_on_building_changed):
		SignalBus.building_changed.connect(_on_building_changed)
	if not SignalBus.research_changed.is_connected(_on_research_changed):
		SignalBus.research_changed.connect(_on_research_changed)
	if not SignalBus.event_changed.is_connected(_on_event_changed):
		SignalBus.event_changed.connect(_on_event_changed)

func shutdown() -> void:
	if SignalBus.sol_started.is_connected(_on_sol_started):
		SignalBus.sol_started.disconnect(_on_sol_started)
	if SignalBus.building_changed.is_connected(_on_building_changed):
		SignalBus.building_changed.disconnect(_on_building_changed)
	if SignalBus.research_changed.is_connected(_on_research_changed):
		SignalBus.research_changed.disconnect(_on_research_changed)
	if SignalBus.event_changed.is_connected(_on_event_changed):
		SignalBus.event_changed.disconnect(_on_event_changed)

func rebuild_from_state() -> void:
	if GameState.data.is_empty():
		return
	_ensure_state()

func add_entry(entry: DialogueEntry) -> GameContracts.ValidationResult:
	if GameState.data.is_empty():
		return GameContracts.failure(&"not_running")
	_ensure_state()
	if String(entry.id).is_empty() or not KINDS.has(entry.kind) or not _localization().has_key_in_both(entry.message_key):
		return GameContracts.failure(&"invalid_dialogue")
	if not String(entry.source_id).is_empty() and _catalog().get_source(entry.source_id).is_empty():
		return GameContracts.failure(&"unknown_source")
	if not String(entry.focus_target).is_empty() and not _valid_focus(entry.focus_target):
		return GameContracts.failure(&"invalid_focus_target")
	for old in GameState.data["dialogue"]["entries"]:
		if old.get("id") == String(entry.id):
			return GameContracts.failure(&"duplicate_dialogue")
	entry.created_sol = int(GameState.data.get("clock", {}).get("sol", 1))
	GameState.data["dialogue"]["entries"].append(entry.as_dict())
	SignalBus.log_entry_added.emit(entry)
	return GameContracts.success()

func add_fact(id: StringName, kind: StringName, key: StringName, params: Dictionary = {}, focus: StringName = &"", source: StringName = &"") -> GameContracts.ValidationResult:
	var entry := DialogueEntry.new()
	entry.id = id
	entry.kind = kind
	entry.severity = &"critical" if kind == &"critical" else &"info"
	entry.message_key = key
	entry.params = params
	entry.focus_target = focus
	entry.source_id = source
	return add_entry(entry)

func get_entries() -> Array[Dictionary]:
	if GameState.data.is_empty():
		return []
	_ensure_state()
	var result: Array[Dictionary] = []
	for item in GameState.data["dialogue"]["entries"]:
		result.append(item.duplicate(true))
	return result

func get_top_notice() -> Dictionary:
	var best: Dictionary = {}
	var rank := 99
	for item in get_entries():
		if item.get("resolved", false):
			continue
		if item.get("kind") == "tutorial" and GameState.data.get("tutorial", {}).get("skipped", false):
			continue
		if item.get("acknowledged", false) and item.get("kind") != "critical":
			continue
		var next_rank := KINDS.find(StringName(item.get("kind", "")))
		if next_rank >= 0 and next_rank < rank:
			best = item
			rank = next_rank
	return best

func acknowledge(id: StringName) -> GameContracts.ValidationResult:
	_ensure_state()
	for item in GameState.data["dialogue"]["entries"]:
		if item.get("id") == String(id):
			item["acknowledged"] = true
			SignalBus.guide_dialogue_changed.emit(id, &"acknowledged")
			return GameContracts.success()
	return GameContracts.failure(&"unknown_dialogue")

func resolve(id: StringName) -> GameContracts.ValidationResult:
	_ensure_state()
	for item in GameState.data["dialogue"]["entries"]:
		if item.get("id") == String(id):
			item["resolved"] = true
			SignalBus.guide_dialogue_changed.emit(id, &"resolved")
			return GameContracts.success()
	return GameContracts.failure(&"unknown_dialogue")

func skip_tutorial() -> void:
	if GameState.data.is_empty():
		return
	GameState.data.get_or_add("tutorial", {})["skipped"] = true
	SignalBus.guide_dialogue_changed.emit(&"tutorial", &"skipped")

func reactivate_tutorial() -> void:
	if GameState.data.is_empty():
		return
	GameState.data.get_or_add("tutorial", {})["skipped"] = false
	SignalBus.guide_dialogue_changed.emit(&"tutorial", &"reactivated")

func observe_fact(fact_type: StringName, params: Dictionary = {}) -> void:
	_ensure_state()
	var tutorial: Dictionary = GameState.data.get_or_add("tutorial", {})
	var completed: Array = tutorial.get_or_add("completed", [])
	var steps: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial.json"))
	if not steps is Dictionary:
		return
	for step in steps.get("steps", []):
		var id := String(step.get("id", ""))
		var completion := String(step.get("completion", ""))
		if completion == String(fact_type) or completion == "%s:%s" % [fact_type, params.get("building_id", "")]:
			complete_tutorial_step(StringName(id))
		if completed.has(id) or GameState.data["dialogue"]["entries"].any(func(item): return item.get("id") == "tutorial_%s" % id):
			continue
		var trigger: Dictionary = step.get("trigger", {})
		if trigger.get("type") != String(fact_type):
			continue
		var matches := true
		for key in trigger:
			if key != "type" and trigger[key] != params.get(key):
				matches = false
		if matches:
			add_fact(StringName("tutorial_%s" % id), &"tutorial", StringName(step["body_key"]), {}, StringName(step.get("focus_target", "")))

func complete_tutorial_step(id: StringName) -> void:
	var tutorial: Dictionary = GameState.data.get_or_add("tutorial", {})
	var completed: Array = tutorial.get_or_add("completed", [])
	if not completed.has(String(id)):
		completed.append(String(id))
	resolve(StringName("tutorial_%s" % id))

func _ensure_state() -> void:
	GameState.data.get_or_add("dialogue", {})
	GameState.data["dialogue"].get_or_add("entries", [])

func _valid_focus(target: StringName) -> bool:
	var value := String(target)
	return value.begins_with("ui:") or value.begins_with("world:") or value.begins_with("crew_") or value.contains("_")

func _on_sol_started(sol: int) -> void:
	observe_fact(&"sol_started", {"sol": sol})

func _on_building_changed(id: StringName, change: StringName) -> void:
	if change == &"placed" and buildings != null:
		var status := buildings.get_status(id)
		if status != null:
			observe_fact(&"building_placed", {"building_id": String(status.type)})
	if change in [&"repaired", &"isolated"] and not _has_tunnel_leak():
		resolve(&"event_tunnel_breach_active")

func _on_research_changed(id: StringName, change: StringName) -> void:
	if change == &"unlocked":
		observe_fact(&"research_completed", {"tech_id": String(id)})

func _on_event_changed(id: StringName, phase: StringName) -> void:
	if phase == &"ended":
		resolve(StringName("event_%s" % id))
		if id != &"tunnel_breach" or not _has_tunnel_leak():
			resolve(StringName("event_%s_active" % id))
		return
	if events == null:
		return
	for event in events.get_snapshot():
		if event.get("id") != String(id):
			continue
		var kind := String(event.get("type", ""))
		if phase == &"warning":
			var sols := maxi(0, int(event.get("start_sol", 0)) - int(GameState.data.get("clock", {}).get("sol", 1)))
			add_fact(StringName("event_%s" % id), &"critical", StringName("event.%s.warning" % kind), {"sols": sols}, &"ui:workspace_crew")
			observe_fact(&"event_warning", {"event_id": kind})
		elif phase == &"active":
			resolve(StringName("event_%s" % id))
			var focus := StringName(event.get("target_ids", [])[0]) if not event.get("target_ids", []).is_empty() else &"ui:workspace_crew"
			add_fact(StringName("event_%s_active" % id), &"critical", StringName("event.%s.active" % kind), {}, focus)
		break

func _has_tunnel_leak() -> bool:
	if buildings == null or buildings.tunnel_network == null:
		return false
	return not buildings.tunnel_network.get_snapshot().get("leaks", []).is_empty()

func _localization() -> Node:
	return Engine.get_main_loop().root.get_node("LocalizationDB")

func _catalog() -> Node:
	return Engine.get_main_loop().root.get_node("NasaDataCatalog")
