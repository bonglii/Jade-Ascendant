extends CharacterBody2D

signal enemy_defeated

## Elite Enemy 1 — Jadebound Iron Disciple
## Heavy wuxia/xianxia bruiser. Gameplay values tetap sama.
## Visual impact hanya dimainkan saat contact damage existing benar-benar mengenai Player.

const XP_GEM: PackedScene = preload(
	"res://scenes/pickups/xp_gem.tscn"
)

const FACING_SWITCH_DISTANCE: float = 12.0
const IMPACT_VISUAL_DURATION: float = 0.40

@export var speed: float = 70.0
@export var max_hp: float = 100.0
@export var contact_damage: float = 5.0
@export var contact_damage_cooldown: float = 1.0
@export var xp_drop_count: int = 3

@onready var player: CharacterBody2D = (
	get_parent().get_node("player_1")
)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_hp: float
var is_dead: bool = false
var contact_damage_timer: float = 0.0
var impact_visual_timer: float = 0.0
var facing_left: bool = true

func _ready() -> void:
	CombatFeedback.register_actor(self)
	current_hp = max_hp
	_update_visual_facing()
	_play_idle_animation()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_impact_visual_timer(delta)

	if player == null:
		velocity = Vector2.ZERO
		if impact_visual_timer <= 0.0:
			_play_idle_animation()
		return

	move_toward_player()
	update_contact_damage(delta)

func move_toward_player() -> void:
	var direction: Vector2 = global_position.direction_to(
		player.global_position
	)

	_update_visual_facing()
	velocity = direction * speed
	move_and_slide()

	if impact_visual_timer <= 0.0:
		_play_walk_animation()

func _update_visual_facing() -> void:
	if player == null or not is_instance_valid(player):
		return

	var horizontal_offset: float = (
		player.global_position.x - global_position.x
	)

	if horizontal_offset <= -FACING_SWITCH_DISTANCE:
		facing_left = true
	elif horizontal_offset >= FACING_SWITCH_DISTANCE:
		facing_left = false

func _directional_animation(prefix: String) -> StringName:
	var suffix: String = "right"
	if facing_left:
		suffix = "left"
	return StringName("%s_%s" % [prefix, suffix])

func _play_idle_animation() -> void:
	_play_loop_animation(_directional_animation("idle"))

func _play_walk_animation() -> void:
	_play_loop_animation(_directional_animation("walk"))

func _play_impact_animation() -> void:
	if animated_sprite == null:
		return
	if animated_sprite.sprite_frames == null:
		return

	var animation_name: StringName = _directional_animation("impact")
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	animated_sprite.play(animation_name)
	impact_visual_timer = IMPACT_VISUAL_DURATION

func _play_loop_animation(animation_name: StringName) -> void:
	if animated_sprite == null:
		return
	if animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func update_impact_visual_timer(delta: float) -> void:
	if impact_visual_timer <= 0.0:
		return
	impact_visual_timer = maxf(impact_visual_timer - delta, 0.0)

func update_contact_damage(delta: float) -> void:
	if contact_damage_timer > 0.0:
		contact_damage_timer -= delta
	if contact_damage_timer <= 0.0:
		check_player_collision()

func check_player_collision() -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision == null:
			continue
		var collider: Object = collision.get_collider()
		if collider == null:
			continue
		if collider is Node and (collider as Node).is_in_group("player"):
			damage_player(collider as Node)
			break

func damage_player(target_player: Node) -> void:
	var player_health: PlayerHealth = (
		target_player.get_node_or_null("PlayerHealth")
		as PlayerHealth
	)
	if player_health == null:
		push_error(str("ERROR: Elite Enemy 1 tidak menemukan PlayerHealth!"))
		return

	_play_impact_animation()
	player_health.take_damage(contact_damage)
	contact_damage_timer = contact_damage_cooldown

func take_damage(amount: float) -> void:
	if is_dead:
		return
	if amount <= 0.0:
		return

	current_hp -= amount
	CombatFeedback.hit(self, amount)
	current_hp = max(current_hp, 0.0)
	DebugLogger.system(str("Elite Enemy 1 HP: ", current_hp, "/", max_hp))
	if current_hp <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	CombatFeedback.death(self)
	remove_from_group("enemy")
	impact_visual_timer = 0.0
	velocity = Vector2.ZERO
	enemy_defeated.emit()
	drop_xp()
	call_deferred("queue_free")

func drop_xp() -> void:
	for i in range(xp_drop_count):
		var xp_gem: Node = XP_GEM.instantiate()
		if xp_gem is Node2D:
			(xp_gem as Node2D).position = position + Vector2(
				randf_range(-20.0, 20.0),
				randf_range(-20.0, 20.0)
			)
		get_parent().call_deferred("add_child", xp_gem)
