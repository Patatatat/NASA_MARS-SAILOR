class_name GuideCard
extends PanelContainer

signal focus_requested(target_id: StringName)

const ROBOT_TEXTURE: Texture2D = preload("res://assets/robot/Designer (7).png")

var dialogue: DialogueService
var _content: HBoxContainer

func _ready() -> void:
	theme = UiHelpers.mission_theme()
	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_content)
	SignalBus.guide_dialogue_changed.connect(func(_id, _state): refresh())
	SignalBus.log_entry_added.connect(func(_entry): refresh())
	SignalBus.language_changed.connect(func(_code): refresh())
	SignalBus.state_restored.connect(refresh)
	refresh()

func configure(service: DialogueService) -> void:
	dialogue = service
	refresh()

func refresh() -> void:
	if not is_instance_valid(_content):
		return
	UiHelpers.clear(_content)
	visible = false
	if dialogue == null:
		return
	var entry: Dictionary = dialogue.get_top_notice()
	if entry.is_empty():
		return
	# Critical entries remain active until the hazard is resolved, but "Got it"
	# should dismiss their popup. Keep the warning in the simulation and history.
	if entry.get("acknowledged", false):
		return
	if entry.get("kind") == "tutorial" and GameState.data.get("tutorial", {}).get("skipped", false):
		return
	visible = true
	var critical: bool = entry.get("kind") == "critical"
	_apply_card_style(critical)

	var portrait := TextureRect.new()
	portrait.texture = ROBOT_TEXTURE
	portrait.custom_minimum_size = Vector2(160.0, 140.0)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(portrait)

	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 8)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(text_column)

	var title := UiHelpers.label(_tr(&"ui.alert_title" if critical else &"ui.guide_title"), 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color("ffd29a") if critical else Color("a3dfd2")
	text_column.add_child(title)

	var message := UiHelpers.label(_tr(StringName(entry["message_key"]), entry.get("params", {})), 22)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_column.add_child(message)

	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 6)
	buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_child(buttons)
	if not String(entry.get("focus_target", "")).is_empty():
		buttons.add_child(UiHelpers.button(_tr(&"ui.focus"), func(): focus_requested.emit(StringName(entry["focus_target"])), true))
	buttons.add_child(UiHelpers.button(_tr(&"ui.acknowledge"), func(): _acknowledge(StringName(entry["id"]))))
	if entry.get("kind") == "tutorial":
		buttons.add_child(UiHelpers.button(_tr(&"dialogue.skip_tutorial"), func(): dialogue.skip_tutorial(); refresh()))

func _acknowledge(id: StringName) -> void:
	var result := dialogue.acknowledge(id)
	if result.ok:
		visible = false
	refresh()

func _apply_card_style(critical: bool) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.05, 0.07, 0.94)
	panel.border_color = Color("d79a5b") if critical else Color("73c7b7")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(18)
	panel.content_margin_left = 14.0
	panel.content_margin_right = 18.0
	panel.content_margin_top = 12.0
	panel.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", panel)

func _tr(key: StringName, params: Dictionary = {}) -> String:
	return get_tree().root.get_node("LocalizationDB").translate_key(key, params)
