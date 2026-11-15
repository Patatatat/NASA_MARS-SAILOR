extends RefCounted
## Situaciones nacidas del estado real. Efectos y pagos pertenecen al dominio.
var state: Dictionary
var config: Dictionary
var facts: Array[Dictionary] = []

func reset(run: Dictionary, data: Dictionary) -> void:
	state = run
	config = data
	facts.clear()
	state.situations = []
	state.decisions = []
	state.situation_keys = {}
	state.salvage = {"remaining": 0, "decision_id": ""}
	state.priority = "air"
	state.storm_was_active = false
	state.flare_was_active = false
	state.flare_decision = "inaction"
	state.crop_decision = ""

func record(reason: String, target: String, details: Dictionary) -> void:
	facts.append({"reason": reason, "target": target, "details": details.duplicate(true)})

func active_event(kind: String) -> bool:
	return state.event.get("kind") == kind and state.event.get("state") == "active"

func building(id: String) -> Dictionary:
	for b: Dictionary in state.buildings:
		if b.id == id:
			return b
	return {}

func option(id: String, title: String, effect: String, later: String) -> Dictionary:
	return {"id": id, "title": title, "effect": effect, "later": later, "cost": {}}

func offer(key: String, kind: String, target: String, title: String, deadline: int, options: Array) -> void:
	if state.situation_keys.has(key):
		return
	state.situation_keys[key] = true
	state.situations.append({"id": "r%d-%s" % [state.run_generation, key], "kind": kind,
		"target": target, "title": title, "deadline": deadline, "status": "queued", "options": options})
	activate_queue()

func activate_queue() -> void:
	var count := 0
	for situation: Dictionary in state.situations:
		if situation.status in ["active", "queued"]:
			situation.status = "active" if count < 2 else "queued"
			count += 1

func before_step() -> void:
	var now: int = state.elapsed_seconds
	var day: bool = posmod(now, int(config.sol_seconds)) < int(config.day_seconds)
	for b: Dictionary in state.buildings:
		if b.repair_remaining > 0 and not state.sheltered:
			b.repair_remaining -= 1
			if b.repair_remaining == 0:
				b.damage = 0.0
				b.crop_health = 100.0
				record("repair_completed", b.id, {"decision_id": b.repair_decision})
		if not str(b.night_decision).is_empty() and day:
			b.night_cut = false
			record("night_cut_ended", b.id, {"decision_id": b.night_decision, "production_lost_seconds": b.cut_seconds})
			b.cut_seconds = 0
			b.night_decision = ""
		if b.night_cut:
			b.cut_seconds += 1
	if state.salvage.remaining > 0 and not state.sheltered:
		state.salvage.remaining -= 1
		if state.salvage.remaining == 0:
			state.resources.regolith += float(config.survival.salvage_regolith)
			record("salvage_returned", "crew", {"decision_id": state.salvage.decision_id, "regolith": config.survival.salvage_regolith})
	# At event end, all exposed panels accrue a visible debt, including inaction.
	if state.storm_was_active and not active_event("storm"):
		for b: Dictionary in state.buildings:
			if b.kind == "solar" and b.remaining_seconds == 0:
				var damage := 0.0 if b.covered else float(config.survival.storm_damage) * (float(config.survival.lotus_damage_multiplier) if b.lotus else 1.0)
				b.damage = minf(0.9, b.damage + damage)
				record("storm_consequence", b.id, {"decision_id": b.storm_decision, "damage_added": damage, "protected_seconds": b.cover_seconds})
				b.covered = false
				b.cover_seconds = 0
	if state.flare_was_active and not active_event("solar_particles"):
		record("flare_consequence", "crew", {"decision_id": state.flare_decision, "sheltered": state.sheltered, "doses": state.crew.map(func(c: Dictionary) -> float: return c.dose)})
	state.storm_was_active = active_event("storm")
	state.flare_was_active = active_event("solar_particles")
	for s: Dictionary in state.situations:
		if s.status in ["active", "queued"] and now >= s.deadline:
			s.status = "expired"
			record("decision_inaction", s.target, {"situation_id": s.id, "kind": s.kind})
	if state.event.get("kind") == "storm":
		for b: Dictionary in state.buildings:
			if b.kind == "solar" and b.remaining_seconds == 0:
				offer("storm-%d-%s" % [state.event.start_seconds, b.id], "storm", b.id, "Polvo sobre " + b.id, state.event.end_seconds,
					[option("cover", "Proteger panel", "Generación solar 0 hasta acabar la tormenta.", "Evita daño; gastarás reserva eléctrica."),
					option("expose", "Mantener desplegado", "Conserva la generación reducida por polvo.", "Al terminar añade 45% de daño (LOTUS reduce la mitad).")])
	if state.event.get("kind") == "solar_particles":
		offer("flare-%d" % state.event.start_seconds, "flare", "crew", "Partículas solares: refugio o trabajo", state.event.end_seconds,
			[option("shelter", "Refugiar tripulación", "Reduce dosis futura; suspende obras y reparaciones.", "El cultivo produce la mitad mientras dura el refugio."),
			option("work", "Continuar trabajos", "Mantiene producción y cuadrillas trabajando.", "La dosis sigue acumulándose. El daño no se revierte.")])
	if not day and state.resources.energy < config.energy_capacity * config.survival.night_threshold:
		for b: Dictionary in state.buildings:
			if b.kind in ["greenhouse", "laboratory"] and b.enabled and b.remaining_seconds == 0 and not b.night_cut:
				var dawn := (int(now / int(config.sol_seconds)) + 1) * int(config.sol_seconds)
				offer("night-%d" % int(now / int(config.sol_seconds)), "night", b.id, "Noche: reserva eléctrica baja", dawn,
					[option("cut", "Suspender " + b.id, "Corta su consumo hasta el amanecer.", "Pierdes su producción o disponibilidad nocturna."),
					option("keep", "Sostener actividad", "El edificio sigue consumiendo batería.", "Si se agota, oxígeno y cultivo competirán por potencia.")])
				break
	activate_queue()

func after_step() -> void:
	for b: Dictionary in state.buildings:
		if b.covered:
			b.cover_seconds += 1
		if b.kind != "greenhouse" or b.remaining_seconds > 0:
			continue
		if b.powered:
			b.crop_health = minf(100, b.crop_health + float(config.survival.crop_recovery_per_second))
		elif b.enabled and not b.night_cut:
			b.crop_health = maxf(10, b.crop_health - float(config.survival.crop_decay_per_second))
		if not str(state.crop_decision).is_empty() and posmod(state.elapsed_seconds, int(config.sol_seconds)) == 0:
			record("crop_consequence", b.id, {"decision_id": state.crop_decision, "crop_health": b.crop_health, "priority": state.priority})
		if b.crop_health < 70 and b.enabled:
			offer("crop-%s-%d" % [b.id, state.completed_sols], "crop", b.id, "Cultivo marchito: " + b.id, state.elapsed_seconds + int(config.sol_seconds),
				[option("priority", "Priorizar alimento", "El cultivo recibe potencia antes que el generador de oxígeno.", "Puedes perder producción de oxígeno si falta potencia."),
				option("accept", "Priorizar oxígeno", "Conserva el orden de soporte vital.", "El cultivo pierde rendimiento si continúa sin energía.")])

func choose(id: String, choice: String) -> Dictionary:
	for s: Dictionary in state.situations:
		if s.id != id:
			continue
		if s.status != "active" or state.elapsed_seconds >= s.deadline:
			return reply(false, "decision_closed")
		var selected: Dictionary = {}
		for candidate: Dictionary in s.options:
			if candidate.id == choice:
				selected = candidate
		if selected.is_empty():
			return reply(false, "invalid_option")
		var b := building(s.target)
		if s.kind != "flare" and b.is_empty():
			return reply(false, "unknown_building")
		match s.kind:
			"storm":
				b.covered = choice == "cover"
				b.storm_decision = s.id
			"flare":
				state.sheltered = choice == "shelter"
				state.flare_decision = s.id
			"night":
				b.night_cut = choice == "cut"
				b.night_decision = s.id
			"crop":
				state.priority = "food" if choice == "priority" else "air"
				state.crop_decision = s.id
		s.status = "resolved"
		var decision := {"id": s.id, "seconds": state.elapsed_seconds, "kind": s.kind, "target": s.target, "choice": choice,
			"title": selected.title, "effect": selected.effect, "later": selected.later}
		state.decisions.append(decision)
		record("decision_taken", s.target, decision)
		activate_queue()
		return reply(true)
	return reply(false, "unknown_decision")

func command(action: String, id: String = "") -> Dictionary:
	var b := building(id)
	var cost: Dictionary = {}
	if action in ["repair", "lotus"]:
		if b.is_empty() or b.remaining_seconds > 0:
			return reply(false, "unknown_building")
		if b.repair_remaining > 0 or state.sheltered:
			return reply(false, "crew_unavailable")
		if action == "lotus" and (b.kind != "solar" or b.lotus):
			return reply(false, "technology_unavailable")
		if action == "repair" and b.damage <= 0 and b.crop_health >= 100:
			return reply(false, "repair_not_needed")
		cost = {"regolith": config.survival.repair_regolith} if action == "repair" else {"regolith": config.survival.lotus_regolith, "energy": config.survival.lotus_energy}
	elif action == "salvage":
		if state.salvage.remaining > 0 or state.sheltered:
			return reply(false, "crew_unavailable")
		cost = {"energy": config.survival.salvage_energy}
	else:
		return reply(false, "unknown_command")
	for key: String in cost:
		if state.resources[key] < cost[key]:
			return reply(false, "insufficient_" + key)
	for key: String in cost:
		state.resources[key] -= cost[key]
	var decision_id := "operation-%d-%d" % [state.run_generation, state.log.size()]
	if action == "salvage":
		state.salvage = {"remaining": int(config.survival.salvage_seconds), "decision_id": decision_id}
	else:
		b.repair_remaining = int(config.survival.repair_seconds)
		b.repair_decision = decision_id
		if action == "lotus":
			b.lotus = true
	record(action + "_ordered", id, {"decision_id": decision_id, "cost": cost})
	return {"ok": true, "error_code": "", "cost": cost, "result": {"decision_id": decision_id}}

func multiplier(b: Dictionary) -> float:
	if b.covered or b.night_cut or b.repair_remaining > 0:
		return 0.0
	var value := 1.0 - float(b.damage)
	if b.kind == "greenhouse":
		value *= float(b.crop_health) / 100.0
		if state.sheltered:
			value *= float(config.survival.shelter_food_multiplier)
	return value

func reply(ok: bool, code: String = "") -> Dictionary:
	return {"ok": ok, "error_code": code, "cost": {}, "result": {}}
