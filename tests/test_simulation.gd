extends SceneTree

const Simulation = preload("res://domain/simulation.gd")
const Config = preload("res://domain/simulation_config.gd")
const CREW := ["engineer", "medic", "botanist", "technician"]
var failures: int = 0
var checks: int = 0
var finished_count: int = 0

func _initialize() -> void:
	var loaded := Config.load_file()
	_check(loaded.ok, "JSON base válido")
	if not loaded.ok:
		quit(1)
		return
	var data: Dictionary = loaded.data
	_test_config(data)
	_test_commands(data)
	_test_clock(data)
	_test_economy(data)
	_test_endings(data)
	print("SIMULATION_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _new(data: Dictionary) -> RefCounted:
	var sim := Simulation.new()
	_check(sim.configure(data).ok, "configurar")
	_check(sim.reset_run(CREW, 123).ok, "reiniciar")
	return sim

func _test_config(data: Dictionary) -> void:
	_check(not Config.validate([]).ok, "rechaza raíz inválida")
	for bad: Variant in ["25", true, -1, NAN, INF, 1.5]:
		var changed := data.duplicate(true)
		changed.sol_seconds = bad
		_check(not Config.validate(changed).ok, "rechaza sol inválido %s" % bad)
	var changed := data.duplicate(true)
	changed.buildings.solar.mass = -1
	_check(not Config.validate(changed).ok, "rechaza costo negativo")
	changed = data.duplicate(true)
	changed.initial.erase("water")
	_check(not Config.validate(changed).ok, "rechaza campo requerido ausente")

func _test_commands(data: Dictionary) -> void:
	var sim := _new(data)
	var before: Dictionary = sim.get_snapshot()
	_check(not sim.reset_run(["engineer", "engineer", "medic", "botanist"]).ok, "rechaza duplicados")
	_check(not sim.reset_run(["engineer"]).ok, "rechaza menos de cuatro")
	_check(sim.get_snapshot() == before, "selección inválida no muta")
	for cell: Vector2i in [Vector2i(-1, 0), Vector2i(6, 0), Vector2i(2, 2)]:
		_check(not sim.place_building("solar", cell).ok, "rechaza celda inválida")
	_check(not sim.place_building("reactor", Vector2i(2, 3)).ok, "distancia reactor")
	_check(not sim.place_building("unknown", Vector2i.ZERO).ok, "tipo desconocido")
	_check(sim.get_snapshot() == before, "rechazos sin cambios")
	_check(sim.preview_placement("solar", Vector2i.ZERO).cost.mass == 15, "vista previa costo 15")
	_check(sim.get_snapshot() == before, "vista previa no muta")
	_check(sim.place_building("reactor", Vector2i.ZERO).ok, "primer reactor")
	_check(sim.place_building("reactor", Vector2i(5, 5)).ok, "segundo reactor")
	before = sim.get_snapshot()
	_check(not sim.place_building("solar", Vector2i(1, 0)).ok, "masa insuficiente")
	_check(not sim.place_building("reactor", Vector2i.ZERO).ok, "repetir compra no cobra")
	_check(sim.get_snapshot() == before, "compra fallida atómica")
	var copy: Dictionary = sim.get_snapshot()
	copy.crew[0].health = -100
	copy.buildings[0].enabled = false
	copy.resources.mass = 999
	_check(sim.get_snapshot() == before, "snapshot profundo aislado")
	_check(sim.reset_run(CREW, 123).ok and sim.get_snapshot().resources.mass == 100, "reinicio recupera masa")
	_check(sim.get_snapshot().buildings.size() == 1 and sim.get_snapshot().log.is_empty(), "reinicio borra edificios y registros")

func _test_clock(data: Dictionary) -> void:
	var a := _new(data)
	var b := _new(data)
	a.advance(100)
	_check(a.get_snapshot().elapsed_seconds == 0, "planificación no avanza")
	for sim: RefCounted in [a, b]:
		sim.place_building("solar", Vector2i.ZERO)
		sim.place_building("oxygen_generator", Vector2i(1, 0))
	a.start_run()
	b.start_run()
	a.advance(75)
	for i: int in range(750):
		b.advance(0.1)
	_check(a.get_snapshot() == b.get_snapshot(), "75 s = 750 frames de 0.1")
	_check(a.get_snapshot().completed_sols == 3, "cruza tres límites de sol")
	a.set_paused(true)
	var before: Dictionary = a.get_snapshot()
	a.advance(100)
	_check(a.get_snapshot() == before, "pausa sin consumo")
	a.set_paused(false)
	a.set_speed(4)
	a.advance(1)
	_check(a.get_snapshot().elapsed_seconds == 79, "velocidad x4")
	before = a.get_snapshot()
	_check(not a.advance(NAN).ok and not a.advance(-1).ok and not a.set_speed(INF).ok, "rechaza tiempo inválido")
	_check(a.get_snapshot() == before, "tiempo inválido no muta")

func _test_economy(data: Dictionary) -> void:
	var sim := _new(data)
	sim.start_run()
	sim.advance(25)
	var state: Dictionary = sim.get_snapshot()
	_near(state.resources.air, 72, "aire: 80 - 4×2")
	_near(state.resources.water, 152, "agua: 160 - 4×2")
	_near(state.resources.food, 92, "comida: 100 - 4×2")
	sim = _new(data)
	sim.place_building("solar", Vector2i.ZERO)
	sim.place_building("oxygen_generator", Vector2i(1, 0))
	sim.start_run()
	sim.advance(5)
	_near(sim.get_snapshot().resources.air, 78.4, "obra no produce durante cinco segundos")
	sim.advance(25)
	state = sim.get_snapshot()
	_near(state.resources.air, 82.4, "oxígeno: 78.4 + 12 - 8")
	_near(state.power.supply, 6, "ingeniero: 5×1.2")
	_near(state.power.demand, 4.2, "sistemas: 1 + 4×0.8")
	sim.set_enabled("b2", false)
	sim.advance(25)
	_near(sim.get_snapshot().resources.air, 74.4, "sin energía no produce aire")
	var dry := data.duplicate(true)
	dry.initial.water = 0
	sim = _new(dry)
	sim.place_building("reactor", Vector2i.ZERO)
	sim.place_building("greenhouse", Vector2i(1, 0))
	sim.start_run()
	sim.advance(25)
	_near(sim.get_snapshot().resources.food, 92, "sin agua no produce comida")
	_near(sim.get_snapshot().deficits.water, 8, "déficit registrado antes de limitar a cero")
	_near(sim.get_snapshot().crew[0].health, 80, "8 faltantes / 4 × 10 de daño")
	sim = _new(data)
	sim.place_building("reactor", Vector2i.ZERO)
	sim.place_building("greenhouse", Vector2i(1, 0))
	sim.start_run()
	sim.advance(35)
	_near(sim.get_snapshot().resources.food, 101.3, "botánico: 100 - 11.2 + 12.5")
	_near(sim.get_snapshot().resources.water, 144.8, "riego: 160 - 11.2 - 4")

func _test_endings(data: Dictionary) -> void:
	var baseline := _new(data)
	for run: int in range(3):
		baseline.reset_run(CREW, 123)
		baseline.place_building("reactor", Vector2i.ZERO)
		baseline.place_building("oxygen_generator", Vector2i(1, 0))
		baseline.place_building("greenhouse", Vector2i(3, 0))
		baseline.start_run()
		baseline.advance(300)
		_check(baseline.get_snapshot().result.verdict == "relief_achieved", "estrategia manual completa, reinicio %d" % run)
	var abundant := data.duplicate(true)
	abundant.initial.air = 1000
	abundant.initial.water = 1000
	abundant.initial.food = 1000
	var sim := _new(abundant)
	sim.place_building("solar", Vector2i.ZERO)
	sim.run_finished.connect(func(_result: Dictionary) -> void: finished_count += 1)
	sim.start_run()
	sim.advance(299)
	_check(sim.get_snapshot().phase == "running", "no termina antes de 300 s")
	sim.advance(1)
	_check(sim.get_snapshot().result.verdict == "relief_achieved", "relevo con soporte")
	sim.advance(1000)
	_check(finished_count == 1, "final emitido una sola vez")
	var before: Dictionary = sim.get_snapshot()
	_check(not sim.place_building("solar", Vector2i(1, 0)).ok, "no construir después del final")
	_check(sim.get_snapshot() == before, "final inmutable por comandos")
	sim.reset_run(CREW)
	sim.start_run()
	sim.advance(1000)
	_check(sim.get_snapshot().result.verdict == "partial_defeat", "relevo sin potencia")
	_check(finished_count == 2, "reinicio habilita un nuevo final")
	var empty := data.duplicate(true)
	empty.initial.air = 0
	empty.initial.water = 0
	empty.initial.food = 0
	sim = _new(empty)
	sim.start_run()
	sim.advance(300)
	_check(sim.get_snapshot().result.verdict == "total_defeat", "derrota por déficit")
	_check(sim.get_snapshot().result.alive == 0, "mueren cuatro una sola vez")
	_near(sim.get_snapshot().power.supply, 0, "sin suministro fantasma")
	var simultaneous := abundant.duplicate(true)
	simultaneous.sol_seconds = 1
	simultaneous.target_sols = 1
	simultaneous.initial.air = 0
	simultaneous.health_loss_per_missing_unit = 100
	sim = _new(simultaneous)
	sim.start_run()
	sim.advance(1)
	_check(sim.get_snapshot().result.verdict == "total_defeat", "muerte prevalece sobre relevo simultáneo")
	var fatal := empty.duplicate(true)
	fatal.buildings.solar.build_seconds = 0
	sim = _new(fatal)
	sim.place_building("solar", Vector2i.ZERO)
	_near(sim.get_snapshot().power.supply, 6, "bonus antes de morir")
	sim.start_run()
	sim.advance(300)
	_near(sim.get_snapshot().power.supply, 5, "muerte retira bonus del ingeniero")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _near(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.000001, "%s: esperado %.6f, observado %.6f" % [label, expected, actual])
