extends Node

signal cultivation_upgraded(upgrade_id: String, new_level: int)
signal hero_progress_changed(
	new_level: int,
	current_experience: int,
	experience_to_next: int
)
signal hero_level_up(new_level: int)
signal hero_milestone_claimed(milestone_level: int)

## Progression Manager
## Menyimpan permanent progression yang tetap tersedia setelah run berakhir.

const SAVE_PATH: String = "user://progression.save"
const SAVE_VERSION: int = 1
const LEGACY_SAVE_VERSION: int = 0

const REQUIRED_SAVE_KEYS: Array[String] = [
	"spirit_stone",
	"vitality_level",
	"sword_power_level",
	"swift_qi_level"
]

const VITALITY_BASE_COST: int = 100
const SWORD_POWER_BASE_COST: int = 100
const SWIFT_QI_BASE_COST: int = 100

const VITALITY_MAX_LEVEL: int = 10
const SWORD_POWER_MAX_LEVEL: int = 10
const SWIFT_QI_MAX_LEVEL: int = 10

## Permanent Lin Yue mastery level. This is intentionally separate from the
## run-level system on player_1.gd and does not replace Cultivation.
const HERO_MAX_LEVEL: int = 50
const HERO_EXP_BASE: int = 100
const HERO_EXP_GROWTH: int = 25
const HERO_MILESTONE_LEVELS: Array[int] = [10, 20, 30, 40, 50]

var spirit_stone: int = 0

var vitality_level: int = 0
var sword_power_level: int = 0
var swift_qi_level: int = 0

## Total permanent Hero EXP. Level is derived from this single authority so
## save data cannot contain a mismatched level/EXP pair.
var hero_experience_total: int = 0
var hero_progression_initialized: bool = false
var hero_milestones_claimed: Array[int] = []

var last_loaded_save_version: int = SAVE_VERSION
var progression_save_migrated: bool = false

func _ready() -> void:
	load_progression()
	print_progression_status()

## Menambahkan Spirit Stone dan langsung menyimpan progression.
func add_spirit_stone(amount: int) -> void:
	if amount <= 0:
		return

	spirit_stone += amount

	print("Spirit Stone +", amount)
	print("Total Spirit Stone: ", spirit_stone)

	save_progression()

## Mengembalikan kebutuhan EXP untuk naik dari Hero Level tertentu.
func get_hero_experience_to_next_for_level(hero_level: int) -> int:
	if hero_level >= HERO_MAX_LEVEL:
		return 0
	var safe_level: int = clampi(hero_level, 1, HERO_MAX_LEVEL)
	return HERO_EXP_BASE + ((safe_level - 1) * HERO_EXP_GROWTH)

## Total EXP maksimum yang dapat disimpan sampai Lin Yue mencapai Level 50.
func get_hero_total_experience_cap() -> int:
	var total: int = 0
	for hero_level: int in range(1, HERO_MAX_LEVEL):
		total += get_hero_experience_to_next_for_level(hero_level)
	return total

## Mengubah total permanent EXP menjadi Hero Level tanpa menyimpan level ganda.
func get_hero_level_for_total_experience(total_experience: int) -> int:
	var remaining: int = clampi(
		total_experience,
		0,
		get_hero_total_experience_cap()
	)
	var hero_level: int = 1
	while hero_level < HERO_MAX_LEVEL:
		var required: int = get_hero_experience_to_next_for_level(hero_level)
		if remaining < required:
			break
		remaining -= required
		hero_level += 1
	return hero_level

func get_hero_level() -> int:
	return get_hero_level_for_total_experience(hero_experience_total)

func get_hero_current_level_experience() -> int:
	if get_hero_level() >= HERO_MAX_LEVEL:
		return 0
	var remaining: int = clampi(
		hero_experience_total,
		0,
		get_hero_total_experience_cap()
	)
	for hero_level: int in range(1, get_hero_level()):
		remaining -= get_hero_experience_to_next_for_level(hero_level)
	return maxi(remaining, 0)

func get_hero_experience_to_next_level() -> int:
	return get_hero_experience_to_next_for_level(get_hero_level())

func get_hero_progress_ratio() -> float:
	var required: int = get_hero_experience_to_next_level()
	if required <= 0:
		return 1.0
	return clampf(
		float(get_hero_current_level_experience()) / float(required),
		0.0,
		1.0
	)

## Rank title is presentation identity, not an additional combat-stat layer.
func get_hero_rank_title_for_level(hero_level: int) -> String:
	var safe_level: int = clampi(hero_level, 1, HERO_MAX_LEVEL)
	if safe_level >= 50:
		return "HEAVENLY ASCENDANT"
	if safe_level >= 40:
		return "ASCENDANT"
	if safe_level >= 30:
		return "DAO MASTER"
	if safe_level >= 20:
		return "JADE ADEPT"
	if safe_level >= 10:
		return "MERIDIAN DISCIPLE"
	return "WANDERING CULTIVATOR"

func get_hero_rank_title() -> String:
	return get_hero_rank_title_for_level(get_hero_level())

func get_hero_milestone_levels() -> Array[int]:
	var milestone_levels: Array[int] = []
	milestone_levels.assign(HERO_MILESTONE_LEVELS)
	return milestone_levels

func is_valid_hero_milestone(milestone_level: int) -> bool:
	return milestone_level in HERO_MILESTONE_LEVELS

func is_hero_milestone_reached(milestone_level: int) -> bool:
	return (
		is_valid_hero_milestone(milestone_level)
		and get_hero_level() >= milestone_level
	)

func is_hero_milestone_claimed(milestone_level: int) -> bool:
	return milestone_level in hero_milestones_claimed

func can_claim_hero_milestone(milestone_level: int) -> bool:
	return (
		is_hero_milestone_reached(milestone_level)
		and not is_hero_milestone_claimed(milestone_level)
	)

func get_next_claimable_hero_milestone() -> int:
	for milestone_level: int in HERO_MILESTONE_LEVELS:
		if can_claim_hero_milestone(milestone_level):
			return milestone_level
	return 0

func get_next_hero_milestone() -> int:
	var hero_level: int = get_hero_level()
	for milestone_level: int in HERO_MILESTONE_LEVELS:
		if hero_level < milestone_level:
			return milestone_level
	return 0

func are_all_hero_milestones_claimed() -> bool:
	for milestone_level: int in HERO_MILESTONE_LEVELS:
		if not is_hero_milestone_claimed(milestone_level):
			return false
	return true

func preview_claim_hero_milestone(
	progression_data: Dictionary,
	milestone_level: int
) -> Dictionary:
	if not is_valid_hero_milestone(milestone_level):
		return {}
	var preview: Dictionary = progression_data.duplicate(true)
	var preview_level: int = get_hero_level_for_total_experience(
		int(preview.get("hero_experience_total", 0))
	)
	if preview_level < milestone_level:
		return {}
	var claimed_levels: Array[int] = _normalize_hero_milestones_claimed(
		preview.get("hero_milestones_claimed", [])
	)
	if milestone_level in claimed_levels:
		return {}
	claimed_levels.append(milestone_level)
	claimed_levels.sort()
	preview["hero_milestones_claimed"] = claimed_levels
	return preview

## Pure preview used by RewardManager before its atomic multi-domain commit.
func preview_add_hero_experience(
	progression_data: Dictionary,
	amount: int
) -> Dictionary:
	var preview: Dictionary = progression_data.duplicate(true)
	var current_total: int = clampi(
		int(preview.get("hero_experience_total", 0)),
		0,
		get_hero_total_experience_cap()
	)
	preview["hero_experience_total"] = clampi(
		current_total + maxi(amount, 0),
		0,
		get_hero_total_experience_cap()
	)
	return preview

## One-time feature bootstrap for saves that predate permanent Hero Level. Existing
## cleared stages can seed first-clear EXP without inventing repeat-clear history.
func initialize_hero_progression(initial_total_experience: int) -> bool:
	if hero_progression_initialized:
		return true
	var save_data: Dictionary = build_progression_save_data()
	save_data["hero_experience_total"] = clampi(
		initial_total_experience,
		0,
		get_hero_total_experience_cap()
	)
	var io_result: Dictionary = SaveManager.write_save_data(
		"progression",
		save_data
	)
	if not bool(io_result.get("success", false)):
		return false
	if not apply_progression_save_data(save_data, true):
		return false
	hero_progression_initialized = true
	return true

## Memeriksa apakah Vitality sudah mencapai batas maksimum.
func is_vitality_maxed() -> bool:
	return vitality_level >= VITALITY_MAX_LEVEL

## Mengembalikan harga upgrade Vitality berdasarkan level saat ini.
func get_vitality_cost() -> int:
	if is_vitality_maxed():
		return 0

	return VITALITY_BASE_COST * (vitality_level + 1)

## Membeli satu level Vitality jika Spirit Stone mencukupi.
func buy_vitality() -> bool:
	if is_vitality_maxed():
		print("Vitality sudah mencapai level maksimum.")
		return false

	var cost: int = get_vitality_cost()

	if spirit_stone < cost:
		print("Spirit Stone tidak cukup untuk Vitality.")
		return false

	spirit_stone -= cost
	vitality_level += 1

	print("Vitality berhasil di-upgrade!")
	print("Vitality Level: ", vitality_level)
	print("Spirit Stone tersisa: ", spirit_stone)

	save_progression()
	cultivation_upgraded.emit("vitality", vitality_level)
	return true

## Memeriksa apakah Sword Power sudah mencapai batas maksimum.
func is_sword_power_maxed() -> bool:
	return sword_power_level >= SWORD_POWER_MAX_LEVEL

## Mengembalikan harga upgrade Sword Power berdasarkan level saat ini.
func get_sword_power_cost() -> int:
	if is_sword_power_maxed():
		return 0

	return SWORD_POWER_BASE_COST * (sword_power_level + 1)

## Membeli satu level Sword Power jika Spirit Stone mencukupi.
func buy_sword_power() -> bool:
	if is_sword_power_maxed():
		print("Sword Power sudah mencapai level maksimum.")
		return false

	var cost: int = get_sword_power_cost()

	if spirit_stone < cost:
		print("Spirit Stone tidak cukup untuk Sword Power.")
		return false

	spirit_stone -= cost
	sword_power_level += 1

	print("Sword Power berhasil di-upgrade!")
	print("Sword Power Level: ", sword_power_level)
	print("Spirit Stone tersisa: ", spirit_stone)

	save_progression()
	cultivation_upgraded.emit(
		"sword_power",
		sword_power_level
	)
	return true

## Memeriksa apakah Swift Qi sudah mencapai batas maksimum.
func is_swift_qi_maxed() -> bool:
	return swift_qi_level >= SWIFT_QI_MAX_LEVEL

## Mengembalikan harga upgrade Swift Qi berdasarkan level saat ini.
func get_swift_qi_cost() -> int:
	if is_swift_qi_maxed():
		return 0

	return SWIFT_QI_BASE_COST * (swift_qi_level + 1)

## Membeli satu level Swift Qi jika Spirit Stone mencukupi.
func buy_swift_qi() -> bool:
	if is_swift_qi_maxed():
		print("Swift Qi sudah mencapai level maksimum.")
		return false

	var cost: int = get_swift_qi_cost()

	if spirit_stone < cost:
		print("Spirit Stone tidak cukup untuk Swift Qi.")
		return false

	spirit_stone -= cost
	swift_qi_level += 1

	print("Swift Qi berhasil di-upgrade!")
	print("Swift Qi Level: ", swift_qi_level)
	print("Spirit Stone tersisa: ", spirit_stone)

	save_progression()
	cultivation_upgraded.emit("swift_qi", swift_qi_level)
	return true

## Menyimpan seluruh permanent progression ke disk.
func save_progression() -> void:
	var save_data: Dictionary = build_progression_save_data()
	var io_result: Dictionary = SaveManager.write_save_data(
		"progression",
		save_data
	)
	if not bool(io_result.get("success", false)):
		print("ERROR: Gagal menyimpan progression!")
		return
	print("Progression berhasil disimpan!")

## Memuat permanent progression yang sebelumnya tersimpan.
func load_progression() -> void:
	var io_result: Dictionary = SaveManager.read_save_data("progression")
	if not bool(io_result.get("exists", false)):
		print("Belum ada progression save.")
		return
	if not bool(io_result.get("success", false)):
		print("ERROR: Gagal membuka progression save!")
		return
	var raw_save_data: Dictionary = io_result.get("data", {})
	var had_hero_progression: bool = raw_save_data.has("hero_experience_total")
	var source_version: int = get_progression_save_version(raw_save_data)
	var normalized_data: Dictionary = normalize_progression_save_data(
		raw_save_data
	)
	if normalized_data.is_empty():
		push_warning(
			"ProgressionManager: schema progression.save tidak didukung."
		)
		return
	if not apply_progression_save_data(normalized_data):
		push_warning(
			"ProgressionManager: progression.save gagal diterapkan."
		)
		return
	hero_progression_initialized = had_hero_progression
	last_loaded_save_version = source_version
	progression_save_migrated = source_version < SAVE_VERSION
	if progression_save_migrated:
		save_progression()
		print(
			"Progression save migrated: v",
			source_version,
			" -> v",
			SAVE_VERSION
		)

## Membentuk payload progression sesuai schema produksi terbaru.
func build_progression_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"spirit_stone": maxi(spirit_stone, 0),
		"vitality_level": clampi(
			vitality_level,
			0,
			VITALITY_MAX_LEVEL
		),
		"sword_power_level": clampi(
			sword_power_level,
			0,
			SWORD_POWER_MAX_LEVEL
		),
		"swift_qi_level": clampi(
			swift_qi_level,
			0,
			SWIFT_QI_MAX_LEVEL
		),
		"hero_experience_total": clampi(
			hero_experience_total,
			0,
			get_hero_total_experience_cap()
		),
		"hero_milestones_claimed": _normalize_hero_milestones_claimed(
			hero_milestones_claimed
		)
	}

## Format lama tanpa version diperlakukan sebagai schema v0.
func get_progression_save_version(save_data: Dictionary) -> int:
	return int(save_data.get("version", LEGACY_SAVE_VERSION))

## Migrasi in-memory menuju schema terbaru tanpa mengubah runtime state.
func normalize_progression_save_data(save_data: Dictionary) -> Dictionary:
	var source_version: int = get_progression_save_version(save_data)
	if (
		source_version < LEGACY_SAVE_VERSION
		or source_version > SAVE_VERSION
	):
		return {}
	for required_key in REQUIRED_SAVE_KEYS:
		if not save_data.has(required_key):
			return {}
	return {
		"version": SAVE_VERSION,
		"spirit_stone": maxi(
			int(save_data.get("spirit_stone", 0)),
			0
		),
		"vitality_level": clampi(
			int(save_data.get("vitality_level", 0)),
			0,
			VITALITY_MAX_LEVEL
		),
		"sword_power_level": clampi(
			int(save_data.get("sword_power_level", 0)),
			0,
			SWORD_POWER_MAX_LEVEL
		),
		"swift_qi_level": clampi(
			int(save_data.get("swift_qi_level", 0)),
			0,
			SWIFT_QI_MAX_LEVEL
		),
		"hero_experience_total": clampi(
			int(save_data.get("hero_experience_total", 0)),
			0,
			get_hero_total_experience_cap()
		),
		"hero_milestones_claimed": _normalize_hero_milestones_claimed(
			save_data.get("hero_milestones_claimed", [])
		)
	}

## Menerapkan payload yang telah dinormalisasi ke runtime progression.
func apply_progression_save_data(
	save_data: Dictionary,
	emit_hero_signals: bool = false
) -> bool:
	if get_progression_save_version(save_data) != SAVE_VERSION:
		return false
	for required_key in REQUIRED_SAVE_KEYS:
		if not save_data.has(required_key):
			return false
	spirit_stone = maxi(int(save_data["spirit_stone"]), 0)
	vitality_level = clampi(
		int(save_data["vitality_level"]),
		0,
		VITALITY_MAX_LEVEL
	)
	sword_power_level = clampi(
		int(save_data["sword_power_level"]),
		0,
		SWORD_POWER_MAX_LEVEL
	)
	var previous_hero_level: int = get_hero_level()
	var previous_hero_total: int = hero_experience_total
	var previous_milestones_claimed: Array[int] = []
	previous_milestones_claimed.assign(hero_milestones_claimed)
	swift_qi_level = clampi(
		int(save_data["swift_qi_level"]),
		0,
		SWIFT_QI_MAX_LEVEL
	)
	hero_experience_total = clampi(
		int(save_data.get("hero_experience_total", 0)),
		0,
		get_hero_total_experience_cap()
	)
	hero_milestones_claimed = _normalize_hero_milestones_claimed(
		save_data.get("hero_milestones_claimed", [])
	)
	if emit_hero_signals and hero_experience_total != previous_hero_total:
		var new_hero_level: int = get_hero_level()
		hero_progress_changed.emit(
			new_hero_level,
			get_hero_current_level_experience(),
			get_hero_experience_to_next_level()
		)
		if new_hero_level > previous_hero_level:
			for gained_level: int in range(
				previous_hero_level + 1,
				new_hero_level + 1
			):
				hero_level_up.emit(gained_level)
	if emit_hero_signals:
		for milestone_level: int in hero_milestones_claimed:
			if milestone_level not in previous_milestones_claimed:
				hero_milestone_claimed.emit(milestone_level)
	return true

func _normalize_hero_milestones_claimed(raw_claims: Variant) -> Array[int]:
	var normalized: Array[int] = []
	if raw_claims is Array:
		for raw_level: Variant in raw_claims:
			var milestone_level: int = int(raw_level)
			if (
				is_valid_hero_milestone(milestone_level)
				and milestone_level not in normalized
			):
				normalized.append(milestone_level)
	normalized.sort()
	return normalized

## Menampilkan status progression saat game mulai untuk kebutuhan debug.
func print_progression_status() -> void:
	print("ProgressionManager aktif!")
	print("Spirit Stone: ", spirit_stone)
	print("Vitality Level: ", vitality_level)
	print("Sword Power Level: ", sword_power_level)
	print("Swift Qi Level: ", swift_qi_level)
	print("Lin Yue Hero Level: ", get_hero_level())
	print("Hero Milestones Claimed: ", hero_milestones_claimed)
	if get_hero_level() >= HERO_MAX_LEVEL:
		print("Hero EXP: MAX")
	else:
		print(
			"Hero EXP: ",
			get_hero_current_level_experience(),
			"/",
			get_hero_experience_to_next_level()
		)
