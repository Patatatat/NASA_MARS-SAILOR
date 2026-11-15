extends Node

var main: MissionMain
var failures: Array[String] = []
var checks := 0
var operations := 0

func _ready() -> void:
	main = preload("res://scenes/integration/main.tscn").instantiate()
	add_child(main)
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("FAIL ", message)

func reset() -> void:
	main._start_new([&"medic", &"engineer_a", &"scientist_a", &"medic"])
	GameClock.set_paused(true)

func corrupt(path: Array, replacement: Variant) -> void:
	var previous := SaveService.export_state()
	var candidate := previous.duplicate(true)
	var cursor: Variant = candidate
	for index in path.size() - 1:
		cursor = cursor[path[index]]
	cursor[path[-1]] = replacement
	check(SaveService.import_state(candidate) == ERR_INVALID_DATA, "corrupt save rejected: %s" % str(path))
	check(GameState.data == previous, "corrupt import is atomic: %s" % str(path))

func run() -> void:
	reset()
	for bad in [NAN, INF, -INF, -1.0, "bad", [], {}, null]:
		corrupt(["clock", "elapsed"], bad)
	corrupt(["clock", "paused"], "yes")
	corrupt(["power", "stored"], -1.0)
	corrupt(["buildings", "instances", "base_1", "origin"], [14])
	corrupt(["buildings", "instances", "base_1", "size"], [0, 3])
	corrupt(["buildings", "pending_tasks"], {"x": "bad"})
	corrupt(["buildings", "logs"], {"base_1": ["bad"]})
	corrupt(["crew", "members", "crew_1", "task_id"], "missing_task")
	corrupt(["crew", "members", "crew_1", "sleep_hours"], "bad")
	corrupt(["crew", "members", "crew_1", "alive"], 4)
	corrupt(["world", "terrain"], {"0,0": {"not": "terrain"}})
	corrupt(["world", "reservations"], {"x": [0, 0]})
	corrupt(["research", "points"], -2.0)
	corrupt(["research", "active"], "fake_technology")
	corrupt(["reports"], {"1": {"facts": ["bad"]}})
	corrupt(["dialogue", "entries"], [null])
	corrupt(["life_support", "supply"], "bad")
	corrupt(["settings", "ui_scale"], 100)
	corrupt(["settings", "language"], "xx")
	check(not main.building.place(null).ok, "null placement safely rejected")
	for seed in [7, 41, 2026, 73021, 99991]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		for index in 200:
			if index % 50 == 0:
				reset()
			var before := main.ledger.get_snapshot()
			var kind := rng.randi_range(0, 8)
			match kind:
				0:
					var types := ["tunnel", "laboratory", "solar_panel", "mine", "unknown"]
					var result := main.building.place(GameContracts.PlacementRequest.new(StringName(types[rng.randi_range(0, 4)]), Vector2i(rng.randi_range(-8, 40), rng.randi_range(-8, 40)), rng.randi_range(-1, 4)))
					if not result.ok:
						check(main.ledger.get_snapshot() == before, "invalid placement is free")
				1:
					var amount: float = [-1.0, NAN, INF, 0.0, 1.0, 1e6][rng.randi_range(0, 5)]
					if not main.ledger.spend({"chips": amount}, "qa_spend"):
						check(main.ledger.get_snapshot() == before, "rejected spend is atomic")
				2:
					var id := StringName("rocket_%d" % rng.randi_range(1, 6))
					var result := main.rockets.confirm_manifest(id, {"chips": rng.randi_range(-5, 130)})
					check(main.ledger.get_snapshot() == before, "confirming cargo never transfers it")
					if result.ok:
						check(not main.rockets.confirm_manifest(id, {"chips": 1}).ok, "confirmed manifest is immutable")
				3:
					main.rockets.reserve_landing_zone(StringName("rocket_%d" % rng.randi_range(1, 4)), Rect2i(rng.randi_range(-4, 36), rng.randi_range(-4, 36), 8, 8))
				4:
					var stock := main.ledger.get_snapshot()
					var result := main.crew.queue_research(StringName("crew_%d" % rng.randi_range(1, 6)), &"missing_lab", float(rng.randi_range(-3, 16)))
					check(not result.ok and main.ledger.get_snapshot() == stock, "invalid research assignment has no resource effects")
				5:
					main.building.set_enabled(&"reactor_1", rng.randf() > 0.5)
					main.building.set_enabled(&"greenhouse_1", rng.randf() > 0.5)
				6:
					GameClock.set_paused(false)
					main.session.update([0.1, 0.2, NAN, INF, -1.0][rng.randi_range(0, 4)])
					GameClock.set_paused(true)
					check(is_finite(main.session.runner.accumulator), "simulation accumulator stays finite")
				7:
					var snapshot := SaveService.export_state()
					check(SaveService.import_state(snapshot) == OK, "valid state round trip under mixed actions")
				8:
					var stock := main.ledger.get_snapshot()
					var result := main.crew.assign_building_action(&"crew_1", &"unknown", &"refuel")
					check(not result.ok and main.ledger.get_snapshot() == stock, "unknown target has no side effects")
			for amount in main.ledger.get_snapshot().values():
				check(is_finite(float(amount)) and float(amount) >= 0.0, "resource balances remain finite and nonnegative")
			operations += 1
			if index % 25 == 0:
				await get_tree().process_frame
	var result := {"passed": failures.is_empty(), "checks": checks, "operations": operations, "seeds": [7, 41, 2026, 73021, 99991], "failures": failures}
	var file := FileAccess.open("user://stress-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("Stress result: ", result)
	get_tree().quit(0 if failures.is_empty() else 1)
