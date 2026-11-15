extends Node

var runner

func set_speed(multiplier: float) -> GameContracts.ValidationResult:
	if not ConfigDB.balance.get("time", {}).get("speed_multipliers", []).has(multiplier):
		return GameContracts.failure(&"invalid_speed", {"speed": multiplier})
	GameState.data["clock"]["speed"] = multiplier
	return GameContracts.success()

func set_paused(paused: bool) -> void:
	if GameState.is_running() and bool(GameState.data["clock"].get("paused", false)) != paused:
		GameState.data["clock"]["paused"] = paused
		SignalBus.pause_changed.emit(paused)

func advance_to_sol(sol: int) -> GameContracts.ValidationResult:
	if runner == null or not GameState.is_running():
		return GameContracts.failure(&"not_running")
	var current := int(GameState.data["clock"]["sol"])
	if sol <= current or sol > int(ConfigDB.balance["time"]["total_sols"]):
		return GameContracts.failure(&"invalid_target_sol", {"sol": sol})
	return runner.advance_to_sol(sol)

func get_snapshot() -> Dictionary:
	return GameState.data.get("clock", {}).duplicate(true)

func get_cycle_snapshot() -> Dictionary:
	var duration := maxf(0.1, float(ConfigDB.balance.get("time", {}).get("sol_seconds_x1", 60.0)))
	var elapsed := float(GameState.data.get("clock", {}).get("elapsed", 0.0))
	var phase := clampf(elapsed / duration, 0.0, 1.0)
	return {"phase": phase, "day": phase < 0.5,
		"seconds_to_change": maxf(0.0, (duration * 0.5 if phase < 0.5 else duration) - elapsed)}
