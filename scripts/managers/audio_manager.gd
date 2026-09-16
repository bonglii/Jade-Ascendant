extends Node

## Two music voices crossfade; ten SFX voices are reused. Combat cues have
## independent cooldowns so rapid damage never starts hundreds of sounds.
const MUSIC: Dictionary = {
	"home": preload("res://assets/audio/celestial_gate.ogg"),
	"journey": preload("res://assets/audio/verdant_journey.ogg"),
	"boss": preload("res://assets/audio/sovereign_ritual.ogg"),
	"pavilion": preload("res://assets/audio/pavilion_celestial_ritual.ogg")
}
const SFX: Dictionary = {
	"ui": preload("res://assets/audio/ui.wav"), "pickup": preload("res://assets/audio/pickup.wav"),
	"shield": preload("res://assets/audio/shield.wav"), "claim": preload("res://assets/audio/claim.wav"),
	"equip": preload("res://assets/audio/equip.wav"), "sword": preload("res://assets/audio/sword.wav"),
	"fire": preload("res://assets/audio/fire.wav"), "thunder": preload("res://assets/audio/thunder.wav"),
	"chain": preload("res://assets/audio/chain.wav"), "hit": preload("res://assets/audio/hit.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"), "death": preload("res://assets/audio/death.wav"),
	"level": preload("res://assets/audio/level.wav"), "victory": preload("res://assets/audio/victory.wav"),
	"defeat": preload("res://assets/audio/defeat.wav"), "boss_defeat": preload("res://assets/audio/boss_defeat.wav"),
	"summon_charge": preload("res://assets/audio/summon_charge.wav"),
	"summon_rare": preload("res://assets/audio/summon_rare.wav"),
	"summon_epic": preload("res://assets/audio/summon_epic.wav"),
	"summon_legendary_omen": preload("res://assets/audio/summon_legendary_omen.wav"),
	"summon_legendary_reveal": preload("res://assets/audio/summon_legendary_reveal.wav"),
	"summon_new": preload("res://assets/audio/summon_new.wav"),
	"summon_duplicate": preload("res://assets/audio/summon_duplicate.wav")
}
var music_players: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer] = []
var cooldown_until: Dictionary = {}
var context: String = ""
var front: int = 0
var crossfade: Tween
var music_duck_tween: Tween
var scene_identity: String = ""
var backgrounded: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in range(2):
		var stream_player: AudioStreamPlayer = AudioStreamPlayer.new()
		stream_player.bus = &"Music"
		stream_player.volume_db = -60.0
		add_child(stream_player)
		music_players.append(stream_player)
	for index in range(10):
		var stream_player: AudioStreamPlayer = AudioStreamPlayer.new()
		stream_player.bus = &"SFX"
		add_child(stream_player)
		voices.append(stream_player)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)

func _connect_button(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	var callback: Callable = play_sfx.bind("ui")
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var identity: String = str(scene.get_instance_id())
	if identity != scene_identity:
		scene_identity = identity
		if scene.has_node("EnemySpawner"):
			set_context("journey")
		elif scene.scene_file_path.ends_with("pavilion_screen.tscn"):
			set_context("pavilion")
		elif not scene.scene_file_path.ends_with("loading_screen.tscn"):
			set_context("home")

func set_context(next_context: String) -> void:
	if context == next_context or not MUSIC.has(next_context) or music_players.is_empty():
		return
	context = next_context
	if crossfade != null and crossfade.is_valid():
		crossfade.kill()
	if music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	music_duck_tween = null
	var old_front: int = front
	front = 1 - front
	music_players[front].stream = MUSIC[context]
	if music_players[front].stream is AudioStreamOggVorbis:
		(music_players[front].stream as AudioStreamOggVorbis).loop = true
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
		if cue in ["hit", "death", "sword"]:
			voice.volume_db = -7.0
		elif cue == "summon_charge":
			voice.volume_db = -7.0
		elif cue == "summon_legendary_omen":
			voice.volume_db = -4.0
		elif cue == "summon_legendary_reveal":
			voice.volume_db = -1.0
		else:
			voice.volume_db = -3.0
		voice.pitch_scale = 1.0
		voice.play()
		return

func duck_music(duration: float, target_db: float = -28.0) -> void:
	if backgrounded or music_players.is_empty():
		return
	var player: AudioStreamPlayer = music_players[front]
	if not is_instance_valid(player) or not player.playing:
		return
	if music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	music_duck_tween = create_tween()
	music_duck_tween.tween_property(player, "volume_db", target_db, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	music_duck_tween.tween_interval(maxf(duration - 0.34, 0.0))
	music_duck_tween.tween_property(player, "volume_db", -11.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	music_duck_tween.tween_callback(_clear_music_duck)

func _clear_music_duck() -> void:
	music_duck_tween = null

## Releases active playback deterministically before SceneTree shutdown.
## This is also used by the strict Phase 0 smoke runner so short SFX/music
## cannot remain referenced while the engine prints its final leak report.
func release_runtime_audio() -> void:
	if crossfade != null and crossfade.is_valid():
		crossfade.kill()
	crossfade = null
	if music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	music_duck_tween = null

	for music_player in music_players:
		if not is_instance_valid(music_player):
			continue
		music_player.stop()
		music_player.stream_paused = false
		music_player.stream = null

	for voice in voices:
		if not is_instance_valid(voice):
			continue
		voice.stop()
		voice.stream_paused = false
		voice.stream = null

	cooldown_until.clear()
	context = ""
	scene_identity = ""
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
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		backgrounded = false
		for music_player in music_players:
			music_player.stream_paused = false
