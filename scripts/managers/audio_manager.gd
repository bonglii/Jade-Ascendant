extends Node

## Two music voices crossfade; chapter ambience adds realm identity without
## replacing the existing score. Ten SFX voices are reused. Combat cues have
## independent cooldowns so rapid damage never starts hundreds of sounds.
const MUSIC: Dictionary = {
	"home": preload("res://assets/audio/celestial_gate.ogg"),
	"journey": preload("res://assets/audio/verdant_journey.ogg"),
	"boss": preload("res://assets/audio/sovereign_ritual.ogg")
}
const CHAPTER_AMBIENCE: Dictionary = {
	"chapter_1": preload("res://assets/audio/ambience_verdant_valley.ogg"),
	"chapter_2": preload("res://assets/audio/ambience_crimson_moon.ogg"),
	"chapter_3": preload("res://assets/audio/ambience_nine_heavens.ogg")
}
const CHAPTER_AMBIENCE_DB: Dictionary = {
	"chapter_1": -23.0,
	"chapter_2": -22.0,
	"chapter_3": -24.0
}
const SFX: Dictionary = {
	"ui": preload("res://assets/audio/ui.wav"), "pickup": preload("res://assets/audio/pickup.wav"),
	"shield": preload("res://assets/audio/shield.wav"), "claim": preload("res://assets/audio/claim.wav"),
	"equip": preload("res://assets/audio/equip.wav"), "sword": preload("res://assets/audio/sword.wav"),
	"fire": preload("res://assets/audio/fire.wav"), "thunder": preload("res://assets/audio/thunder.wav"),
	"chain": preload("res://assets/audio/chain.wav"), "hit": preload("res://assets/audio/hit.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"), "death": preload("res://assets/audio/death.wav"),
	"level": preload("res://assets/audio/level.wav"), "victory": preload("res://assets/audio/victory.wav"),
	"defeat": preload("res://assets/audio/defeat.wav"), "boss_defeat": preload("res://assets/audio/boss_defeat.wav")
}

var music_players: Array[AudioStreamPlayer] = []
var ambience_players: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer] = []
var cooldown_until: Dictionary = {}
var context: String = ""
var front: int = 0
var ambience_front: int = 0
var crossfade: Tween
var ambience_crossfade: Tween
var scene_identity: String = ""
var chapter_audio_identity: String = ""
var backgrounded: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for index in range(2):
		var stream_player: AudioStreamPlayer = AudioStreamPlayer.new()
		stream_player.bus = &"Music"
		stream_player.volume_db = -60.0
		add_child(stream_player)
		music_players.append(stream_player)

	for index in range(2):
		var ambience_player: AudioStreamPlayer = AudioStreamPlayer.new()
		ambience_player.bus = &"Music"
		ambience_player.volume_db = -60.0
		add_child(ambience_player)
		ambience_players.append(ambience_player)

	for ambience_stream: AudioStream in CHAPTER_AMBIENCE.values():
		var ogg_stream: AudioStreamOggVorbis = ambience_stream as AudioStreamOggVorbis
		if ogg_stream != null:
			ogg_stream.loop = true

	for index in range(10):
		var stream_player: AudioStreamPlayer = AudioStreamPlayer.new()
		stream_player.bus = &"SFX"
		add_child(stream_player)
		voices.append(stream_player)

	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button.call_deferred(node)

func _connect_button(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var callback: Callable = play_sfx.bind("ui")
	if not node.is_connected("pressed", callback):
		node.connect("pressed", callback)

func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var identity: String = str(scene.get_instance_id())
	if identity == scene_identity:
		return

	scene_identity = identity
	if scene.scene_file_path.ends_with("loading_screen.tscn"):
		return

	_set_chapter_ambience(_resolve_chapter_audio_identity(scene.scene_file_path))
	if scene.has_node("EnemySpawner"):
		set_context("journey")
	else:
		set_context("home")

func _resolve_chapter_audio_identity(scene_path: String) -> String:
	if scene_path == "res://scenes/levels/level_1.tscn" or scene_path.contains("/stage_1_"):
		return "chapter_1"
	if scene_path.contains("/stage_2_"):
		return "chapter_2"
	if scene_path.contains("/stage_3_"):
		return "chapter_3"
	return ""

func _set_chapter_ambience(next_identity: String) -> void:
	if next_identity == chapter_audio_identity or ambience_players.is_empty():
		return

	if ambience_crossfade != null and ambience_crossfade.is_valid():
		ambience_crossfade.kill()
	ambience_crossfade = null

	for index in range(ambience_players.size()):
		if index != ambience_front:
			ambience_players[index].stop()
			ambience_players[index].stream = null

	if next_identity == "" or not CHAPTER_AMBIENCE.has(next_identity):
		chapter_audio_identity = ""
		var current_player: AudioStreamPlayer = ambience_players[ambience_front]
		if not current_player.playing:
			current_player.stream = null
			return
		ambience_crossfade = create_tween()
		ambience_crossfade.tween_property(current_player, "volume_db", -55.0, 0.7)
		ambience_crossfade.tween_callback(current_player.stop)
		ambience_crossfade.tween_callback(func() -> void: current_player.stream = null)
		return

	chapter_audio_identity = next_identity
	var old_front: int = ambience_front
	ambience_front = 1 - ambience_front
	var old_player: AudioStreamPlayer = ambience_players[old_front]
	var new_player: AudioStreamPlayer = ambience_players[ambience_front]
	new_player.stream = CHAPTER_AMBIENCE[next_identity]
	new_player.volume_db = -55.0
	new_player.pitch_scale = 1.0
	new_player.play()
	new_player.stream_paused = backgrounded

	var target_db: float = float(CHAPTER_AMBIENCE_DB.get(next_identity, -23.0))
	ambience_crossfade = create_tween().set_parallel(true)
	ambience_crossfade.tween_property(old_player, "volume_db", -55.0, 0.8)
	ambience_crossfade.tween_property(new_player, "volume_db", target_db, 1.1)
	ambience_crossfade.chain().tween_callback(old_player.stop)
	ambience_crossfade.chain().tween_callback(_clear_player_stream.bind(old_player))

func _clear_player_stream(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		player.stream = null

func set_context(next_context: String) -> void:
	if context == next_context or not MUSIC.has(next_context) or music_players.is_empty():
		return
	context = next_context
	if crossfade != null and crossfade.is_valid():
		crossfade.kill()
	var old_front: int = front
	front = 1 - front
	music_players[front].stream = MUSIC[context]
	music_players[front].volume_db = -55.0
	music_players[front].play()
	music_players[front].stream_paused = backgrounded
	crossfade = create_tween().set_parallel(true)
	crossfade.tween_property(music_players[old_front], "volume_db", -55.0, 0.65)
	crossfade.tween_property(music_players[front], "volume_db", -11.0, 0.8)
	crossfade.chain().tween_callback(music_players[old_front].stop)

func play_sfx(cue: String) -> void:
	if backgrounded or not SFX.has(cue):
		return
	var now: int = Time.get_ticks_msec()
	if now < int(cooldown_until.get(cue, 0)):
		return
	cooldown_until[cue] = now + (80 if cue in ["hit", "pickup", "death", "chain"] else 120)
	for voice in voices:
		if voice.playing:
			continue
		voice.stream = SFX[cue]
		voice.volume_db = -7.0 if cue in ["hit", "death", "sword"] else -3.0
		voice.pitch_scale = 1.0
		voice.play()
		return

## Releases active playback deterministically before SceneTree shutdown.
## This is also used by the strict Phase 0 smoke runner so short SFX/music
## cannot remain referenced while the engine prints its final leak report.
func release_runtime_audio() -> void:
	if crossfade != null and crossfade.is_valid():
		crossfade.kill()
	crossfade = null
	if ambience_crossfade != null and ambience_crossfade.is_valid():
		ambience_crossfade.kill()
	ambience_crossfade = null

	for music_player in music_players:
		if not is_instance_valid(music_player):
			continue
		music_player.stop()
		music_player.stream_paused = false
		music_player.stream = null

	for ambience_player in ambience_players:
		if not is_instance_valid(ambience_player):
			continue
		ambience_player.stop()
		ambience_player.stream_paused = false
		ambience_player.stream = null

	for voice in voices:
		if not is_instance_valid(voice):
			continue
		voice.stop()
		voice.stream_paused = false
		voice.stream = null

	cooldown_until.clear()
	context = ""
	scene_identity = ""
	chapter_audio_identity = ""
	backgrounded = false

func _exit_tree() -> void:
	release_runtime_audio()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		backgrounded = true
		for voice in voices:
			voice.stop()
		for music_player in music_players:
			music_player.stream_paused = true
		for ambience_player in ambience_players:
			ambience_player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		backgrounded = false
		for music_player in music_players:
			music_player.stream_paused = false
		for ambience_player in ambience_players:
			ambience_player.stream_paused = false
