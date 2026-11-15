class_name AudioController
extends Node

var _player: AudioStreamPlayer
var _priority: int = 0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = 0.3
	_player.stream = stream
	add_child(_player)
	SignalBus.event_changed.connect(_on_event)
	SignalBus.log_entry_added.connect(_on_log)
	SignalBus.building_changed.connect(_on_building)

func _on_event(_id: StringName, state: StringName) -> void:
	if state in [&"warning", &"active"]:
		play_notice(true)

func _on_log(entry: RefCounted) -> void:
	if entry is DialogueEntry:
		play_notice(entry.kind == &"critical")

func _on_building(_id: StringName, change_type: StringName) -> void:
	if change_type == &"damaged":
		play_notice(true)

func play_notice(critical: bool) -> void:
	var next_priority := 2 if critical else 1
	if _player.playing and next_priority < _priority:
		return
	_priority = next_priority
	_player.stop()
	var settings: Dictionary = get_tree().root.get_node("SettingsService").get_settings() if get_tree().root.has_node("SettingsService") else {}
	_player.volume_db = linear_to_db(maxf(0.001, float(settings.get("master_volume", 0.8)) * float(settings.get("sfx_volume", 0.8))))
	_player.play()
	var playback := _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var sample_count := 4400 if critical else 2200
	var frequency := 700.0 if critical else 440.0
	for index in sample_count:
		var fade := 1.0 - float(index) / float(sample_count)
		var wave := sin(TAU * frequency * float(index) / 22050.0) * fade * 0.12
		playback.push_frame(Vector2(wave, wave))

func get_priority() -> int:
	return _priority
