class_name GuideCard
extends PanelContainer

signal focus_requested(target_id: StringName)

var dialogue: DialogueService
var _column: VBoxContainer

func _ready() -> void:
	_column = UiHelpers.column(self)
	SignalBus.guide_dialogue_changed.connect(func(_id, _state): refresh())
	SignalBus.log_entry_added.connect(func(_entry): refresh())
	SignalBus.language_changed.connect(func(_code): refresh())
	SignalBus.state_restored.connect(refresh)
	refresh()

func configure(service: DialogueService) -> void:
	dialogue = service
	refresh()

func refresh() -> void:
	if _column == null:
		return
	UiHelpers.clear(_column)
	visible = false
	if dialogue == null:
		return
	var entry: Dictionary = dialogue.get_top_notice()
	if entry.is_empty():
		return
	if entry.get("kind") == "tutorial" and GameState.data.get("tutorial", {}).get("skipped", false):
		return
	visible = true
	var critical: bool = entry.get("kind") == "critical"
	var layout := UiHelpers.row(_column)
	var text := UiHelpers.column(layout)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UiHelpers.label(_tr(&"ui.alert_title" if critical else &"ui.guide_title"), 20)
	title.modulate = Color("ffd29a") if critical else Color("a3dfd2")
	text.add_child(title)
	text.add_child(UiHelpers.label(_tr(StringName(entry["message_key"]), entry.get("params", {}))))
	var buttons := UiHelpers.row(layout)
	if not String(entry.get("focus_target", "")).is_empty():
		buttons.add_child(UiHelpers.button(_tr(&"ui.focus"), func(): focus_requested.emit(StringName(entry["focus_target"])), true))
	buttons.add_child(UiHelpers.button(_tr(&"ui.acknowledge"), func(): dialogue.acknowledge(StringName(entry["id"])); refresh()))
	if entry.get("kind") == "tutorial":
		buttons.add_child(UiHelpers.button(_tr(&"dialogue.skip_tutorial"), func(): dialogue.skip_tutorial(); refresh()))

func _tr(key: StringName, params: Dictionary = {}) -> String:
	return get_tree().root.get_node("LocalizationDB").translate_key(key, params)

