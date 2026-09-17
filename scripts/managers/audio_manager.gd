extends Node

## Two music voices crossfade; ten SFX voices are reused. Combat cues have
## independent cooldowns so rapid damage never starts hundreds of sounds.
## Menu interaction audio is classified centrally so shared/dynamic buttons
## receive consistent feedback without coupling presentation screens to audio.
const MUSIC: Dictionary = {
	"home": preload("res://assets/audio/celestial_gate.ogg"),
	"journey": preload("res://assets/audio/verdant_journey.ogg"),
	"boss": preload("res://assets/audio/sovereign_ritual.ogg"),
	"pavilion": preload("res://assets/audio/pavilion_celestial_ritual.ogg")
}
const SFX: Dictionary = {
	"ui": preload("res://assets/audio/ui.wav"),
	"ui_tab": preload("res://assets/audio/ui_tab.wav"),
	"ui_confirm": preload("res://assets/audio/ui_confirm.wav"),
	"ui_back": preload("res://assets/audio/ui_back.wav"),
	"ui_locked": preload("res://assets/audio/ui_locked.wav"),
	"pickup": preload("res://assets/audio/pickup.wav"),
	"shield": preload("res://assets/audio/shield.wav"),
	"claim": preload("res://assets/audio/claim.wav"),
	"equip": preload("res://assets/audio/equip.wav"),
	"sword": preload("res://assets/audio/sword.wav"),
	"fire": preload("res://assets/audio/fire.wav"),
	"thunder": preload("res://assets/audio/thunder.wav"),
	"chain": preload("res://assets/audio/chain.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"),
	"death": preload("res://assets/audio/death.wav"),
	"level": preload("res://assets/audio/level.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"defeat": preload("res://assets/audio/defeat.wav"),
	"boss_defeat": preload("res://assets/audio/boss_defeat.wav"),
	"summon_charge": preload("res://assets/audio/summon_charge.wav"),
	"summon_rare": preload("res://assets/audio/summon_rare.wav"),
	"summon_epic": preload("res://assets/audio/summon_epic.wav"),
	"summon_legendary_omen": preload("res://assets/audio/summon_legendary_omen.wav"),
	"summon_legendary_reveal": preload("res://assets/audio/summon_legendary_reveal.wav"),
	"summon_new": preload("res://assets/audio/summon_new.wav"),
	"summon_duplicate": preload("res://assets/audio/summon_duplicate.wav")
}

const AUTO_UI_CUES: Array[String] = [
	"ui",
	"ui_tab",
	"ui_confirm",
	"ui_back",
	"ui_locked"
]
const SEMANTIC_UI_CUES: Array[String] = [
	"equip",
	"claim",
	"summon_charge",
	"summon_rare",
	"summon_epic",
	"summon_legendary_omen",
	"summon_legendary_reveal",
	"summon_new",
	"summon_duplicate"
]
const AUTO_UI_SUPPRESS_MSEC: int = 90

var music_players: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer] = []
var cooldown_until: Dictionary = {}
var context: String = ""
var front: int = 0
var crossfade: Tween
var music_duck_tween: Tween
var scene_identity: String = ""
var backgrounded: bool = false
var semantic_ui_until_msec: int = 0


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
	var callback: Callable = _on_ui_button_pressed.bind(button)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _on_ui_button_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	var cue: String = _resolve_button_sfx(button)
	# Run after the button's own handler. Successful semantic actions such as
	# equip/claim/summon can then suppress this automatic click and avoid doubles.
	call_deferred("_play_auto_ui_sfx", cue)


func _play_auto_ui_sfx(cue: String) -> void:
	if cue not in AUTO_UI_CUES:
		cue = "ui"
	if Time.get_ticks_msec() < semantic_ui_until_msec:
		return
	play_sfx(cue)


func _resolve_button_sfx(button: BaseButton) -> String:
	if button.has_meta("sfx_cue"):
		var explicit_cue: String = str(button.get_meta("sfx_cue"))
		if explicit_cue in AUTO_UI_CUES:
			return explicit_cue

	var name_key: String = str(button.name).to_upper()
	var text_key: String = ""
	if button is Button:
		text_key = (button as Button).text.to_upper()
	var tooltip_key: String = button.tooltip_text.to_upper()
	var identity: String = name_key + " " + text_key + " " + tooltip_key

	# Locked CTA feedback is only applied to controls that can actually emit
	# pressed. Disabled buttons keep Godot's normal no-input behavior.
	if (
		identity.contains("LOCKED")
		or identity.contains("SEALED")
		or identity.contains("UNAVAILABLE")
		or identity.contains("REQUIRES ")
	):
		return "ui_locked"

	if (
		name_key.contains("BACK")
		or name_key.contains("CLOSE")
		or name_key.contains("CANCEL")
		or text_key in ["BACK", "CLOSE", "CANCEL", "RETURN"]
		or text_key.begins_with("BACK ")
		or text_key.begins_with("RETURN ")
	):
		return "ui_back"

	if (
		name_key.ends_with("TAB")
		or name_key.contains("FILTER")
		or name_key.contains("RARITYBUTTON")
		or name_key.contains("SLOTBUTTON")
		or name_key.contains("CATEGORY")
	):
		return "ui_tab"

	for keyword: String in [
		"START",
		"ENTER",
		"CONTINUE",
		"CONFIRM",
		"SUMMON",
		"MEDITATE",
		"ASCEND",
		"UPGRADE",
		"PURCHASE",
		"BUY",
		"CLAIM",
		"EQUIP",
		"UNEQUIP",
		"SET WISH",
		"SELECT"
	]:
		if identity.contains(keyword):
			return "ui_confirm"

	return "ui"


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
	if cue in SEMANTIC_UI_CUES:
		semantic_ui_until_msec = maxi(
			semantic_ui_until_msec,
			now + AUTO_UI_SUPPRESS_MSEC
		)
	if now < int(cooldown_until.get(cue, 0)):
		return
	cooldown_until[cue] = now + _get_sfx_cooldown_msec(cue)
	for voice in voices:
		if voice.playing:
			continue
		voice.stream = SFX[cue]
		voice.volume_db = _get_sfx_volume_db(cue)
		voice.pitch_scale = _get_sfx_pitch(cue)
		voice.play()
		return


func _get_sfx_cooldown_msec(cue: String) -> int:
	match cue:
		"ui":
			return 70
		"ui_tab":
			return 85
		"ui_confirm", "ui_back":
			return 100
		"ui_locked":
			return 150
		"hit", "pickup", "death", "chain":
			return 80
		_:
			return 120


func _get_sfx_volume_db(cue: String) -> float:
	match cue:
		"hit", "death", "sword":
			return -7.0
		"summon_charge":
			return -7.0
		"summon_legendary_omen":
			return -4.0
		"summon_legendary_reveal":
			return -1.0
		"ui_tab", "ui_back":
			return -5.0
		"ui_locked":
			return -4.5
		"ui":
			return -4.0
		_:
			return -3.0


func _get_sfx_pitch(cue: String) -> float:
	match cue:
		"ui_tab":
			return 1.035
		"ui_back":
			return 0.97
		"ui_locked":
			return 0.94
		_:
			return 1.0


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
	semantic_ui_until_msec = 0


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
