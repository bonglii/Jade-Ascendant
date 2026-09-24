extends Node

## Jade Ascendant Audio Identity V2.1
##
## Goals:
## - every active runtime cue is routed through one coherent xianxia palette;
## - frequent sounds rotate through authored variants instead of repeating one file;
## - UI browsing is tactile again, while semantic actions suppress duplicate clicks;
## - major reward/result cues automatically create room in the music mix;
## - existing gameplay/save/billing call sites stay untouched;
## - semantic overlays add identity to revive, boss, equipment and achievement events.

const AUDIO_ROOT: String = "res://assets/audio/presentation_v2/"
const MUSIC_TARGET_DB: float = -18.5
const MUSIC_OFF_DB: float = -55.0

const MUSIC: Dictionary = {
	"home": preload(	"res://assets/audio/presentation_v2/music_home.ogg"),
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

# V2.1 semantic overlays deliberately reuse the curated V2 palette as layers
# instead of introducing more raw third-party files. Existing direct cues remain
# API-compatible; these combinations only add identity where one old cue was
# carrying too many meanings.
const COMPOSITE_SFX: Dictionary = {
	"revive": [
		{"source": "shield", "volume_offset_db": -3.5, "pitch_multiplier": 1.04},
		{"source": "level", "volume_offset_db": -6.0, "pitch_multiplier": 1.06}
	],
	"boss_spawn": [
		{"source": "summon_charge", "volume_offset_db": -2.0, "pitch_multiplier": 0.93},
		{"source": "thunder", "volume_offset_db": -4.5, "pitch_multiplier": 0.88}
	],
	"boss_phase": [
		{"source": "summon_charge", "volume_offset_db": -4.0, "pitch_multiplier": 0.90},
		{"source": "thunder", "volume_offset_db": -5.0, "pitch_multiplier": 0.82}
	],
	"equipment_ascend": [
		{"source": "upgrade", "volume_offset_db": -2.0, "pitch_multiplier": 1.03}
	],
	"unequip": [
		{"source": "equip", "volume_offset_db": -5.5, "pitch_multiplier": 0.94},
		{"source": "ui_back", "volume_offset_db": -2.0, "pitch_multiplier": 0.98}
	],
	"achievement_unlock": [
		{"source": "summon_new", "volume_offset_db": -2.0, "pitch_multiplier": 1.02}
	]
}

const AUTO_UI_CUES: Array[String] = [
	"ui",
	"ui_tab",
	"ui_confirm",
	"ui_back",
	"ui_locked",
	"claim",
	"summon_charge"
]

const SEMANTIC_UI_CUES: Array[String] = [
	"equip",
	"unequip",
	"equipment_ascend",
	"achievement_unlock",
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
const EQUIPMENT_CHANGE_SUPPRESS_MSEC: int = 180
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
var equipment_change_suppress_until_msec: int = 0


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
	# Several presentation owners load before and after AudioManager. Defer once
	# so all autoload singletons exist, then bind semantic-only signals without
	# moving gameplay/save responsibility into the audio layer.
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

	if (
		is_instance_valid(MonetizationManager)
		and not MonetizationManager.reward_delivery_finished.is_connected(
			_on_reward_delivery_finished_audio
		)
	):
		MonetizationManager.reward_delivery_finished.connect(
			_on_reward_delivery_finished_audio
		)

	if (
		is_instance_valid(EquipmentManager)
		and not EquipmentManager.equipment_changed.is_connected(
			_on_equipment_changed_audio
		)
	):
		EquipmentManager.equipment_changed.connect(
			_on_equipment_changed_audio
		)

	if (
		is_instance_valid(EquipmentManager)
		and not EquipmentManager.equipment_ascended.is_connected(
			_on_equipment_ascended_audio
		)
	):
		EquipmentManager.equipment_ascended.connect(
			_on_equipment_ascended_audio
		)

	if (
		is_instance_valid(AchievementManager)
		and not AchievementManager.achievement_unlocked.is_connected(
			_on_achievement_unlocked_audio
		)
	):
		AchievementManager.achievement_unlocked.connect(
			_on_achievement_unlocked_audio
		)

	var enemy_spawners := get_tree().root.find_children(
		"EnemySpawner",
		"Node",
		true,
		false
	)
	for enemy_spawner: Node in enemy_spawners:
		_try_connect_enemy_spawner(enemy_spawner)


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


func _on_reward_delivery_finished_audio(
	placement: String,
	success: bool,
	_amount: int,
	_message: String
) -> void:
	if success and placement == "game_over_revive":
		# PlayerHealth still owns the established claim transient. The V2.1
		# overlay adds shield + breakthrough resonance so revive no longer reads
		# as an ordinary reward claim, without touching revive/gameplay logic.
		play_sfx("revive")


func _on_equipment_ascended_audio(
	_item_id: String,
	_old_star: int,
	_new_star: int
) -> void:
	equipment_change_suppress_until_msec = (
		Time.get_ticks_msec() + EQUIPMENT_CHANGE_SUPPRESS_MSEC
	)
	# EquipmentManager already emits its material "equip" transient after this
	# signal. Add only the progression layer here to create a distinct ascend.
	play_sfx("equipment_ascend")


func _on_equipment_changed_audio(
	_slot_id: String,
	item_id: String
) -> void:
	if Time.get_ticks_msec() < equipment_change_suppress_until_msec:
		return
	if item_id.is_empty():
		play_sfx("unequip")
	else:
		play_sfx("equip")


func _on_achievement_unlocked_audio(_achievement_id: String) -> void:
	# The toast presenter keeps its quiet ui_confirm. This short discovery layer
	# lifts the unlock above a normal confirmation without becoming a fanfare.
	play_sfx("achievement_unlock")


func _connect_existing_buttons(root: Node) -> void:
	for child: Node in root.get_children():
		if child is BaseButton:
			_connect_button(child as BaseButton)
		_try_connect_enemy_spawner(child)
		_connect_existing_buttons(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)
	_try_connect_enemy_spawner(node)


func _try_connect_enemy_spawner(node: Node) -> void:
	if node == null or node.name != "EnemySpawner":
		return
	if not node.has_signal("boss_spawned_signal"):
		return
	var callback := Callable(self, "_on_boss_spawned_audio")
	if not node.is_connected("boss_spawned_signal", callback):
		node.connect("boss_spawned_signal", callback)


func _on_boss_spawned_audio(boss: Node) -> void:
	if boss == null:
		return
	play_sfx("boss_spawn")
	if not boss.has_signal("phase_changed"):
		return
	var callback := Callable(self, "_on_boss_phase_changed_audio")
	if not boss.is_connected("phase_changed", callback):
		boss.connect("phase_changed", callback)


func _on_boss_phase_changed_audio(new_phase: int) -> void:
	if new_phase >= 2:
		# boss_1.gd keeps its established level/breakthrough transient; this
		# overlay adds low thunder/ritual pressure and makes Phase 2 unmistakable.
		play_sfx("boss_phase")


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

	if identity.contains("LOCKED"):
		return "ui_locked"
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
	if (
		backgrounded
		or (
			not SFX.has(cue)
			and not COMPOSITE_SFX.has(cue)
		)
	):
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

	if COMPOSITE_SFX.has(cue):
		_play_composite_sfx(cue)
		return
	_play_sfx_variant(cue)


func _play_composite_sfx(cue: String) -> void:
	var raw_layers: Variant = COMPOSITE_SFX.get(cue, [])
	if not (raw_layers is Array):
		return
	var layers: Array = raw_layers
	for raw_layer: Variant in layers:
		if not (raw_layer is Dictionary):
			continue
		var layer: Dictionary = raw_layer
		var source_cue := str(layer.get("source", ""))
		if source_cue.is_empty() or not SFX.has(source_cue):
			continue
		_play_sfx_variant(
			source_cue,
			float(layer.get("volume_offset_db", 0.0)),
			float(layer.get("pitch_multiplier", 1.0))
		)


func _play_sfx_variant(
	cue: String,
	volume_offset_db: float = 0.0,
	pitch_multiplier: float = 1.0
) -> void:
	var stream := _get_sfx_stream(cue)
	if stream == null:
		return
	for voice: AudioStreamPlayer in voices:
		if voice.playing:
			continue
		voice.stream = stream
		voice.volume_db = _get_sfx_volume_db(cue) + volume_offset_db
		voice.pitch_scale = _get_sfx_pitch(cue) * pitch_multiplier
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
		"level", "upgrade", "equipment_ascend":
			return 260
		"equip", "unequip":
			return 170
		"claim", "purchase_success":
			return 180
		"achievement_unlock":
			return 350
		"revive":
			return 800
		"boss_spawn":
			return 900
		"boss_phase":
			return 700
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
		"revive":
			duck_music(0.95, -25.0)
		"boss_spawn":
			duck_music(1.35, -29.0)
		"boss_phase":
			duck_music(0.95, -27.0)
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
	equipment_change_suppress_until_msec = 0


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
