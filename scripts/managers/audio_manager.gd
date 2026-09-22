extends Node

## Jade Ascendant Audio Identity V2
##
## Goals:
## - every active runtime cue is routed through one coherent xianxia palette;
## - frequent sounds rotate through authored variants instead of repeating one file;
## - UI browsing is tactile again, while semantic actions suppress duplicate clicks;
## - major reward/result cues automatically create room in the music mix;
## - existing call sites keep their cue names, so gameplay logic is unchanged.

const AUDIO_ROOT: String = "res://assets/audio/presentation_v2/"
const MUSIC_TARGET_DB: float = -18.5
const MUSIC_OFF_DB: float = -55.0

const MUSIC: Dictionary = {
	"home": preload("res://assets/audio/presentation_v2/music_home.ogg"),
	"journey": preload("res://assets/audio/presentation_v2/music_journey.ogg"),
	"boss": preload("res://assets/audio/presentation_v2/music_boss.ogg"),
	"pavilion": preload("res://assets/audio/presentation_v2/music_pavilion.ogg")
}

const SFX: Dictionary = {
	"ui": [
		preload("res://assets/audio/presentation_v2/ui_tap_01.wav"),
		preload("res://assets/audio/presentation_v2/ui_tap_02.wav")
	],
	"ui_tab": [
		preload("res://assets/audio/presentation_v2/ui_tab_01.wav"),
		preload("res://assets/audio/presentation_v2/ui_tab_02.wav")
	],
	"ui_confirm": [
		preload("res://assets/audio/presentation_v2/ui_confirm_01.wav"),
		preload("res://assets/audio/presentation_v2/ui_confirm_02.wav")
	],
	"ui_back": [
		preload("res://assets/audio/presentation_v2/ui_back_01.wav"),
		preload("res://assets/audio/presentation_v2/ui_back_02.wav")
	],
	"ui_locked": [
		preload("res://assets/audio/presentation_v2/ui_locked_01.wav"),
		preload("res://assets/audio/presentation_v2/ui_locked_02.wav")
	],
	"pickup": [
		preload("res://assets/audio/presentation_v2/pickup_jade_01.wav"),
		preload("res://assets/audio/presentation_v2/pickup_jade_02.wav"),
		preload("res://assets/audio/presentation_v2/pickup_jade_03.wav")
	],
	"shield": [
		preload("res://assets/audio/presentation_v2/shield_01.wav"),
		preload("res://assets/audio/presentation_v2/shield_02.wav")
	],
	"claim": [
		preload("res://assets/audio/presentation_v2/claim_01.wav"),
		preload("res://assets/audio/presentation_v2/claim_02.wav")
	],
	"equip": [
		preload("res://assets/audio/presentation_v2/equip_01.wav"),
		preload("res://assets/audio/presentation_v2/equip_02.wav")
	],
	"sword": [
		preload("res://assets/audio/presentation_v2/sword_01.wav"),
		preload("res://assets/audio/presentation_v2/sword_02.wav")
	],
	"fire": [
		preload("res://assets/audio/presentation_v2/fire_01.wav"),
		preload("res://assets/audio/presentation_v2/fire_02.wav"),
		preload("res://assets/audio/presentation_v2/fire_03.wav")
	],
	"thunder": [
		preload("res://assets/audio/presentation_v2/thunder_01.wav"),
		preload("res://assets/audio/presentation_v2/thunder_02.wav"),
		preload("res://assets/audio/presentation_v2/thunder_03.wav")
	],
	"chain": [
		preload("res://assets/audio/presentation_v2/chain_01.wav"),
		preload("res://assets/audio/presentation_v2/chain_02.wav"),
		preload("res://assets/audio/presentation_v2/chain_03.wav")
	],
	"hit": [
		preload("res://assets/audio/presentation_v2/hit_01.wav"),
		preload("res://assets/audio/presentation_v2/hit_02.wav"),
		preload("res://assets/audio/presentation_v2/hit_03.wav")
	],
	"hurt": [
		preload("res://assets/audio/presentation_v2/hurt_01.wav"),
		preload("res://assets/audio/presentation_v2/hurt_02.wav")
	],
	"death": [
		preload("res://assets/audio/presentation_v2/death_01.wav"),
		preload("res://assets/audio/presentation_v2/death_02.wav")
	],
	"level": [
		preload("res://assets/audio/presentation_v2/level_01.wav"),
		preload("res://assets/audio/presentation_v2/level_02.wav")
	],
	"victory": [
		preload("res://assets/audio/presentation_v2/victory_01.wav"),
		preload("res://assets/audio/presentation_v2/victory_02.wav")
	],
	"defeat": [
		preload("res://assets/audio/presentation_v2/defeat_01.wav"),
		preload("res://assets/audio/presentation_v2/defeat_02.wav")
	],
	"boss_defeat": [
		preload("res://assets/audio/presentation_v2/boss_defeat_01.wav"),
		preload("res://assets/audio/presentation_v2/boss_defeat_02.wav")
	],
	"summon_charge": [
		preload("res://assets/audio/presentation_v2/summon_charge_01.wav"),
		preload("res://assets/audio/presentation_v2/summon_charge_02.wav")
	],
	"summon_rare": [
		preload("res://assets/audio/presentation_v2/summon_rare_01.wav"),
		preload("res://assets/audio/presentation_v2/summon_rare_02.wav")
	],
	"summon_epic": [
		preload("res://assets/audio/presentation_v2/summon_epic_01.wav"),
		preload("res://assets/audio/presentation_v2/summon_epic_02.wav")
	],
	"summon_legendary_omen": [
		preload("res://assets/audio/presentation_v2/summon_legendary_omen_01.wav"),
		preload("res://assets/audio/presentation_v2/summon_legendary_omen_02.wav")
	],
	"summon_legendary_reveal": [
		preload("res://assets/audio/presentation_v2/summon_legendary_reveal_01.wav"),
		preload("res://assets/audio/presentation_v2/summon_legendary_reveal_02.wav")
	],
	"summon_new": [
		preload("res://assets/audio/presentation_v2/summon_new_01.wav"),
		preload("res://assets/audio/presentation_v2/summon_new_02.wav")
	],
	"summon_duplicate": [
		preload("res://assets/audio/presentation_v2/summon_duplicate_01.wav"),
		preload("res://assets/audio/presentation_v2/summon_duplicate_02.wav")
	],
	# Prepared semantic cues for the Presentation Overhaul. They are intentionally
	# routed now so screens can adopt them without another audio-architecture pass.
	"upgrade": [
		preload("res://assets/audio/presentation_v2/upgrade_01.wav"),
		preload("res://assets/audio/presentation_v2/upgrade_02.wav")
	],
	"stage_unlock": [
		preload("res://assets/audio/presentation_v2/stage_unlock_01.wav"),
		preload("res://assets/audio/presentation_v2/stage_unlock_02.wav")
	],
	"purchase_success": [
		preload("res://assets/audio/presentation_v2/purchase_success_01.wav"),
		preload("res://assets/audio/presentation_v2/purchase_success_02.wav")
	]
}

const AUTO_UI_CUES: Array[String] = [
	"ui",
	"ui_tab",
	"ui_confirm",
	"ui_back",
	"claim",
	"summon_charge"
]

const SEMANTIC_UI_CUES: Array[String] = [
	"equip",
	"claim",
	"level",
	"upgrade",
	"stage_unlock",
	"purchase_success",
	"summon_charge",
	"summon_rare",
	"summon_epic",
	"summon_legendary_omen",
	"summon_legendary_reveal",
	"summon_new",
	"summon_duplicate"
]

const PITCH_VARIATION_CUES: Array[String] = [
	"ui",
	"ui_tab",
	"pickup",
	"sword",
	"fire",
	"thunder",
	"chain",
	"hit",
	"death"
]

const PITCH_SEQUENCE: Array[float] = [
	0.988,
	1.006,
	0.997,
	1.014,
	0.992,
	1.003
]

const AUTO_UI_SUPPRESS_MSEC: int = 125
const SFX_VOICE_COUNT: int = 14

var music_players: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer] = []
var cooldown_until: Dictionary = {}
var variation_cursor: Dictionary = {}
var pitch_cursor: Dictionary = {}
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
		var stream_player := AudioStreamPlayer.new()
		stream_player.bus = &"Music"
		stream_player.volume_db = MUSIC_OFF_DB
		add_child(stream_player)
		music_players.append(stream_player)
	for index in range(SFX_VOICE_COUNT):
		var stream_player := AudioStreamPlayer.new()
		stream_player.bus = &"SFX"
		add_child(stream_player)
		voices.append(stream_player)
	get_tree().node_added.connect(_on_node_added)
	# Buttons already present before this Autoload's ready pass still need the
	# same tactile contract as controls created later at runtime.
	_connect_existing_buttons(get_tree().root)
	# PavilionManager is autoloaded after AudioManager. Connect permanent
	# progression / purchase-result semantics on the deferred frame, once every
	# autoload in project.godot is present.
	call_deferred("_connect_semantic_runtime_signals")


func _connect_semantic_runtime_signals() -> void:
	if (
		is_instance_valid(ProgressionManager)
		and not ProgressionManager.cultivation_upgraded.is_connected(
			_on_cultivation_upgraded_audio
		)
	):
		ProgressionManager.cultivation_upgraded.connect(
			_on_cultivation_upgraded_audio
		)

	if (
		is_instance_valid(PavilionManager)
		and not PavilionManager.purchase_delivery_finished.is_connected(
			_on_purchase_delivery_audio
		)
	):
		PavilionManager.purchase_delivery_finished.connect(
			_on_purchase_delivery_audio
		)


func _on_cultivation_upgraded_audio(
	_upgrade_id: String,
	_new_level: int
) -> void:
	play_sfx("upgrade")


func _on_purchase_delivery_audio(
	_product_id: String,
	success: bool,
	_message: String
) -> void:
	if success:
		play_sfx("purchase_success")


func _connect_existing_buttons(root: Node) -> void:
	for child: Node in root.get_children():
		if child is BaseButton:
			_connect_button(child as BaseButton)
		_connect_existing_buttons(child)


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
	if cue.is_empty():
		return
	# Run after the button's own handler. Semantic actions can therefore play
	# their dedicated cue first and suppress the generic tactile layer.
	call_deferred("_play_auto_ui_sfx", cue)


func _play_auto_ui_sfx(cue: String) -> void:
	if cue.is_empty() or cue not in AUTO_UI_CUES:
		return
	if Time.get_ticks_msec() < semantic_ui_until_msec:
		return
	play_sfx(cue)


func _resolve_button_sfx(button: BaseButton) -> String:
	if bool(button.get_meta("sfx_silent", false)):
		return ""

	if button.has_meta("sfx_cue"):
		var explicit_cue := str(button.get_meta("sfx_cue"))
		if explicit_cue in AUTO_UI_CUES:
			return explicit_cue

	var name_key := str(button.name).to_upper()
	var text_key := ""
	if button is Button:
		text_key = (button as Button).text.to_upper()
	var identity := name_key + " " + text_key

	if identity.contains("CLAIM") or identity.contains("COLLECT"):
		return "claim"
	if identity.contains("SUMMON"):
		return "summon_charge"
	if (
		identity.contains("PURCHASE")
		or identity.contains("BUY")
		or identity.contains("TOP UP")
	):
		return "ui_confirm"
	if (
		identity.contains("BACK")
		or identity.contains("HOME")
		or identity.contains("CLOSE")
		or identity.contains("CANCEL")
		or identity.contains("EXIT")
	):
		return "ui_back"
	if (
		button.toggle_mode
		or identity.contains("TAB")
		or identity.contains("FILTER")
		or identity.contains("SORT")
	):
		return "ui_tab"

	# V2 deliberately restores a restrained tactile cue for normal browsing.
	# The clips are 40-80 ms and mixed well below progression/reward events.
	return "ui"


func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var identity := str(scene.get_instance_id())
	if identity != scene_identity:
		scene_identity = identity
		if scene.has_node("EnemySpawner"):
			set_context("journey")
		elif scene.scene_file_path.ends_with("pavilion_screen.tscn"):
			set_context("pavilion")
		elif not scene.scene_file_path.ends_with("loading_screen.tscn"):
			set_context("home")


func set_context(next_context: String) -> void:
	if (
		context == next_context
		or not MUSIC.has(next_context)
		or music_players.is_empty()
	):
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
	music_players[front].volume_db = MUSIC_OFF_DB
	music_players[front].play()
	music_players[front].stream_paused = backgrounded
	crossfade = create_tween().set_parallel(true)
	crossfade.tween_property(
		music_players[old_front],
		"volume_db",
		MUSIC_OFF_DB,
		0.72
	)
	crossfade.tween_property(
		music_players[front],
		"volume_db",
		MUSIC_TARGET_DB,
		0.92
	)
	crossfade.chain().tween_callback(music_players[old_front].stop)


func play_sfx(cue: String) -> void:
	if backgrounded or not SFX.has(cue):
		return
	var now := Time.get_ticks_msec()
	if cue in SEMANTIC_UI_CUES:
		semantic_ui_until_msec = maxi(
			semantic_ui_until_msec,
			now + AUTO_UI_SUPPRESS_MSEC
		)
	if now < int(cooldown_until.get(cue, 0)):
		return
	cooldown_until[cue] = now + _get_sfx_cooldown_msec(cue)
	_maybe_duck_music_for_cue(cue)

	var stream := _get_sfx_stream(cue)
	if stream == null:
		return
	for voice: AudioStreamPlayer in voices:
		if voice.playing:
			continue
		voice.stream = stream
		voice.volume_db = _get_sfx_volume_db(cue)
		voice.pitch_scale = _get_sfx_pitch(cue)
		voice.play()
		return


func _get_sfx_stream(cue: String) -> AudioStream:
	var raw_variants: Variant = SFX.get(cue, [])
	if not (raw_variants is Array):
		return null
	var variants: Array = raw_variants
	if variants.is_empty():
		return null
	var index := int(variation_cursor.get(cue, 0)) % variants.size()
	variation_cursor[cue] = index + 1
	return variants[index] as AudioStream


func _get_sfx_cooldown_msec(cue: String) -> int:
	match cue:
		"ui":
			return 55
		"ui_tab", "ui_confirm", "ui_back":
			return 85
		"ui_locked":
			return 160
		"hit":
			return 55
		"death", "chain":
			return 75
		"sword":
			return 70
		"fire":
			return 105
		"thunder":
			return 130
		"pickup":
			return 90
		"level", "upgrade":
			return 260
		"claim", "purchase_success":
			return 180
		"victory", "defeat", "boss_defeat", "stage_unlock":
			return 600
		_:
			return 120


func _get_sfx_volume_db(cue: String) -> float:
	match cue:
		"ui":
			return -17.0
		"ui_tab":
			return -16.0
		"ui_confirm":
			return -14.0
		"ui_back":
			return -15.0
		"ui_locked":
			return -13.0
		"pickup":
			return -14.0
		"hit":
			return -15.0
		"hurt":
			return -10.5
		"death":
			return -13.0
		"sword":
			return -11.5
		"fire":
			return -10.5
		"thunder":
			return -9.5
		"chain":
			return -12.0
		"shield":
			return -9.0
		"equip":
			return -8.5
		"claim":
			return -7.0
		"level", "upgrade":
			return -7.0
		"victory":
			return -4.5
		"defeat":
			return -5.0
		"boss_defeat":
			return -4.0
		"stage_unlock":
			return -4.5
		"purchase_success":
			return -5.5
		"summon_charge":
			return -10.0
		"summon_rare":
			return -7.5
		"summon_epic":
			return -6.0
		"summon_legendary_omen":
			return -4.0
		"summon_legendary_reveal":
			return -2.5
		"summon_new":
			return -7.5
		"summon_duplicate":
			return -9.5
		_:
			return -8.0


func _get_sfx_pitch(cue: String) -> float:
	var base_pitch := 1.0
	match cue:
		"ui_back":
			base_pitch = 0.97
		"ui_locked":
			base_pitch = 0.94
		"summon_duplicate":
			base_pitch = 0.96

	if cue not in PITCH_VARIATION_CUES:
		return base_pitch
	var index := int(pitch_cursor.get(cue, 0)) % PITCH_SEQUENCE.size()
	pitch_cursor[cue] = index + 1
	return base_pitch * PITCH_SEQUENCE[index]


func _maybe_duck_music_for_cue(cue: String) -> void:
	match cue:
		"victory":
			duck_music(2.45, -31.0)
		"defeat":
			duck_music(3.10, -34.0)
		"boss_defeat":
			duck_music(2.75, -35.0)
		"stage_unlock":
			duck_music(2.45, -29.0)
		"purchase_success":
			duck_music(1.15, -25.0)
		_:
			pass


func duck_music(duration: float, target_db: float = -30.0) -> void:
	if backgrounded or music_players.is_empty():
		return
	var player: AudioStreamPlayer = music_players[front]
	if not is_instance_valid(player) or not player.playing:
		return
	if music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	music_duck_tween = create_tween()
	music_duck_tween.tween_property(
		player,
		"volume_db",
		target_db,
		0.10
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	music_duck_tween.tween_interval(maxf(duration - 0.32, 0.0))
	music_duck_tween.tween_property(
		player,
		"volume_db",
		MUSIC_TARGET_DB,
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	music_duck_tween.tween_callback(_clear_music_duck)


func _clear_music_duck() -> void:
	music_duck_tween = null


func release_runtime_audio() -> void:
	if crossfade != null and crossfade.is_valid():
		crossfade.kill()
	crossfade = null
	if music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	music_duck_tween = null

	for music_player: AudioStreamPlayer in music_players:
		if not is_instance_valid(music_player):
			continue
		music_player.stop()
		music_player.stream_paused = false
		music_player.stream = null

	for voice: AudioStreamPlayer in voices:
		if not is_instance_valid(voice):
			continue
		voice.stop()
		voice.stream_paused = false
		voice.stream = null

	cooldown_until.clear()
	variation_cursor.clear()
	pitch_cursor.clear()
	context = ""
	scene_identity = ""
	backgrounded = false
	semantic_ui_until_msec = 0


func _exit_tree() -> void:
	release_runtime_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		backgrounded = true
		for voice: AudioStreamPlayer in voices:
			voice.stop()
		for music_player: AudioStreamPlayer in music_players:
			music_player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		backgrounded = false
		for music_player: AudioStreamPlayer in music_players:
			music_player.stream_paused = false
