extends VBoxContainer
## Adaptador de las preferencias de Andrés al HUD actual de Rafael.

var _manager: Node
var _page_index: int = 0
var _pages: Array[VBoxContainer] = []
var _title: Label
var _resolution: OptionButton
var _language: OptionButton
var _fullscreen: CheckBox
var _audio_labels: Dictionary = {}
var _audio_sliders: Dictionary = {}

func _ready() -> void:
	_manager = get_node("/root/SettingsManager")
	add_theme_constant_override("separation", 10)
	var navigation := HBoxContainer.new()
	add_child(navigation)
	var previous := Button.new()
	previous.text = "‹"
	previous.tooltip_text = "Menú anterior"
	previous.pressed.connect(_change_page.bind(-1))
	navigation.add_child(previous)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_child(_title)
	var next := Button.new()
	next.text = "›"
	next.tooltip_text = "Siguiente menú"
	next.pressed.connect(_change_page.bind(1))
	navigation.add_child(next)
	for i: int in range(3):
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 8)
		add_child(page)
		_pages.append(page)
	for key: String in ["master", "music", "sfx"]:
		var label := Label.new()
		_pages[0].add_child(label)
		_audio_labels[key] = label
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size.y = 36
		_pages[0].add_child(slider)
		_audio_sliders[key] = slider
		slider.value_changed.connect(_set_sound.bind(key))
	_fullscreen = CheckBox.new()
	_fullscreen.text = "Pantalla completa"
	_fullscreen.toggled.connect(_manager.set_fullscreen)
	_pages[1].add_child(_fullscreen)
	_resolution = OptionButton.new()
	for value: Vector2i in _manager.get_resolution_options():
		_resolution.add_item("%d × %d" % [value.x, value.y])
	_resolution.item_selected.connect(_set_resolution)
	_pages[1].add_child(_resolution)
	_language = OptionButton.new()
	_language.add_item("Español")
	_language.add_item("Inglés")
	_language.item_selected.connect(_set_language)
	_pages[2].add_child(_language)
	_manager.language_changed.connect(_refresh)
	_manager.display_settings_changed.connect(_refresh)
	_manager.sound_settings_changed.connect(_refresh)
	_refresh()

func _change_page(direction: int) -> void:
	_page_index = posmod(_page_index + direction, 3)
	_refresh()

func _set_sound(value: float, key: String) -> void:
	_manager.set_sound_percentage(key, value)

func _set_resolution(index: int) -> void:
	_manager.set_resolution(_manager.get_resolution_options()[index])

func _set_language(index: int) -> void:
	_manager.set_language("es" if index == 0 else "en")

func _refresh() -> void:
	_title.text = _manager.translate_text(["Sonido", "Pantalla", "Idioma"][_page_index])
	for index: int in range(_pages.size()):
		_pages[index].visible = index == _page_index
	var sound: Dictionary = _manager.get_sound_percentages()
	for key: String in _audio_labels:
		var title: String = {"master": "Principal", "music": "Música", "sfx": "Efectos"}[key]
		_audio_labels[key].text = "%s: %d%%" % [_manager.translate_text(title), sound[key]]
		_audio_sliders[key].set_value_no_signal(sound[key])
	_fullscreen.set_pressed_no_signal(_manager.fullscreen)
	_resolution.disabled = _manager.fullscreen
	var resolutions: Array = _manager.get_resolution_options()
	var resolution_index := resolutions.find(_manager.resolution)
	if resolution_index >= 0:
		_resolution.select(resolution_index)
	_language.select(0 if _manager.language == "es" else 1)
	_manager.translate_tree(self)
