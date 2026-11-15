class_name MissionMain
extends Node

const SAVE_SLOT := &"autosave"
const DEMO_SEED := 20261114

@onready var world: MartianWorld = $World
@onready var menu: MainMenu = $Interface/MainMenu
@onready var hud: MissionHud = $Interface/HUD

var session := GameSession.new()
var ledger := ResourceLedger.new()
var power := PowerService.new()
var life_support := LifeSupportService.new()
var report := SolReportService.new()
var grid := GridService.new()
var tunnel := TunnelNetwork.new()
var building := BuildingService.new()
var production := ProductionService.new()
var research := ResearchService.new()
var scan := ScanService.new()
var crew := CrewService.new()
var events := EventService.new()
var rockets := RocketService.new()
var dialogue := DialogueService.new()
var services: Dictionary = {}

func _ready() -> void:
	_wire_services()
	menu.start_requested.connect(_start_new)
	menu.continue_requested.connect(_continue_game)
	hud.save_requested.connect(_save_game)
	hud.menu_requested.connect(_return_to_menu)
	SignalBus.sol_ended.connect(_autosave)
	SignalBus.game_over.connect(_autosave_after_result)
	world.configure(building, grid)
	hud.configure(services, world)
	_show_menu()
	if ConfigDB.balance.is_empty():
		menu.show_message(LocalizationDB.translate_key(&"error.invalid_balance"))

func _exit_tree() -> void:
	dialogue.shutdown()
	if SignalBus.building_changed.is_connected(crew.on_building_changed):
		SignalBus.building_changed.disconnect(crew.on_building_changed)
	if GameClock.runner == session.runner:
		GameClock.runner = null
	SaveService.configure([])
	# Services reference each other; release those cycles when this scene closes.
	for service in services.values():
		for property in service.get_property_list():
			if property["name"] in ["ledger", "report", "grid", "power", "research", "tunnel_network", "building_service", "grid_service", "crew_service", "life_support", "rocket_service", "events", "buildings"]:
				service.set(property["name"], null)
	crew.scheduler.building_service = null
	session.runner.services.clear()
	session.services.clear()

func _process(delta: float) -> void:
	session.update(delta)

func _wire_services() -> void:
	ledger.report = report
	building.grid = grid
	building.ledger = ledger
	building.power = power
	building.research = research
	building.tunnel_network = tunnel
	grid.building_service = building
	power.building_service = building
	power.grid_service = grid
	production.ledger = ledger
	production.building_service = building
	production.power = power
	life_support.ledger = ledger
	life_support.crew_service = crew
	life_support.tunnel_network = tunnel
	crew.life_support = life_support
	crew.building_service = building
	crew.ledger = ledger
	crew.rocket_service = rockets
	crew.report = report
	if not SignalBus.building_changed.is_connected(crew.on_building_changed):
		SignalBus.building_changed.connect(crew.on_building_changed)
	research.power = power
	research.crew_service = crew
	scan.grid = grid
	scan.power = power
	events.building_service = building
	events.report = report
	rockets.grid = grid
	rockets.ledger = ledger
	rockets.crew_service = crew
	rockets.report = report
	services = {"ledger": ledger, "power": power, "life_support": life_support,
		"report": report, "grid": grid, "building": building, "production": production,
		"research": research, "scan": scan, "crew": crew, "event": events,
		"rocket": rockets, "dialogue": dialogue}
	session.configure(services)
	SaveService.configure([grid, building, tunnel, power, production, life_support,
		crew, research, scan, events, rockets, dialogue])
	dialogue.configure(events, building)

func _start_new(profile_ids: Array[StringName]) -> void:
	var preferences := SettingsService.get_settings()
	var result: GameContracts.ValidationResult = session.start_new(profile_ids, DEMO_SEED)
	if not result.ok:
		menu.show_message(LocalizationDB.translate_key(result.message_key, result.params))
		return
	SettingsService.apply_settings(preferences)
	dialogue.rebuild_from_state()
	world.cancel_placement()
	world.selected_id = &""
	world.camera_rig.focus = Vector3(16, 0, 16)
	world.camera_rig.zoom = 36.0
	world.camera_rig._apply()
	hud._workspace.reset_drafts()
	hud.show_panel(&"workspace")
	hud._inspector.target_id = &""
	world.rebuild_from_state()
	power.step(0.0)
	hud.rebuild_from_state()
	SaveService.save_to_slot(SAVE_SLOT)
	_show_game()

func _continue_game() -> void:
	var result := SaveService.load_from_slot(SAVE_SLOT)
	if result != OK:
		menu.show_message(LocalizationDB.translate_key(&"ui.no_saved_game" if result == ERR_FILE_NOT_FOUND else &"ui.load_failed"))
		return
	session.runner.accumulator = 0.0
	power.step(0.0)
	_show_game()

func _save_game() -> void:
	var result := SaveService.save_to_slot(SAVE_SLOT)
	hud.show_message(LocalizationDB.translate_key(&"ui.saved" if result == OK else &"ui.save_failed"))

func _return_to_menu() -> void:
	if SaveService.save_to_slot(SAVE_SLOT) != OK:
		hud.show_message(LocalizationDB.translate_key(&"ui.save_failed"))
		return
	GameClock.set_paused(true)
	_show_menu()

func _autosave(sol: int) -> void:
	if sol % 7 == 0:
		SaveService.save_to_slot(SAVE_SLOT)

func _autosave_after_result(_result: StringName) -> void:
	SaveService.save_to_slot(SAVE_SLOT)

func _show_menu() -> void:
	menu.refresh_availability()
	menu.visible = true
	hud.visible = false
	world.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED

func _show_game() -> void:
	menu.visible = false
	world.visible = true
	world.process_mode = Node.PROCESS_MODE_INHERIT
	hud.visible = true
