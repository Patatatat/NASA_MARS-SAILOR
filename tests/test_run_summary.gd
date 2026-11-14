extends SceneTree

const Simulation = preload("res://domain/simulation.gd")
const Config = preload("res://domain/simulation_config.gd")
const CREW := ["engineer", "medic", "botanist", "technician"]
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var loaded := Config.load_file()
	_check(loaded.ok, "configuración válida")
	if not loaded.ok:
		quit(1)
		return
	var data: Dictionary = loaded.data
	_test_contract(data)
	_test_sustainability(data)
	_test_resilience(data)
	_test_early_defeat(data)
	_test_frames(data)
	print("RUN_SUMMARY_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _rules(data: Dictionary) -> Dictionary:
	var rules := data.duplicate(true)
	for resource: String in ["air", "water", "food", "mass"]:
		rules.initial[resource] = 1000
	rules.events.storm.probability = 0
	rules.events.solar_particles.probability = 0
	rules.maintenance.interval_sols = 100
	return rules

func _new(rules: Dictionary) -> RefCounted:
	var sim := Simulation.new()
	_check(sim.configure(rules).ok, "configurar resumen")
	_check(sim.reset_run(CREW, 123).ok, "reiniciar resumen")
	return sim

func _test_contract(data: Dictionary) -> void:
	var empty := Simulation.new()
	_check(empty.get_run_summary().error_code == "not_initialized", "sin partida no hay resumen")
	var rules := _rules(data)
	rules.sol_seconds = 5
	rules.target_sols = 1
	var sim := _new(rules)
	_check(sim.get_run_summary().error_code == "not_finished", "planificación no tiene resumen final")
	sim.start_run()
	sim.advance(4)
	_check(sim.get_run_summary().error_code == "not_finished", "simulación en curso no tiene resumen final")
	var received: Array = []
	sim.run_finished.connect(func(_result: Dictionary) -> void: received.append(sim.get_run_summary()), CONNECT_ONE_SHOT)
	sim.advance(1)
	_check(received.size() == 1 and received[0].ok, "resumen disponible durante run_finished")
	var summary: Dictionary = sim.get_run_summary().result
	_check(summary.schema_version == 1 and summary.verdict == "partial_defeat", "resumen conserva veredicto")
	_near(summary.components.survival, 1, "supervivencia 5 / 5")
	_near(summary.components.crew, 1, "salud de cuatro plazas 400 / 400")
	_near(summary.components.resilience, 0.5, "neutral sin oportunidades")
	_check(summary.resilience.neutral_used and summary.resilience.total == 0, "neutral explícito")
	_check(summary.sustainability.window_seconds == 5 and summary.sustainability.requested_window_seconds == 10, "partida corta usa solo tiempo disponible")
	_near(summary.sustainability.resources.air.net_per_sol, -8, "tendencia por sol independiente de duración")
	_near(summary.components.sustainability, 0, "acumular stock sin reponer no obtiene sostenibilidad")
	_check(summary.timeline.size() == 1, "cronología sin informe duplicado en límite de sol")
	var before := summary.duplicate(true)
	summary.crew.members[0].health = -999
	summary.timeline[0].closing.air = -999
	summary.facts[0].reason = "modified"
	_check(sim.get_run_summary().result == before, "resumen devuelve copia profunda")
	sim.advance(100)
	_check(sim.get_run_summary().result == before and received.size() == 1, "resumen final congelado y señal única")
	sim.reset_run(CREW, 123)
	_check(sim.get_run_summary().error_code == "not_finished" and sim.get_snapshot().run_summary.is_empty(), "reinicio borra resumen anterior")
	for field: String in ["resilience_neutral", "critical_reserve_sols"]:
		var invalid := rules.duplicate(true)
		invalid.summary[field] = 1.5
		_check(not Config.validate(invalid).ok, "valida rango resumen " + field)
	for invalid_value: Variant in [0, "2", true, NAN]:
		var invalid := rules.duplicate(true)
		invalid.summary.window_sols = invalid_value
		_check(not Config.validate(invalid).ok, "valida ventana de resumen")
	var invalid := rules.duplicate(true)
	invalid.summary.max_causes = 5
	_check(not Config.validate(invalid).ok, "valida máximo de causas")

func _test_sustainability(data: Dictionary) -> void:
	var rules := _rules(data)
	rules.target_sols = 3
	for kind: String in ["solar", "oxygen_generator", "greenhouse"]:
		rules.buildings[kind].build_seconds = 0
	rules.buildings.solar.power_supply = 100
	rules.buildings.oxygen_generator.air_per_sol = 8
	rules.buildings.greenhouse.air_per_sol = 0
	rules.buildings.greenhouse.food_per_sol = 6.4
	rules.buildings.greenhouse.water_per_sol = 0
	var sim := _new(rules)
	sim.place_building("solar", Vector2i(1, 1))
	sim.place_building("oxygen_generator", Vector2i(4, 1))
	sim.place_building("greenhouse", Vector2i(7, 1))
	sim.start_run()
	sim.advance(75)
	var summary: Dictionary = sim.get_run_summary().result
	_check(summary.verdict == "relief_achieved", "resumen de relevo logrado")
	_check(summary.sustainability.start_seconds == 25 and summary.sustainability.end_seconds == 75, "ventana exacta de dos soles finales")
	_near(summary.sustainability.resources.air.net_per_sol, 0, "aire estable con producción 8 y consumo 8")
	_near(summary.sustainability.resources.food.net_per_sol, 0, "comida estable: 6.4×1.25 = 8")
	_near(summary.sustainability.resources.water.delta, -16, "agua baja 8 por sol durante dos soles")
	_near(summary.components.sustainability, 2.0 / 3.0, "dos recursos sostenibles de tres")
	var no_consumption := _rules(data)
	no_consumption.target_sols = 1
	for resource: String in ["air", "water", "food"]:
		no_consumption.consumption_per_crew_per_sol[resource] = 0
	sim = _new(no_consumption)
	sim.start_run()
	sim.advance(25)
	_near(sim.get_run_summary().result.components.sustainability, 1, "consumo cero sin división por cero")

func _test_resilience(data: Dictionary) -> void:
	var rules := _rules(data)
	rules.target_sols = 3
	rules.events.warning_seconds = 5
	rules.events.storm.probability = 1
	rules.events.storm.start_seconds = 25
	rules.events.storm.duration_seconds = 25
	rules.buildings.reactor.build_seconds = 0
	var sim := _new(rules)
	sim.place_building("reactor", Vector2i(18, 15))
	sim.start_run()
	sim.advance(75)
	var summary: Dictionary = sim.get_run_summary().result
	_check(summary.resilience.total == 1 and summary.resilience.resolved == 1, "un evento activo es una oportunidad")
	_near(summary.components.resilience, 1, "preparación supera tormenta sin crítico")
	sim = _new(rules)
	sim.start_run()
	sim.advance(75)
	var unpowered: Dictionary = sim.get_run_summary().result
	_near(unpowered.components.resilience, 0, "tormenta completada con hábitat sin potencia es crítica")
	_check("habitat_unpowered" in unpowered.resilience.opportunities[0].critical_reasons, "resiliencia conserva razón de estado crítico")
	_check(not unpowered.resilience.opportunities[0].critical_snapshot.habitat_powered, "resiliencia conserva medición crítica")
	var unfinished := rules.duplicate(true)
	unfinished.target_sols = 1
	unfinished.events.storm.start_seconds = 20
	sim = _new(unfinished)
	sim.place_building("reactor", Vector2i(18, 15))
	sim.start_run()
	sim.advance(25)
	summary = sim.get_run_summary().result
	_check(summary.resilience.total == 1 and summary.resilience.pending == 1, "evento aún activo al final no se da por resuelto")
	_near(summary.components.resilience, 0, "evento pendiente no obtiene punto de resolución")
	var maintenance := _rules(data)
	maintenance.target_sols = 6
	maintenance.buildings.reactor.build_seconds = 0
	maintenance.maintenance.interval_sols = 1
	sim = _new(maintenance)
	sim.place_building("reactor", Vector2i(18, 15))
	sim.start_run()
	sim.advance(25)
	var opened: Dictionary = sim.begin_maintenance("b2")
	sim.apply_maintenance_result(opened.result.id, false, 1)
	var retry: Dictionary = sim.begin_maintenance("b2")
	sim.apply_maintenance_result(retry.result.id, true, 2)
	for second: int in range(125):
		sim.advance(1)
		if sim.get_snapshot().phase == "running" and sim.get_snapshot().buildings[1].maintenance.state == "requested":
			opened = sim.begin_maintenance("b2")
			if opened.ok:
				sim.apply_maintenance_result(opened.result.id, true, 1)
	summary = sim.get_run_summary().result
	_check(summary.resilience.total == 6, "seis solicitudes, no siete por reintento")
	_check(summary.resilience.successful_without_critical == 5 and summary.resilience.pending == 1, "aviso al relevo permanece pendiente")
	_near(summary.components.resilience, 5.0 / 6.0, "proporción real de solicitudes resueltas")
	_check(summary.causes.size() <= 4, "máximo cuatro causas")
	_validate_evidence(summary, sim.get_snapshot())
	maintenance.maintenance.interval_sols = 1
	sim = _new(maintenance)
	sim.place_building("reactor", Vector2i(18, 15))
	sim.start_run()
	sim.advance(150)
	summary = sim.get_run_summary().result
	_check(summary.resilience.total == 1 and summary.resilience.opportunities[0].critical, "apagado ignorado marca oportunidad crítica")
	_near(summary.components.resilience, 0, "ignorar mantenimiento no cuenta como resolución")
	_validate_evidence(summary, sim.get_snapshot())

func _test_early_defeat(data: Dictionary) -> void:
	var rules := _rules(data)
	rules.initial.air = 16
	rules.health_loss_per_missing_unit = 20
	var sim := _new(rules)
	sim.start_run()
	sim.advance(300)
	var summary: Dictionary = sim.get_run_summary().result
	_check(summary.verdict == "total_defeat" and summary.elapsed_seconds == 113, "derrota no alineada: 50 s reserva + ceil(100/1.6)")
	_check(summary.sustainability.start_seconds == 63 and summary.sustainability.end_seconds == 113, "ventana final incluye tramo parcial exacto")
	_check(summary.crew.alive == 0 and summary.timeline[-1].partial, "muertos e informe parcial conservados")
	_near(summary.components.crew, 0, "muertos cuentan cero")
	_near(summary.components.survival, 113.0 / 300.0, "supervivencia de derrota anticipada")
	_validate_evidence(summary, sim.get_snapshot())
	var borrowed: Dictionary = sim.get_snapshot()
	borrowed.run_summary.causes.clear()
	_check(not sim.get_run_summary().result.causes.is_empty(), "snapshot tampoco permite editar causas del dominio")
	var individual := _rules(data)
	individual.target_sols = 1
	individual.radiation.damage_threshold = 0
	individual.events.warning_seconds = 1
	individual.events.storm.probability = 1
	individual.events.storm.start_seconds = 1
	individual.events.storm.duration_seconds = 1
	sim = _new(individual)
	# Fixture sintético: ingeniero previamente herido para aislar una sola muerte.
	sim._state.crew[0].health = 0.01
	sim.start_run()
	sim.advance(25)
	summary = sim.get_run_summary().result
	_check(summary.crew.alive == 3, "tres supervivientes no se convierten en cuatro plazas sanas")
	_near(summary.components.crew, 3.0 * 98.5 / 400.0, "muerto aporta cero y tres vivos conservan salud real")
	_check(summary.resilience.opportunities[0].critical, "muerte individual durante evento marca crítico")
	for value: float in summary.components.values():
		_check(is_finite(value) and value >= 0 and value <= 1, "componentes finitos entre 0 y 1")

func _test_frames(data: Dictionary) -> void:
	var rules := _rules(data)
	var a := _new(rules)
	var b := _new(rules)
	a.start_run()
	b.start_run()
	a.advance(300)
	for i: int in range(3000):
		b.advance(0.1)
	_check(a.get_run_summary() == b.get_run_summary(), "resumen independiente de partición de frames")
	_check(a.get_snapshot().summary_history.size() == 51, "historial acotado a 50 intervalos más apertura")

func _validate_evidence(summary: Dictionary, state: Dictionary) -> void:
	for cause: Dictionary in summary.causes:
		_check(not cause.fact_ids.is_empty() or not cause.sol_refs.is_empty(), "causa tiene evidencia")
		for id: String in cause.fact_ids:
			var found := false
			for fact: Dictionary in summary.facts:
				if fact.id == id:
					found = true
			_check(found, "hecho causal existe " + id)
		for sol: int in cause.sol_refs:
			var found := false
			for report: Dictionary in summary.timeline:
				if report.sol == sol and report.blocked_seconds.has(cause.target):
					found = true
			_check(found, "bloqueo enlaza a informe real")

func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.000001, "%s: esperado %.6f, observado %.6f" % [message, expected, actual])

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
