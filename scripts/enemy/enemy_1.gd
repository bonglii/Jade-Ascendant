extends CharacterBody2D

## Enemy 1
## Enemy melee dasar yang mengejar Player,
## memberikan contact damage, dan menjatuhkan XP Gem saat mati.

signal enemy_defeated

const XP_GEM = preload(
	"res://scenes/pickups/xp_gem.tscn"
)

@export var speed: float = 80.0
@export var max_hp: float = 30.0
@export var contact_damage: float = 10.0
@export var contact_damage_cooldown: float = 0.75

var current_hp: float
var is_dead: bool = false
var contact_damage_timer: float = 0.0
var damage_reduction_sources: Dictionary = {}

@onready var player: CharacterBody2D = (
	get_parent().get_node("player_1")
)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	CombatFeedback.register_actor(self)
	current_hp = max_hp
	animated_sprite.play(&"walk_left")

func _physics_process(delta: float) -> void:
	if player == null:
		return

	var move_direction: Vector2 = global_position.direction_to(
		player.global_position
	)

	velocity = move_direction * speed
	_update_walk_animation(move_direction)
	move_and_slide()

	if contact_damage_timer > 0.0:
		contact_damage_timer -= delta

	if contact_damage_timer <= 0.0:
		check_player_collision()


## Menjaga animasi berjalan mengikuti arah horizontal gerakan Enemy 1.
## Sprite legacy saat ini hanya mempunyai walk_left / walk_right.
## Logic ini sengaja minimal agar tidak mengubah movement atau collision.
func _update_walk_animation(move_direction: Vector2) -> void:
	if animated_sprite == null:
		return

	var target_animation: StringName = animated_sprite.animation

	if move_direction.x < -0.01:
		target_animation = &"walk_left"
	elif move_direction.x > 0.01:
		target_animation = &"walk_right"

	if (
		animated_sprite.animation != target_animation
		or not animated_sprite.is_playing()
	):
		animated_sprite.play(target_animation)

## Memberikan contact damage kepada Player.
func damage_player(target_player: Node) -> void:
	var player_health = (
		target_player.get_node_or_null("PlayerHealth")
	)

	if player_health == null:
		push_error(str("ERROR: PlayerHealth tidak ditemukan!"))
		return

	DebugLogger.combat(
		"Enemy Hit Player | Damage: %.1f"
		% contact_damage
	)

	player_health.take_damage(contact_damage)

	contact_damage_timer = contact_damage_cooldown

## Menambahkan sumber damage reduction tanpa menumpuk efek
## dari beberapa Qi Guardian secara multiplikatif.
func add_damage_reduction_source(
	source: Object,
	multiplier: float
) -> void:
	if source == null:
		return

	damage_reduction_sources[source.get_instance_id()] = clampf(
		multiplier,
		0.0,
		1.0
	)

## Menghapus satu sumber damage reduction.
func remove_damage_reduction_source(source: Object) -> void:
	if source == null:
		return

	damage_reduction_sources.erase(
		source.get_instance_id()
	)

## Mengembalikan multiplier damage terkuat yang sedang aktif.
func get_damage_taken_multiplier() -> float:
	var final_multiplier: float = 1.0

	for multiplier in damage_reduction_sources.values():
		final_multiplier = minf(
			final_multiplier,
			float(multiplier)
		)

	return final_multiplier

## Mengurangi HP Enemy berdasarkan damage yang diterima.
func take_damage(amount: float) -> void:
	if is_dead:
		return

	var final_damage: float = (
		amount * get_damage_taken_multiplier()
	)

	current_hp -= final_damage
	CombatFeedback.hit(self, final_damage)

	DebugLogger.combat(
		"Enemy HP: %.1f"
		% current_hp
	)

	if current_hp <= 0:
		die()

## Menangani kematian Enemy dan menjatuhkan XP Gem.
func die() -> void:
	if is_dead:
		return

	is_dead = true
	CombatFeedback.death(self)
	remove_from_group("enemy")
	damage_reduction_sources.clear()

	enemy_defeated.emit()

	var xp_gem = XP_GEM.instantiate()

	xp_gem.position = position

	get_parent().call_deferred(
		"add_child",
		xp_gem
	)

	call_deferred("queue_free")

## Memeriksa collision dengan Player untuk contact damage.
func check_player_collision() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)

		if collision == null:
			continue

		var collider = collision.get_collider()

		if collider == null:
			continue

		if collider.is_in_group("player"):
			damage_player(collider)
			break
