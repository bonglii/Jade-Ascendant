extends Node

## Difficulty Manager
## Mengelola peningkatan difficulty berdasarkan survival time.
## Normal enemy mempertahankan base stat milik archetype masing-masing,
## lalu Difficulty memberikan scaling secara proporsional.

const DEFAULT_ENEMY_HP: float = 20.0
const DEFAULT_ENEMY_SPEED: float = 80.0
const HP_MULTIPLIER_PER_LEVEL: float = 0.25
const SPEED_MULTIPLIER_PER_LEVEL: float = 0.0625

@export var difficulty_interval: float = 60.0

var difficulty_level: int = 1
var last_difficulty_level: int = 1

@onready var survival_manager = (
	get_parent().get_node("SurvivalManager")
)

func _ready() -> void:
	DebugLogger.system(str("DifficultyManager aktif!"))

func _process(_delta: float) -> void:
	if survival_manager == null:
		return

	update_difficulty()

## Memperbarui Difficulty Level berdasarkan survival time.
func update_difficulty() -> void:
	var new_level: int = int(
		survival_manager.survival_time
		/ difficulty_interval
	) + 1

	if new_level == last_difficulty_level:
		return

	difficulty_level = new_level
	last_difficulty_level = new_level

	DebugLogger.system(str(
		"DIFFICULTY NAIK! Level: ",
		difficulty_level
	))

## Menghasilkan HP final tanpa menghilangkan identitas base HP Enemy.
## Parameter default menjaga kompatibilitas dengan caller lama.
func get_enemy_hp(
	base_hp: float = DEFAULT_ENEMY_HP
) -> float:
	var level_bonus: float = max(
		difficulty_level - 1,
		0
	) * HP_MULTIPLIER_PER_LEVEL

	return base_hp * (1.0 + level_bonus)

## Menghasilkan Speed final tanpa menghilangkan identitas base Speed Enemy.
## Parameter default menjaga kompatibilitas dengan caller lama.
func get_enemy_speed(
	base_speed: float = DEFAULT_ENEMY_SPEED
) -> float:
	var level_bonus: float = max(
		difficulty_level - 1,
		0
	) * SPEED_MULTIPLIER_PER_LEVEL

	return base_speed * (1.0 + level_bonus)

## Jumlah Enemy dasar per spawn tetap dikontrol oleh WaveManager.
func get_spawn_count() -> int:
	return 1
