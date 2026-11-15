extends Node

var checks := 0
var failures: Array[String] = []
var main: MissionMain
var tracks: Array[Dictionary] = []
var capture: AudioEffectCapture

func _ready() -> void:
	main = preload("res://scenes/integration/main.tscn").instantiate()
	add_child(main)
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)

func wait_audio(seconds: float = 0.2) -> void:
	await get_tree().create_timer(seconds).timeout

func peak() -> float:
	var samples := capture.get_buffer(capture.get_frames_available())
	var result := 0.0
	for sample in samples:
		result = maxf(result, maxf(absf(sample.x), absf(sample.y)))
	return result

func run() -> void:
	SettingsService.apply_settings({"master_volume": 0.8, "ambient_volume": 0.5, "sfx_volume": 0.5})
	for id in AudioManager.TRACKS:
		var stream := AudioManager._stream(id)
		check(stream != null and stream.get_length() > 0.5, "provided audio imports and decodes: " + String(id))
		if stream != null:
			tracks.append({"id": id, "file": AudioManager.TRACKS[id], "seconds": stream.get_length()})
	check(AudioManager.current_track == &"menu" and AudioManager.music.playing, "main menu plays its theme")
	check(is_equal_approx(AudioManager.music.volume_linear, 0.4), "music combines master and music preferences")
	# Capture the engine's mixed output to verify actual decoded sound, not just flags.
	capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, capture)
	AudioManager.music.play(10.0)
	await wait_audio()
	var music_peak := peak()
	check(music_peak > 0.0001, "menu music produces non-silent mixed audio")
	main.menu._show_select()
	check(AudioManager.current_track == &"selection", "selection plays its own theme")
	AudioManager.music.play(15.0)
	await wait_audio()
	var selection_position := AudioManager.music.get_playback_position()
	SettingsService.apply_settings({"language": "en"})
	await wait_audio()
	check(AudioManager.current_track == &"selection" and AudioManager.music.get_playback_position() >= selection_position, "language refresh does not restart music")
	main.menu.show_main_menu()
	check(AudioManager.current_track == &"menu", "back restores menu theme")
	main.menu._show_settings()
	check(AudioManager.current_track == &"menu", "settings retain menu music")
	main.menu._return_from_settings()
	main.menu._new_game_button.pressed.emit()
	check(AudioManager.ui_sound.playing, "real button signal plays supplied button sound")
	main._start_new([&"medic", &"engineer_a", &"scientist_a", &"botanist_a"])
	GameClock.set_paused(true)
	check(AudioManager.current_track == &"gameplay_1", "new mission starts the first gameplay track")
	check(AudioManager.effect.stream == AudioManager._stream(&"stage") and AudioManager.effect.playing, "mission start plays stage sound")
	AudioManager.music.play(20.0)
	await wait_audio()
	var gameplay_position := AudioManager.music.get_playback_position()
	main._open_pause_menu()
	await wait_audio()
	check(AudioManager.current_track == &"gameplay_1" and AudioManager.music.get_playback_position() > gameplay_position, "music continues in pause menu")
	main._close_pause_menu()
	# Seek near the end; let the real audio backend emit finished naturally.
	AudioManager.music.play(AudioManager.music.stream.get_length() - 0.12)
	await wait_audio(0.65)
	check(AudioManager.current_track == &"gameplay_2" and AudioManager.music.playing, "natural end of gameplay 1 starts gameplay 2")
	AudioManager.music.play(AudioManager.music.stream.get_length() - 0.12)
	await wait_audio(0.65)
	check(AudioManager.current_track == &"gameplay_1" and AudioManager.music.playing, "natural end of gameplay 2 returns to gameplay 1")
	AudioManager.music.play(25.0)
	await wait_audio()
	gameplay_position = AudioManager.music.get_playback_position()
	check(main.events.trigger_event(&"dust_storm").ok, "event starts through real service")
	check(AudioManager.current_track == &"event", "active event replaces normal gameplay theme")
	check(AudioManager.notification_player.stream == AudioManager._stream(&"notification"), "event uses supplied notification_player sound")
	main.events.clear_event(&"dust_storm")
	check(AudioManager.current_track == &"gameplay_1" and AudioManager.music.get_playback_position() >= gameplay_position - 0.1, "event end resumes interrupted gameplay position")
	main.events.on_sol_started(11)
	check(AudioManager.current_track == &"gameplay_1", "warning alone does not interrupt gameplay music")
	SignalBus.research_changed.emit(&"solar_panel", &"unlocked")
	check(AudioManager.effect.stream == AudioManager._stream(&"upgrade") and AudioManager.effect.playing, "research completion uses upgrade sound")
	AudioManager.effect.stop()
	SignalBus.rocket_changed.emit(&"rocket_1", &"landed")
	check(AudioManager.effect.stream == AudioManager._stream(&"stage"), "rocket landing uses stage sound")
	SettingsService.apply_settings({"ambient_volume": 0.0})
	check(is_zero_approx(AudioManager.music.volume_linear), "music slider can completely mute music")
	check(AudioManager.effect.volume_linear > 0.0, "muting music leaves SFX available")
	SettingsService.apply_settings({"ambient_volume": 1.0, "sfx_volume": 0.0})
	check(is_zero_approx(AudioManager.ui_sound.volume_linear) and is_zero_approx(AudioManager.effect.volume_linear) and is_zero_approx(AudioManager.notification_player.volume_linear), "SFX slider mutes every effects channel")
	check(AudioManager.music.volume_linear > 0.0, "muting SFX leaves music available")
	SettingsService.apply_settings({"master_volume": 0.0})
	# Discard the previous audio block while the backend applies its gain ramp.
	await wait_audio(0.15)
	capture.clear_buffer()
	await wait_audio(0.3)
	var muted_peak := peak()
	check(is_zero_approx(muted_peak), "master zero produces true digital silence")
	SettingsService.apply_settings({"master_volume": 0.8, "ambient_volume": 0.45, "sfx_volume": 0.8})
	main._return_to_menu()
	check(AudioManager.current_track == &"menu", "return to menu restores the menu theme")
	main._continue_game()
	check(AudioManager.current_track in AudioManager.GAMEPLAY, "continue restores gameplay music")
	var saved := SaveService.export_state()
	GameState.data["events"]["items"]["random_25"] = {"id": "random_25", "type": "solar_flare", "phase": "active"}
	SignalBus.state_restored.emit()
	check(AudioManager.current_track == &"event", "restored random event selects event theme by phase")
	check(SaveService.import_state(saved) == OK, "regular save reloads")
	check(AudioManager.current_track in AudioManager.GAMEPLAY, "loading clear weather restores gameplay playlist")
	var before := JSON.stringify(GameState.to_dict())
	AudioManager.set_context(&"menu")
	AudioManager.set_context(&"gameplay")
	check(JSON.stringify(GameState.to_dict()) == before, "music transitions never mutate the simulation or RNG")
	# Menu/selection themes loop on actual completion too.
	AudioManager.set_context(&"selection")
	AudioManager.music.play(AudioManager.music.stream.get_length() - 0.12)
	await wait_audio(0.65)
	check(AudioManager.current_track == &"selection" and AudioManager.music.playing and AudioManager.music.get_playback_position() < 2.0, "selection theme loops without stopping")
	main._start_new([&"medic", &"engineer_a", &"scientist_a", &"botanist_a"])
	GameClock.set_paused(true)
	check(AudioManager.current_track == &"gameplay_1" and AudioManager.music.get_playback_position() < 2.0, "new mission resets the gameplay playlist")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "tracks": tracks, "audio_driver": AudioServer.get_driver_name(), "music_peak": music_peak, "muted_peak": muted_peak}
	var output := FileAccess.open("user://audio-result.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("AUDIO QA: ", JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
