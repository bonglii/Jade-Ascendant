extends Weapon
class_name HeavenlySwordRainWeapon

## Heavenly Sword Rain Weapon
## Timed ranged-area weapon yang memanggil beberapa
## spiritual sword untuk menghantam area di sekitar target.
##
## Weapon mengontrol progression, damage, jumlah strike,
## radius impact, cooldown, dan pola penyebaran strike.
##
## Ketika Heavenly Tribulation dimiliki,
## successful impact dari satu strike akan memanggil
## satu Heavenly Lightning pada posisi impact tersebut.

const STRIKE_SCENE: PackedScene = preload(
	"res://scenes/weapons/heavenly_sword_rain.tscn"
)

const HEAVENLY_LIGHTNING_SCENE: PackedScene = preload(
	"res://scenes/weapons/heavenly_lightning.tscn"
)

const MAX_LEVEL: int = 7

const BASE_DAMAGE: float = 18.0
const DAMAGE_PER_LEVEL: float = 4.0

const BASE_STRIKE_COUNT: int = 2
const MAX_STRIKE_COUNT: int = 5

const BASE_STRIKE_RADIUS: float = 32.0
const STRIKE_SPREAD_RADIUS: float = 48.0

const TRIBULATION_DAMAGE_MULTIPLIER: float = 0.60
const TRIBULATION_RADIUS: float = 64.0

var level: int = 1
var strike_count: int = BASE_STRIKE_COUNT
var strike_radius: float = BASE_STRIKE_RADIUS

func _init() -> void:
	weapon_name = "Heavenly Sword Rain"
	cooldown = 2.4

	apply_level_stats()

## Memanggil seluruh strike Heavenly Sword Rain di sekitar target.
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
			"PlayerStats tidak ditemukan untuk Heavenly Sword Rain."
		)

		return

	for strike_index in range(strike_count):
		spawn_strike(
			target.global_position,
			strike_index,
			player_stats
		)

## Menaikkan level Heavenly Sword Rain hingga level maksimum.
func upgrade() -> bool:
	if level >= MAX_LEVEL:
		DebugLogger.system(str(
			"Heavenly Sword Rain sudah mencapai level maksimum."
		))

		return false

	level += 1

	apply_level_stats()
	print_upgrade_status()

	return true

## Menerapkan damage, jumlah strike, dan radius berdasarkan level.
func apply_level_stats() -> void:
	level = clamp(
		level,
		1,
		MAX_LEVEL
	)

	damage = (
		BASE_DAMAGE
		+ DAMAGE_PER_LEVEL * float(level - 1)
	)

	if level >= 7:
		strike_count = 5
	elif level >= 5:
		strike_count = 4
	elif level >= 3:
		strike_count = 3
	else:
		strike_count = 2

	if level >= 6:
		strike_radius = 44.0
	elif level >= 4:
		strike_radius = 38.0
	else:
		strike_radius = 32.0

## Membuat satu strike pada posisi impact yang ditentukan.
func spawn_strike(
	target_position: Vector2,
	strike_index: int,
	player_stats: Node
) -> void:
	var strike: HeavenlySwordRain = (
		STRIKE_SCENE.instantiate()
		as HeavenlySwordRain
	)

	if strike == null:
		push_error(
			"Heavenly Sword Rain scene gagal dibuat."
		)

		return

	strike.setup(
		damage,
		strike_radius,
		player_stats
	)

	strike.successful_impact.connect(
		_on_strike_successful_impact.bind(
			player_stats
		)
	)

	var impact_position: Vector2 = (
		get_strike_position(
			target_position,
			strike_index
		)
	)

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		strike.queue_free()
		return

	current_scene.add_child(strike)

	strike.global_position = impact_position

## Menghitung posisi strike agar tersebar di sekitar target.
func get_strike_position(
	target_position: Vector2,
	strike_index: int
) -> Vector2:
	if strike_index == 0:
		return target_position

	var angle: float = (
		TAU
		* float(strike_index)
		/ float(max(strike_count, 1))
	)

	var offset: Vector2 = (
		Vector2.RIGHT.rotated(angle)
		* STRIKE_SPREAD_RADIUS
	)

	return target_position + offset

## Menerima successful-hit event dari satu strike.
## Lightning hanya dibuat jika Heavenly Tribulation dimiliki.
func _on_strike_successful_impact(
	impact_position: Vector2,
	base_damage: float,
	player_stats: Node
) -> void:
	if player_stats == null:
		return

	if not player_stats.has_method(
		"has_heavenly_tribulation"
	):
		return

	if not player_stats.has_heavenly_tribulation():
		return

	spawn_heavenly_lightning(
		impact_position,
		base_damage,
		player_stats
	)

## Membuat satu Heavenly Lightning pada posisi successful impact.
func spawn_heavenly_lightning(
	impact_position: Vector2,
	base_damage: float,
	player_stats: Node
) -> void:
	var lightning: HeavenlyLightning = (
		HEAVENLY_LIGHTNING_SCENE.instantiate()
		as HeavenlyLightning
	)

	if lightning == null:
		push_error(
			"Heavenly Lightning scene gagal dibuat."
		)

		return

	var lightning_base_damage: float = (
		base_damage
		* TRIBULATION_DAMAGE_MULTIPLIER
	)

	lightning.setup(
		lightning_base_damage,
		TRIBULATION_RADIUS,
		player_stats
	)

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		lightning.queue_free()
		return

	current_scene.add_child(lightning)

	lightning.global_position = impact_position

	DebugLogger.combat(
		"Heavenly Tribulation Triggered"
		+ " | Base Damage: %.1f"
		% lightning_base_damage
	)

## Menampilkan status progression setelah upgrade.
func print_upgrade_status() -> void:
	DebugLogger.system(str(
		"Heavenly Sword Rain Level: ",
		level
	))

	DebugLogger.system(str(
		"Heavenly Sword Rain Damage: ",
		damage
	))

	DebugLogger.system(str(
		"Heavenly Sword Rain Strike Count: ",
		strike_count
	))

	DebugLogger.system(str(
		"Heavenly Sword Rain Radius: ",
		strike_radius
	))
