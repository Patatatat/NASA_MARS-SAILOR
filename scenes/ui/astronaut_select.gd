class_name AstronautSelect
extends PanelContainer

signal start_requested(profiles: Array[StringName])

var selected: Array[StringName] = []
var _content: VBoxContainer

func _ready() -> void:
	_content = UiHelpers.column(self)
	SignalBus.language_changed.connect(refresh)
	refresh()

func refresh(_language: StringName = &"") -> void:
	if _content == null:
		return
	UiHelpers.clear(_content)
	_content.add_child(UiHelpers.label(_tr(&"setup.select_crew.title"), 26))
	_content.add_child(UiHelpers.label(_tr(&"setup.select_crew.counter", {"selected": selected.size()})))
	var start := UiHelpers.button(_tr(&"setup.select_crew.start"), _start, true)
	start.disabled = selected.size() != 4
	start.tooltip_text = _tr(&"setup.select_crew.required") if start.disabled else _tr(&"ui.start_ready")
	_content.add_child(start)
	var slots := HFlowContainer.new()
	_content.add_child(slots)
	for index in 4:
		if index < selected.size():
			var slot := UiHelpers.button("%d. %s ×" % [index + 1, _tr(StringName("profile.%s" % selected[index]))], func(): selected.remove_at(index); refresh())
			slot.tooltip_text = _tr(&"ui.remove_crew_slot")
			slots.add_child(slot)
		else:
			slots.add_child(UiHelpers.label(_tr(&"ui.empty_crew_slot", {"number": index + 1})))
	_content.add_child(UiHelpers.label(_tr(&"ui.crew_select_help")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/crew/profiles.json"))
	for id in profiles:
		var row := UiHelpers.row(grid)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(UiHelpers.label(_tr(StringName("profile.%s" % id))))
		var add := UiHelpers.button("+", func(): add_profile(StringName(id)))
		add.custom_minimum_size.x = 48
		add.disabled = selected.size() == 4
		add.tooltip_text = _tr(StringName("profile.tip.%s" % id))
		row.tooltip_text = add.tooltip_text
		row.add_child(add)

func add_profile(id: StringName) -> void:
	if selected.size() < 4:
		selected.append(id)
		refresh()

func remove_last() -> void:
	if not selected.is_empty():
		selected.pop_back()
		refresh()

func _start() -> void:
	if selected.size() == 4:
		start_requested.emit(selected.duplicate())

func _tr(key: StringName, params: Dictionary = {}) -> String:
	return get_tree().root.get_node("LocalizationDB").translate_key(key, params)

