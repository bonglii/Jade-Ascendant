class_name FireOrbWeapon
extends Weapon

## Fire Orb Weapon
## Menembakkan orb api ke target.
## Final damage dihitung melalui PlayerStats.

@export var projectile_scene: PackedScene = preload(
	"res://scenes/weapons/fire_orb.tscn"
)

const MAX_LEVEL: int = 7
var level: int = 1
var base_damage: float = 20.0

func _ready() -> void:
	weapon_name = "Fire Orb"
	cooldown = 2.0

func attack(player: Node2D, target: Node2D) -> void:
	if player == null or target == null:
		return

	var orb = projectile_scene.instantiate()

	player.get_parent().add_child(orb)
	orb.global_position = player.global_position

	orb.damage = player.player_stats.calculate_damage(
		base_damage
	)

	orb.setup(target.global_position)

func upgrade() -> void:
	if level >= MAX_LEVEL:
		return
	level += 1
	base_damage += 10.0

	DebugLogger.system(str("Fire Orb Level: ", level))
	DebugLogger.system(str("Fire Orb Damage: ", base_damage))
