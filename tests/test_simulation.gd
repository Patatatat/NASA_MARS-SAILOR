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
	_test_events(data)
	_test_roberts(data)
	_test_radiation(data)
	_test_robert_reuse(data)
	_test_upgrades(data)
	_test_maintenance(data)
	_test_reports(data)
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
		for second: int in range(300):
			baseline.advance(1)
			for building: Dictionary in baseline.get_snapshot().buildings:
				if building.maintenance.state in ["requested", "degraded"]:
					var maintenance: Dictionary = baseline.begin_maintenance(building.id)
					if maintenance.ok:
						baseline.apply_maintenance_result(maintenance.result.id, true, 1.0)
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

func _safe_data(data: Dictionary) -> Dictionary:
	var safe := data.duplicate(true)
	safe.initial.air = 1000
	safe.initial.water = 1000
	safe.initial.food = 1000
	safe.initial.mass = 1000
	safe.events.storm.probability = 0
	safe.events.solar_particles.probability = 0
	return safe

func _test_events(data: Dictionary) -> void:
	var rules := _safe_data(data)
	rules.events.storm.probability = 1
	rules.events.solar_particles.probability = 1
	var sim := _new(rules)
	_check(sim.get_forecast().storm.probability == 1, "pronóstico usa probabilidad configurada")
	sim.place_building("solar", Vector2i.ZERO)
	sim.place_building("reactor", Vector2i(5, 5))
	sim.start_run()
	sim.advance(54)
	_check(sim.get_snapshot().event.is_empty(), "no aviso antes de tiempo")
	sim.advance(1)
	_check(sim.get_snapshot().event.state == "warning", "aviso tormenta a 55")
	_near(sim.get_snapshot().power.supply, 22.8, "aviso no altera potencia: 6 + 16.8")
	sim.advance(20)
	_near(sim.get_snapshot().power.supply, 18.3, "tormenta afecta solo solar: 1.5 + 16.8")
	sim.set_paused(true)
	var before: Dictionary = sim.get_snapshot()
	sim.advance(500)
	_check(sim.get_snapshot() == before, "pausa congela evento y dosis")
	sim.set_paused(false)
	sim.advance(50)
	_check(sim.get_snapshot().event.is_empty(), "tormenta termina en 125")
	_near(sim.get_snapshot().power.supply, 22.8, "potencia restaurada")
	_near(sim.get_snapshot().metrics.solar_output_lost_power_seconds, 225, "pérdida solar medida: 50×4.5")
	sim.advance(50)
	_check(sim.get_snapshot().event.kind == "solar_particles" and sim.get_snapshot().event.state == "active", "partículas activas en 175")
	sim.advance(25)
	_check(sim.get_snapshot().event.is_empty(), "partículas terminan en 200")
	var a := _new(rules)
	var b := _new(rules)
	a.start_run()
	b.start_run()
	a.advance(220)
	for i: int in range(2200):
		b.advance(0.1)
	_check(a.get_snapshot() == b.get_snapshot(), "eventos y dosis independientes de frames")
	var zero := _new(_safe_data(data))
	zero.start_run()
	zero.advance(220)
	var active_count := 0
	for entry: Dictionary in zero.get_snapshot().log:
		if entry.reason == "event_active":
			active_count += 1
	_check(active_count == 0, "probabilidad cero nunca activa")
	for invalid: Variant in [-0.1, 1.1, "0.5", true, NAN]:
		var bad := rules.duplicate(true)
		bad.events.storm.probability = invalid
		_check(not Config.validate(bad).ok, "valida probabilidad externa")
	var overlap := rules.duplicate(true)
	overlap.events.solar_particles.start_seconds = 100
	_check(not Config.validate(overlap).ok, "rechaza eventos/avisos solapados")
	for path: String in ["radiation", "roberts"]:
		var bad := rules.duplicate(true)
		bad[path] = []
		_check(not Config.validate(bad).ok, "rechaza sección inválida " + path)
	var invalid_destination := rules.duplicate(true)
	invalid_destination.roberts.destinations.ice.resource = "food"
	_check(not Config.validate(invalid_destination).ok, "no permite carga de recurso incorrecto")

func _mission_sim(rules: Dictionary) -> RefCounted:
	var sim := _new(rules)
	sim.place_building("reactor", Vector2i.ZERO)
	sim.place_building("laboratory", Vector2i(1, 0))
	sim.start_run()
	sim.advance(10)
	return sim

func _test_roberts(data: Dictionary) -> void:
	var rules := _safe_data(data)
	for destination: Dictionary in rules.roberts.destinations.values():
		destination.loss_probability = 0
	var sim := _new(rules)
	_check(not sim.send_robert("robert_1", "ice").ok, "no sale en planificación")
	sim.start_run()
	var before: Dictionary = sim.get_snapshot()
	_check(not sim.send_robert("robert_1", "ice").ok, "no sale sin laboratorio")
	_check(sim.get_snapshot() == before, "salida inválida no muta")
	sim = _mission_sim(rules)
	before = sim.get_snapshot()
	_check(not sim.send_robert("unknown", "ice").ok and not sim.send_robert("robert_1", "unknown").ok, "valida IDs de misión")
	_check(sim.get_snapshot() == before, "IDs inválidos no mutan")
	_check(sim.preview_robert("robert_1", "ice").result.duration_seconds == 50, "dos soles = 50 s")
	_check(sim.get_snapshot() == before, "vista previa no consume")
	_check(sim.send_robert("robert_1", "ice").ok, "sale robot uno")
	before = sim.get_snapshot()
	_check(not sim.send_robert("robert_1", "ice").ok, "robot ocupado rechazado")
	_check(sim.get_snapshot() == before, "no duplica misión")
	_check(sim.send_robert("robert_2", "quarry").ok, "sale robot dos")
	_near(sim.get_snapshot().power.demand, 7, "demanda: hábitat 1 + laboratorio 2 + dos robots 4")
	sim.set_enabled("b2", false)
	sim.advance(49)
	_check(sim.get_snapshot().roberts[0].state == "on_mission", "no entrega antes del límite aun sin energía")
	sim.advance(1)
	_near(sim.get_snapshot().resources.water, 1025.8, "agua: 1000 - 60×0.32 + 45")
	_near(sim.get_snapshot().resources.regolith, 25, "entrega cantera")
	_check(sim.get_snapshot().roberts[0].state == "available", "retorno habilita robot")
	sim.advance(1)
	_near(sim.get_snapshot().resources.water, 1025.48, "no repite carga")
	_check(not sim.send_robert("robert_1", "ice").ok, "revalida laboratorio sin energía")
	sim.reset_run(CREW, 123)
	_check(sim.get_snapshot().roberts[0].state == "available" and sim.get_snapshot().mission_count == 0, "reinicio limpia misiones")
	var storm := rules.duplicate(true)
	storm.events.storm.probability = 1
	storm.roberts.storm_loss_probability = 1
	sim = _mission_sim(storm)
	sim.advance(40)
	sim.send_robert("robert_1", "ice")
	sim.advance(50)
	_check(sim.get_snapshot().roberts[0].state == "lost", "tormenta riesgo 1 pierde robot")
	_near(sim.get_snapshot().resources.water, 968, "robot perdido no entrega: 1000 - 100×0.32")
	_check(not sim.send_robert("robert_1", "ice").ok, "no reutiliza perdido")
	var geo := _mission_sim(rules)
	geo.reset_run(["geologist", "medic", "engineer", "technician"], 123)
	geo.place_building("reactor", Vector2i.ZERO)
	geo.place_building("laboratory", Vector2i(1, 0))
	geo.start_run()
	geo.advance(10)
	_near(geo.preview_robert("robert_1", "ice").result.amount, 56.25, "geólogo: 45×1.25")
	geo.send_robert("robert_1", "ice")
	geo.advance(50)
	_near(geo.get_snapshot().resources.water, 1037.05, "carga con bonus real: 1000 - 19.2 + 56.25")
	var low := rules.duplicate(true)
	low.buildings.reactor.power_supply = 3
	sim = _mission_sim(low)
	before = sim.get_snapshot()
	_check(not sim.send_robert("robert_1", "ice").ok, "no sale sin potencia sobrante")
	_check(sim.get_snapshot() == before, "potencia insuficiente no muta")
	var a := _mission_sim(storm)
	var b := _mission_sim(storm)
	for subject: RefCounted in [a, b]:
		subject.send_robert("robert_1", "wreckage")
		subject.send_robert("robert_2", "ice")
	a.advance(200)
	for i: int in range(2000):
		b.advance(0.1)
	_check(a.get_snapshot() == b.get_snapshot(), "misiones y sorteo reproducibles por frames")
	# Probabilidades intermedias reales: misma semilla, acciones y resultados.
	var random_rules := _safe_data(data)
	random_rules.events.storm.probability = 0.6
	random_rules.events.solar_particles.probability = 0.5
	a = _mission_sim(random_rules)
	b = _mission_sim(random_rules)
	for subject: RefCounted in [a, b]:
		subject.send_robert("robert_1", "wreckage")
		subject.send_robert("robert_2", "ice")
	a.advance(200)
	for i: int in range(800):
		b.advance(0.25)
	_check(a.get_snapshot() == b.get_snapshot(), "semilla fija con probabilidades intermedias")
	var final_rules := rules.duplicate(true)
	final_rules.target_sols = 3
	sim = _mission_sim(final_rules)
	sim.advance(15)
	sim.send_robert("robert_1", "wreckage")
	sim.set_paused(true)
	before = sim.get_snapshot()
	sim.advance(100)
	_check(sim.get_snapshot() == before, "pausa congela misión")
	sim.set_paused(false)
	sim.advance(50)
	_check(sim.get_snapshot().phase == "finished", "relevo coincide con retorno")
	_near(sim.get_snapshot().resources.mass, 955, "retorno se aplica antes de final: 1000-45-20+20")
	before = sim.get_snapshot()
	sim.advance(100)
	_check(sim.get_snapshot() == before, "final no reentrega misión")

func _test_radiation(data: Dictionary) -> void:
	var rules := _safe_data(data)
	var sim := _new(rules)
	sim.start_run()
	sim.advance(25)
	_near(sim.get_snapshot().crew[0].dose, 0.75, "médico reduce dosis futura")
	sim.set_sheltered(true)
	sim.place_building("solar", Vector2i.ZERO)
	sim.advance(25)
	_near(sim.get_snapshot().crew[0].dose, 0.9375, "refugio acumula: .75 + .75×.25")
	_check(sim.get_snapshot().buildings[1].remaining_seconds == 5, "refugio detiene obras")
	sim.set_sheltered(false)
	sim.advance(5)
	_check(sim.get_snapshot().buildings[1].remaining_seconds == 0, "salir reanuda obras")
	var before: Dictionary = sim.get_snapshot()
	_check(not sim.bury_habitat().ok and sim.get_snapshot() == before, "enterrar sin regolito no cobra")
	rules.initial.regolith = 20
	sim = _new(rules)
	sim.start_run()
	_check(sim.bury_habitat().ok, "enterramiento paga y comienza")
	before = sim.get_snapshot()
	_check(not sim.bury_habitat().ok and sim.get_snapshot() == before, "enterrar dos veces no cobra")
	sim.advance(25)
	_near(sim.get_snapshot().crew[0].dose, 0.75, "obra sin protección prematura")
	sim.advance(25)
	_near(sim.get_snapshot().crew[0].dose, 1.05, "enterrado: .75 + .75×.4")
	_near(sim.get_snapshot().resources.mass, 990, "enterrar cobra masa una vez")
	_near(sim.get_snapshot().resources.regolith, 0, "enterrar cobra regolito")
	rules.events.solar_particles.probability = 1
	sim = _new(rules)
	sim.reset_run(["engineer", "scientist", "geologist", "technician"])
	sim.start_run()
	sim.advance(200)
	_near(sim.get_snapshot().crew[0].dose, 43, "dosis ambiental 8 + partículas 35")
	_near(sim.get_snapshot().crew[0].health, 94, "solo dosis nueva sobre 40 daña: 3×2")

func _test_robert_reuse(data: Dictionary) -> void:
	var rules := _safe_data(data)
	for destination: Dictionary in rules.roberts.destinations.values():
		destination.loss_probability = 0
	var sim := _mission_sim(rules)
	for mission: int in range(3):
		var sent: Dictionary = sim.send_robert("robert_1", "quarry")
		_check(sent.ok, "ROBERT reutilizable, salida %d" % (mission + 1))
		_check(sent.result.get("mission_id") == "m%d" % (mission + 1), "ID nuevo en reutilización")
		sim.advance(50)
		_check(sim.get_snapshot().roberts[0].state == "available", "robot disponible después de carga")
	_near(sim.get_snapshot().resources.regolith, 75, "tres viajes entregan 25 cada uno")
	# Reproduce el bloqueo legítimo: el laboratorio pierde potencia en tormenta.
	rules.events.storm.probability = 1
	sim = _new(rules)
	sim.place_building("solar", Vector2i.ZERO)
	sim.place_building("laboratory", Vector2i(1, 0))
	sim.start_run()
	sim.advance(10)
	_check(sim.send_robert("robert_1", "quarry").ok, "sale con laboratorio solar")
	sim.advance(50)
	_check(sim.preview_robert("robert_1", "quarry").ok, "puede salir otra vez al regresar en 60s")
	sim.advance(15)
	_check(sim.get_snapshot().roberts[0].state == "available", "sigue disponible en tormenta")
	_check(sim.send_robert("robert_1", "quarry").error_code == "laboratory_not_operational", "bloqueo explica laboratorio sin potencia")
	sim.advance(50)
	_check(sim.send_robert("robert_1", "quarry").ok, "puede salir al recuperarse laboratorio")

func _test_upgrades(data: Dictionary) -> void:
	var rules := _safe_data(data)
	for bad_value: Variant in [0, -1, 1.1, "0.75", NAN, true]:
		var bad := rules.duplicate(true)
		bad.scientist_upgrade_duration_multiplier = bad_value
		_check(not Config.validate(bad).ok, "valida multiplicador de científico")
	for field: String in ["mass", "duration_seconds", "power_supply", "water_per_sol"]:
		var bad := rules.duplicate(true)
		bad.upgrades.greenhouse.erase(field)
		_check(not Config.validate(bad).ok, "valida campo de mejora " + field)
	var sim := _new(rules)
	var before: Dictionary = sim.get_snapshot()
	_check(not sim.start_upgrade("b1").ok and sim.get_snapshot() == before, "no mejora en planificación")
	sim.place_building("solar", Vector2i.ZERO)
	sim.start_run()
	before = sim.get_snapshot()
	_check(sim.start_upgrade("b2").error_code == "building_under_construction", "no mejora obra incompleta")
	_check(sim.start_upgrade("b1").error_code == "upgrade_not_supported", "hábitat sin nivel 2")
	_check(sim.start_upgrade("unknown").error_code == "unknown_building", "ID mejora inválido")
	_check(sim.get_snapshot() == before, "rechazos de mejora atómicos")
	sim.advance(5)
	before = sim.get_snapshot()
	var preview: Dictionary = sim.preview_upgrade("b2")
	_check(preview.ok and preview.cost.mass == 10 and preview.result.duration_seconds == 20, "vista previa solar: 10 masa / 20 s")
	_check(sim.get_snapshot() == before, "vista previa mejora no muta")
	_check(sim.start_upgrade("b2").ok, "inicia mejora solar")
	_near(sim.get_snapshot().resources.mass, 975, "cobra 15 construcción + 10 mejora")
	before = sim.get_snapshot()
	_check(sim.start_upgrade("b2").error_code == "upgrade_in_progress", "no repite mejora en curso")
	_check(sim.get_snapshot() == before, "mejora repetida no cobra")
	sim.advance(19)
	_check(sim.get_snapshot().buildings[1].level == 1, "nivel 1 hasta último segundo")
	_near(sim.get_snapshot().power.supply, 6, "produce nivel 1 durante mejora")
	sim.set_paused(true)
	before = sim.get_snapshot()
	sim.advance(100)
	_check(sim.get_snapshot() == before, "pausa congela mejora")
	sim.set_paused(false)
	sim.set_sheltered(true)
	sim.advance(5)
	_near(sim.get_snapshot().buildings[1].upgrade_remaining_work, 1, "refugio congela mejora")
	sim.set_sheltered(false)
	sim.advance(1)
	_check(sim.get_snapshot().buildings[1].level == 2, "finaliza exactamente una vez")
	_near(sim.get_snapshot().power.supply, 9.6, "solar nivel 2: 8×1.2")
	before = sim.get_snapshot()
	_check(sim.start_upgrade("b2").error_code == "max_level" and sim.get_snapshot() == before, "nivel máximo no cobra")
	var poor := rules.duplicate(true)
	poor.initial.mass = 15
	var other := _new(poor)
	other.place_building("solar", Vector2i.ZERO)
	other.start_run()
	other.advance(5)
	before = other.get_snapshot()
	_check(other.start_upgrade("b2").error_code == "insufficient_mass" and other.get_snapshot() == before, "mejora sin masa conserva estado")
	# Las cinco definiciones de nivel 2 se consumen realmente por la economía.
	for kind: String in ["reactor", "oxygen_generator", "greenhouse", "laboratory"]:
		other = _new(rules)
		other.place_building("solar", Vector2i.ZERO)
		other.place_building("reactor", Vector2i(5, 5))
		other.place_building(kind, Vector2i(1, 0))
		other.start_run()
		other.advance(10)
		_check(other.start_upgrade("b4").ok, "mejora " + kind)
		other.advance(float(rules.upgrades[kind].duration_seconds))
		_check(other.get_snapshot().buildings[3].level == 2, "nivel 2 aplicado " + kind)
		before = other.get_snapshot()
		other.advance(1)
		var after: Dictionary = other.get_snapshot()
		match kind:
			"reactor":
				_near(after.power.supply, 46.8, "reactor N2: 6 +16.8 +24")
			"oxygen_generator":
				_near(after.resources.air - before.resources.air, 0.4, "oxígeno N2: 18/25 - .32")
				_near(after.power.demand, 5, "demanda oxígeno N2: 1 +5×.8")
			"greenhouse":
				_near(after.resources.food - before.resources.food, 0.43, "comida N2: 15×1.25/25 -.32")
				_near(after.resources.water - before.resources.water, -0.56, "riego N2: -6/25 -.32")
			"laboratory":
				_near(after.power.demand, 2, "laboratorio N2 ahorra: 1 +1")
	# Científico dinámico: acelerar el trabajo, sin apilar multiplicadores.
	var crew := ["engineer", "scientist", "medic", "technician"]
	var a := _new(rules)
	a.reset_run(crew)
	a.place_building("solar", Vector2i.ZERO)
	a.start_run()
	a.advance(5)
	_check(a.preview_upgrade("b2").result.duration_seconds == 15, "científico reduce 20 s a 15")
	a.start_upgrade("b2")
	a.advance(14)
	_check(a.get_snapshot().buildings[1].level == 1, "científico no completa antes de 15")
	a.advance(1)
	_check(a.get_snapshot().buildings[1].level == 2, "científico completa en 15")
	_near(a.get_snapshot().metrics.scientist_extra_upgrade_work, 5, "aporte medido: 5 unidades extra de trabajo")
	a.reset_run(crew)
	_check(a.get_snapshot().buildings.size() == 1 and a.get_snapshot().metrics.scientist_extra_upgrade_work == 0, "reinicio limpia mejoras y aportes")
	# Estado sintético de salud previa para aislar muerte de un único especialista.
	var lethal := rules.duplicate(true)
	lethal.radiation.damage_threshold = 0
	lethal.radiation.health_loss_per_dose = 10
	a = _new(lethal)
	a.reset_run(crew)
	a.place_building("solar", Vector2i.ZERO)
	a.start_run()
	a.advance(5)
	a.start_upgrade("b2")
	a.advance(3)
	_near(a.get_snapshot().buildings[1].upgrade_remaining_work, 16, "3 s científico avanzan 4 de trabajo")
	a._state.crew[1].health = 0.1
	a.advance(1)
	_check(not a.get_snapshot().crew[1].alive, "muere científico en paso de radiación")
	_near(a.get_snapshot().buildings[1].upgrade_remaining_work, 15, "pierde bonus en mismo paso sin reiniciar progreso")
	a.advance(15)
	_check(a.get_snapshot().buildings[1].level == 2, "completa con velocidad normal tras muerte")
	a = _new(rules)
	var b := _new(rules)
	for subject: RefCounted in [a, b]:
		subject.reset_run(crew)
		subject.place_building("solar", Vector2i.ZERO)
		subject.start_run()
		subject.advance(5)
		subject.start_upgrade("b2")
	a.advance(30)
	for i: int in range(300):
		b.advance(0.1)
	_check(a.get_snapshot() == b.get_snapshot(), "mejoras independientes de frames")
	var boundary := rules.duplicate(true)
	boundary.target_sols = 1
	a = _new(boundary)
	a.place_building("solar", Vector2i.ZERO)
	a.start_run()
	a.advance(5)
	a.start_upgrade("b2")
	a.set_enabled("b2", false)
	a.advance(20)
	_check(a.get_snapshot().buildings[1].level == 2, "mejora termina aun apagada y coincide con relevo")
	_check(not a.get_snapshot().buildings[1].powered, "mejorar no enciende edificio apagado")
	var completion_count := 0
	for entry: Dictionary in a.get_snapshot().log:
		if entry.reason == "upgrade_completed":
			completion_count += 1
	_check(completion_count == 1, "finalización de mejora registrada una vez")
	before = a.get_snapshot()
	_check(a.start_upgrade("b2").error_code == "invalid_phase" and a.get_snapshot() == before, "no mejora después del final")

func _test_maintenance(data: Dictionary) -> void:
	var rules := _safe_data(data)
	for field: String in ["max_pending", "max_attempts", "session_max_real_seconds"]:
		var bad := rules.duplicate(true)
		bad.maintenance[field] = 99
		_check(not Config.validate(bad).ok, "límites mantenimiento " + field)
	var bad := rules.duplicate(true)
	bad.maintenance.degraded_multiplier = -1
	_check(not Config.validate(bad).ok, "multiplicador mantenimiento inválido")
	var sim := _mission_sim(rules)
	sim.advance(99)
	_check(sim.get_snapshot().buildings[1].maintenance.state == "healthy", "no pide antes de 110")
	sim.advance(1)
	_check(sim.get_snapshot().buildings[1].maintenance.state == "requested", "avisa tras cuatro soles desde obra")
	var first: Dictionary = sim.begin_maintenance("b2")
	_check(first.ok and first.result.robot_support, "sesión tiene apoyo ROBERT disponible")
	_near(first.result.difficulty_multiplier, 0.8, "apoyo configurable de robots")
	var before: Dictionary = sim.get_snapshot()
	_check(not sim.begin_maintenance("b2").ok and sim.get_snapshot() == before, "no abre sesión duplicada")
	_check(not sim.apply_maintenance_result(first.result.id, true, NAN).ok and sim.get_snapshot() == before, "rechaza tiempo inválido sin mutar")
	_check(sim.apply_maintenance_result(first.result.id, false, 2).ok, "fallo consume primer intento")
	var retry: Dictionary = sim.begin_maintenance("b2")
	_check(retry.ok and retry.result.id != first.result.id, "un reintento con token nuevo")
	before = sim.get_snapshot()
	_check(not sim.apply_maintenance_result(first.result.id, true, 2).ok and sim.get_snapshot() == before, "callback del primer intento no afecta al segundo")
	_check(sim.apply_maintenance_result(retry.result.id, true, 3).ok, "éxito del reintento")
	_check(sim.get_snapshot().buildings[1].maintenance.state == "healthy", "éxito restaura estado")
	before = sim.get_snapshot()
	_check(not sim.apply_maintenance_result(retry.result.id, true, 3).ok and sim.get_snapshot() == before, "resultado aplicado una sola vez")
	sim = _mission_sim(rules)
	sim.advance(125)
	_near(sim.get_snapshot().power.supply, 11.76, "degradado a 135: 14×1.2×.7")
	sim.advance(25)
	_check(sim.get_snapshot().buildings[1].maintenance.state == "shutdown", "apagado a 160")
	_near(sim.get_snapshot().power.supply, 0, "apagado sin suministro")
	before = sim.get_snapshot()
	_check(sim.reactivate_building("b2").error_code == "maintenance_cooling_down" and sim.get_snapshot() == before, "no reactiva antes del enfriamiento")
	sim.advance(50)
	_check(sim.reactivate_building("b2").ok, "reactiva a 210")
	_near(sim.get_snapshot().resources.mass, 930, "1000 -45 -20 -5")
	_near(sim.get_snapshot().power.supply, 16.8, "reactivado vuelve al rendimiento normal")
	before = sim.get_snapshot()
	_check(not sim.reactivate_building("b2").ok and sim.get_snapshot() == before, "no cobra reactivación dos veces")
	var poor := rules.duplicate(true)
	poor.initial.mass = 65
	sim = _mission_sim(poor)
	sim.advance(200)
	before = sim.get_snapshot()
	_check(sim.reactivate_building("b2").error_code == "insufficient_mass" and sim.get_snapshot() == before, "reactivación sin masa no muta")
	sim = _mission_sim(rules)
	sim.advance(100)
	first = sim.begin_maintenance("b2")
	sim.set_paused(true)
	before = sim.get_snapshot()
	sim.advance(100)
	_check(sim.get_snapshot() == before, "pausa congela sesión")
	sim.set_paused(false)
	sim.set_speed(4)
	sim.advance(14)
	_check(sim.get_snapshot().buildings[1].maintenance.session.state == "active", "14 s reales a x4 no agotan sesión")
	sim.advance(1)
	_check(sim.get_snapshot().buildings[1].maintenance.session.state == "timeout", "15 s reales agotan sesión a x4")
	_check(not sim.apply_maintenance_result(first.result.id, true, 15).ok, "éxito tardío no restaura")
	# Atender el aviso congela su edad; el reloj global continúa.
	var crisis := rules.duplicate(true)
	crisis.events.storm.probability = 1
	crisis.events.storm.start_seconds = 140
	crisis.events.storm.duration_seconds = 10
	sim = _mission_sim(crisis)
	sim.advance(100)
	first = sim.begin_maintenance("b2")
	sim.advance(10)
	_check(sim.get_snapshot().buildings[1].maintenance.session.state == "suspended", "aviso de crisis suspende sesión")
	before = sim.get_snapshot()
	_check(sim.apply_maintenance_result(first.result.id, true, 10).error_code == "maintenance_suspended" and sim.get_snapshot() == before, "interrupción no consume resultado")
	sim.advance(30)
	_check(sim.get_snapshot().buildings[1].maintenance.session.state == "active", "fin de crisis reanuda sesión")
	_check(sim.apply_maintenance_result(first.result.id, true, 10).ok, "sesión interrumpida conserva derecho a éxito")
	var stale_id: String = first.result.id
	sim.reset_run(CREW, 123)
	sim.place_building("reactor", Vector2i.ZERO)
	sim.start_run()
	sim.advance(110)
	var next_run: Dictionary = sim.begin_maintenance("b2")
	_check(next_run.ok and next_run.result.id != stale_id, "reinicio cambia namespace de sesiones")
	before = sim.get_snapshot()
	_check(not sim.apply_maintenance_result(stale_id, true, 1).ok and sim.get_snapshot() == before, "callback de partida anterior rechazado")
	var a := _mission_sim(rules)
	var b := _mission_sim(rules)
	a.advance(220)
	for i: int in range(2200):
		b.advance(0.1)
	_check(a.get_snapshot() == b.get_snapshot(), "mantenimiento e informes independientes de frames")
	sim = _mission_sim(rules)
	sim.advance(90)
	sim.send_robert("robert_1", "ice")
	sim.send_robert("robert_2", "ice")
	sim.advance(10)
	first = sim.begin_maintenance("b2")
	_check(first.ok and not first.result.robot_support, "sin robots disponibles no hay apoyo")
	_near(first.result.difficulty_multiplier, 1, "dificultad normal cuando ambos están fuera")
	_check(sim.apply_maintenance_result(first.result.id, false, 1, true).ok, "abandono cierra intento sin bloquear partida")
	retry = sim.begin_maintenance("b2")
	_check(sim.apply_maintenance_result(retry.result.id, false, 2).ok, "segundo fallo válido")
	before = sim.get_snapshot()
	_check(sim.begin_maintenance("b2").error_code == "maintenance_attempts_exhausted" and sim.get_snapshot() == before, "no permite tercer intento")
	var pending_rules := rules.duplicate(true)
	pending_rules.maintenance.global_gap_seconds = 5
	sim = _new(pending_rules)
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(5, 0), Vector2i(0, 5), Vector2i(5, 5)]:
		sim.place_building("reactor", cell)
	sim.start_run()
	sim.advance(115)
	var pending_count := 0
	var notice_times: Array[int] = []
	for building: Dictionary in sim.get_snapshot().buildings:
		if building.maintenance.state == "requested":
			pending_count += 1
	for entry: Dictionary in sim.get_snapshot().log:
		if entry.reason == "maintenance_requested":
			notice_times.append(entry.seconds)
	_check(pending_count == 2 and notice_times == [110, 115], "máximo dos avisos y separación global")
	var oxygen := _new(rules)
	oxygen.place_building("reactor", Vector2i.ZERO)
	oxygen.place_building("oxygen_generator", Vector2i(1, 0))
	oxygen.start_run()
	oxygen.advance(130)
	before = oxygen.get_snapshot()
	oxygen.advance(1)
	_near(oxygen.get_snapshot().resources.air - before.resources.air, 0.016, "oxígeno degradado: 12×.7/25 -8/25")
	a = _mission_sim(rules)
	b = _mission_sim(rules)
	for subject: RefCounted in [a, b]:
		subject.advance(100)
		subject.begin_maintenance("b2")
		subject.set_speed(0.5)
	a.advance(14.9)
	for i: int in range(149):
		b.advance(0.1)
	_check(a.get_snapshot() == b.get_snapshot(), "sesión real a x0.5 independiente de frames")
	_check(a.get_snapshot().buildings[1].maintenance.session.state == "active", "no vence a 14.9 segundos reales")
	a.advance(0.1)
	_check(a.get_snapshot().buildings[1].maintenance.session.state == "timeout", "vence a 15 reales sin esperar segundo simulado completo")

func _test_reports(data: Dictionary) -> void:
	var rules := _safe_data(data)
	rules.roberts.destinations.ice.loss_probability = 0
	var sim := _new(rules)
	sim.start_run()
	sim.advance(25)
	var report: Dictionary = sim.get_snapshot().sol_reports[0]
	_near(report.consumption.air, 8, "informe consumo aire medido")
	_near(report.delta.water, -8, "informe variación agua")
	_check(report.sol == 1 and not report.partial, "informe sol completo")
	for id: String in report.fact_ids:
		var found := false
		for entry: Dictionary in sim.get_snapshot().log:
			if entry.id == id:
				found = true
		_check(found, "hecho del informe tiene registro real")
	sim = _mission_sim(rules)
	var status: Dictionary = sim.get_building_status("b2")
	_check(status.ok and status.result.local_log.size() == 2, "inspector incluye pago y fin de obra")
	status.result.maintenance.state = "shutdown"
	status.result.local_log[0].reason = "modified"
	_check(sim.get_building_status("b2").result.maintenance.state == "healthy", "inspector aislado del dominio")
	_check(not sim.get_building_status("unknown").ok, "inspector rechaza ID inválido")
	sim.send_robert("robert_1", "ice")
	sim.advance(65)
	_near(sim.get_snapshot().sol_reports[2].delta.water, 37, "sol con carga: 45 importado - 8 consumo")
	for resource: String in ["air", "water", "food"]:
		for sol_report: Dictionary in sim.get_snapshot().sol_reports:
			var measured := float(sol_report.production.get(resource, 0)) + float(sol_report.imports.get(resource, 0)) - float(sol_report.consumption.get(resource, 0))
			_near(sol_report.delta[resource], measured, "contabilidad del informe " + resource)
	var dry := rules.duplicate(true)
	dry.initial.water = 0
	sim = _new(dry)
	sim.place_building("reactor", Vector2i.ZERO)
	sim.place_building("greenhouse", Vector2i(1, 0))
	sim.start_run()
	sim.advance(25)
	report = sim.get_snapshot().sol_reports[0]
	_near(report.deficits.water, 8, "informe conserva faltantes previos al clamp")
	_check(report.blocked_seconds.b3.water_shortage == 15, "causa medida: invernadero sin agua 15 segundos")
	var empty := rules.duplicate(true)
	empty.initial.air = 0
	empty.initial.water = 0
	empty.initial.food = 0
	sim = _new(empty)
	sim.start_run()
	sim.advance(300)
	_check(sim.get_snapshot().sol_reports[-1].partial, "derrota anticipada conserva informe parcial")
	var count: int = sim.get_snapshot().sol_reports.size()
	sim.advance(100)
	_check(sim.get_snapshot().sol_reports.size() == count, "informe final único")
