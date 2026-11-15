extends SceneTree
const Simulation = preload("res://domain/simulation.gd")
const Config = preload("res://domain/simulation_config.gd")
const CREW := ["engineer", "medic", "botanist", "technician"]
var failures := 0
var checks := 0

func _initialize() -> void:
	var data: Dictionary = Config.load_file().data
	for scenario: String in ["frontier", "eclipse", "harvest"]:
		for seed_value: int in [1, 123]:
			var sim := make(data, seed_value, scenario)
			var twin := make(data, seed_value, scenario)
			check(sim.get_snapshot() == twin.get_snapshot(), "escenario reproducible " + scenario)
			place(sim, "reactor")
			place(sim, "oxygen_generator")
			if scenario != "harvest": place(sim, "greenhouse")
			else: check(sim.survival_command("repair", "b2").ok, "reparar cosecha heredada")
			sim.start_run()
			for step: int in range(504):
				service(sim)
				sim.advance(5)
			var end: Dictionary = sim.get_snapshot()
			print("PLAYTHROUGH %s seed=%d: %s food=%.1f air=%.1f" % [scenario, seed_value, end.result, end.resources.food, end.resources.air])
			check(end.result.get("verdict") == "relief_achieved", "escenario termina con relevo: " + scenario)
			check(sim.reset_run(CREW, seed_value, scenario).ok and sim.get_snapshot().decisions.is_empty(), "reinicio limpia decisiones")
	var safe := data.duplicate(true)
	safe.initial.regolith = 1000
	safe.initial.air = 100000
	safe.initial.food = 100000
	safe.initial.energy = 100000
	safe.energy_capacity = 100000
	safe.map_obstacle_ratio = 0
	safe.map_sizes = [32]
	safe.events.storm.probability = 1
	safe.events.solar_particles.probability = 0
	var protected := make(safe, 1)
	var exposed := make(safe, 1)
	for sim: RefCounted in [protected, exposed]:
		for count: int in range(3): place(sim, "solar")
		sim.start_run()
	var begin: int = protected.get_snapshot().forecast.storm.start_sol
	var until := (begin - 1) * 60 + 1
	protected.advance(until)
	exposed.advance(until)
	var snapshot: Dictionary = protected.get_snapshot()
	check(snapshot.situations.filter(func(s: Dictionary) -> bool: return s.status == "active").size() == 2, "máximo dos urgencias")
	check(snapshot.situations.filter(func(s: Dictionary) -> bool: return s.status == "queued").size() == 1, "tercera urgencia en cola")
	var decision: String = snapshot.situations[0].id
	check(not protected.choose_decision(decision, "invalid").ok and protected.get_snapshot() == snapshot, "opción inválida no muta")
	check(protected.choose_decision(decision, "cover").ok, "proteger solar")
	check(not protected.choose_decision(decision, "expose").ok, "decisión excluyente")
	protected.advance(120)
	exposed.advance(120)
	check(is_equal_approx(protected.get_snapshot().buildings[1].damage, 0), "cubierta evita daño")
	check(is_equal_approx(exposed.get_snapshot().buildings[1].damage, 0.45), "inacción causa daño persistente")
	check(protected.get_snapshot().log.any(func(e: Dictionary) -> bool: return e.reason == "storm_consequence" and e.details.get("decision_id") == decision), "cadena causal con decisión original")
	check(exposed.survival_command("repair", "b2").ok, "pago reparación")
	var paid: Dictionary = exposed.get_snapshot()
	check(not exposed.survival_command("repair", "b2").ok and exposed.get_snapshot() == paid, "no cobra reparación duplicada")
	exposed.set_sheltered(true)
	exposed.advance(10)
	check(exposed.get_snapshot().buildings[1].repair_remaining == 30, "refugio pausa reparación")
	exposed.set_sheltered(false)
	exposed.advance(30)
	check(exposed.get_snapshot().buildings[1].damage == 0, "reparación restaura producción")
	var tech := make(safe, 1)
	place(tech, "solar")
	tech.start_run()
	tech.advance(6)
	check(tech.survival_command("lotus", "b2").ok, "instalación LOTUS")
	check(not tech.survival_command("lotus", "b2").ok, "sin compra duplicada")
	tech.advance(until + 120 - 6)
	check(is_equal_approx(tech.get_snapshot().buildings[1].damage, 0.225), "LOTUS reduce daño a mitad")
	var salvage := make(safe, 8)
	salvage.start_run()
	check(salvage.survival_command("salvage").ok, "salida exterior")
	salvage.advance(60)
	check(is_equal_approx(salvage.get_snapshot().resources.regolith, 1012), "retorno de material exacto")
	salvage.advance(60)
	check(is_equal_approx(salvage.get_snapshot().resources.regolith, 1012), "retorno único")
	var idle := make(data, 1)
	idle.start_run()
	idle.advance(2520)
	check(idle.get_snapshot().result.get("verdict") == "total_defeat", "inacción no sobrevive sin soporte")
	_test_night_and_flare(safe)
	print("SURVIVAL_LOOP_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func make(data: Dictionary, seed_value: int, scenario: String = "frontier") -> RefCounted:
	var sim := Simulation.new()
	check(sim.configure(data).ok, "configuración")
	check(sim.reset_run(CREW, seed_value, scenario).ok, "reset " + scenario)
	return sim

func _test_night_and_flare(data: Dictionary) -> void:
	var rules := data.duplicate(true)
	rules.initial.energy = 40
	rules.energy_capacity = 240
	rules.events.storm.probability = 0
	var night := make(rules, 1)
	place(night, "greenhouse")
	night.start_run()
	night.advance(41)
	var snap: Dictionary = night.get_snapshot()
	var options: Array = snap.situations.filter(func(s: Dictionary) -> bool: return s.kind == "night" and s.status == "active")
	check(not options.is_empty(), "batería baja genera decisión nocturna")
	if not options.is_empty():
		night.choose_decision(options[0].id, "cut")
		check(night.get_snapshot().buildings[1].night_cut, "corte detiene demanda")
		night.advance(19)
		check(not night.get_snapshot().buildings[1].night_cut, "amanecer restaura edificio")
	var crops: Array = night.get_snapshot().situations.filter(func(s: Dictionary) -> bool: return s.kind == "crop" and s.status == "active")
	if not crops.is_empty():
		check(night.choose_decision(crops[0].id, "priority").ok and night.get_snapshot().priority == "food", "prioridad cultivos afecta orden de potencia")
	else:
		night.advance(120)
		crops = night.get_snapshot().situations.filter(func(s: Dictionary) -> bool: return s.kind == "crop" and s.status == "active")
		check(not crops.is_empty(), "cultivo marchito genera decisión")
	var flare_rules := data.duplicate(true)
	flare_rules.events.storm.probability = 0
	flare_rules.events.solar_particles.probability = 1
	var sheltered := make(flare_rules, 4)
	var working := make(flare_rules, 4)
	for sim: RefCounted in [sheltered, working]:
		place(sim, "greenhouse")
		sim.start_run()
	var start: int = (sheltered.get_snapshot().forecast.solar_particles.start_sol - 1) * 60
	sheltered.advance(start)
	working.advance(start)
	var situation: Dictionary = sheltered.get_snapshot().situations.filter(func(s: Dictionary) -> bool: return s.kind == "flare")[0]
	check(sheltered.choose_decision(situation.id, "shelter").ok, "refugio como elección")
	sheltered.advance(60)
	working.advance(60)
	check(sheltered.get_snapshot().crew[0].dose < working.get_snapshot().crew[0].dose, "refugio reduce dosis futura")
	check(sheltered.get_snapshot().resources.food < working.get_snapshot().resources.food, "refugio sacrifica producción de alimento")
	var a := make(rules, 9)
	var b := make(rules, 9)
	place(a, "greenhouse")
	place(b, "greenhouse")
	a.start_run()
	b.start_run()
	a.advance(120)
	for tick: int in range(240): b.advance(0.5)
	check(a.get_snapshot() == b.get_snapshot(), "crisis y cultivos independientes del frame")

func place(sim: RefCounted, kind: String) -> void:
	for y: int in range(32):
		for x: int in range(32):
			if sim.preview_placement(kind, Vector2i(x, y)).ok:
				check(sim.place_building(kind, Vector2i(x, y)).ok, "construir " + kind)
				return
	check(false, "sin sitio para " + kind)

func service(sim: RefCounted) -> void:
	var snapshot: Dictionary = sim.get_snapshot()
	for s: Dictionary in snapshot.situations:
		if s.status == "active":
			sim.choose_decision(s.id, "shelter" if s.kind == "flare" else s.options[0].id)
	if snapshot.sheltered and snapshot.event.is_empty(): sim.set_sheltered(false)
	for b: Dictionary in snapshot.buildings:
		if b.maintenance.state in ["requested", "degraded"]:
			var session: Dictionary = sim.begin_maintenance(b.id)
			if session.ok: sim.apply_maintenance_result(session.result.id, true, 0)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
