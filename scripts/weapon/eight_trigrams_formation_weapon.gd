extends Weapon
class_name EightTrigramsFormationWeapon

## Eight Trigrams Formation
## Timed persistent-area weapon yang menciptakan formation
## pada posisi target dan memberikan periodic area damage.
##
## Weapon mengontrol progression, cooldown, damage,
## radius, duration, pulse interval, jumlah formation,
## serta posisi spawn setiap formation.
##
## Formation individual mengontrol lifetime,
## overlap detection, dan actual damage pulse.

const FORMATION_SCENE: PackedScene = preload(
	"res://scenes/weapons/eight_trigrams_formation.tscn"
)

const MAX_LEVEL: int = 7

const BASE_DAMAGE: float = 8.0
const BASE_RADIUS: float = 80.0
const BASE_DURATION: float = 4.0
const BASE_PULSE_INTERVAL: float = 0.75
const BASE_FORMATION_COUNT: int = 1

const LEVEL_2_DAMAGE: float = 11.0
const LEVEL_3_RADIUS: float = 96.0
const LEVEL_4_DAMAGE: float = 14.0
const LEVEL_5_DURATION: float = 5.0
const LEVEL_6_DAMAGE: float = 18.0
const LEVEL_7_FORMATION_COUNT: int = 2

const FORMATION_SPREAD_RADIUS: float = 64.0

var level: int = 1
var formation_radius: float = BASE_RADIUS
var formation_duration: float = BASE_DURATION
var pulse_interval: float = BASE_PULSE_INTERVAL
var formation_count: int = BASE_FORMATION_COUNT

func _init() -> void:
	weapon_name = "Eight Trigrams Formation"
	cooldown = 6.0

	apply_level_stats()

## Membuat seluruh formation pada area target.
func attack(player: Node2D, target: Node2D) -> void:
	if player == null:
		return

	if target == null:
		return

	if not is_instance_valid(target):
		return

	var player_stats: Node = player.get_node_or_null(
		"PlayerStats"
	)

	if player_stats == null:
		push_error(
			"PlayerStats tidak ditemukan untuk Eight Trigrams Formation."
		)
		return

	var target_position: Vector2 = target.global_position

	for formation_index in range(formation_count):
		spawn_formation(
			target_position,
			formation_index,
			player_stats
		)

## Menaikkan level Eight Trigrams Formation hingga level maksimum.
func upgrade() -> bool:
	if level >= MAX_LEVEL:
		DebugLogger.system(str(
			"Eight Trigrams Formation sudah mencapai level maksimum."
		))
		return false

	level += 1

	apply_level_stats()
	print_upgrade_status()

	return true

## Menerapkan progression berdasarkan level saat ini.
func apply_level_stats() -> void:
	level = clamp(
		level,
		1,
		MAX_LEVEL
	)

	damage = BASE_DAMAGE
	formation_radius = BASE_RADIUS
	formation_duration = BASE_DURATION
	pulse_interval = BASE_PULSE_INTERVAL
	formation_count = BASE_FORMATION_COUNT

	if level >= 2:
		damage = LEVEL_2_DAMAGE

	if level >= 3:
		formation_radius = LEVEL_3_RADIUS

	if level >= 4:
		damage = LEVEL_4_DAMAGE

	if level >= 5:
		formation_duration = LEVEL_5_DURATION

	if level >= 6:
		damage = LEVEL_6_DAMAGE

	if level >= 7:
		formation_count = LEVEL_7_FORMATION_COUNT

## Membuat satu formation pada posisi yang ditentukan.
func spawn_formation(
	target_position: Vector2,
	formation_index: int,
	player_stats: Node
) -> void:
	var formation: EightTrigramsFormation = (
		FORMATION_SCENE.instantiate()
		as EightTrigramsFormation
	)

	if formation == null:
		push_error(
			"Eight Trigrams Formation scene gagal dibuat."
		)
		return

	formation.setup(
		damage,
		formation_radius,
		formation_duration,
		pulse_interval,
		player_stats
	)

	var spawn_position: Vector2 = (
		get_formation_position(
			target_position,
			formation_index
		)
	)

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		formation.queue_free()
		return

	current_scene.add_child(formation)

	formation.global_position = spawn_position

## Menghitung posisi formation agar tidak saling menumpuk.
func get_formation_position(
	target_position: Vector2,
	formation_index: int
) -> Vector2:
	if formation_count <= 1:
		return target_position

	var angle: float = (
		TAU
		* float(formation_index)
		/ float(formation_count)
	)

	var offset: Vector2 = (
		Vector2.RIGHT.rotated(angle)
		* FORMATION_SPREAD_RADIUS
	)

	return target_position + offset

## Menampilkan status progression setelah upgrade.
func print_upgrade_status() -> void:
	DebugLogger.system(str(
		"Eight Trigrams Formation Level: ",
		level
	))

	DebugLogger.system(str(
		"Eight Trigrams Formation Damage: ",
		damage
	))

	DebugLogger.system(str(
		"Eight Trigrams Formation Radius: ",
		formation_radius
	))

	DebugLogger.system(str(
		"Eight Trigrams Formation Duration: ",
		formation_duration
	))

	DebugLogger.system(str(
		"Eight Trigrams Formation Pulse Interval: ",
		pulse_interval
	))

	DebugLogger.system(str(
		"Eight Trigrams Formation Count: ",
		formation_count
	))
