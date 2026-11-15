extends VBoxContainer
## Dos intervenciones jugables; el dominio valida sesión, tiempo y repetición.
signal submitted(success: bool)
var _session: String = ""
var _title: Label
var _clock: Label
var _slider: HSlider
var _coefficients: Array[SpinBox] = []
var _confirm: Button
var _target: float = 0.0
var _kind: String = ""

func _ready() -> void:
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_title)
	_clock = Label.new()
	add_child(_clock)
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = 40
	_slider.step = 0.1
	_slider.custom_minimum_size.y = 44
	add_child(_slider)
	var row := HBoxContainer.new()
	add_child(row)
	for molecule: String in ["CO₂ →", "CO +", "O₂"]:
		var input := SpinBox.new()
		input.min_value = 1
		input.max_value = 6
		input.prefix = molecule
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(input)
		_coefficients.append(input)
	_confirm = Button.new()
	_confirm.text = "Confirmar intervención"
	_confirm.custom_minimum_size.y = 44
	_confirm.pressed.connect(_submit)
	add_child(_confirm)
	hide()

func update_session(snapshot: Dictionary, id: String) -> void:
	var maintenance: Dictionary = {}
	for b: Dictionary in snapshot.buildings:
		if b.maintenance.session.get("id") == id and not id.is_empty():
			maintenance = b.maintenance
	if maintenance.is_empty() or maintenance.session.get("state") not in ["active", "suspended"]:
		hide()
		return
	show()
	if _session != id:
		_session = id
		_kind = maintenance.session.minigame_id
		_target = snappedf(clampf(snapshot.power.demand, 1, 35), 0.1)
		_slider.value = 0
		for input: SpinBox in _coefficients:
			input.value = 1
	_slider.visible = _kind == "load_balance"
	_coefficients[0].get_parent().visible = _kind != "load_balance"
	_title.text = "Equilibra la carga: ajusta %.1f unidades. Tu ajuste: %.1f\nTolerancia ±5%%. Modelo educativo; no es operación de un reactor." % [_target, _slider.value] if _kind == "load_balance" else "Conserva los átomos: ajusta los coeficientes mínimos de CO₂ → CO + O₂."
	_clock.text = "%s · %.1f / 15 s · intento %d/2" % ["Suspendido por crisis / refugio" if maintenance.session.state == "suspended" else "Intervención activa", maintenance.elapsed_real_seconds, maintenance.attempts]
	_confirm.disabled = maintenance.session.state != "active"

func _submit() -> void:
	if _confirm.disabled:
		return
	var success := absf(_slider.value - _target) <= maxf(0.1, _target * 0.05) if _kind == "load_balance" else (int(_coefficients[0].value) == 2 and int(_coefficients[1].value) == 2 and int(_coefficients[2].value) == 1)
	_confirm.disabled = true
	submitted.emit(success)
