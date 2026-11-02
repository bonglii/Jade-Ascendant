extends "res://scripts/enemy/enemy_2.gd"
class_name RealmRangedEnemy

## IV/V projectile damage is owned by the projectile, not the caster.
## All production predictive/spread patterns and XP drops remain untouched.
const RealmProjectileFxScript = preload("res://scripts/enemy/realm_projectile_fx.gd")

var realm_projectile_damage: float = 2.0
var realm_projectile_speed: float = 205.0
var realm_visual_theme: StringName = &"frostveil"


func _spawn_projectile_toward(target_position: Vector2) -> void:
	_spawn_projectile_from(global_position, target_position)

var _followup_left: float = -1
var _followup_target: Vector2
func _physics_process(delta: float) -> void:
	super(delta)
	if is_dead or _followup_left < 0: return
	_followup_left -= delta
	if _followup_left <= 0:
		_followup_left = -1
		_spawn_projectile_toward(_followup_target)

func shoot_projectile() -> void:
	if not is_instance_valid(player): return
	var target: Vector2 = locked_aim if use_locked_aim else player.global_position
	var direction: Vector2 = global_position.direction_to(target)
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	if realm_visual_theme == &"frostveil":
		# Parallel brackets leave a real central gap, rather than predictive spread.
		for sign_v: float in [-1.0, 1.0]:
			var start: Vector2 = global_position + direction.orthogonal() * sign_v * 30
			_spawn_projectile_from(start, start + direction * PROJECTILE_AIM_DISTANCE)
	else:
		_spawn_projectile_toward(target)
		_followup_target = global_position + direction.rotated(.28) * PROJECTILE_AIM_DISTANCE
		_followup_left = .38 # Snapshot retained even if the player changes direction.

func _spawn_projectile_from(start: Vector2, target: Vector2) -> void:
	if get_tree().get_node_count_in_group("realm_mob_projectile") >= 48: return
	var projectile: Node2D = ENEMY_PROJECTILE.instantiate()
	projectile.set_script(RealmProjectileFxScript)
	projectile.realm_visual_theme = realm_visual_theme
	projectile.damage = realm_projectile_damage; projectile.speed = realm_projectile_speed
	if projectile_sprite_frames != null: projectile.configure_sprite_frames(projectile_sprite_frames)
	projectile.add_to_group("realm_mob_projectile")
	get_parent().add_child(projectile)
	projectile.global_position = start
	projectile.setup(target)
