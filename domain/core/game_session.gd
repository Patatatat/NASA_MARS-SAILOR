class_name GameSession
extends RefCounted

var services: Dictionary = {}
var runner := SimulationRunner.new()

func configure(dependencies: Dictionary) -> void:
	services = dependencies
	runner.configure(dependencies)

func update(delta: float) -> void:
	runner.update(delta)

func start_new(profile_ids: Array[StringName], seed: int) -> GameContracts.ValidationResult:
	if profile_ids.size() != 4:
		return GameContracts.failure(&"four_profiles_required")
	for id in profile_ids:
		if String(id).is_empty():
			return GameContracts.failure(&"invalid_profile")
	if ConfigDB.balance.is_empty():
		return GameContracts.failure(&"invalid_balance")
	if not services.has("crew") or not services.has("building"):
		return GameContracts.failure(&"missing_services")
	var previous := GameState.to_dict()
	GameState.reset(seed)
	services["ledger"].initialize(ConfigDB.balance["initial_inventory"])
	var roster_result: GameContracts.ValidationResult = services["crew"].create_roster(profile_ids)
	if not roster_result.ok:
		GameState.from_dict(previous)
		return roster_result
	var layout_result: GameContracts.ValidationResult = services["building"].initialize_layout()
	if not layout_result.ok:
		GameState.from_dict(previous)
		for service in services.values():
			if service.has_method("rebuild_from_state"):
				service.rebuild_from_state()
		return layout_result
	services["power"].rebuild_from_state()
	runner.accumulator = 0.0
	return GameContracts.success()
