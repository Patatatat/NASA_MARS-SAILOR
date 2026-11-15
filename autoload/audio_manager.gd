extends Node

const TRACKS := {
	&"menu": "res://assets/audio/Project_Mars_Menu_Theme.wav",
	&"selection": "res://assets/audio/Project_Mars_Character_Selection.wav",
	&"gameplay_1": "res://assets/audio/Project_Mars_Gameplay_1.wav",
	&"gameplay_2": "res://assets/audio/Project_Mars_Gameplay_2.wav",
	&"event": "res://assets/audio/Project_Mars_Event.wav",
	&"notification": "res://assets/audio/Project_Mars_Button-Notification.wav",
	&"upgrade": "res://assets/audio/Project_Mars_FX_Upgrade.wav",
	&"stage": "res://assets/audio/Project_Mars_FX_Stage.wav"
}
const GAMEPLAY: Array[StringName] = [&"gameplay_1", &"gameplay_2"]

var music: AudioStreamPlayer
var ui_sound: AudioStreamPlayer
var notification_player: AudioStreamPlayer
var effect: AudioStreamPlayer
var context: StringName = &"menu"
var current_track: StringName = &""
var gameplay_index := 0
var _streams: Dictionary = {}
var _positions: Dictionary = {}
var _effect_priority := 0
var _notice_priority := 0
var _last_click_msec := -1000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = _make_player("Music")
	ui_sound = _make_player("Buttons")
	notification_player = _make_player("Notifications")
	effect = _make_player("Milestones")
	music.finished.connect(_on_music_finished)
	effect.finished.connect(func(): _effect_priority = 0)
	notification_player.finished.connect(func(): _notice_priority = 0)
	SettingsService.settings_changed.connect(_apply_volumes)
	SignalBus.state_restored.connect(_on_state_restored)
	SignalBus.event_changed.connect(_on_event)
	SignalBus.research_changed.connect(_on_research)
	SignalBus.rocket_changed.connect(_on_rocket)
	SignalBus.game_over.connect(_on_game_over)
	get_tree().node_added.connect(_observe_button)
	_apply_volumes()
	_refresh_music()

func _make_player(label: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	add_child(player)
	return player

func _stream(id: StringName) -> AudioStream:
	if not _streams.has(id):
		var stream := load(TRACKS[id]) as AudioStream
		if stream is AudioStreamWAV:
			# Playlist changes depend on the real finished signal, never per-file loops.
			stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		_streams[id] = stream
	return _streams[id]

func set_context(next: StringName) -> void:
	if next not in [&"menu", &"selection", &"gameplay"]:
		return
	context = next
	_refresh_music()

func reset_gameplay_playlist() -> void:
	if context == &"gameplay":
		music.stop()
	gameplay_index = 0
	for id in GAMEPLAY:
		_positions[id] = 0.0
	_positions[&"event"] = 0.0

func _refresh_music() -> void:
	var next := context
	if context == &"gameplay":
		next = &"event" if _has_active_event() else GAMEPLAY[gameplay_index]
	if next == current_track and music.playing:
		return
	if music.playing:
		_positions[current_track] = music.get_playback_position()
	current_track = next
	music.stop()
	music.stream = _stream(next)
	if music.stream != null:
		music.play(float(_positions.get(next, 0.0)))

func _on_music_finished() -> void:
	_positions[current_track] = 0.0
	if context == &"gameplay" and current_track in GAMEPLAY:
		gameplay_index = (gameplay_index + 1) % GAMEPLAY.size()
	_refresh_music()

func _has_active_event() -> bool:
	if not GameState.is_running():
		return false
	for item in GameState.data.get("events", {}).get("items", {}).values():
		if item.get("phase") == "active":
			return true
	return false

func _apply_volumes() -> void:
	var values := SettingsService.get_settings()
	var master := float(values.get("master_volume", 0.8))
	music.volume_linear = master * float(values.get("ambient_volume", 0.45))
	for player in [ui_sound, notification_player, effect]:
		player.volume_linear = master * float(values.get("sfx_volume", 0.8))

func _on_state_restored() -> void:
	_apply_volumes()
	_refresh_music()

func _observe_button(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(play_button):
		node.pressed.connect(play_button)

func play_button() -> void:
	# A single voice avoids stacking the 2.85-second sound during fast navigation.
	var now := Time.get_ticks_msec()
	if now - _last_click_msec < 70:
		return
	_last_click_msec = now
	ui_sound.stream = _stream(&"notification")
	ui_sound.play()

func play_notice(critical: bool) -> void:
	var priority := 2 if critical else 1
	if notification_player.playing and priority < _notice_priority:
		return
	_notice_priority = priority
	notification_player.stream = _stream(&"notification")
	notification_player.play()

func play_milestone(id: StringName) -> void:
	if id not in [&"stage", &"upgrade"] or context != &"gameplay":
		return
	var priority := 2 if id == &"upgrade" else 1
	if effect.playing and priority < _effect_priority:
		return
	_effect_priority = priority
	effect.stream = _stream(id)
	effect.play()

func _on_event(_id: StringName, phase: StringName) -> void:
	if context == &"gameplay" and phase in [&"warning", &"active"]:
		play_notice(true)
	if phase == &"active":
		_positions[&"event"] = 0.0
	_refresh_music()

func _on_research(_id: StringName, phase: StringName) -> void:
	if phase == &"unlocked":
		play_milestone(&"upgrade")
	elif phase == &"sector_revealed":
		play_milestone(&"stage")

func _on_rocket(_id: StringName, phase: StringName) -> void:
	if phase == &"landed":
		play_milestone(&"stage")

func _on_game_over(_result: StringName) -> void:
	play_milestone(&"stage")
	_refresh_music()
