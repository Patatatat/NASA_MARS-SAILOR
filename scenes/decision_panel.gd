extends VBoxContainer
signal chosen(situation_id: String, option_id: String)
var _signature: String = ""
var _deadlines: Dictionary = {}
var _header: Label
var _cards: VBoxContainer

func _ready() -> void:
	_header = Label.new()
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_header)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 14)
	add_child(_cards)

func update_state(snapshot: Dictionary) -> void:
	var active: Array = []
	var queued := 0
	for s: Dictionary in snapshot.situations:
		if s.status == "active":
			active.append(s)
		elif s.status == "queued":
			queued += 1
	_header.text = "DECISIONES DE MISIÓN\nEl reloj continúa. No responder conserva el riesgo. %d en espera." % queued
	var signature := str(snapshot.run_generation) + str(active.map(func(s: Dictionary) -> String: return s.id))
	if signature != _signature:
		_signature = signature
		_deadlines.clear()
		for child: Node in _cards.get_children():
			_cards.remove_child(child)
			child.queue_free()
		if active.is_empty():
			var quiet := Label.new()
			quiet.text = "Sin crisis pendiente.\nReserva energía para la noche y material para reparar."
			quiet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_cards.add_child(quiet)
		for situation: Dictionary in active:
			var panel := PanelContainer.new()
			_cards.add_child(panel)
			var box := VBoxContainer.new()
			panel.add_child(box)
			var title := Label.new()
			title.text = situation.title
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			title.add_theme_color_override("font_color", Color("ffb778"))
			box.add_child(title)
			var deadline := Label.new()
			box.add_child(deadline)
			_deadlines[situation.id] = deadline
			for option: Dictionary in situation.options:
				var button := Button.new()
				button.text = option.title
				button.custom_minimum_size.y = 44
				button.pressed.connect(func() -> void: chosen.emit(situation.id, option.id))
				box.add_child(button)
				var consequence := Label.new()
				consequence.text = "Ahora: %s\nDespués: %s" % [option.effect, option.later]
				consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				box.add_child(consequence)
	for s: Dictionary in active:
		if _deadlines.has(s.id):
			_deadlines[s.id].text = "Ventana restante: %d s simulados" % maxi(0, s.deadline - snapshot.elapsed_seconds)
