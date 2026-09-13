extends Node

signal cultivation_upgraded(upgrade_id: String, new_level: int)

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

var spirit_stone: int = 0

var vitality_level: int = 0
var sword_power_level: int = 0
var swift_qi_level: int = 0

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

	DebugLogger.system(str("Spirit Stone +", amount))
	DebugLogger.system(str("Total Spirit Stone: ", spirit_stone))

	save_progression()

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
	if SaveManager.is_progress_read_only() or SaveManager.is_save_write_blocked("progression"):
		return false
	if is_vitality_maxed():
		DebugLogger.system(str("Vitality sudah mencapai level maksimum."))
		return false

	var cost: int = get_vitality_cost()

	if spirit_stone < cost:
		DebugLogger.system(str("Spirit Stone tidak cukup untuk Vitality."))
		return false

	var previous: Dictionary = build_progression_save_data()
	spirit_stone -= cost
	vitality_level += 1

	DebugLogger.system(str("Vitality berhasil di-upgrade!"))
	DebugLogger.system(str("Vitality Level: ", vitality_level))
	DebugLogger.system(str("Spirit Stone tersisa: ", spirit_stone))

	if not SaveManager.write_save_batch({"progression": build_progression_save_data()}):
		apply_progression_save_data(previous)
		return false
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
	if SaveManager.is_progress_read_only() or SaveManager.is_save_write_blocked("progression"):
		return false
	if is_sword_power_maxed():
		DebugLogger.system(str("Sword Power sudah mencapai level maksimum."))
		return false

	var cost: int = get_sword_power_cost()

	if spirit_stone < cost:
		DebugLogger.system(str("Spirit Stone tidak cukup untuk Sword Power."))
		return false

	var previous: Dictionary = build_progression_save_data()
	spirit_stone -= cost
	sword_power_level += 1

	DebugLogger.system(str("Sword Power berhasil di-upgrade!"))
	DebugLogger.system(str("Sword Power Level: ", sword_power_level))
	DebugLogger.system(str("Spirit Stone tersisa: ", spirit_stone))

	if not SaveManager.write_save_batch({"progression": build_progression_save_data()}):
		apply_progression_save_data(previous)
		return false
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
	if SaveManager.is_progress_read_only() or SaveManager.is_save_write_blocked("progression"):
		return false
	if is_swift_qi_maxed():
		DebugLogger.system(str("Swift Qi sudah mencapai level maksimum."))
		return false

	var cost: int = get_swift_qi_cost()

	if spirit_stone < cost:
		DebugLogger.system(str("Spirit Stone tidak cukup untuk Swift Qi."))
		return false

	var previous: Dictionary = build_progression_save_data()
	spirit_stone -= cost
	swift_qi_level += 1

	DebugLogger.system(str("Swift Qi berhasil di-upgrade!"))
	DebugLogger.system(str("Swift Qi Level: ", swift_qi_level))
	DebugLogger.system(str("Spirit Stone tersisa: ", spirit_stone))

	if not SaveManager.write_save_batch({"progression": build_progression_save_data()}):
		apply_progression_save_data(previous)
		return false
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
		push_error(str("ERROR: Gagal menyimpan progression!"))
		return
	DebugLogger.system(str("Progression berhasil disimpan!"))

## Memuat permanent progression yang sebelumnya tersimpan.
func load_progression() -> void:
	var io_result: Dictionary = SaveManager.read_save_data("progression")
	if not bool(io_result.get("exists", false)):
		DebugLogger.system(str("Belum ada progression save."))
		return
	if not bool(io_result.get("success", false)):
		push_error(str("ERROR: Gagal membuka progression save!"))
		return
	var raw_save_data: Dictionary = io_result.get("data", {})
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
	last_loaded_save_version = source_version
	progression_save_migrated = source_version < SAVE_VERSION
	if progression_save_migrated:
		save_progression()
		DebugLogger.system(str(
			"Progression save migrated: v",
			source_version,
			" -> v",
			SAVE_VERSION
		))

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
		)
	}

## Menerapkan payload yang telah dinormalisasi ke runtime progression.
func apply_progression_save_data(save_data: Dictionary) -> bool:
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
	swift_qi_level = clampi(
		int(save_data["swift_qi_level"]),
		0,
		SWIFT_QI_MAX_LEVEL
	)
	return true

## Menampilkan status progression saat game mulai untuk kebutuhan debug.
func print_progression_status() -> void:
	DebugLogger.system(str("ProgressionManager aktif!"))
	DebugLogger.system(str("Spirit Stone: ", spirit_stone))
	DebugLogger.system(str("Vitality Level: ", vitality_level))
	DebugLogger.system(str("Sword Power Level: ", sword_power_level))
	DebugLogger.system(str("Swift Qi Level: ", swift_qi_level))
