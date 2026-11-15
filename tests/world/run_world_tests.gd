extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	GameState.reset(1234)
	var ledger := ResourceLedger.new()
	ledger.initialize(ConfigDB.balance["initial_inventory"])
	var grid := GridService.new()
	var buildings := BuildingService.new()
	var power := PowerService.new()
	var production := ProductionService.new()
	var research := ResearchService.new()
	var scan := ScanService.new()
	var tunnels := TunnelNetwork.new()
	buildings.ledger = ledger
	buildings.grid = grid
	buildings.power = power
	buildings.research = research
	grid.building_service = buildings
	power.building_service = buildings
	power.grid_service = grid
	production.building_service = buildings
	production.power = power
	production.ledger = ledger
	research.power = power
	scan.grid = grid
	scan.power = power
	_check(buildings.initialize_layout().ok, "initial layout")
	_check(grid.is_revealed(Vector2i(31, 31)), "initial 32 map")
	_check(not grid.is_revealed(Vector2i(32, 31)), "outside initial map")
	_check(grid.terrain_at(Vector2i(10, 14)) == &"aquifer", "aquifer")
	_check(grid.terrain_at(Vector2i(24, 23)) == &"iron_regolith", "mineral")
	_check(ledger.get_amount(&"iron_plates") == 32.0, "initial buildings free")
	var tunnel := GameContracts.PlacementRequest.new(&"tunnel", Vector2i(14, 17))
	_check(buildings.place(tunnel).ok, "tutorial tunnel")
	var lab := GameContracts.PlacementRequest.new(&"laboratory", Vector2i(14, 18))
	_check(buildings.place(lab).ok, "tutorial lab")
	var invalid := buildings.place(GameContracts.PlacementRequest.new(&"laboratory", Vector2i(250, 250)))
	_check(not invalid.ok and ledger.get_amount(&"iron_plates") == 15.0, "invalid placement free")
	GameState.data["research"]["unlocked"].append("solar_panel")
	var panel := GameContracts.PlacementRequest.new(&"solar_panel", Vector2i(10, 18))
	_check(buildings.place(panel).ok, "tutorial panel")
	_check(ledger.get_amount(&"iron_plates") == 5.0, "tutorial budget")
	_check(not buildings.place(GameContracts.PlacementRequest.new(&"isru", Vector2i(26, 26))).ok, "isru needs aquifer")
	_check(not buildings.place(GameContracts.PlacementRequest.new(&"mine", Vector2i(24, 23))).ok, "mine locked")
	_check(not grid.reserve_zone(&"rocket_1", Rect2i(30, 30, 8, 8)).ok, "zone boundary")
	_check(not scan.scan(Vector2i(32, 0)).ok, "scan maximum 256")
	_check(not scan.scan(Vector2i(6, 6)).ok, "scan adjacency")
	_check(not scan.scan(Vector2i(4, 0)).ok, "scan locked")
	GameState.data["research"]["unlocked"].append("satellite_scan")
	GameState.data["research"]["points"] = 8.0
	GameState.data["power"]["stored"] = 6.0
	_check(scan.scan(Vector2i(4, 0)).ok, "scan contiguous")
	_check(grid.is_revealed(Vector2i(32, 0)), "sector revealed")
	_check(not scan.scan(Vector2i(4, 0)).ok, "scan once")
	buildings.apply_damage(&"tunnel_1", 20.0, &"test")
	_check(tunnels.get_snapshot()["oxygen_leak_per_sol"] == 4.0, "breach leak")
	var task := buildings.request_repair(&"tunnel_1", &"weld", &"crew_1")
	_check(task.ok, "repair task")
	var task_id := StringName(task.params.get("task_id", ""))
	_check(buildings.apply_task_result(task_id, &"tunnel_1", {"completed": true}).ok, "repair apply")
	_check(not buildings.apply_task_result(task_id, &"tunnel_1", {"completed": true}).ok, "repair once")
	_check(buildings.get_status(&"tunnel_1").condition == &"fragile", "weld fragile")
	_check(tunnels.get_snapshot()["oxygen_leak_per_sol"] == 0.0, "repair stops leak")
	power.step(0.1)
	_check(power.is_powered(&"isru_1"), "initial reactor powers isru")
	var oxygen_before := ledger.get_amount(&"oxygen")
	production.step(0.1)
	_check(ledger.get_amount(&"oxygen") > oxygen_before, "powered isru produces")
	GameState.data["buildings"]["instances"]["reactor_1"]["fuel_sols"] = 0.0
	GameState.data["buildings"]["instances"]["solar_panel_5"]["enabled"] = false
	power.step(0.1)
	_check(not power.is_powered(&"isru_1"), "reactor outage")
	oxygen_before = ledger.get_amount(&"oxygen")
	production.step(0.1)
	_check(is_equal_approx(ledger.get_amount(&"oxygen"), oxygen_before), "unpowered isru stops")
	var food_before := ledger.get_amount(&"food")
	production.step(30.0)
	_check(GameState.data["buildings"]["instances"]["greenhouse_1"]["crop"] == "dead", "crop dies after grace")
	_check(is_equal_approx(ledger.get_amount(&"food"), food_before), "dead crop no food")
	GameState.data["buildings"]["instances"]["reactor_1"]["fuel_sols"] = 14.0
	power.step(0.1)
	_check(research.start_research(&"battery").ok, "research starts with lab")
	_check(research.consume_work({"task_id": "science_1", "target_id": "laboratory_4", "work_hours": 14.0}).ok, "research work")
	_check(GameState.data["research"]["unlocked"].has("battery"), "battery unlocked")
	_check(not research.consume_work({"task_id": "science_1", "target_id": "laboratory_4", "work_hours": 14.0}).ok, "research work once")
	var saved := GameState.to_dict()
	GameState.from_dict(saved)
	_check(buildings.get_all_statuses().size() == 9, "state restored building count")
	var scene: PackedScene = load("res://scenes/world/world.tscn")
	var world: MartianWorld = scene.instantiate()
	get_tree().root.add_child(world)
	world.configure(buildings, grid)
	_check(world.get_node("Buildings").get_child_count() == 9, "world renders buildings")
	_check(world.focus_target(&"base_1"), "focus target")
	world.rebuild_from_state()
	_check(world.get_node("Buildings").get_child_count() == 9, "world restore without duplicates")
	world.queue_free()
	if failures.is_empty():
		print("R2 world tests passed")
		get_tree().call_deferred("quit", 0)
	else:
		for message in failures:
			push_error(message)
		get_tree().call_deferred("quit", 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
