extends Node

signal cultivation_upgraded(upgrade_id: String, new_level: int)
signal hero_progress_changed(
	new_level: int,
	current_experience: int,
	experience_to_next: int
)
signal hero_level_up(new_level: int)

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

var spirit_stone: int = 0

var vitality_level: int = 0
var sword_power_level: int = 0
var swift_qi_level: int = 0

## Total permanent Hero EXP. Level is derived from this single authority so
## save data cannot contain a mismatched level/EXP pair.
var hero_experience_total: int = 0
var hero_progression_initialized: bool = false

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
func get_hero_rank_title() -> String:
	var hero_level: int = get_hero_level()
	if hero_level >= 50:
		return "HEAVENLY ASCENDANT"
	if hero_level >= 40:
		return "ASCENDANT"
	if hero_level >= 30:
		return "DAO MASTER"
	if hero_level >= 20:
		return "JADE ADEPT"
	if hero_level >= 10:
		return "MERIDIAN DISCIPLE"
	return "WANDERING CULTIVATOR"

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
	return true

## Menampilkan status progression saat game mulai untuk kebutuhan debug.
func print_progression_status() -> void:
	print("ProgressionManager aktif!")
	print("Spirit Stone: ", spirit_stone)
	print("Vitality Level: ", vitality_level)
	print("Sword Power Level: ", sword_power_level)
	print("Swift Qi Level: ", swift_qi_level)
	print("Lin Yue Hero Level: ", get_hero_level())
	if get_hero_level() >= HERO_MAX_LEVEL:
		print("Hero EXP: MAX")
	else:
		print(
			"Hero EXP: ",
			get_hero_current_level_experience(),
			"/",
			get_hero_experience_to_next_level()
		)
