class_name WeatherEffects
extends Control

# A bounded, deterministic visual layer. It never advances simulation RNG or time.
var dust_active := false
var flare_active := false
var phases: Dictionary = {}
var _animation_time := 0.0
var _signature := ""
var _badge: PanelContainer
var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_badge = PanelContainer.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.position = Vector2(12.0, 12.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.07, 0.94)
	style.border_color = Color("e8b47c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12.0)
	_badge.add_theme_stylebox_override("panel", style)
	add_child(_badge)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color("fff1d7"))
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_badge.add_child(_label)
	hide()

func sync_from_events(events: Dictionary, map_rect: Rect2, world_visible: bool) -> void:
	position = map_rect.position
	size = map_rect.size.max(Vector2.ONE)
	phases = {}
	for event in events.get("items", {}).values():
		var kind := String(event.get("type", ""))
		var phase := String(event.get("phase", "ended"))
		if kind in ["dust_storm", "solar_flare"] and phase in ["warning", "active"]:
			# Random event IDs are aliases: appearance follows type, not ID.
			if phases.get(kind, "") != "active":
				phases[kind] = phase
	dust_active = phases.get("dust_storm") == "active"
	flare_active = phases.get("solar_flare") == "active"
	visible = world_visible and not phases.is_empty()
	if not is_node_ready():
		return
	var signature := "%s:%s:%s" % [phases.get("dust_storm", ""), phases.get("solar_flare", ""), LocalizationDB.language]
	if signature != _signature:
		_signature = signature
		var lines: PackedStringArray = []
		for kind in ["dust_storm", "solar_flare"]:
			if phases.has(kind):
				lines.append(LocalizationDB.translate_key(StringName("weather.%s.%s" % [kind, phases[kind]])))
		_label.text = "\n".join(lines)
	_badge.size = Vector2(maxf(1.0, minf(440.0, size.x - 24.0)), 0.0)
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	if not bool(GameClock.get_snapshot().get("paused", false)):
		_animation_time = fmod(_animation_time + minf(delta, 0.1), 600.0)
	queue_redraw()

func _draw() -> void:
	if dust_active:
		# Sand travels in one direction; a translucent veil preserves map legibility.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.65, 0.32, 0.10, 0.12))
		for index in 72:
			var x := fposmod(float(index) * 137.51 + _animation_time * (110.0 + index % 5 * 12.0), size.x + 120.0) - 60.0
			var y := fposmod(float(index) * 73.31 + _animation_time * 12.0, size.y)
			var length := 14.0 + float(index % 6) * 9.0
			draw_line(Vector2(x, y), Vector2(x + length, y + length * 0.12), Color(0.98, 0.77, 0.46, 0.28), 1.5, true)
			if index % 4 == 0:
				draw_circle(Vector2(x, y), 2.0, Color(1.0, 0.69, 0.32, 0.26))
	if flare_active:
		# A slow glow and broad radiation arcs, without strobing or rapid flashes.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.25, 0.08, 0.07))
		var center := Vector2(size.x * 0.82, -size.y * 0.30)
		for index in 5:
			var radius := size.y * (0.45 + float(index) * 0.19) + sin(_animation_time * 0.6 + index) * 8.0
			draw_arc(center, radius, 0.12, PI - 0.12, 64, Color(1.0, 0.71, 0.36, 0.20), 3.0, true)
		for index in 8:
			var x := size.x * (float(index) + 0.5) / 8.0
			draw_line(Vector2(x, 0.0), Vector2(x - size.x * 0.12, size.y * 0.20), Color(1.0, 0.78, 0.48, 0.14), 2.0, true)
