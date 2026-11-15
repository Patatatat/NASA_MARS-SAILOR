class_name UiHelpers
extends RefCounted

static func label(text_value: String, size: int = 18) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", maxi(18, size))
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

static func button(text_value: String, action: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text_value
	node.custom_minimum_size = Vector2(96, 44)
	if primary:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("246b61")
		style.set_corner_radius_all(8)
		style.set_content_margin_all(12)
		node.add_theme_stylebox_override("normal", style)
	node.pressed.connect(action)
	return node

static func translated(key: StringName, params: Dictionary = {}) -> String:
	return Engine.get_main_loop().root.get_node("LocalizationDB").translate_key(key, params)

static func resource_text(values: Dictionary) -> String:
	if values.is_empty():
		return translated(&"ui.none")
	var parts: Array[String] = []
	for id in values:
		var key := StringName("resource.%s" % id)
		if id in ["stored_energy", "research"]:
			key = StringName("ui.%s" % id)
		parts.append("%s %s" % [String.num(float(values[id]), 1).trim_suffix(".0"), translated(key)])
	return " · ".join(parts)

static func entity_name(id: String) -> String:
	var parts := id.rsplit("_", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int():
		if parts[0] in ["crew", "rocket"]:
			return translated(StringName("ui.%s_name" % parts[0]), {"number": parts[1]})
		return "%s %s" % [translated(StringName("building.%s" % parts[0])), parts[1]]
	return id

static func technology_name(id: String) -> String:
	if id.is_empty():
		return translated(&"ui.none")
	if ConfigDB.balance.get("buildings", {}).has(id):
		return translated(StringName("building.%s" % id))
	return translated(StringName("technology.%s" % id))

static func row(parent: Node) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", 8)
	parent.add_child(node)
	return node

static func column(parent: Node) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", 8)
	parent.add_child(node)
	return node

static func clear(parent: Node) -> void:
	for child in parent.get_children():
		_disconnect_observers(child)
		parent.remove_child(child)
		child.queue_free()

static func _disconnect_observers(node: Node) -> void:
	# Removed pages live until frame end. They must not receive language/state
	# changes in that interval, when get_tree() is already unavailable.
	for connection in node.get_incoming_connections():
		var source: Signal = connection["signal"]
		if source.get_object() in [SignalBus, SettingsService]:
			source.disconnect(connection["callable"])
	for child in node.get_children():
		_disconnect_observers(child)

static func mission_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 18
	for type in ["Button", "OptionButton", "LineEdit", "Label", "PopupMenu"]:
		result.set_font_size("font_size", type, 18)
	result.set_constant("scrollbar_width", "VScrollBar", 16)
	result.set_color("font_color", "Label", Color("f4efe5"))
	result.set_color("font_color", "Button", Color("fff7e9"))
	result.set_color("font_hover_color", "Button", Color("ffffff"))
	result.set_color("font_disabled_color", "Button", Color("9c9aa0"))
	result.set_color("font_pressed_color", "Button", Color("17202b"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.045, 0.085, 0.14, 0.98)
	panel.border_color = Color("47627a")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(14)
	result.set_stylebox("panel", "PanelContainer", panel)
	var button := StyleBoxFlat.new()
	button.bg_color = Color("8a4b45")
	button.set_corner_radius_all(6)
	button.set_content_margin_all(12)
	button.content_margin_top = 8
	button.content_margin_bottom = 8
	result.set_stylebox("normal", "Button", button)
	var hover := button.duplicate() as StyleBoxFlat
	hover.bg_color = Color("995047")
	result.set_stylebox("hover", "Button", hover)
	var pressed := button.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("d68462")
	result.set_stylebox("pressed", "Button", pressed)
	var disabled := button.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("514d53")
	result.set_stylebox("disabled", "Button", disabled)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("ffe3a1")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(8)
	for type in ["Button", "OptionButton", "LineEdit"]:
		result.set_stylebox("focus", type, focus)
		if type != "Button":
			var input_style := panel.duplicate() as StyleBoxFlat
			input_style.content_margin_top = 12
			input_style.content_margin_bottom = 12
			result.set_stylebox("normal", type, input_style)
			result.set_stylebox("hover", type, hover.duplicate())
	return result
