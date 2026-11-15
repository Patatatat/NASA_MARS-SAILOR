extends Node
## Persists player preferences shared by menus and the simulation.

signal language_changed
signal display_settings_changed
signal sound_settings_changed

const SETTINGS_PATH := "user://mars_sinner_settings.cfg"
const WORD_CHARACTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_ÁÉÍÓÚÜÑáéíóúüñ"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(800, 600),
	Vector2i(1024, 768),
	Vector2i(1100, 760),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1440, 810),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]
const ES_TO_EN: Dictionary = {
	"Base": "Base",
	"Resumen": "Summary",
	"Ajustes": "Settings",
	"Sostenibilidad": "Sustainability",
	"Supervivencia": "Survival",
	"Resiliencia": "Resilience",
	"AJUSTES": "SETTINGS",
	"VOLVER": "BACK",
	"JUGAR": "PLAY",
	"CÓMO JUGAR": "HOW TO PLAY",
	"CRÉDITOS": "CREDITS",
	"MarSins | Banco de simulación · tablero 3D isométrico": "MarSins | Simulation lab · isometric 3D board",
	"La tripulación se elige en su escena y puedes cambiarla con el botón superior. Pulsa una celda vacía para abrir construcciones.\nLas celdas oscurecidas forman el espacio reservado de cada edificio. Pulsa una huella ocupada para inspeccionarla y encender/apagar.\nCámara: A/D o ←/→ giran; W/S o ↑/↓ acercan/alejan. También puedes arrastrar con el botón derecho o usar la rueda.\nEspacio inicia/pausa, Esc o Tab abre el sonido, y R reinicia.": "Choose your crew in its scene; change it with the top button. Select an empty tile to open construction options.\nDarkened tiles show each building's reserved space. Select an occupied footprint to inspect it and toggle power.\nCamera: A/D or ←/→ rotate; W/S or ↑/↓ zoom. You can also drag with the right mouse button or use the wheel.\nSpace starts/pauses, Esc or Tab opens settings, and R resets.",
	"Sonido": "Sound",
	"Pantalla": "Display",
	"Idioma": "Language",
	"Español": "Spanish",
	"Inglés": "English",
	"Pantalla completa": "Fullscreen",
	"Resolución": "Resolution",
	"Ajustes de pantalla": "Display settings",
	"Selecciona un idioma": "Select a language",
	"Solar": "Solar",
	"Reactor": "Reactor",
	"Generador de oxígeno": "Oxygen generator",
	"Invernadero": "Greenhouse",
	"Laboratorio": "Laboratory",
	"HÁBITAT": "HABITAT",
	"OXÍGENO": "OXYGEN",
	"CULTIVO": "GREENHOUSE",
	"Hielo → agua": "Ice → water",
	"Cantera → regolito": "Quarry → regolith",
	"Restos → masa": "Wreckage → mass",
	"Principal": "Master",
	"Música": "Music",
	"Efectos": "SFX",
	"VOLUMEN PRINCIPAL": "MASTER VOLUME",
	"VOLUMEN DE MÚSICA": "MUSIC VOLUME",
	"EFECTOS DE SONIDO": "SFX VOLUME",
	"Selecciona tu tripulación": "Select your crew",
	"Elige exactamente cuatro especialistas para iniciar la misión.": "Choose exactly four specialists to start the mission.",
	"Ingeniería": "Engineering",
	"Medicina": "Medicine",
	"Medicina*": "Medicine*",
	"Botánica": "Botany",
	"Ciencia": "Science",
	"Ciencia*": "Science*",
	"Geología": "Geology",
	"Geología*": "Geology*",
	"Sistemas": "Systems",
	"* Efectos de medicina, ciencia y geología aún pendientes.": "* Medicine, science, and geology effects are not implemented yet.",
	"Continuar a la simulación  →": "Continue to simulation  →",
	"Especialistas seleccionados: ": "Specialists selected: ",
	"Tripulación: ": "Crew: ",
	"Cambiar tripulación": "Change crew",
	"Volver a la selección de personajes": "Return to crew selection",
	"Masa": "Mass",
	"Aire": "Air",
	"Agua": "Water",
	"Comida": "Food",
	"Oxígeno": "Oxygen",
	"Alimento": "Food",
	"Suma de reservas de agua y comida": "Combined water and food reserves",
	"Energía": "Energy",
	"Soles transcurridos": "Sols elapsed",
	"Inspector del edificio": "Building inspector",
	"Tripulación e historial": "Crew and history",
	"Eventos · radiación · refugio": "Events · radiation · shelter",
	"Expediciones ROBERT": "ROBERT expeditions",
	"Mejoras": "Upgrades",
	"Mantenimiento · controles provisionales": "Maintenance · temporary controls",
	"Informe por sol": "Sol report",
	"Enterrar hábitat": "Bury habitat",
	"Enviar": "Send",
	"Mejorar": "Upgrade",
	"Atender": "Service",
	"Probar éxito": "Test success",
	"Probar fallo": "Test failure",
	"Abandonar": "Abandon",
	"Reactivar": "Reactivate",
	"Construir": "Build",
	"Cerrar": "Close",
	"Sin edificio seleccionado": "No building selected",
	"Selecciona una construcción en el tablero para ver sus datos.": "Select a building on the board to view its details.",
	"Selecciona una construcción para consultar sus últimos hechos.": "Select a building to view its latest events.",
	"Construye un edificio para ver su costo y duración de mejora.": "Build a structure to see its upgrade cost and duration.",
	"Construye un reactor u oxigenador para habilitar mantenimiento.": "Build a reactor or oxygen generator to enable maintenance.",
	"Aún no hay un sol completo; el informe se actualiza al final de cada sol.": "No full sol yet; the report updates at the end of each sol.",
	"Iniciar partida": "Start game",
	"Pausar simulación": "Pause simulation",
	"Continuar simulación": "Resume simulation",
	"Partida terminada": "Game over",
	"R para reiniciar": "R to restart",
	"faltan": "remaining",
	"soporte": "support",
	"retorno en": "return in",
	"Velocidad de simulación": "Simulation speed",
	"Opciones de sonido": "Sound options",
	"Cerrar opciones de sonido": "Close settings",
	"Cerrar opciones": "Close settings",
	"Menú anterior": "Previous menu",
	"Siguiente menú": "Next menu",
	"La resolución se elige en modo ventana.": "Resolution applies in windowed mode.",
	"El juego incrustado no puede cambiar el modo de pantalla. Desactiva Embed Game on Next Play para probarlo.": "The embedded game cannot change display mode. Disable Embed Game on Next Play to test it.",
	"Error de configuración: ": "Configuration error: ",
	"Cuesta 10 masa y 20 regolito; el trabajo tarda 25 segundos": "Costs 10 mass and 20 regolith; takes 25 seconds",
	"Enviar el ROBERT seleccionado a la expedición": "Send the selected ROBERT on the expedition",
	"Resultado temporal; falta integrar el minijuego de mantenimiento": "Temporary result; maintenance minigame integration is pending",
	"Girar izquierda": "Rotate left",
	"Girar derecha": "Rotate right",
	"Acercar": "Zoom in",
	"Alejar": "Zoom out",
	"Restablecer vista": "Reset view",
	"Reiniciar partida": "Restart game",
	"Nivel de acercamiento": "Zoom level",
	"Nivel": "Level",
	"por sol": "per sol",
	"sin evento activo": "no active event",
	"Último informe": "Latest report",
	"variación": "change",
	"reservas": "reserves",
	"Producción": "Production",
	"consumo": "consumption",
	"importaciones": "imports",
	"Déficits": "Deficits",
	"bloqueos": "blocked time",
	"parcial": "partial",
	"ON": "ON",
	"OFF": "OFF",
	"Opciones": "Options",
	"Menú de opciones": "Options menu",
	"Espacio": "Space",
	"Masa insuficiente": "Insufficient mass",
	"masa insuficiente": "insufficient mass",
	"reactor muy cerca": "reactor too close",
	"partida no disponible": "game unavailable",
	"fuera del mapa": "outside the map",
	"espacio fuera del mapa": "footprint outside the map",
	"espacio ocupado": "space occupied",
	"no disponible": "unavailable",
	"disponible": "available",
	"perdido": "lost",
	"en misión": "on mission",
	"Regolito": "Regolith",
	"FINAL": "FINAL",
	"Últimos hechos": "Recent events",
	"salud": "health",
	"dosis": "dose",
	"comida": "food",
	"agua": "water",
	"activo": "active",
	"inactivo": "inactive",
	"superficie": "surface",
	"energizado": "powered",
	"sin potencia": "no power",
	"ninguno": "none",
	"Historial": "History",
	"Pronóstico": "Forecast",
	"tormenta": "storm",
	"partículas solares": "solar particles",
	"Evento: ": "Event: ",
	"Refugio": "Shelter",
	"hábitat": "habitat",
	"dosis del equipo": "crew dose",
	"Entrar al refugio": "Enter shelter",
	"Salir del refugio": "Leave shelter",
	"Hábitat enterrado": "Habitat buried",
	"Enterrando": "Burying",
	"Construir en": "Build at",
	"masa": "mass",
	"costo": "cost",
	"salida bloqueada": "departure blocked",
	"Salida bloqueada": "Departure blocked",
	"misión a": "mission to",
	"Vista previa": "Preview",
	"Carga prevista": "Expected cargo",
	"riesgo actual": "current risk",
	"puede cambiar con tormentas": "may change with storms",
	"Costo": "Cost",
	"trabajo": "work",
	"estimado con la tripulación actual": "estimated with current crew",
	"edad": "age",
	"intentos": "attempts",
	"Potencia": "Power",
	"demanda": "demand",
	"Estado": "Status",
	"aviso": "warning",
	"Apagar": "Turn off",
	"Encender": "Turn on",
	"Selecciona una construcción": "Select a building",
	"Soles transcurridos: ": "Sols elapsed: ",
	"Energía: ": "Energy: ",
	"Suministro eléctrico disponible / demanda eléctrica": "Available power supply / power demand",
	"Selecciona un edificio construido para mejorar.": "Select a built structure to upgrade.",
	"Construye un reactor o generador de oxígeno antes de atender mantenimiento.": "Build a reactor or oxygen generator before servicing maintenance.",
	"Primero pulsa Atender para iniciar una sesión de mantenimiento.": "Press Service first to start a maintenance session.",
	"Selecciona un reactor o generador de oxígeno.": "Select a reactor or oxygen generator.",
	"Esta acción no está disponible en esta fase de la partida.": "This action is unavailable in the current game phase.",
	"Ese tipo de construcción no está disponible.": "That type of structure is unavailable.",
	"La casilla está fuera del tablero.": "The tile is outside the board.",
	"La huella completa del edificio sale del tablero.": "The full building footprint extends beyond the board.",
	"Parte de esa huella ya está ocupada por otro edificio.": "Part of that footprint is already occupied by another building.",
	"El reactor debe estar al menos a dos casillas del hábitat.": "The reactor must be at least two tiles away from the habitat.",
	"No se encontró ese ROBERT.": "That ROBERT was not found.",
	"No se encontró ese destino de expedición.": "That expedition destination was not found.",
	"El laboratorio debe estar terminado, encendido y con potencia.": "The laboratory must be complete, powered on, and supplied with power.",
	"No hay suficiente potencia libre.": "There is not enough available power.",
	"Este ROBERT está en misión o se perdió.": "This ROBERT is on a mission or has been lost.",
	"Sal del refugio antes de iniciar una expedición o mejora.": "Leave the shelter before starting an expedition or upgrade.",
	"No hay suficiente masa para esta acción.": "There is not enough mass for this action.",
	"Este edificio ya está en nivel 2.": "This building is already at level 2.",
	"Este edificio ya tiene una mejora en curso.": "This building already has an upgrade in progress.",
	"Espera a que termine la construcción.": "Wait for construction to finish.",
	"El hábitat se protege mediante Enterrar y no admite mejora.": "The habitat is protected by burial and cannot be upgraded.",
	"Este edificio no tiene mantenimiento pendiente.": "This building has no pending maintenance.",
	"La sesión se suspendió por una crisis o por el refugio.": "The session was suspended by a crisis or sheltering.",
	"Se agotaron los intentos o el tiempo disponible.": "Attempts or available time have run out.",
	"Espera a que termine el enfriamiento para reactivar.": "Wait for cooldown to finish before reactivating.",
	"Este edificio no está apagado por mantenimiento.": "This building is not shut down for maintenance.",
	"Ya hay una sesión de este edificio abierta.": "A session for this building is already open.",
	"Termina la otra sesión de mantenimiento antes de abrir esta.": "Finish the other maintenance session before opening this one.",
	"Esta sesión ya se cerró o venció.": "This session is already closed or expired.",
	"No hay una sesión de mantenimiento vigente.": "There is no active maintenance session.",
	"El enterramiento del hábitat ya comenzó.": "Habitat burial has already started.",
	"Falta masa o regolito para enterrar el hábitat.": "More mass or regolith is needed to bury the habitat.",
	"El hábitat principal no se puede apagar.": "The main habitat cannot be powered off.",
	"Continuar a la simulación": "Continue to simulation"
}
const EN_TO_ES: Dictionary = {
	"SETTINGS": "AJUSTES",
	"BACK": "VOLVER",
	"PLAY": "JUGAR",
	"HOW TO PLAY": "CÓMO JUGAR",
	"CREDITS": "CRÉDITOS",
	"MASTER VOLUME": "VOLUMEN PRINCIPAL",
	"MUSIC VOLUME": "VOLUMEN DE MÚSICA",
	"SFX VOLUME": "EFECTOS DE SONIDO",
	"SFX": "Efectos"
}

var language := "es"
var fullscreen := false
var resolution := Vector2i(1440, 810)
var sound_percentages: Dictionary = {"master": 0, "music": 0, "sfx": 0}
var _config := ConfigFile.new()

func _ready() -> void:
	var load_error := _config.load(SETTINGS_PATH)
	if load_error == OK:
		language = str(_config.get_value("general", "language", "es"))
		if language not in ["es", "en"]:
			language = "es"
		fullscreen = bool(_config.get_value("display", "fullscreen", false))
		var saved_resolution: Variant = _config.get_value("display", "resolution", Vector2i(1440, 810))
		if saved_resolution is Vector2i:
			resolution = saved_resolution
		var saved_sound: Variant = _config.get_value("audio", "percentages", sound_percentages)
		if saved_sound is Dictionary:
			for key: String in sound_percentages.keys():
				sound_percentages[key] = clampi(roundi(float(saved_sound.get(key, 0))), 0, 100)
	_apply_display_settings()
	_apply_sound_settings()

func get_resolution_options() -> Array[Vector2i]:
	return RESOLUTIONS.duplicate()

func is_game_window_embedded() -> bool:
	var window := get_tree().root as Window
	return window != null and window.is_embedded()

func set_language(value: String) -> void:
	if value not in ["es", "en"] or language == value:
		return
	language = value
	_config.set_value("general", "language", language)
	_save()
	language_changed.emit()

func set_fullscreen(value: bool) -> void:
	if fullscreen == value:
		return
	fullscreen = value
	_config.set_value("display", "fullscreen", fullscreen)
	_save()
	_apply_display_settings()
	display_settings_changed.emit()

func set_resolution(value: Vector2i) -> void:
	if value.x <= 0 or value.y <= 0:
		return
	resolution = value
	_config.set_value("display", "resolution", resolution)
	_save()
	_apply_display_settings()
	display_settings_changed.emit()

func get_sound_percentages() -> Dictionary:
	return sound_percentages.duplicate(true)

func set_sound_percentage(key: String, value: float) -> void:
	if not sound_percentages.has(key):
		return
	sound_percentages[key] = clampi(roundi(value), 0, 100)
	_config.set_value("audio", "percentages", sound_percentages.duplicate(true))
	_save()
	_apply_sound_settings()
	sound_settings_changed.emit()

func _apply_sound_settings() -> void:
	for key: String in ["master", "music", "sfx"]:
		var bus_name: String = {"master": "Master", "music": "Music", "sfx": "SFX"}[key]
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
		var volume := float(sound_percentages[key]) / 100.0
		AudioServer.set_bus_mute(index, volume <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))

func translate_text(source: String) -> String:
	var translated := source
	if language == "en":
		for phrase: String in ES_TO_EN:
			translated = _replace_translation_phrase(translated, phrase, str(ES_TO_EN[phrase]))
	else:
		for phrase: String in EN_TO_ES:
			translated = _replace_translation_phrase(translated, phrase, str(EN_TO_ES[phrase]))
		for phrase: String in ES_TO_EN:
			var translated_phrase := str(ES_TO_EN[phrase])
			if translated_phrase != phrase:
				translated = _replace_translation_phrase(translated, translated_phrase, phrase)
	return translated

func _replace_translation_phrase(source: String, phrase: String, replacement: String) -> String:
	if phrase.is_empty():
		return source
	var result := source
	var search_from := 0
	var first_character := phrase.substr(0, 1)
	var last_character := phrase.substr(phrase.length() - 1, 1)
	while search_from <= result.length():
		var match_start := result.find(phrase, search_from)
		if match_start < 0:
			break
		var match_end := match_start + phrase.length()
		var left_boundary := true
		if WORD_CHARACTERS.contains(first_character) and match_start > 0:
			left_boundary = not WORD_CHARACTERS.contains(result.substr(match_start - 1, 1))
		var right_boundary := true
		if WORD_CHARACTERS.contains(last_character) and match_end < result.length():
			right_boundary = not WORD_CHARACTERS.contains(result.substr(match_end, 1))
		if left_boundary and right_boundary:
			result = result.substr(0, match_start) + replacement + result.substr(match_end)
			search_from = match_start + replacement.length()
		else:
			search_from = match_end
	return result

func translate_tree(node: Node) -> void:
	if node is OptionButton:
		var option := node as OptionButton
		for index: int in range(option.item_count):
			option.set_item_text(index, translate_text(option.get_item_text(index)))
	elif node is Label:
		var label := node as Label
		label.text = translate_text(label.text)
		label.tooltip_text = translate_text(label.tooltip_text)
	elif node is TextEdit:
		var text_edit := node as TextEdit
		var vertical_scroll := text_edit.scroll_vertical
		var horizontal_scroll := text_edit.scroll_horizontal
		text_edit.text = translate_text(text_edit.text)
		text_edit.scroll_vertical = vertical_scroll
		text_edit.scroll_horizontal = horizontal_scroll
	elif node is Button:
		var button := node as Button
		button.text = translate_text(button.text)
		button.tooltip_text = translate_text(button.tooltip_text)
	for child: Node in node.get_children():
		translate_tree(child)

func _apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_tree().root as Window
	if window == null:
		return
	# The editor-embedded game has no independent OS window to resize or center.
	# Keep the preference saved and apply it when the game runs in its own window.
	if window.is_embedded():
		return
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = resolution
		window.move_to_center()

func _save() -> void:
	var save_error := _config.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("No se pudo guardar la configuración: %s" % error_string(save_error))
