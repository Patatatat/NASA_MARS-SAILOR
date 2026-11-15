class_name SolReportView
extends PanelContainer

var report: SolReportService
var sol: int = 1
var _column: VBoxContainer

func _ready() -> void:
	_column = UiHelpers.column(self)
	SignalBus.language_changed.connect(func(_code): refresh())
	SignalBus.state_restored.connect(refresh)
	refresh()

func configure(service: SolReportService) -> void:
	report = service
	refresh()

func show_sol(value: int) -> void:
	sol = value
	refresh()

func refresh() -> void:
	if _column == null:
		return
	UiHelpers.clear(_column)
	_column.add_child(UiHelpers.label(_tr(&"report.what_changed_why"), 22))
	if report == null:
		return
	var data: Dictionary = report.get_report(sol)
	for category in ["production", "consumption", "balance"]:
		_column.add_child(UiHelpers.label(_tr(StringName("ui.report.%s" % category)), 22))
		_column.add_child(UiHelpers.label(UiHelpers.resource_text(data.get(category, {}))))
	for fact in data.get("explanations", []):
		_column.add_child(UiHelpers.label(_tr(StringName(fact.get("message_key", "")), fact.get("params", {}))))

func _tr(key: StringName, params: Dictionary = {}) -> String:
	return get_tree().root.get_node("LocalizationDB").translate_key(key, params)

