extends RefCounted
## Resumen medido, sin UI ni cálculo del puntaje ponderado.

const VITALS := ["air", "water", "food"]

static func initialize(state: Dictionary) -> void:
	state.run_summary = {}
	state.summary_history = []
	state.summary_opportunities = {}

static func observe(state: Dictionary, reason: String, target: String, details: Dictionary, fact_id: String) -> void:
	if reason == "crew_died":
		for opportunity: Dictionary in state.summary_opportunities.values():
			if not opportunity.resolved:
				opportunity.critical = true
				if opportunity.first_critical_seconds < 0:
					opportunity.first_critical_seconds = state.elapsed_seconds
				if "crew_death" not in opportunity.critical_reasons:
					opportunity.critical_reasons.append("crew_death")
				opportunity.fact_ids.append(fact_id)
		return
	var key := ""
	var kind := ""
	if reason == "event_active":
		key = "event:" + target
		kind = "event"
	elif reason == "maintenance_requested":
		key = str(details.request_id)
		kind = "maintenance"
	if not key.is_empty():
		state.summary_opportunities[key] = {"id": key, "kind": kind, "target": target,
			"start_seconds": state.elapsed_seconds, "end_seconds": -1,
			"resolved": false, "critical": false, "outcome": "pending", "fact_ids": [fact_id],
			"first_critical_seconds": -1, "critical_reasons": [], "critical_snapshot": {}}
		return
	if reason == "event_ended":
		key = "event:" + target
	elif reason in ["maintenance_success", "maintenance_shutdown", "maintenance_reactivated"]:
		key = str(details.get("request_id", ""))
	if key.is_empty() or not state.summary_opportunities.has(key):
		return
	var opportunity: Dictionary = state.summary_opportunities[key]
	opportunity.fact_ids.append(fact_id)
	if reason == "maintenance_shutdown":
		opportunity.critical = true
		if opportunity.first_critical_seconds < 0:
			opportunity.first_critical_seconds = state.elapsed_seconds
		opportunity.critical_reasons.append("maintenance_shutdown")
	else:
		opportunity.resolved = true
		opportunity.end_seconds = state.elapsed_seconds
		opportunity.outcome = reason

static func sample(state: Dictionary, config: Dictionary) -> void:
	var alive := 0
	var health_critical := false
	for member: Dictionary in state.crew:
		if member.alive:
			alive += 1
			if member.health <= float(config.summary.critical_health):
				health_critical = true
	var demand := {}
	var critical_reasons: Array[String] = []
	if alive == 0:
		critical_reasons.append("no_survivors")
	if health_critical:
		critical_reasons.append("low_crew_health")
	if not state.buildings[0].powered:
		critical_reasons.append("habitat_unpowered")
	for resource: String in VITALS:
		demand[resource] = float(config.consumption_per_crew_per_sol[resource]) * alive
		if float(state.resources[resource]) <= float(demand[resource]) * float(config.summary.critical_reserve_sols):
			critical_reasons.append("low_reserve_" + resource)
	var previous: Dictionary = state.summary_history[-1] if not state.summary_history.is_empty() else {}
	if not previous.is_empty():
		for resource: String in VITALS:
			if float(state.deficits[resource]) > float(previous.deficits[resource]) + 0.000000001:
				critical_reasons.append("deficit_" + resource)
	for opportunity: Dictionary in state.summary_opportunities.values():
		if opportunity.resolved:
			continue
		if not critical_reasons.is_empty():
			opportunity.critical = true
			if opportunity.first_critical_seconds < 0:
				opportunity.first_critical_seconds = state.elapsed_seconds
			for reason: String in critical_reasons:
				if reason not in opportunity.critical_reasons:
					opportunity.critical_reasons.append(reason)
		if opportunity.critical and opportunity.critical_snapshot.is_empty():
			opportunity.critical_snapshot = {"seconds": state.elapsed_seconds, "alive": alive,
				"resources": state.resources.duplicate(true), "habitat_powered": state.buildings[0].powered,
				"crew": state.crew.duplicate(true), "deficits": state.deficits.duplicate(true)}
	state.summary_history.append({"seconds": state.elapsed_seconds, "resources": state.resources.duplicate(true),
		"crew_demand_per_sol": demand, "alive": alive, "deficits": state.deficits.duplicate(true)})
	var oldest: int = state.elapsed_seconds - int(config.summary.window_sols * config.sol_seconds)
	while state.summary_history.size() > 1 and state.summary_history[0].seconds < oldest:
		state.summary_history.pop_front()

static func build(state: Dictionary, config: Dictionary) -> Dictionary:
	var health := 0.0
	var alive := 0
	for member: Dictionary in state.crew:
		if member.alive:
			health += float(member.health)
			alive += 1
	var sustainability := _sustainability(state, config)
	var opportunities: Array = state.summary_opportunities.values().duplicate(true)
	var resolved := 0
	var successful := 0
	for opportunity: Dictionary in opportunities:
		if opportunity.resolved:
			resolved += 1
		opportunity.success_without_critical = opportunity.resolved and not opportunity.critical
		if opportunity.success_without_critical:
			successful += 1
	var target_seconds := int(config.target_sols * config.sol_seconds)
	var survival := clampf(float(state.elapsed_seconds) / float(target_seconds), 0.0, 1.0)
	var crew_value := clampf(health / 400.0, 0.0, 1.0)
	var resilience := float(successful) / float(opportunities.size()) if not opportunities.is_empty() else float(config.summary.resilience_neutral)
	return {"schema_version": 1, "seed": state.seed, "run_generation": state.run_generation,
		"verdict": state.result.verdict, "elapsed_seconds": state.elapsed_seconds, "target_seconds": target_seconds,
		"components": {"survival": survival, "crew": crew_value, "sustainability": sustainability.value, "resilience": resilience},
		"survival": {"elapsed_seconds": state.elapsed_seconds, "target_seconds": target_seconds},
		"crew": {"alive": alive, "slots": 4, "mean_health_all_slots": health / 4.0, "members": state.crew.duplicate(true)},
		"sustainability": sustainability,
		"resilience": {"opportunities": opportunities, "total": opportunities.size(), "resolved": resolved,
			"successful_without_critical": successful, "pending": opportunities.size() - resolved,
			"neutral_used": opportunities.is_empty(), "neutral_value": config.summary.resilience_neutral},
		"final_resources": state.resources.duplicate(true), "final_power": state.power.duplicate(true),
		"metrics": state.metrics.duplicate(true), "deficits": state.deficits.duplicate(true),
		"roberts": state.roberts.duplicate(true), "timeline": state.sol_reports.duplicate(true), "facts": state.log.duplicate(true),
		"causes": _causes(state, int(config.summary.max_causes)),
		"criteria": config.summary.duplicate(true)}

static func _sustainability(state: Dictionary, config: Dictionary) -> Dictionary:
	var history: Array = state.summary_history
	var opening: Dictionary = history[0]
	var closing: Dictionary = history[-1]
	var duration: int = closing.seconds - opening.seconds
	var resources := {}
	var total := 0.0
	for resource: String in VITALS:
		var availability := 0.0
		var mean_demand := 0.0
		for index: int in range(1, history.size()):
			var point: Dictionary = history[index]
			var demand: float = point.crew_demand_per_sol[resource]
			var target := demand * float(config.summary.reserve_target_sols)
			mean_demand += demand
			if point.alive > 0:
				availability += clampf(float(point.resources[resource]) / target, 0.0, 1.0) if target > 0 else (1.0 if point.resources[resource] > 0 else 0.0)
		availability /= maxi(duration, 1)
		mean_demand /= maxi(duration, 1)
		var delta := float(closing.resources[resource]) - float(opening.resources[resource])
		var rate := delta * float(config.sol_seconds) / maxi(duration, 1)
		var trend := clampf(1.0 + rate / mean_demand, 0.0, 1.0) if mean_demand > 0 else (1.0 if rate >= 0 else 0.0)
		var value := availability * trend
		resources[resource] = {"opening": opening.resources[resource], "closing": closing.resources[resource],
			"delta": delta, "net_per_sol": rate, "mean_crew_demand_per_sol": mean_demand,
			"availability": availability, "trend_value": trend, "value": value}
		total += value
	return {"start_seconds": opening.seconds, "end_seconds": closing.seconds, "window_seconds": duration,
		"requested_window_seconds": int(config.summary.window_sols * config.sol_seconds),
		"resources": resources, "value": clampf(total / 3.0, 0.0, 1.0)}

static func _causes(state: Dictionary, limit: int) -> Array[Dictionary]:
	var causes: Array[Dictionary] = []
	for resource: String in VITALS:
		if state.deficits[resource] > 0:
			var ids: Array[String] = []
			for fact: Dictionary in state.log:
				if fact.reason == "crew_deficit" and fact.target == resource:
					ids.append(fact.id)
			causes.append({"kind": "crew_resource_deficit", "target": resource, "amount": state.deficits[resource], "fact_ids": ids, "sol_refs": []})
	for reason: String in ["maintenance_shutdown", "robert_lost"]:
		for fact: Dictionary in state.log:
			if fact.reason == reason:
				causes.append({"kind": reason, "target": fact.target, "seconds": fact.seconds,
					"details": fact.details.duplicate(true), "fact_ids": [fact.id], "sol_refs": []})
	for reason: String in ["water_shortage", "power_shortage", "disabled"]:
		var buildings := {}
		for report: Dictionary in state.sol_reports:
			for id: String in report.blocked_seconds:
				var count := int(report.blocked_seconds[id].get(reason, 0))
				if count == 0:
					continue
				if not buildings.has(id):
					buildings[id] = {"kind": "building_blocked", "target": id, "reason": reason, "duration_seconds": 0, "fact_ids": [], "sol_refs": []}
				buildings[id].duration_seconds += count
				buildings[id].sol_refs.append(report.sol)
		for cause: Dictionary in buildings.values():
			causes.append(cause)
	for reason: String in ["robert_returned", "maintenance_success", "upgrade_completed", "habitat_buried"]:
		for fact: Dictionary in state.log:
			if fact.reason == reason:
				causes.append({"kind": reason, "target": fact.target, "seconds": fact.seconds,
					"details": fact.details.duplicate(true), "fact_ids": [fact.id], "sol_refs": []})
	return causes.slice(0, limit)
