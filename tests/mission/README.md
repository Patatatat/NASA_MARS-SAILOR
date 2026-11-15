# R3 mission tests

Run from the project root with Godot 4.7:

`godot --headless --path . res://tests/mission/run_mission_tests.tscn`

R3 only writes `GameState.crew`, `events`, and `rockets`. Configure dependencies before `GameSession.start_new`. For save restore, register CrewService, EventService, and RocketService in SaveService's rebuild targets.

Provisional policies pending D4–D7: only cargo keys with explicit mass in balance are accepted; a manifest freezes on confirmation; an unconfirmed or invalid arrival remains pending for explicit `trigger_arrival`; exchange requires a living astronaut and one manifested replacement; a rocket's zone is released on salvage or exchange; repeated medics give one global morale bonus. No free manifest or cargo is generated.

Integration requests for file owners: R1 must wire R3 services into Main/SimulationRunner and SaveService; R2 must expose a panel-dust mutation through BuildingService so storms can accumulate dust without R3 writing building state. R1 owns any additional balance parameters for health, morale, storm damage, and salvage work duration. R4 owns localized strings for the emitted message keys and the operational alert UI.
