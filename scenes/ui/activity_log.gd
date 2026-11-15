class_name ActivityLog
extends PanelContainer

var dialogue: DialogueService
var _list: VBoxContainer
var _filter: StringName = &"all"
var _title: Label
var _filters: Dictionary = {}

func _ready() -> void:
	var column := UiHelpers.column(self)
	_title = UiHelpers.label(_tr(&"hud.activity_log"), 20)
	column.add_child(_title)
	var filters := HFlowContainer.new()
	column.add_child(filters)
	for id in [&"all", &"operational", &"science", &"ambient"]:
		var filter_button := UiHelpers.button(_tr(StringName("ui.filter.%s" % id)), func(): _filter = id; refresh())
		_filters[String(id)] = filter_button
		filters.add_child(filter_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = UiHelpers.column(scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SignalBus.log_entry_added.connect(func(_entry): refresh())
	SignalBus.language_changed.connect(func(_code): refresh())
	SignalBus.state_restored.connect(refresh)
	refresh()

func configure(service: DialogueService) -> void:
	dialogue = service
	refresh()

func refresh() -> void:
	if _list == null:
		return
	_title.text = _tr(&"hud.activity_log")
	for id in _filters:
		_filters[id].text = _tr(StringName("ui.filter.%s" % id))
	UiHelpers.clear(_list)
	if dialogue == null:
		return
	for entry in dialogue.get_entries():
		if _filter != &"all" and entry.get("kind") != String(_filter) and entry.get("kind") != "critical":
			continue
		_list.add_child(UiHelpers.label("[%s] %s" % [entry.get("created_sol", 1), _tr(StringName(entry["message_key"]), entry.get("params", {}))], 14))

func _tr(key: StringName, params: Dictionary = {}) -> String:
	return get_tree().root.get_node("LocalizationDB").translate_key(key, params)

