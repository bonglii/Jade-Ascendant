class_name FireOrbWeapon
extends Weapon

## Fire Orb Weapon
## Menembakkan orb api ke target.
## Final damage dihitung melalui PlayerStats.
##
## Mulai Lv.3, Fire Orb membuka Cinder Bloom: direct-hit damage utama
## tetap sama, sementara musuh lain di sekitar impact menerima splash damage.
## Radius dan splash multiplier meningkat pada milestone Lv.5 dan Lv.7.

@export var projectile_scene: PackedScene = preload(
	"res://scenes/weapons/fire_orb.tscn"
)

const MAX_LEVEL: int = 7

const CINDER_BLOOM_UNLOCK_LEVEL: int = 3
const CINDER_BLOOM_LEVEL_3_RADIUS: float = 48.0
const CINDER_BLOOM_LEVEL_5_RADIUS: float = 60.0
const CINDER_BLOOM_LEVEL_7_RADIUS: float = 72.0
const CINDER_BLOOM_LEVEL_3_MULTIPLIER: float = 0.30
const CINDER_BLOOM_LEVEL_5_MULTIPLIER: float = 0.35
const CINDER_BLOOM_LEVEL_7_MULTIPLIER: float = 0.40
const BASE_IMPACT_VISUAL_RADIUS: float = 34.0

var level: int = 1
var base_damage: float = 20.0

func _ready() -> void:
	weapon_name = "Fire Orb"
	cooldown = 2.0

func attack(player: Node2D, target: Node2D) -> void:
	if player == null or target == null:
		return

	var orb = projectile_scene.instantiate()
	var damage_result: Dictionary = (
		player.player_stats.calculate_damage_result(
			base_damage
		)
	)

	player.get_parent().add_child(orb)
	orb.global_position = player.global_position

	orb.damage = float(damage_result["damage"])
	orb.is_critical = bool(damage_result["is_critical"])
	orb.cinder_bloom_radius = get_cinder_bloom_radius()
	orb.cinder_bloom_damage_multiplier = (
		get_cinder_bloom_damage_multiplier()
	)
	orb.impact_visual_scale = get_impact_visual_scale()

	orb.setup(target.global_position)

func upgrade() -> void:
	if level >= MAX_LEVEL:
		return

	level += 1
	base_damage += 10.0

	DebugLogger.system(str("Fire Orb Level: ", level))
	DebugLogger.system(str("Fire Orb Damage: ", base_damage))

	if level == CINDER_BLOOM_UNLOCK_LEVEL:
		DebugLogger.system(
			"Fire Orb Art Awakened: Cinder Bloom"
		)
	elif level == 5 or level == 7:
		DebugLogger.system(str(
			"Cinder Bloom Refined | Radius: ",
			get_cinder_bloom_radius(),
			" | Splash: ",
			get_cinder_bloom_damage_multiplier() * 100.0,
			"%"
		))

## Mengembalikan radius actual gameplay Cinder Bloom untuk level saat ini.
## Level di bawah 3 tetap merupakan projectile single-target murni.
func get_cinder_bloom_radius() -> float:
	if level >= 7:
		return CINDER_BLOOM_LEVEL_7_RADIUS
	if level >= 5:
		return CINDER_BLOOM_LEVEL_5_RADIUS
	if level >= CINDER_BLOOM_UNLOCK_LEVEL:
		return CINDER_BLOOM_LEVEL_3_RADIUS
	return 0.0

## Splash hanya mengenai enemy selain direct-hit target, sehingga single-target
## baseline Fire Orb tidak berubah oleh identity pass ini.
func get_cinder_bloom_damage_multiplier() -> float:
	if level >= 7:
		return CINDER_BLOOM_LEVEL_7_MULTIPLIER
	if level >= 5:
		return CINDER_BLOOM_LEVEL_5_MULTIPLIER
	if level >= CINDER_BLOOM_UNLOCK_LEVEL:
		return CINDER_BLOOM_LEVEL_3_MULTIPLIER
	return 0.0

## Menskalakan impact presentation mengikuti radius actual splash.
## Lv.1-2 mempertahankan ukuran hit effect production sebelumnya.
func get_impact_visual_scale() -> float:
	var bloom_radius: float = get_cinder_bloom_radius()
	if bloom_radius <= 0.0:
		return 1.0

	return maxf(
		bloom_radius / BASE_IMPACT_VISUAL_RADIUS,
		1.0
	)
