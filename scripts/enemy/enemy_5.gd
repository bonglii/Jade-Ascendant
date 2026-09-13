extends CharacterBody2D

signal enemy_defeated

## Enemy 5 — Shadow Assassin
## Burst / ambush enemy yang mengejar Player.
## Assassin mengunci arah Player, melakukan wind-up,
## dash satu arah, masuk recovery, lalu menunggu cooldown
## sebelum dapat melakukan dash berikutnya.

const XP_GEM: PackedScene = preload(
	"res://scenes/pickups/xp_gem.tscn"
)

const FACING_SWITCH_DISTANCE: float = 12.0

@export var speed: float = 90.0
@export var max_hp: float = 35.0
@export var dash_trigger_range: float = 180.0
@export var wind_up_duration: float = 0.45
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.35
@export var dash_damage: float = 12.0
@export var recovery_duration: float = 0.45
@export var dash_cooldown: float = 3.0

var current_hp: float
var is_dead: bool = false
var is_winding_up: bool = false
var is_dashing: bool = false
var is_recovering: bool = false
var has_hit_player_this_dash: bool = false
var wind_up_timer: float = 0.0
var dash_timer: float = 0.0
var recovery_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var facing_left: bool = true
var damage_reduction_sources: Dictionary = {}

@onready var player: CharacterBody2D = (
	get_tree().get_first_node_in_group("player")
	as CharacterBody2D
)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	CombatFeedback.register_actor(self)
	current_hp = max_hp
	_update_visual_facing()
	_play_idle_animation()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null:
		velocity = Vector2.ZERO
		_play_idle_animation()
		return

	update_dash_cooldown(delta)

	if is_dashing:
		update_dash(delta)
		return

	if is_winding_up:
		update_wind_up(delta)
		return

	if is_recovering:
		update_recovery(delta)
		return

	_update_visual_facing()

	var distance_to_player: float = (
		global_position.distance_to(
			player.global_position
		)
	)

	if (
		distance_to_player <= dash_trigger_range
		and dash_cooldown_timer <= 0.0
	):
		begin_wind_up()
		return

	move_toward_player()
	_play_walk_animation()

## Menjaga facing horizontal stabil saat chase.
func _update_visual_facing() -> void:
	if player == null or not is_instance_valid(player):
		return

	_update_facing_from_position(player.global_position)

## Mengunci facing berdasarkan posisi target tertentu.
func _update_facing_from_position(target_position: Vector2) -> void:
	var horizontal_offset: float = target_position.x - global_position.x

	if horizontal_offset <= -FACING_SWITCH_DISTANCE:
		facing_left = true
	elif horizontal_offset >= FACING_SWITCH_DISTANCE:
		facing_left = false

## Mengunci facing berdasarkan dash direction yang sudah disimpan.
func _update_facing_from_dash_direction() -> void:
	if dash_direction.x < -0.01:
		facing_left = true
	elif dash_direction.x > 0.01:
		facing_left = false

func _get_directional_animation(prefix: String) -> StringName:
	var suffix: String = "right"
	if facing_left:
		suffix = "left"
	return StringName("%s_%s" % [prefix, suffix])

func _play_visual_animation(animation_name: StringName) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func _play_timed_animation(prefix: String, target_duration: float) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var animation_name: StringName = _get_directional_animation(prefix)
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	var frame_count: int = animated_sprite.sprite_frames.get_frame_count(animation_name)
	var base_fps: float = animated_sprite.sprite_frames.get_animation_speed(animation_name)
	var base_duration: float = float(frame_count) / maxf(base_fps, 0.001)
	var safe_duration: float = maxf(target_duration, 0.01)
	animated_sprite.play(animation_name, base_duration / safe_duration)

func _play_idle_animation() -> void:
	_play_visual_animation(_get_directional_animation("idle"))

func _play_walk_animation() -> void:
	_play_visual_animation(_get_directional_animation("walk"))

## Menggerakkan Shadow Assassin menuju Player.
func move_toward_player() -> void:
	var direction: Vector2 = (
		global_position.direction_to(
			player.global_position
		)
	)

	velocity = direction * speed
	move_and_slide()

## Memulai wind-up dan mengunci arah Player.
func begin_wind_up() -> void:
	if player == null:
		return
	if not is_instance_valid(player):
		return

	is_winding_up = true
	wind_up_timer = wind_up_duration
	dash_direction = global_position.direction_to(player.global_position)
	velocity = Vector2.ZERO
	_update_facing_from_dash_direction()
	_play_timed_animation("windup", wind_up_duration)

	DebugLogger.combat(
		"Shadow Assassin Wind-Up Start | Direction: %s"
		% str(dash_direction)
	)

## Menjalankan wind-up sebelum dash.
func update_wind_up(delta: float) -> void:
	velocity = Vector2.ZERO
	wind_up_timer -= delta
	if wind_up_timer > 0.0:
		return
	complete_wind_up()

## Menyelesaikan wind-up dan memulai dash.
func complete_wind_up() -> void:
	if not is_winding_up:
		return
	is_winding_up = false
	wind_up_timer = 0.0

	DebugLogger.combat(
		"Shadow Assassin Wind-Up Complete | Locked Direction: %s"
		% str(dash_direction)
	)
	begin_dash()

## Memulai dash menggunakan arah yang telah dikunci.
func begin_dash() -> void:
	if dash_direction == Vector2.ZERO:
		return
	is_dashing = true
	has_hit_player_this_dash = false
	dash_timer = dash_duration
	_update_facing_from_dash_direction()
	_play_timed_animation("dash", dash_duration)

	DebugLogger.combat(
		"Shadow Assassin Dash Start | Direction: %s"
		% str(dash_direction)
	)

## Menggerakkan Assassin dan memeriksa collision selama dash.
func update_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed
	move_and_slide()
	try_dash_damage_player()
	if dash_timer > 0.0:
		return
	complete_dash()

## Memberikan satu kali damage jika dash bertabrakan dengan Player.
func try_dash_damage_player() -> void:
	if has_hit_player_this_dash:
		return
	if player == null:
		return
	if not is_instance_valid(player):
		return

	for collision_index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision == null:
			continue
		if collision.get_collider() != player:
			continue
		damage_player_from_dash()
		return

## Mengirim damage dash ke PlayerHealth.
func damage_player_from_dash() -> void:
	if has_hit_player_this_dash:
		return
	var player_health: PlayerHealth = player.get_node_or_null("PlayerHealth") as PlayerHealth
	if player_health == null:
		push_error("Shadow Assassin tidak menemukan PlayerHealth.")
		return
	has_hit_player_this_dash = true
	player_health.take_damage(dash_damage)

	DebugLogger.combat(
		"Shadow Assassin Dash Hit | Damage: %.1f"
		% dash_damage
	)

## Menyelesaikan dash dan memulai recovery.
func complete_dash() -> void:
	if not is_dashing:
		return
	is_dashing = false
	dash_timer = 0.0
	velocity = Vector2.ZERO

	DebugLogger.combat("Shadow Assassin Dash Complete")
	begin_recovery()

## Memulai fase recovery setelah dash.
func begin_recovery() -> void:
	is_recovering = true
	recovery_timer = recovery_duration
	_play_timed_animation("recovery", recovery_duration)

	DebugLogger.combat("Shadow Assassin Recovery Start")

## Menahan Assassin selama fase recovery.
func update_recovery(delta: float) -> void:
	velocity = Vector2.ZERO
	recovery_timer -= delta
	if recovery_timer > 0.0:
		return
	complete_recovery()

## Menyelesaikan recovery dan memulai cooldown dash.
func complete_recovery() -> void:
	if not is_recovering:
		return
	is_recovering = false
	recovery_timer = 0.0
	dash_cooldown_timer = dash_cooldown
	_play_idle_animation()

	DebugLogger.combat("Shadow Assassin Recovery Complete")

## Mengurangi cooldown dash ketika Assassin aktif.
func update_dash_cooldown(delta: float) -> void:
	if dash_cooldown_timer <= 0.0:
		return
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

## Menambahkan sumber damage reduction.
func add_damage_reduction_source(source: Object, multiplier: float) -> void:
	if source == null:
		return
	damage_reduction_sources[source.get_instance_id()] = clampf(multiplier, 0.0, 1.0)

## Menghapus satu sumber damage reduction.
func remove_damage_reduction_source(source: Object) -> void:
	if source == null:
		return
	damage_reduction_sources.erase(source.get_instance_id())

## Mengembalikan multiplier damage terkuat yang sedang aktif.
func get_damage_taken_multiplier() -> float:
	var final_multiplier: float = 1.0
	for multiplier in damage_reduction_sources.values():
		final_multiplier = minf(final_multiplier, float(multiplier))
	return final_multiplier

## Mengurangi HP Shadow Assassin ketika menerima damage.
func take_damage(amount: float) -> void:
	if is_dead:
		return
	if amount <= 0.0:
		return
	var final_damage: float = amount * get_damage_taken_multiplier()
	current_hp -= final_damage
	CombatFeedback.hit(self, final_damage)

	DebugLogger.combat(
		"Shadow Assassin HP: %.1f"
		% current_hp
	)
	if current_hp <= 0.0:
		die()

## Menghapus Assassin dan menjatuhkan XP Gem.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	CombatFeedback.death(self)
	remove_from_group("enemy")
	is_winding_up = false
	is_dashing = false
	is_recovering = false
	has_hit_player_this_dash = false
	damage_reduction_sources.clear()
	velocity = Vector2.ZERO
	enemy_defeated.emit()

	var xp_gem: Node = XP_GEM.instantiate()
	if xp_gem is Node2D:
		(xp_gem as Node2D).position = position
	get_parent().call_deferred("add_child", xp_gem)
	call_deferred("queue_free")
