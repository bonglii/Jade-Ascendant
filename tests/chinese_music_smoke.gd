extends SceneTree

var checks: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		push_error("CHINESE_MUSIC_FAIL: " + label)
		quit(1)
		assert(value, label)
	checks += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var audio: Node = root.get_node("AudioManager")
	check(audio.MUSIC.home == audio.MUSIC.pavilion, "menu shares one stream")
	check(audio.MUSIC.journey == audio.MUSIC.boss, "boss shares combat stream")
	check(audio.MUSIC.home != audio.MUSIC.journey, "combat has its own music")
	check(is_equal_approx(audio.MUSIC.home.get_length(), 64.0), "Lotus authored duration")
	check(absf(audio.MUSIC.journey.get_length() - 68.571354) < 0.001, "Dragon authored duration")
	audio.set_context("home")
	await create_timer(1.15).timeout
	var first: AudioStreamPlayer = audio.music_players[audio.front]
	var position: float = first.get_playback_position()
	check(first.playing and position > 0.5, "actual Ogg playback advances")
	audio.duck_music(1.2, -30.0)
	var duck: Tween = audio.music_duck_tween
	audio.set_context("pavilion")
	check(audio.music_players[audio.front] == first, "Pavilion keeps active player")
	check(first.get_playback_position() >= position - 0.03, "Pavilion does not rewind")
	check(audio.music_duck_tween == duck and duck.is_valid(), "menu switch keeps duck")
	await create_timer(0.15).timeout
	audio.set_context("home")
	check(audio.music_players[audio.front] == first, "return menu keeps player")
	check(first.get_playback_position() > position, "menu timeline continues")
	audio._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(first.stream_paused, "background pauses music")
	position = first.get_playback_position()
	await create_timer(0.16).timeout
	check(absf(first.get_playback_position() - position) < 0.06, "background does not advance")
	audio.set_context("pavilion")
	check(first.stream_paused and audio.music_players[audio.front] == first, "paused alias retains player")
	audio._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await create_timer(0.15).timeout
	check(not first.stream_paused and first.get_playback_position() > position, "resume continues timeline")
	audio.set_context("journey")
	var combat: AudioStreamPlayer = audio.music_players[audio.front]
	check(combat != first and combat.stream == audio.MUSIC.journey, "combat crossfade uses second player")
	await create_timer(1.15).timeout
	check(combat.playing and not first.playing, "old stream stops after crossfade")
	check(absf(combat.volume_db - audio.MUSIC_TARGET_DB) < 0.01, "restrained mix target")
	position = combat.get_playback_position()
	audio.set_context("boss")
	check(audio.music_players[audio.front] == combat and combat.get_playback_position() >= position - 0.03, "boss does not rewind combat")
	for stream: AudioStreamOggVorbis in [audio.MUSIC.home, audio.MUSIC.journey]:
		check(stream.loop, "authored Ogg loop enabled")
		combat.stop()
		combat.stream = stream
		combat.play(stream.get_length() - 0.15)
		await create_timer(0.45).timeout
		check(combat.playing and combat.get_playback_position() < 1.0, "real Ogg wraps without stopping")
	check(audio.SFX.sword[0].resource_path.contains("presentation_v2"), "restored weapon sound retained")
	check(audio._get_sfx_pitch("ui") == 1.0, "fixed touch pitch retained")
	audio.set_process(false)
	audio.release_runtime_audio()
	check(not first.playing and not combat.playing, "cleanup stops music")
	await create_timer(0.15).timeout
	audio.queue_free()
	call_deferred("finish")

func finish() -> void:
	await process_frame
	await process_frame
	print("CHINESE_MUSIC_RUNTIME=PASS; CHECKS=" + str(checks))
	quit()
