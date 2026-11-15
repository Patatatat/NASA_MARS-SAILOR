extends Node

var main: MissionMain
var failures := 0

func _ready() -> void:
	main = load("res://scenes/integration/main.tscn").instantiate()
	add_child(main)
	call_deferred("_run")

func _run() -> void:
	var profiles: Array[StringName] = [&"engineer_a", &"medic", &"medic", &"medic"]
	main.menu.start_requested.emit(profiles)
	check(GameState.is_running(), "start campaign")
	prepare_rocket(1, {"nuclear_core": 1})
	advance(6)
	check(main.crew.assign_eva_repair(&"crew_1", &"tunnel_1").ok, "repair breach")
	advance(7)
	check(main.tunnel.get_snapshot()["oxygen_leak_per_sol"] == 0.0, "breach repaired")
	check(main.rockets.get_snapshot()[0]["landed"], "rocket 1 landed")
	check(main.rockets.salvage(&"rocket_1", &"crew_2").ok, "salvage rocket 1")
	prepare_rocket(2, {"nuclear_core": 1})
	advance(13)
	check(main.crew.assign_building_action(&"crew_2", &"reactor_1", &"refuel").ok, "first refuel")
	advance(14)
	check(main.rockets.get_snapshot()[1]["landed"], "rocket 2 landed")
	check(main.rockets.salvage(&"rocket_2", &"crew_2").ok, "salvage rocket 2")
	prepare_rocket(3, {"nuclear_core": 1})
	advance(21)
	check(main.rockets.get_snapshot()[2]["landed"], "rocket 3 landed")
	check(main.rockets.salvage(&"rocket_3", &"crew_2").ok, "salvage rocket 3")
	prepare_rocket(4, {"seeds": 1})
	advance(26)
	check(main.crew.assign_building_action(&"crew_2", &"reactor_1", &"refuel").ok, "second refuel")
	advance(28)
	check(main.rockets.get_snapshot()[3]["landed"], "rocket 4 landed")
	advance(39)
	check(main.crew.assign_building_action(&"crew_2", &"reactor_1", &"refuel").ok, "third refuel")
	advance(42)
	main.session.update(60.0)
	check(GameState.data.get("result", "") == "victory", "survival through sol 42 wins")
	check(main.hud._final.visible, "victory screen visible")
	if failures == 0:
		print("Real 42-sol victory flow passed")
	get_tree().quit(1 if failures > 0 else 0)

func prepare_rocket(number: int, cargo: Dictionary) -> void:
	var id := StringName("rocket_%d" % number)
	check(main.rockets.reserve_landing_zone(id, Rect2i(22, 22, 8, 8)).ok, "zone for rocket %d" % number)
	check(main.rockets.confirm_manifest(id, cargo).ok, "manifest for rocket %d" % number)

func advance(sol: int) -> void:
	var result: GameContracts.ValidationResult = GameClock.advance_to_sol(sol)
	check(result.ok, "advance to sol %d" % sol)

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
