class_name SolReportService
extends RefCounted

func record_ledger(entry: Dictionary) -> void:
	var sol := int(entry.get("sol", 0))
	var bucket := _bucket(sol)
	var reason := String(entry.get("reason", ""))
	for resource in entry.get("delta", {}):
		var amount := float(entry["delta"][resource])
		var category := "consumption"
		if amount > 0.0:
			category = "production" if reason.begins_with("production") else "cargo" if reason.begins_with("cargo") else "other_income"
		bucket[category][resource] = float(bucket[category].get(resource, 0.0)) + absf(amount)
	GameState.data["reports"][str(sol)] = bucket

func record_fact(fact: Dictionary) -> void:
	for key in ["reason_id", "source_id", "target_id", "sol", "sim_time", "message_key", "params", "impact"]:
		if not fact.has(key):
			push_error("Report fact missing %s" % key)
			return
	var sol := int(fact["sol"])
	var bucket := _bucket(sol)
	var facts: Array = bucket["facts"]
	var id := String(fact["reason_id"])
	for existing in facts:
		if String(existing.get("reason_id", "")) == id:
			return
	facts.append(fact.duplicate(true))
	bucket["facts"] = facts
	GameState.data["reports"][str(sol)] = bucket

func get_report(sol: int) -> Dictionary:
	var bucket := _bucket(sol)
	var result := bucket.duplicate(true)
	var balances := {}
	for category in ["production", "consumption", "cargo", "other_income"]:
		for resource in bucket[category]:
			var sign := -1.0 if category == "consumption" else 1.0
			balances[resource] = float(balances.get(resource, 0.0)) + sign * float(bucket[category][resource])
	result["balance"] = balances
	var facts: Array = result["facts"]
	result["explanations"] = facts.slice(0, mini(3, facts.size()))
	return result

func _bucket(sol: int) -> Dictionary:
	return GameState.data.get("reports", {}).get(str(sol), {
		"production": {}, "consumption": {}, "cargo": {}, "other_income": {}, "facts": []}).duplicate(true)
