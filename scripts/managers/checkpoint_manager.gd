extends Node

## Checkpoint Manager
## Mengelola penyimpanan dan pemulihan kondisi run saat ini.
## Checkpoint digunakan oleh fitur Continue dan dihapus
## ketika run berakhir melalui Death atau Victory.

const SAVE_PATH: String = "user://checkpoint.save"
const SAVE_VERSION: int = 1
const LEGACY_SAVE_VERSION: int = 0

const REQUIRED_SAVE_KEYS: Array[String] = [
	"survival_time",
	"wave",
	"wave_timer",
	"difficulty_level",
	"player_level",
	"experience",
	"experience_to_next_level"
]

const OPTIONAL_NUMERIC_SAVE_KEYS: Array[String] = [
	"chapter_id", "stage_id", "spiritual_insight_level", "movement_speed_level",
	"movement_speed", "body_refinement_level", "current_health", "max_health",
	"qi_shield_level", "qi_shield_charges", "iron_body_level", "blood_qi_level",
	"blood_qi_kill_progress", "power_level", "power_multiplier", "attack_speed_level",
	"attack_cooldown", "sword_intent_level", "spirit_sword_level", "fire_orb_level",
	"thunder_talisman_level", "yin_yang_blades_level", "heavenly_sword_rain_level",
	"eight_trigrams_formation_level"
]
const OPTIONAL_BOOL_SAVE_KEYS: Array[String] = [
	"sword_dao_resonance_owned", "yin_yang_reversal_owned", "heavenly_tribulation_owned",
	"fire_orb_owned", "thunder_talisman_owned", "yin_yang_blades_owned",
	"heavenly_sword_rain_owned", "eight_trigrams_formation_owned",
	"defeat_pending", "rewarded_revive_used"
]

@onready var player = get_tree().get_first_node_in_group("player")
@onready var survival_manager = get_parent().get_node_or_null(
	"SurvivalManager"
)
@onready var wave_manager = get_parent().get_node_or_null(
	"WaveManager"
)
@onready var difficulty_manager = get_parent().get_node_or_null(
	"DifficultyManager"
)

var defeat_pending: bool = false
var rewarded_revive_used: bool = false

func _ready() -> void:
	DebugLogger.system(str("CheckpointManager aktif!"))
	DebugLogger.system(str(
		"SAVE LOCATION: ",
		ProjectSettings.globalize_path(SAVE_PATH)
	))

	if GameSession.consume_continue_request():
		call_deferred("_load_continue")

func _load_continue() -> void:
	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("CONTINUE GAME DIMULAI..."))
	DebugLogger.system(str("=========================================="))

	var success := load_checkpoint()

	if success:
		DebugLogger.system(str("CONTINUE GAME BERHASIL!"))
	else:
		DebugLogger.system(str("CONTINUE GAME GAGAL!"))

	DebugLogger.system(str("=========================================="))
	if not success:
		# A failed Continue must not quietly become a fresh run that autosaves
		# over the snapshot. Wait until the current gate releases its ownership.
		while SceneTransitionManager.is_transitioning:
			await get_tree().process_frame
		GameSession.start_new_game()
		var return_error: Error = SceneTransitionManager.transition_to(
			"res://scenes/ui/main_menu.tscn",
			{"title": "Jade Sanctuary", "subtitle": "Returning to the sanctuary"}
		)
		if return_error != OK:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func save_checkpoint() -> bool:
	if player == null:
		push_error(str("ERROR: Player tidak ditemukan!"))
		return false

	if survival_manager == null:
		push_error(str("ERROR: SurvivalManager tidak ditemukan!"))
		return false

	if wave_manager == null:
		push_error(str("ERROR: WaveManager tidak ditemukan!"))
		return false

	if difficulty_manager == null:
		push_error(str("ERROR: DifficultyManager tidak ditemukan!"))
		return false

	var player_stats = player.get_node_or_null("PlayerStats")

	var player_health: PlayerHealth = player.get_node_or_null(
		"PlayerHealth"
	) as PlayerHealth

	var weapon_manager = player.get_node_or_null("WeaponManager")

	if player_stats == null:
		push_error(str("ERROR: PlayerStats tidak ditemukan!"))
		return false

	if player_health == null:
		push_error(str("ERROR: PlayerHealth tidak ditemukan!"))
		return false

	if weapon_manager == null:
		push_error(str("ERROR: WeaponManager tidak ditemukan!"))
		return false

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"defeat_pending": false,
		"rewarded_revive_used": rewarded_revive_used
	}

	if JourneyManager.has_active_run():
		save_data["chapter_id"] = JourneyManager.active_run_chapter_id
		save_data["stage_id"] = JourneyManager.active_run_stage_id

	save_data["survival_time"] = survival_manager.survival_time

	save_data["wave"] = wave_manager.current_wave
	save_data["wave_timer"] = wave_manager.wave_timer

	save_data["difficulty_level"] = (
		difficulty_manager.difficulty_level
	)

	save_data["player_level"] = player.level
	save_data["experience"] = player.experience
	save_data["experience_to_next_level"] = (
		player.experience_to_next_level
	)

	save_data["spiritual_insight_level"] = (
		player.spiritual_insight_level
	)

	save_data["movement_speed_level"] = (
		player.movement_speed_level
	)

	save_data["movement_speed"] = player.speed

	save_data["body_refinement_level"] = (
		player_health.body_refinement_level
	)

	save_data["current_health"] = player_health.current_health
	save_data["max_health"] = player_health.max_health

	save_data["qi_shield_level"] = (
		player_health.qi_shield_level
	)

	save_data["qi_shield_charges"] = (
		player_health.qi_shield_charges
	)

	save_data["iron_body_level"] = (
		player_health.iron_body_level
	)

	save_data["blood_qi_level"] = (
		player_health.blood_qi_level
	)

	save_data["blood_qi_kill_progress"] = (
		player_health.blood_qi_kill_progress
	)

	save_data["power_level"] = player_stats.power_level
	save_data["power_multiplier"] = (
		player_stats.power_multiplier
	)

	save_data["attack_speed_level"] = (
		player_stats.attack_speed_level
	)

	save_data["attack_cooldown"] = (
		player_stats.attack_cooldown
	)

	save_data["sword_intent_level"] = (
		player_stats.sword_intent_level
	)

	save_data["sword_dao_resonance_owned"] = (
		player_stats.has_sword_dao_resonance()
	)

	save_data["yin_yang_reversal_owned"] = (
		player_stats.has_yin_yang_reversal()
	)

	save_data["heavenly_tribulation_owned"] = (
		player_stats.has_heavenly_tribulation()
	)

	var spirit_sword = weapon_manager.get_weapon_by_name(
		"Spirit Sword"
	)

	if spirit_sword != null:
		save_data["spirit_sword_level"] = spirit_sword.level

	var fire_orb = weapon_manager.get_weapon_by_name(
		"Fire Orb"
	)

	save_data["fire_orb_owned"] = (
		fire_orb != null
	)

	if fire_orb != null:
		save_data["fire_orb_level"] = fire_orb.level

	var thunder_talisman = weapon_manager.get_weapon_by_name(
		"Thunder Talisman"
	)

	save_data["thunder_talisman_owned"] = (
		thunder_talisman != null
	)

	if thunder_talisman != null:
		save_data["thunder_talisman_level"] = (
			thunder_talisman.level
		)

	var yin_yang_blades = weapon_manager.get_weapon_by_name(
		"Yin-Yang Blades"
	)

	save_data["yin_yang_blades_owned"] = (
		yin_yang_blades != null
	)

	if yin_yang_blades != null:
		save_data["yin_yang_blades_level"] = (
			yin_yang_blades.level
		)

	var heavenly_sword_rain = weapon_manager.get_weapon_by_name(
		"Heavenly Sword Rain"
	)

	save_data["heavenly_sword_rain_owned"] = (
		heavenly_sword_rain != null
	)

	if heavenly_sword_rain != null:
		save_data["heavenly_sword_rain_level"] = (
			heavenly_sword_rain.level
		)

	var eight_trigrams_formation = (
		weapon_manager.get_weapon_by_name(
			"Eight Trigrams Formation"
		)
	)

	save_data["eight_trigrams_formation_owned"] = (
		eight_trigrams_formation != null
	)

	if eight_trigrams_formation != null:
		save_data["eight_trigrams_formation_level"] = (
			eight_trigrams_formation.level
		)

	if not _write_checkpoint_data(save_data):
		push_error(str("ERROR: Gagal membuat checkpoint!"))
		return false

	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("CHECKPOINT DISIMPAN!"))
	DebugLogger.system(str(
		"Survival Time: ",
		survival_manager.format_time()
	))

	DebugLogger.system(str("Wave: ", wave_manager.current_wave))
	DebugLogger.system(str("Wave Timer: ", wave_manager.wave_timer))

	if save_data.has("chapter_id") and save_data.has("stage_id"):
		DebugLogger.system(str(
			"Checkpoint Stage: Chapter ",
			save_data["chapter_id"],
			" Stage ",
			save_data["stage_id"]
		))

	DebugLogger.system(str(
		"Difficulty: ",
		difficulty_manager.difficulty_level
	))

	DebugLogger.system(str("Player Level: ", player.level))

	DebugLogger.system(str(
		"EXP: ",
		player.experience,
		"/",
		player.experience_to_next_level
	))

	DebugLogger.system(str(
		"Spiritual Insight Level: ",
		player.spiritual_insight_level
	))

	DebugLogger.system(str(
		"EXP Multiplier: ",
		player.get_experience_multiplier()
	))

	DebugLogger.system(str(
		"Movement Speed Level: ",
		player.movement_speed_level
	))

	DebugLogger.system(str("Movement Speed: ", player.speed))

	DebugLogger.system(str(
		"Body Refinement Level: ",
		player_health.body_refinement_level
	))

	DebugLogger.system(str(
		"Player HP: ",
		player_health.current_health,
		"/",
		player_health.max_health
	))

	DebugLogger.system(str(
		"Qi Shield Level: ",
		player_health.qi_shield_level
	))

	DebugLogger.system(str(
		"Qi Shield Charges: ",
		player_health.qi_shield_charges
	))

	DebugLogger.system(str(
		"Iron Body Level: ",
		player_health.iron_body_level
	))

	DebugLogger.system(str(
		"Iron Body Damage Reduction: ",
		player_health.get_iron_body_reduction() * 100.0,
		"%"
	))

	DebugLogger.system(str(
		"Blood Qi Level: ",
		player_health.blood_qi_level
	))

	DebugLogger.system(str(
		"Blood Qi Kill Progress: ",
		player_health.blood_qi_kill_progress,
		"/",
		player_health.get_blood_qi_kills_required()
	))

	DebugLogger.system(str("Power Level: ", player_stats.power_level))

	DebugLogger.system(str(
		"Power Multiplier: ",
		player_stats.power_multiplier
	))

	DebugLogger.system(str(
		"Attack Speed Level: ",
		player_stats.attack_speed_level
	))

	DebugLogger.system(str(
		"Attack Cooldown: ",
		player_stats.attack_cooldown
	))

	DebugLogger.system(str(
		"Sword Intent Level: ",
		player_stats.sword_intent_level
	))

	DebugLogger.system(str(
		"Critical Chance: ",
		player_stats.get_critical_chance() * 100.0,
		"%"
	))

	DebugLogger.system(str(
		"Sword Dao Resonance Owned: ",
		player_stats.has_sword_dao_resonance()
	))

	DebugLogger.system(str(
		"Yin-Yang Reversal Owned: ",
		player_stats.has_yin_yang_reversal()
	))

	DebugLogger.system(str(
		"Heavenly Tribulation Owned: ",
		player_stats.has_heavenly_tribulation()
	))

	if spirit_sword != null:
		DebugLogger.system(str(
			"Spirit Sword Level: ",
			spirit_sword.level
		))

	if fire_orb != null:
		DebugLogger.system(str(
			"Fire Orb Level: ",
			fire_orb.level
		))

	DebugLogger.system(str(
		"Thunder Talisman Owned: ",
		thunder_talisman != null
	))

	if thunder_talisman != null:
		DebugLogger.system(str(
			"Thunder Talisman Level: ",
			thunder_talisman.level
		))

	DebugLogger.system(str(
		"Yin-Yang Blades Owned: ",
		yin_yang_blades != null
	))

	if yin_yang_blades != null:
		DebugLogger.system(str(
			"Yin-Yang Blades Level: ",
			yin_yang_blades.level
		))

	DebugLogger.system(str(
		"Heavenly Sword Rain Owned: ",
		heavenly_sword_rain != null
	))

	if heavenly_sword_rain != null:
		DebugLogger.system(str(
			"Heavenly Sword Rain Level: ",
			heavenly_sword_rain.level
		))

	DebugLogger.system(str(
		"Eight Trigrams Formation Owned: ",
		eight_trigrams_formation != null
	))

	if eight_trigrams_formation != null:
		DebugLogger.system(str(
			"Eight Trigrams Formation Level: ",
			eight_trigrams_formation.level
		))

	DebugLogger.system(str("=========================================="))
	return true

func has_checkpoint() -> bool:
	return SaveManager.has_save_file("checkpoint")

func _write_checkpoint_data(save_data: Dictionary) -> bool:
	var normalized_data: Dictionary = normalize_checkpoint_save_data(save_data)
	if normalized_data.is_empty():
		DebugLogger.system("Checkpoint: write ditolak karena payload tidak valid.")
		return false
	# Read first so an existing future/corrupt save receives the write protection
	# already provided by SaveManager. New Trial explicitly clears this domain.
	if SaveManager.has_save_file("checkpoint"):
		var existing_result: Dictionary = read_checkpoint_result()
		if not bool(existing_result.get("success", false)):
			DebugLogger.system("Checkpoint: save existing dilindungi dari overwrite.")
			return false
	var io_result: Dictionary = SaveManager.write_save_data(
		"checkpoint",
		normalized_data
	)
	if not bool(io_result.get("success", false)):
		DebugLogger.system("Checkpoint: atomic write gagal: %s" % io_result.get("error", ""))
	return bool(io_result.get("success", false))

## Shared read contract for the hub and runtime. Legacy normalization is in
## memory here; the runtime commits a v0 migration through shared atomic I/O.
static func is_checkpoint_resumable(save_data: Dictionary) -> bool:
	return (
		not save_data.is_empty()
		and save_data.get("ended", false) != true
		and save_data.get("defeat_pending", false) != true
	)


static func read_checkpoint_result() -> Dictionary:
	var io_result: Dictionary = SaveManager.read_save_data("checkpoint")
	if not bool(io_result.get("success", false)):
		return io_result
	var raw_data: Dictionary = io_result.get("data", {})
	if raw_data.get("ended", false) == true:
		io_result["success"] = false
		io_result["data"] = {}
		io_result["error"] = "Run already completed."
		return io_result
	var normalized_data: Dictionary = normalize_checkpoint_save_data(raw_data)
	if normalized_data.is_empty():
		# SaveManager validates the shared envelope; checkpoint-specific values
		# also need a valid backup before any recovery is attempted.
		var backup_result: Dictionary = SaveManager.read_save_backup("checkpoint")
		var backup_data: Dictionary = backup_result.get("data", {})
		var normalized_backup: Dictionary = normalize_checkpoint_save_data(backup_data)
		if bool(backup_result.get("success", false)) and not normalized_backup.is_empty():
			var recovery_result: Dictionary = SaveManager.recover_save_from_backup("checkpoint")
			if bool(recovery_result.get("success", false)):
				io_result = recovery_result
				raw_data = backup_data
				normalized_data = normalized_backup
	if normalized_data.is_empty():
		io_result["success"] = false
		io_result["data"] = {}
		io_result["error"] = "schema atau identitas checkpoint tidak valid"
		return io_result
	io_result["source_version"] = get_checkpoint_save_version(raw_data)
	io_result["data"] = normalized_data
	return io_result

## Format lama tanpa version diperlakukan sebagai schema v0.
static func get_checkpoint_save_version(save_data: Dictionary) -> int:
	var raw_version: Variant = save_data.get("version", LEGACY_SAVE_VERSION)
	return int(raw_version) if raw_version is int else -1

## Migrasi in-memory menuju schema terbaru tanpa mengubah runtime scene.
static func normalize_checkpoint_save_data(
	save_data: Dictionary
) -> Dictionary:
	if save_data.get("ended", false) == true:
		return {}
	var source_version: int = get_checkpoint_save_version(save_data)
	if (
		source_version < LEGACY_SAVE_VERSION
		or source_version > SAVE_VERSION
	):
		return {}
	for required_key in REQUIRED_SAVE_KEYS:
		if not save_data.has(required_key):
			return {}
	# Validate before numeric conversion so a malformed checkpoint cannot break
	# hub initialization. Valid v0/v1 values and balance formulas are unchanged.
	for raw_key: Variant in save_data.keys():
		var key: String = str(raw_key)
		var value: Variant = save_data[raw_key]
		if key in REQUIRED_SAVE_KEYS or key in OPTIONAL_NUMERIC_SAVE_KEYS:
			if not (value is int or value is float):
				return {}
			if not is_finite(float(value)):
				return {}
		elif key in OPTIONAL_BOOL_SAVE_KEYS and not value is bool:
			return {}
	var has_chapter_id: bool = save_data.has("chapter_id")
	var has_stage_id: bool = save_data.has("stage_id")
	if has_chapter_id != has_stage_id:
		return {}
	if has_chapter_id:
		if (
			int(save_data.get("chapter_id", 0)) <= 0
			or int(save_data.get("stage_id", 0)) <= 0
		):
			return {}

	var normalized_data: Dictionary = save_data.duplicate(true)
	# Backward compatibility: every checkpoint created before explicit Fire Orb
	# ownership existed came from the old starter loadout where Fire Orb was
	# always owned. New checkpoints always write fire_orb_owned explicitly.
	if not normalized_data.has("fire_orb_owned"):
		normalized_data["fire_orb_owned"] = true
	normalized_data["defeat_pending"] = bool(
		save_data.get("defeat_pending", false)
	)
	normalized_data["rewarded_revive_used"] = bool(
		save_data.get("rewarded_revive_used", false)
	)
	normalized_data["version"] = SAVE_VERSION
	normalized_data["survival_time"] = maxf(
		float(save_data.get("survival_time", 0.0)),
		0.0
	)
	normalized_data["wave"] = maxi(
		int(save_data.get("wave", 1)),
		1
	)
	normalized_data["wave_timer"] = maxf(
		float(save_data.get("wave_timer", 0.0)),
		0.0
	)
	normalized_data["difficulty_level"] = maxi(
		int(save_data.get("difficulty_level", 1)),
		1
	)
	normalized_data["player_level"] = maxi(
		int(save_data.get("player_level", 1)),
		1
	)
	normalized_data["experience"] = maxi(
		int(save_data.get("experience", 0)),
		0
	)
	normalized_data["experience_to_next_level"] = maxi(
		int(save_data.get("experience_to_next_level", 1)),
		1
	)
	if has_chapter_id:
		normalized_data["chapter_id"] = int(save_data["chapter_id"])
		normalized_data["stage_id"] = int(save_data["stage_id"])
	return normalized_data

func _restore_journey_identity(save_data: Dictionary) -> bool:
	var has_chapter_id := save_data.has("chapter_id")
	var has_stage_id := save_data.has("stage_id")
	if not has_chapter_id and not has_stage_id:
		return JourneyManager.restore_active_run(
			JourneyManager.DEFAULT_CHAPTER_ID,
			JourneyManager.DEFAULT_STAGE_ID
		)
	if has_chapter_id != has_stage_id:
		push_error(str("ERROR: Identitas Chapter/Stage checkpoint tidak lengkap!"))
		return false
	var chapter_id := int(save_data["chapter_id"])
	var stage_id := int(save_data["stage_id"])
	if not JourneyManager.restore_active_run(chapter_id, stage_id):
		push_error(str(
			"ERROR: Gagal memulihkan active stage dari checkpoint! ",
			"Chapter ",
			chapter_id,
			" Stage ",
			stage_id
		))
		return false
	DebugLogger.system(str(
		"Checkpoint Stage: Chapter ",
		chapter_id,
		" Stage ",
		stage_id
	))
	return true

func load_checkpoint() -> bool:
	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("MEMUAT CHECKPOINT..."))

	if not has_checkpoint():
		DebugLogger.system(str("Tidak ada checkpoint!"))
		return false

	if player == null:
		push_error(str("ERROR: Player tidak ditemukan!"))
		return false

	if survival_manager == null:
		push_error(str("ERROR: SurvivalManager tidak ditemukan!"))
		return false

	if wave_manager == null:
		push_error(str("ERROR: WaveManager tidak ditemukan!"))
		return false

	if difficulty_manager == null:
		push_error(str("ERROR: DifficultyManager tidak ditemukan!"))
		return false

	var player_stats = player.get_node_or_null("PlayerStats")

	var player_health: PlayerHealth = player.get_node_or_null(
		"PlayerHealth"
	) as PlayerHealth

	var weapon_manager = player.get_node_or_null("WeaponManager")

	if player_stats == null:
		push_error(str("ERROR: PlayerStats tidak ditemukan!"))
		return false

	if player_health == null:
		push_error(str("ERROR: PlayerHealth tidak ditemukan!"))
		return false

	if weapon_manager == null:
		push_error(str("ERROR: WeaponManager tidak ditemukan!"))
		return false

	var io_result: Dictionary = read_checkpoint_result()
	if not bool(io_result.get("success", false)):
		DebugLogger.system("Checkpoint: load ditolak: %s" % io_result.get("error", ""))
		return false
	var source_version: int = int(io_result.get("source_version", SAVE_VERSION))
	var save_data: Dictionary = io_result.get("data", {})
	if not is_checkpoint_resumable(save_data):
		DebugLogger.system(
			"Checkpoint: Continue ditolak karena run sudah berada di Game Over."
		)
		return false
	rewarded_revive_used = bool(
		save_data.get("rewarded_revive_used", false)
	)
	defeat_pending = false
	if source_version < SAVE_VERSION:
		if _write_checkpoint_data(save_data):
			DebugLogger.system(str(
				"Checkpoint save migrated: v",
				source_version,
				" -> v",
				SAVE_VERSION
			))
		else:
			push_warning(
				"CheckpointManager: checkpoint legacy berhasil dibaca, "
				+ "tetapi migrasi schema gagal disimpan."
			)

	if not _restore_journey_identity(save_data):
		return false

	if save_data.has("survival_time"):
		survival_manager.survival_time = (
			save_data["survival_time"]
		)

	if save_data.has("wave"):
		wave_manager.current_wave = save_data["wave"]

	if save_data.has("wave_timer"):
		wave_manager.wave_timer = save_data["wave_timer"]

	if save_data.has("difficulty_level"):
		difficulty_manager.difficulty_level = save_data[
			"difficulty_level"
		]

	if save_data.has("player_level"):
		player.level = save_data["player_level"]

	if save_data.has("experience"):
		player.experience = save_data["experience"]

	if save_data.has("experience_to_next_level"):
		player.experience_to_next_level = save_data[
			"experience_to_next_level"
		]

	player.spiritual_insight_level = clampi(
		int(
			save_data.get(
				"spiritual_insight_level",
				0
			)
		),
		0,
		player.SPIRITUAL_INSIGHT_MAX_LEVEL
	)

	if save_data.has("movement_speed_level"):
		player.movement_speed_level = save_data[
			"movement_speed_level"
		]

	if save_data.has("movement_speed"):
		player.speed = save_data["movement_speed"]

	if save_data.has("body_refinement_level"):
		player_health.body_refinement_level = save_data[
			"body_refinement_level"
		]

	if save_data.has("max_health"):
		player_health.max_health = save_data["max_health"]

	if save_data.has("current_health"):
		player_health.current_health = save_data[
			"current_health"
		]

	if save_data.has("qi_shield_level"):
		player_health.qi_shield_level = save_data[
			"qi_shield_level"
		]

	if save_data.has("qi_shield_charges"):
		player_health.qi_shield_charges = save_data[
			"qi_shield_charges"
		]

	player_health.iron_body_level = clampi(
		int(
			save_data.get(
				"iron_body_level",
				0
			)
		),
		0,
		player_health.IRON_BODY_MAX_LEVEL
	)

	player_health.blood_qi_level = clampi(
		int(
			save_data.get(
				"blood_qi_level",
				0
			)
		),
		0,
		player_health.BLOOD_QI_MAX_LEVEL
	)

	player_health.blood_qi_kill_progress = maxi(
		int(
			save_data.get(
				"blood_qi_kill_progress",
				0
			)
		),
		0
	)

	player_health.health_changed.emit(
		player_health.current_health,
		player_health.max_health
	)

	if save_data.has("power_level"):
		player_stats.power_level = save_data["power_level"]

	if save_data.has("power_multiplier"):
		player_stats.power_multiplier = save_data[
			"power_multiplier"
		]

	if save_data.has("attack_speed_level"):
		player_stats.attack_speed_level = maxi(
			int(
				save_data[
					"attack_speed_level"
				]
			),
			0
		)

	if save_data.has("attack_cooldown"):
		player_stats.attack_cooldown = maxf(
			float(
				save_data[
					"attack_cooldown"
				]
			),
			player_stats.minimum_attack_cooldown
		)

	player_stats.sword_intent_level = clampi(
		int(
			save_data.get(
				"sword_intent_level",
				0
			)
		),
		0,
		player_stats.SWORD_INTENT_MAX_LEVEL
	)

	var sword_dao_resonance_owned: bool = bool(
		save_data.get(
			"sword_dao_resonance_owned",
			false
		)
	)

	if sword_dao_resonance_owned:
		player_stats.unlock_sword_dao_resonance()

	var yin_yang_reversal_owned: bool = bool(
		save_data.get(
			"yin_yang_reversal_owned",
			false
		)
	)

	if yin_yang_reversal_owned:
		player_stats.unlock_yin_yang_reversal()

	var heavenly_tribulation_owned: bool = bool(
		save_data.get(
			"heavenly_tribulation_owned",
			false
		)
	)

	if heavenly_tribulation_owned:
		player_stats.unlock_heavenly_tribulation()

	var spirit_sword = weapon_manager.get_weapon_by_name(
		"Spirit Sword"
	)

	if spirit_sword != null:
		if save_data.has("spirit_sword_level"):
			spirit_sword.level = clampi(int(save_data["spirit_sword_level"]), 1, SpiritSwordWeapon.MAX_LEVEL)

			spirit_sword.base_damage = (
				10.0
				+ ((spirit_sword.level - 1) * 5.0)
			)

	var fire_orb_owned: bool = bool(
		save_data.get(
			"fire_orb_owned",
			true
		)
	)

	var fire_orb = weapon_manager.get_weapon_by_name(
		"Fire Orb"
	)

	if fire_orb_owned:
		if fire_orb == null:
			weapon_manager.add_fire_orb()
			fire_orb = weapon_manager.get_weapon_by_name(
				"Fire Orb"
			)

		if fire_orb != null:
			var fire_orb_level: int = int(
				save_data.get(
					"fire_orb_level",
					1
				)
			)
			fire_orb.level = clampi(
				fire_orb_level,
				1,
				FireOrbWeapon.MAX_LEVEL
			)

			fire_orb.base_damage = (
				20.0
				+ ((fire_orb.level - 1) * 10.0)
			)
	elif fire_orb != null:
		weapon_manager.remove_weapon(fire_orb)
		fire_orb.queue_free()
		fire_orb = null

	var thunder_talisman_owned: bool = save_data.get(
		"thunder_talisman_owned",
		false
	)

	var thunder_talisman = weapon_manager.get_weapon_by_name(
		"Thunder Talisman"
	)

	if thunder_talisman_owned:
		if thunder_talisman == null:
			weapon_manager.add_thunder_talisman()

			thunder_talisman = weapon_manager.get_weapon_by_name(
				"Thunder Talisman"
			)

		if thunder_talisman != null:
			var thunder_talisman_level: int = save_data.get(
				"thunder_talisman_level",
				1
			)

			thunder_talisman.level = clampi(thunder_talisman_level, 1, ThunderTalismanWeapon.MAX_LEVEL)

			thunder_talisman.base_damage = (
				8.0
				+ ((thunder_talisman.level - 1) * 4.0)
			)

			if thunder_talisman.level >= 7:
				thunder_talisman.chain_count = 5
			elif thunder_talisman.level >= 5:
				thunder_talisman.chain_count = 4
			elif thunder_talisman.level >= 3:
				thunder_talisman.chain_count = 3
			else:
				thunder_talisman.chain_count = 2

	var yin_yang_blades_owned: bool = save_data.get(
		"yin_yang_blades_owned",
		false
	)

	var yin_yang_blades = weapon_manager.get_weapon_by_name(
		"Yin-Yang Blades"
	)

	if yin_yang_blades_owned:
		if yin_yang_blades == null:
			weapon_manager.add_yin_yang_blades()

			yin_yang_blades = weapon_manager.get_weapon_by_name(
				"Yin-Yang Blades"
			)

		if yin_yang_blades != null:
			var yin_yang_blades_level: int = clampi(
				int(
					save_data.get(
						"yin_yang_blades_level",
						1
					)
				),
				1,
				YinYangBladesWeapon.MAX_LEVEL
			)

			yin_yang_blades.level = yin_yang_blades_level
			yin_yang_blades.apply_level_stats()
			yin_yang_blades.rebuild_blades()

	var heavenly_sword_rain_owned: bool = save_data.get(
		"heavenly_sword_rain_owned",
		false
	)

	var heavenly_sword_rain = weapon_manager.get_weapon_by_name(
		"Heavenly Sword Rain"
	)

	if heavenly_sword_rain_owned:
		if heavenly_sword_rain == null:
			weapon_manager.add_heavenly_sword_rain()

			heavenly_sword_rain = (
				weapon_manager.get_weapon_by_name(
					"Heavenly Sword Rain"
				)
			)

		if heavenly_sword_rain != null:
			var heavenly_sword_rain_level: int = clampi(
				int(
					save_data.get(
						"heavenly_sword_rain_level",
						1
					)
				),
				1,
				HeavenlySwordRainWeapon.MAX_LEVEL
			)

			heavenly_sword_rain.level = (
				heavenly_sword_rain_level
			)

			heavenly_sword_rain.apply_level_stats()

	var eight_trigrams_formation_owned: bool = bool(
		save_data.get(
			"eight_trigrams_formation_owned",
			false
		)
	)

	var eight_trigrams_formation = (
		weapon_manager.get_weapon_by_name(
			"Eight Trigrams Formation"
		)
	)

	if eight_trigrams_formation_owned:
		if eight_trigrams_formation == null:
			weapon_manager.add_eight_trigrams_formation()

			eight_trigrams_formation = (
				weapon_manager.get_weapon_by_name(
					"Eight Trigrams Formation"
				)
			)

		if eight_trigrams_formation != null:
			var eight_trigrams_formation_level: int = clampi(
				int(
					save_data.get(
						"eight_trigrams_formation_level",
						1
					)
				),
				1,
				EightTrigramsFormationWeapon.MAX_LEVEL
			)

			eight_trigrams_formation.level = (
				eight_trigrams_formation_level
			)

			eight_trigrams_formation.apply_level_stats()

	DebugLogger.system(str("------------------------------------------"))
	DebugLogger.system(str("CHECKPOINT BERHASIL DIMUAT!"))

	DebugLogger.system(str(
		"Survival Time: ",
		survival_manager.format_time()
	))

	DebugLogger.system(str(
		"Wave: ",
		wave_manager.current_wave
	))

	DebugLogger.system(str(
		"Wave Timer: ",
		wave_manager.wave_timer
	))

	DebugLogger.system(str(
		"Difficulty: ",
		difficulty_manager.difficulty_level
	))

	DebugLogger.system(str(
		"Player Level: ",
		player.level
	))

	DebugLogger.system(str(
		"EXP: ",
		player.experience,
		"/",
		player.experience_to_next_level
	))

	DebugLogger.system(str(
		"Spiritual Insight Level: ",
		player.spiritual_insight_level
	))

	DebugLogger.system(str(
		"EXP Multiplier: ",
		player.get_experience_multiplier()
	))

	DebugLogger.system(str(
		"Movement Speed Level: ",
		player.movement_speed_level
	))

	DebugLogger.system(str(
		"Movement Speed: ",
		player.speed
	))

	DebugLogger.system(str(
		"Body Refinement Level: ",
		player_health.body_refinement_level
	))

	DebugLogger.system(str(
		"Player HP: ",
		player_health.current_health,
		"/",
		player_health.max_health
	))

	DebugLogger.system(str(
		"Qi Shield Level: ",
		player_health.qi_shield_level
	))

	DebugLogger.system(str(
		"Qi Shield Charges: ",
		player_health.qi_shield_charges
	))

	DebugLogger.system(str(
		"Iron Body Level: ",
		player_health.iron_body_level
	))

	DebugLogger.system(str(
		"Iron Body Damage Reduction: ",
		player_health.get_iron_body_reduction() * 100.0,
		"%"
	))

	DebugLogger.system(str(
		"Blood Qi Level: ",
		player_health.blood_qi_level
	))

	DebugLogger.system(str(
		"Blood Qi Kill Progress: ",
		player_health.blood_qi_kill_progress,
		"/",
		player_health.get_blood_qi_kills_required()
	))

	DebugLogger.system(str(
		"Power Level: ",
		player_stats.power_level
	))

	DebugLogger.system(str(
		"Attack Speed Level: ",
		player_stats.attack_speed_level
	))

	DebugLogger.system(str(
		"Sword Intent Level: ",
		player_stats.sword_intent_level
	))

	DebugLogger.system(str(
		"Critical Chance: ",
		player_stats.get_critical_chance() * 100.0,
		"%"
	))

	DebugLogger.system(str(
		"Sword Dao Resonance Owned: ",
		player_stats.has_sword_dao_resonance()
	))

	DebugLogger.system(str(
		"Yin-Yang Reversal Owned: ",
		player_stats.has_yin_yang_reversal()
	))

	DebugLogger.system(str(
		"Heavenly Tribulation Owned: ",
		player_stats.has_heavenly_tribulation()
	))

	if spirit_sword != null:
		DebugLogger.system(str(
			"Spirit Sword Level: ",
			spirit_sword.level
		))

	if fire_orb != null:
		DebugLogger.system(str(
			"Fire Orb Level: ",
			fire_orb.level
		))
	else:
		DebugLogger.system(str("Fire Orb: Not Owned"))

	if thunder_talisman != null:
		DebugLogger.system(str(
			"Thunder Talisman Level: ",
			thunder_talisman.level
		))

		DebugLogger.system(str(
			"Thunder Talisman Damage: ",
			thunder_talisman.base_damage
		))

		DebugLogger.system(str(
			"Thunder Talisman Chain Count: ",
			thunder_talisman.chain_count
		))
	else:
		DebugLogger.system(str("Thunder Talisman: Not Owned"))

	if yin_yang_blades != null:
		DebugLogger.system(str(
			"Yin-Yang Blades Level: ",
			yin_yang_blades.level
		))

		DebugLogger.system(str(
			"Yin-Yang Blades Damage: ",
			yin_yang_blades.damage
		))

		DebugLogger.system(str(
			"Yin-Yang Blades Blade Count: ",
			yin_yang_blades.blade_count
		))
	else:
		DebugLogger.system(str("Yin-Yang Blades: Not Owned"))

	if heavenly_sword_rain != null:
		DebugLogger.system(str(
			"Heavenly Sword Rain Level: ",
			heavenly_sword_rain.level
		))

		DebugLogger.system(str(
			"Heavenly Sword Rain Damage: ",
			heavenly_sword_rain.damage
		))

		DebugLogger.system(str(
			"Heavenly Sword Rain Strike Count: ",
			heavenly_sword_rain.strike_count
		))

		DebugLogger.system(str(
			"Heavenly Sword Rain Radius: ",
			heavenly_sword_rain.strike_radius
		))
	else:
		DebugLogger.system(str("Heavenly Sword Rain: Not Owned"))

	if eight_trigrams_formation != null:
		DebugLogger.system(str(
			"Eight Trigrams Formation Level: ",
			eight_trigrams_formation.level
		))

		DebugLogger.system(str(
			"Eight Trigrams Formation Damage: ",
			eight_trigrams_formation.damage
		))

		DebugLogger.system(str(
			"Eight Trigrams Formation Radius: ",
			eight_trigrams_formation.formation_radius
		))

		DebugLogger.system(str(
			"Eight Trigrams Formation Duration: ",
			eight_trigrams_formation.formation_duration
		))

		DebugLogger.system(str(
			"Eight Trigrams Formation Count: ",
			eight_trigrams_formation.formation_count
		))
	else:
		DebugLogger.system(str("Eight Trigrams Formation: Not Owned"))

	DebugLogger.system(str("=========================================="))
	return true

func mark_defeat_pending() -> bool:
	defeat_pending = true
	if not SaveManager.has_save_file("checkpoint"):
		return true
	var io_result: Dictionary = SaveManager.read_save_data("checkpoint")
	if not bool(io_result.get("success", false)):
		return false
	var save_data: Dictionary = io_result.get("data", {}).duplicate(true)
	save_data["version"] = SAVE_VERSION
	save_data["defeat_pending"] = true
	save_data["rewarded_revive_used"] = rewarded_revive_used
	var write_result: Dictionary = SaveManager.write_save_data(
		"checkpoint",
		save_data
	)
	return bool(write_result.get("success", false))


func can_use_rewarded_revive() -> bool:
	return not rewarded_revive_used


func mark_rewarded_revive_used() -> void:
	rewarded_revive_used = true


func clear_defeat_pending() -> void:
	defeat_pending = false


func delete_checkpoint() -> bool:
	DebugLogger.system(str("Mencoba menghapus checkpoint..."))
	var absolute_path := ProjectSettings.globalize_path(
		SAVE_PATH
	)
	DebugLogger.system(str("Delete path: ", absolute_path))
	var delete_result: Dictionary = SaveManager.delete_active_run_save(
		"checkpoint"
	)
	if bool(delete_result.get("success", false)):
		if bool(delete_result.get("existed", false)):
			DebugLogger.system(str("CHECKPOINT BERHASIL DIHAPUS!"))
		else:
			DebugLogger.system(str("Tidak ada checkpoint untuk dihapus."))
	else:
		push_error(str(
			"ERROR: Gagal menghapus checkpoint! ",
			delete_result.get("error", "unknown error")
		))
	DebugLogger.system(str(
		"Checkpoint masih ada setelah delete? ",
		FileAccess.file_exists(SAVE_PATH)
	))
	if bool(delete_result.get("success", false)):
		defeat_pending = false
	return bool(delete_result.get("success", false))
