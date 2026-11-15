class_name FinalResultView
extends Control

signal menu_requested()

var _title: Label
var _description: Label
var _menu: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.06, 0.88)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	center.add_child(card)
	var column := UiHelpers.column(card)
	_title = UiHelpers.label("", 32)
	column.add_child(_title)
	_description = UiHelpers.label("")
	_description.custom_minimum_size.x = 480
	column.add_child(_description)
	_menu = UiHelpers.button("", func(): menu_requested.emit(), true)
	column.add_child(_menu)
	SignalBus.game_over.connect(show_result)
	SignalBus.language_changed.connect(func(_code): refresh())
	SignalBus.state_restored.connect(refresh)
	refresh()

func show_result(_result: StringName) -> void:
	refresh()

func refresh() -> void:
	if _title == null:
		return
	var result := String(GameState.data.get("result", ""))
	visible = not result.is_empty()
	if visible:
		_title.text = UiHelpers.translated(StringName("ui.result_title.%s" % result))
		_description.text = UiHelpers.translated(StringName("result.%s" % result))
		_menu.text = UiHelpers.translated(&"ui.main_menu")
