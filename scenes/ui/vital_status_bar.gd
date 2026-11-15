class_name VitalStatusBar
extends HFlowContainer

var services: Dictionary = {}
var _labels: Dictionary = {}
var _refresh_queued := false

func _ready() -> void:
	for id in ["oxygen", "water", "food", "power", "pressure", "morale", "autonomy"]:
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("183047")
		style.set_corner_radius_all(8)
		style.set_content_margin_all(6)
		card.add_theme_stylebox_override("panel", style)
		add_child(card)
		var label_node := UiHelpers.label("", 18)
		label_node.autowrap_mode = TextServer.AUTOWRAP_OFF
		label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_labels[id] = label_node
		card.add_child(label_node)
	SignalBus.language_changed.connect(func(_code): refresh())
	SignalBus.resources_changed.connect(func(_delta, _reason): request_refresh())
	SignalBus.energy_changed.connect(func(_snapshot): request_refresh())
	SignalBus.crew_changed.connect(func(_id): request_refresh())
	SignalBus.sol_ended.connect(func(_sol): request_refresh())
	refresh()

func configure(dependencies: Dictionary) -> void:
	services = dependencies
	refresh()

func request_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_deferred_refresh")

func _deferred_refresh() -> void:
	_refresh_queued = false
	refresh()

func refresh() -> void:
	if _labels.is_empty():
		return
	var inventory: Dictionary = services["ledger"].get_snapshot() if services.has("ledger") else {}
	var local := get_tree().root.get_node("LocalizationDB")
	for id in ["oxygen", "water", "food"]:
		_labels[id].text = "%s %s" % [local.translate_key(StringName("resource.%s" % id)), String.num(float(inventory.get(id, 0.0)), 1).trim_suffix(".0")]
		_labels[id].tooltip_text = local.translate_key(&"ui.supply_tip")
	var energy: Dictionary = services["power"].get_snapshot().as_dict() if services.has("power") else {}
	_labels["power"].text = local.translate_key(&"tab.energy") + " %.0f / %.0f" % [float(energy.get("generation", 0.0)), float(energy.get("demand", 0.0))]
	_labels["power"].tooltip_text = local.translate_key(&"ui.power_tip") + "\n" + local.translate_key(&"hud.power_flow", {"generation": energy.get("generation", 0.0), "demand": energy.get("demand", 0.0), "stored": energy.get("stored", 0.0), "capacity": energy.get("capacity", 0.0)})
	var support: Dictionary = services["life_support"].get_status() if services.has("life_support") else {}
	var leaking := float(support.get("oxygen_leak_per_sol", 0.0)) > 0.0
	_labels["pressure"].text = "%s %s" % [local.translate_key(&"hud.pressure"), "! " + local.translate_key(&"ui.warning") if leaking else local.translate_key(&"ui.normal")]
	_labels["pressure"].modulate = Color("ffd29a") if leaking else Color.WHITE
	var crew: Array = services["crew"].get_snapshot() if services.has("crew") else []
	var sum_morale := 0.0
	var count := 0
	for member in crew:
		if member.get("alive", false):
			sum_morale += float(member.get("morale", 0.0))
			count += 1
	_labels["morale"].text = "%s %.0f" % [local.translate_key(&"ui.morale_short"), sum_morale / count if count > 0 else 0.0]
	var autonomy: Dictionary = GameState.data.get("autonomy", {})
	_labels["autonomy"].text = local.translate_key(&"ui.autonomy_short") + " " + ("%.0f%%" % float(autonomy.get("percent", 0.0)) if not autonomy.is_empty() else "—")
	_labels["autonomy"].tooltip_text = local.translate_key(&"ui.autonomy_tip")

