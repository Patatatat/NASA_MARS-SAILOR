class_name MissionHud
extends Control

signal save_requested()
signal menu_requested()

var services: Dictionary = {}
var world: Node
var _vitals: VitalStatusBar
var _workspace: MissionWorkspace
var _inspector: BuildingInspector
var _guide: GuideCard
var _log: ActivityLog
var _report: SolReportView
var _admin: AdminPanel
var _final: FinalResultView
var _save_button: Button
var _menu_button: Button
var _map_space: Control
var _dock: VBoxContainer
var _dock_title: Label
var _back: Button
var _views: Dictionary = {}
var _toolbar: Dictionary = {}
var _active_panel: StringName = &"workspace"
var _time: TimeControls

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiHelpers.mission_theme()
	mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	var column := UiHelpers.column(margin)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	var status := PanelContainer.new()
	column.add_child(status)
	var status_column := UiHelpers.column(status)
	_vitals = VitalStatusBar.new()
	status_column.add_child(_vitals)
	_time = TimeControls.new()
	status_column.add_child(_time)
	var center := UiHelpers.row(column)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_space = Control.new()
	_map_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(_map_space)
	_dock = UiHelpers.column(center)
	var navigation := UiHelpers.row(_dock)
	_back = UiHelpers.button("", func(): show_panel(&"workspace"))
	navigation.add_child(_back)
	_dock_title = UiHelpers.label("", 22)
	navigation.add_child(_dock_title)
	var close := UiHelpers.button("×", close_panel)
	close.custom_minimum_size.x = 44
	close.tooltip_text = UiHelpers.translated(&"ui.close_panel")
	navigation.add_child(close)
	_workspace = MissionWorkspace.new()
	_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.add_child(_workspace)
	_workspace._tab_picker.reparent(navigation)
	navigation.move_child(_workspace._tab_picker, 0)
	_workspace._tab_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_views["workspace"] = _workspace
	_inspector = BuildingInspector.new()
	_mount_view("inspector", _inspector)
	_report = SolReportView.new()
	_mount_view("report", _report)
	_log = ActivityLog.new()
	_mount_view("log", _log)
	_admin = AdminPanel.new()
	_mount_view("admin", _admin)
	_guide = GuideCard.new()
	column.add_child(_guide)
	var footer := HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", 8)
	footer.add_theme_constant_override("v_separation", 6)
	column.add_child(footer)
	for id in ["tools", "report", "log", "help", "demo"]:
		var item := UiHelpers.button("", func(): _toolbar_action(id))
		_toolbar[id] = item
		footer.add_child(item)
	_save_button = UiHelpers.button("", func(): save_requested.emit())
	_menu_button = UiHelpers.button("", func(): menu_requested.emit())
	footer.add_child(_save_button)
	footer.add_child(_menu_button)
	_final = FinalResultView.new()
	add_child(_final)
	_final.menu_requested.connect(func(): menu_requested.emit())
	add_child(AudioController.new())
	SignalBus.language_changed.connect(_refresh_buttons)
	SignalBus.state_restored.connect(rebuild_from_state)
	SignalBus.game_over.connect(func(_result): rebuild_from_state())
	_workspace.tab_opened.connect(func(_id): show_panel(&"workspace"))
	_guide.focus_requested.connect(focus_target)
	resized.connect(_layout)
	_map_space.resized.connect(func(): call_deferred("_update_camera"))
	_refresh_buttons()
	show_panel(&"workspace")
	configure(services, world)
	_layout()

func _mount_view(id: String, view: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.add_child(scroll)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(view)
	_views[id] = scroll

func show_panel(id: StringName) -> void:
	if not _views.has(String(id)):
		return
	_active_panel = id
	_dock.show()
	for key in _views:
		_views[key].visible = key == String(id)
	_back.visible = id != &"workspace"
	_dock_title.visible = id != &"workspace"
	_workspace._tab_picker.visible = id == &"workspace"
	_dock_title.text = UiHelpers.translated(StringName("ui.panel.%s" % id))
	call_deferred("_update_camera")

func close_panel() -> void:
	_dock.hide()
	if world != null:
		world.cancel_placement()
	call_deferred("_update_camera")

func _toolbar_action(id: String) -> void:
	match id:
		"tools": show_panel(&"workspace")
		"report":
			_report.show_sol(maxi(1, int(GameClock.get_snapshot().get("sol", 1)) - 1))
			show_panel(&"report")
		"log": show_panel(&"log")
		"demo": show_panel(&"admin")
		"help":
			show_panel(&"workspace")
			_workspace.open_tab(&"codex")

func _layout() -> void:
	if _dock == null:
		return
	_dock.custom_minimum_size.x = clampf(size.x * 0.35, 360.0, 460.0)
	call_deferred("_update_camera")

func _update_camera() -> void:
	if world != null and is_instance_valid(_map_space) and size.x > 0.0 and size.y > 0.0:
		var rect := _map_space.get_global_rect()
		world.camera_rig.set_map_view(Rect2(rect.position / size, rect.size / size))

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is OptionButton:
		return
	if event.keycode == KEY_ESCAPE:
		close_panel()
	elif event.keycode == KEY_SPACE:
		_time._toggle_pause()
	else:
		return
	get_viewport().set_input_as_handled()

func configure(dependencies: Dictionary, world_node: Node = null) -> void:
	services = dependencies
	world = world_node
	if _vitals == null:
		return
	_vitals.configure(dependencies)
	_workspace.configure(dependencies)
	_workspace.set_world(world)
	_inspector.configure(dependencies)
	_admin.configure(dependencies)
	if dependencies.has("dialogue"):
		_log.configure(dependencies["dialogue"])
		_guide.configure(dependencies["dialogue"])
	if dependencies.has("report"):
		_report.configure(dependencies["report"])
	if world != null and not world.target_selected.is_connected(_on_target_selected):
		world.target_selected.connect(_on_target_selected)
	if world != null and not world.placement_requested.is_connected(_workspace.apply_placement):
		world.placement_requested.connect(_workspace.apply_placement)
	rebuild_from_state()
	call_deferred("_update_camera")

func _on_target_selected(id: StringName) -> void:
	_inspector.show_target(id)
	if _inspector.visible:
		show_panel(&"inspector")

func focus_target(id: StringName) -> void:
	if String(id).begins_with("ui:workspace_"):
		_workspace.open_tab(StringName(String(id).trim_prefix("ui:workspace_")))
	elif id == &"ui:time_controls":
		_time._pause.grab_focus()
	elif id == &"world:scan_sector":
		_workspace.open_tab(&"laboratory")
	elif world != null:
		world.focus_target(id)

func rebuild_from_state() -> void:
	if _vitals == null:
		return
	_vitals.refresh()
	_workspace.refresh()
	_inspector.refresh()
	_log.refresh()
	_guide.refresh()
	_report.refresh()
	_final.refresh()
	_time.refresh()

func show_message(value: String) -> void:
	_workspace._feedback.text = value
	_workspace._feedback.show()
	show_panel(&"workspace")

func _refresh_buttons(_code: StringName = &"") -> void:
	if _save_button == null:
		return
	_save_button.text = UiHelpers.translated(&"ui.save_game")
	_menu_button.text = UiHelpers.translated(&"ui.main_menu")
	for id in _toolbar:
		_toolbar[id].text = UiHelpers.translated(StringName("ui.toolbar.%s" % id))
	_dock_title.text = UiHelpers.translated(StringName("ui.panel.%s" % _active_panel))
	_back.text = UiHelpers.translated(&"ui.tools_back")
