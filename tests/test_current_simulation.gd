extends SceneTree
## Regresión del contrato actual de Rafael: cuatro recursos y 42 soles.
const Simulation = preload("res://domain/simulation.gd")
const Config = preload("res://domain/simulation_config.gd")
const CREW := ["engineer", "medic", "botanist", "technician"]
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var loaded := Config.load_file()
	_check(loaded.ok, "datos actuales válidos")
	if not loaded.ok:
		quit(1)
		return
	var data: Dictionary = loaded.data
	_check(data.sol_seconds == 60 and data.target_sols == 42, "duración de Rafael preservada")
	_check(data.initial.keys().size() == 4 and not data.initial.has("mass") and not data.initial.has("water"), "cuatro recursos sin inventarios anteriores")
	var safe := data.duplicate(true)
	safe.map_sizes = [32]
	safe.map_obstacle_ratio = 0
	safe.initial.regolith = 1000
	safe.initial.air = 100000
	safe.initial.food = 100000
	safe.energy_capacity = 100000
	safe.initial.energy = 100000
	for kind: String in ["storm", "solar_particles"]:
		safe.events[kind].probability = 0
	_test_commands(safe)
	_test_economy(data)
	_test_missions(safe)
	_test_upgrade_maintenance(safe)
	_test_events(safe)
	_test_summary_frames(safe)
	print("CURRENT_SIMULATION_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _make(data: Dictionary, crew: Array = CREW) -> RefCounted:
	var sim := Simulation.new()
	_check(sim.configure(data).ok, "configurar")
	_check(sim.reset_run(crew, 123).ok, "iniciar estado")
	return sim

func _place(sim: RefCounted, kind: String) -> String:
	for y: int in range(1, 31):
		for x: int in range(1, 31):
			if sim.preview_placement(kind, Vector2i(x, y)).ok:
				var result: Dictionary = sim.place_building(kind, Vector2i(x, y))
				_check(result.ok, "construir " + kind)
				return result.result.building_id
	_check(false, "hay sitio para " + kind)
	return ""

func _test_commands(data: Dictionary) -> void:
	var sim := _make(data)
	var before: Dictionary = sim.get_snapshot()
	_check(not sim.reset_run(["engineer", "engineer", "medic", "botanist"]).ok, "rechaza duplicados")
	_check(not sim.place_building("solar", Vector2i(-1, 0)).ok, "rechaza límites")
	_check(not sim.place_building("unknown", Vector2i(1, 1)).ok, "rechaza tipo inválido")
	_check(sim.get_snapshot() == before, "rechazos no mutan")
	var id := _place(sim, "solar")
	_near(sim.get_snapshot().resources.regolith, 985, "regolito: 1000 -15")
	before = sim.get_snapshot()
	var b: Dictionary = before.buildings[-1]
	_check(not sim.place_building("solar", Vector2i(b.x, b.y)).ok and sim.get_snapshot() == before, "huella ocupada no cobra")
	var copy: Dictionary = sim.get_snapshot()
	copy.resources.regolith = -1
	copy.buildings[-1].enabled = false
	_check(sim.get_snapshot() == before, "snapshot profundo")
	_check(sim.set_enabled(id, false).ok, "apagar")
	sim.reset_run(CREW, 123)
	_check(sim.get_snapshot().buildings.size() == 1 and sim.get_snapshot().map == before.map, "reinicio y mapa reproducibles")

func _test_economy(data: Dictionary) -> void:
	var sim := _make(data)
	_place(sim, "solar")
	sim.start_run()
	sim.advance(10)
	_near(sim.get_snapshot().resources.air, 80 - 8.0 / 6, "aire consumido por segundo")
	_near(sim.get_snapshot().resources.food, 260 - 16.0 / 6, "alimento combinado")
	_near(sim.get_snapshot().resources.energy, 180, "energía: 160 -5 + 5×(6-1)")
	sim.advance(30)
	_check(not sim.get_snapshot().power.is_day, "noche a 40 s")
	_near(sim.get_snapshot().power.supply, 0, "solar no genera de noche")
	var stored: float = sim.get_snapshot().resources.energy
	sim.advance(1)
	_near(sim.get_snapshot().resources.energy, stored - 1, "batería abastece hábitat")
	sim.set_paused(true)
	var before: Dictionary = sim.get_snapshot()
	sim.advance(100)
	_check(sim.get_snapshot() == before, "pausa congela reservas y reloj")
	sim.set_paused(false)
	sim.set_speed(4)
	sim.advance(1)
	_check(sim.get_snapshot().elapsed_seconds == 45, "velocidad x4")
	sim.advance(4)
	_check(sim.get_snapshot().power.is_day, "siguiente día")
	_near(sim.get_snapshot().crew[0].dose, 61.0 / 60 * 0.75, "dosis acumulativa con médico")

func _test_missions(data: Dictionary) -> void:
	var rules := data.duplicate(true)
	for destination: Dictionary in rules.roberts.destinations.values():
		destination.loss_probability = 0
	var sim := _make(rules)
	_place(sim, "laboratory")
	sim.start_run()
	sim.advance(10)
	_check(sim.send_robert("robert_1", "ice").ok, "sale ROBERT por alimento")
	_check(sim.send_robert("robert_2", "quarry").ok, "sale ROBERT por regolito")
	var before: Dictionary = sim.get_snapshot()
	_check(not sim.send_robert("robert_1", "ice").ok and sim.get_snapshot() == before, "ocupado no duplica salida")
	sim.advance(120)
	_near(sim.get_snapshot().resources.food, 100000 - 16.0 * 130 / 60 + 45, "retorno aporta alimento una sola vez")
	_near(sim.get_snapshot().resources.regolith, 1005, "1000 -20 laboratorio +25 cantera")
	_check(sim.send_robert("robert_1", "ice").ok, "robot reutilizable")
	var food: float = sim.get_snapshot().resources.food
	sim.advance(120)
	_near(sim.get_snapshot().resources.food - food, 13, "segundo viaje: +45 -32 consumo")

func _test_upgrade_maintenance(data: Dictionary) -> void:
	var sim := _make(data, ["engineer", "medic", "scientist", "technician"])
	var solar := _place(sim, "solar")
	sim.start_run()
	sim.advance(5)
	_check(sim.start_upgrade(solar).ok, "mejora con científico")
	var before: Dictionary = sim.get_snapshot()
	_check(not sim.start_upgrade(solar).ok and sim.get_snapshot() == before, "no cobra mejora repetida")
	sim.advance(14)
	_check(sim.get_snapshot().buildings[1].level == 1, "nivel 1 durante trabajo")
	sim.advance(1)
	_check(sim.get_snapshot().buildings[1].level == 2, "científico completa en 15 s")
	_near(sim.get_snapshot().power.supply, 9.6, "solar mejorado")
	sim = _make(data)
	var reactor := _place(sim, "reactor")
	sim.start_run()
	sim.advance(250)
	_check(sim.get_snapshot().buildings[1].maintenance.state == "requested", "mantenimiento a cuatro soles de obra")
	var opened: Dictionary = sim.begin_maintenance(reactor)
	_check(opened.ok and sim.apply_maintenance_result(opened.result.id, true, 1).ok, "sesión aplica resultado")
	before = sim.get_snapshot()
	_check(not sim.apply_maintenance_result(opened.result.id, true, 1).ok and sim.get_snapshot() == before, "resultado único")
	sim = _make(data)
	reactor = _place(sim, "reactor")
	sim.start_run()
	sim.advance(310)
	_near(sim.get_snapshot().power.supply, 11.76, "degradación 14×1.2×.7")
	sim.advance(60)
	_check(sim.get_snapshot().buildings[1].maintenance.state == "shutdown", "apagado por ignorar")
	sim.advance(120)
	_check(sim.reactivate_building(reactor).ok, "reactivación con reglamento actual")
	_near(sim.get_snapshot().resources.regolith, 950, "1000 -45 -5")

func _test_events(data: Dictionary) -> void:
	var rules := data.duplicate(true)
	rules.events.storm.probability = 1
	rules.events.storm.start_sols_min = 2
	rules.events.storm.start_sols_max = 2
	rules.events.storm.duration_sols = 1
	var sim := _make(rules)
	_place(sim, "solar")
	sim.start_run()
	sim.advance(60)
	_check(sim.get_snapshot().event.state == "active", "evento de ventana variable activa a fecha sorteada")
	_near(sim.get_snapshot().power.supply, 1.5, "tormenta reduce solar diurno")
	sim.advance(60)
	_near(sim.get_snapshot().power.supply, 3.3, "tormenta deja 45% de daño por inacción: 6 × .55")

func _test_summary_frames(data: Dictionary) -> void:
	var a := _make(data)
	var b := _make(data)
	a.start_run()
	b.start_run()
	a.advance(120)
	for i: int in range(1200):
		b.advance(0.1)
	_check(a.get_snapshot() == b.get_snapshot(), "misma semilla y distintos frames")
	a.advance(3000)
	_check(a.get_snapshot().phase == "finished" and a.get_run_summary().ok, "final y resumen actual")
	var result: Dictionary = a.get_run_summary().result
	_check(result.sustainability.resources.has("energy") and not result.sustainability.resources.has("water"), "resumen refleja energía y alimento unificado")
	for value: float in result.components.values():
		_check(is_finite(value) and value >= 0 and value <= 1, "componentes normalizados")
	var copy := result.duplicate(true)
	result.crew.members[0].health = -1
	_check(a.get_run_summary().result == copy, "resumen aislado")
	a.reset_run(CREW)
	_check(not a.get_run_summary().ok, "reinicio limpia final")

func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.00001, "%s: esperado %.5f, observado %.5f" % [message, expected, actual])

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
