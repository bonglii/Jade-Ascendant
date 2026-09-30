extends "res://scripts/enemy/enemy_2.gd"
class_name RealmRangedEnemy

## IV/V projectile damage is owned by the projectile, not the caster.
## All production predictive/spread patterns and XP drops remain untouched.
const RealmProjectileFxScript = preload("res://scripts/enemy/realm_projectile_fx.gd")

var realm_projectile_damage: float = 2.0
var realm_projectile_speed: float = 205.0
var realm_visual_theme: StringName = &"frostveil"


func _spawn_projectile_toward(target_position: Vector2) -> void:
	var projectile: Node = ENEMY_PROJECTILE.instantiate()
	# Only realm-specific ranged projectiles receive the solar/frost stamped FX.
	# Apply script BEFORE base fields and _ready so damage scaling remains intact.
	projectile.set_script(RealmProjectileFxScript)
	projectile.set("realm_visual_theme", realm_visual_theme)
	projectile.set("damage", realm_projectile_damage)
	projectile.set("speed", realm_projectile_speed)
	if projectile_sprite_frames != null and projectile.has_method("configure_sprite_frames"):
		projectile.call("configure_sprite_frames", projectile_sprite_frames)
	get_parent().add_child(projectile)
	if projectile is Node2D:
		(projectile as Node2D).global_position = global_position
	if projectile.has_method("setup"):
		projectile.call("setup", target_position)
