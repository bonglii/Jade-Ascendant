extends CharacterBody2D

signal enemy_defeated

## Enemy 3
## Fast melee enemy dengan HP rendah dan movement cepat.
## Dirancang untuk memberikan tekanan dengan mengejar Player secara agresif.

const XP_GEM: PackedScene = preload(
	"res://scenes/pickups/xp_gem.tscn"
)

const FACING_SWITCH_DISTANCE: float = 12.0

@export var speed: float = 140.0
@export var max_hp: float = 15.0
@export var contact_damage: float = 6.0
@export var contact_damage_cooldown: float = 0.6

@onready var player: CharacterBody2D = (
	get_parent().get_node("player_1")
)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_hp: float
var is_dead: bool = false
var contact_damage_timer: float = 0.0
var damage_reduction_sources: Dictionary = {}
var facing_left: bool = false

func _ready() -> void:
	CombatFeedback.register_actor(self)
	current_hp = max_hp
	_update_visual_facing()
	_play_run_animation()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null:
		velocity = Vector2.ZERO

		if animated_sprite != null:
			animated_sprite.stop()

		return

	_update_visual_facing()
	move_toward_player()
	_play_run_animation()
	update_contact_damage(delta)

## Menjaga facing horizontal Enemy 3 tetap stabil.
## Dead-zone mencegah flip kiri/kanan ketika hampir sejajar dengan Player.
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

## Memainkan run animation sesuai facing terakhir.
func _play_run_animation() -> void:
	if animated_sprite == null:
		return

	if animated_sprite.sprite_frames == null:
		return

	var animation_name: StringName = &"run_right"

	if facing_left:
		animation_name = &"run_left"

	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	if (
		animated_sprite.animation != animation_name
		or not animated_sprite.is_playing()
	):
		animated_sprite.play(animation_name)

## Mengejar Player menggunakan movement cepat.
func move_toward_player() -> void:
	var direction: Vector2 = (
		global_position.direction_to(
			player.global_position
		)
	)

	velocity = direction * speed
	move_and_slide()

## Mengelola cooldown dan pemeriksaan contact damage.
func update_contact_damage(delta: float) -> void:
	if contact_damage_timer > 0.0:
		contact_damage_timer -= delta

	if contact_damage_timer <= 0.0:
		check_player_collision()

## Memeriksa collision dengan Player setelah movement.
func check_player_collision() -> void:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)

		if collision == null:
			continue

		var collider = collision.get_collider()

		if collider == null:
			continue

		if collider.is_in_group("player"):
			damage_player(collider)
			break

## Memberikan contact damage kepada Player.
func damage_player(target_player: Node) -> void:
	var player_health: PlayerHealth = (
		target_player.get_node_or_null(
			"PlayerHealth"
		)
		as PlayerHealth
	)

	if player_health == null:
		push_error(str(
			"ERROR: Enemy 3 tidak menemukan PlayerHealth!"
		))
		return

	DebugLogger.system(str("ENEMY 3 HIT!"))
	DebugLogger.system(str("Enemy 3 Damage: ", contact_damage))

	player_health.take_damage(contact_damage)
	contact_damage_timer = contact_damage_cooldown

## Menambahkan sumber damage reduction.
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

## Mengurangi HP Enemy 3 ketika menerima damage.
func take_damage(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	var final_damage: float = (
		amount * get_damage_taken_multiplier()
	)

	current_hp -= final_damage
	CombatFeedback.hit(self, final_damage)

	DebugLogger.system(str("Enemy 3 HP: ", current_hp))

	if current_hp <= 0.0:
		die()

## Menghapus Enemy 3 dan menjatuhkan XP Gem.
func die() -> void:
	if is_dead:
		return

	is_dead = true
	CombatFeedback.death(self)
	remove_from_group("enemy")
	damage_reduction_sources.clear()

	enemy_defeated.emit()
	velocity = Vector2.ZERO

	var xp_gem = XP_GEM.instantiate()
	xp_gem.position = position

	get_parent().call_deferred(
		"add_child",
		xp_gem
	)

	call_deferred("queue_free")
