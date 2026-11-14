extends RefCounted
## Medidas de la simulación; no redacta explicaciones ni calcula puntaje.

static func open(state: Dictionary) -> Dictionary:
	return {"sol": state.completed_sols + 1, "start_seconds": state.elapsed_seconds,
		"opening": state.resources.duplicate(true), "production": {}, "consumption": {},
		"requested_consumption": {}, "deficits": {}, "imports": {}, "blocked_seconds": {}, "fact_ids": []}

static func add(report: Dictionary, bucket: String, resource: String, amount: float) -> void:
	report[bucket][resource] = float(report[bucket].get(resource, 0.0)) + amount

static func blocked(report: Dictionary, building_id: String, reason: String) -> void:
	if not report.blocked_seconds.has(building_id):
		report.blocked_seconds[building_id] = {}
	var values: Dictionary = report.blocked_seconds[building_id]
	values[reason] = int(values.get(reason, 0)) + 1

static func close(state: Dictionary, partial: bool) -> Dictionary:
	var report: Dictionary = state.current_sol_report.duplicate(true)
	report.end_seconds = state.elapsed_seconds
	report.partial = partial
	report.closing = state.resources.duplicate(true)
	report.delta = {}
	for resource: String in state.resources:
		report.delta[resource] = float(state.resources[resource]) - float(report.opening[resource])
	return report
