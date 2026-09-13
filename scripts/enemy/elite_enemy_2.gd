extends CharacterBody2D

signal enemy_defeated

## Elite Enemy 2 — Storm Cultivator
## Mobile ranged elite yang menjaga jarak menengah dari Player.
## Storm Cultivator menggunakan Lightning Strike pada posisi
## Player yang dikunci saat cast dimulai.
##
## Ketika Player terlalu dekat, Storm Cultivator menggunakan
## Qi Step untuk melakukan reposition cepat menjauhi Player.

const XP_GEM: PackedScene = preload(
	"res://scenes/pickups/xp_gem.tscn"
)

const LIGHTNING_STRIKE: PackedScene = preload(
	"res://scenes/enemy/lightning_strike.tscn"
)

const FACING_HORIZONTAL_THRESHOLD: float = 0.05

@export var speed: float = 75.0
@export var max_hp: float = 130.0
@export var preferred_range: float = 240.0
@export var retreat_range: float = 150.0
@export var lightning_damage: float = 10.0
@export var lightning_radius: float = 55.0
@export var lightning_telegraph_duration: float = 0.75
@export var lightning_cooldown: float = 2.5
@export var qi_step_distance: float = 180.0
@export var qi_step_duration: float = 0.20
@export var qi_step_cooldown: float = 4.0
@export var xp_drop_count: int = 4

var current_hp: float
var is_dead: bool = false

var is_casting: bool = false
var cast_timer: float = 0.0
var lightning_cooldown_timer: float = 0.0
var cast_target_position: Vector2 = Vector2.ZERO

var is_qi_stepping: bool = false
var qi_step_timer: float = 0.0
var qi_step_cooldown_timer: float = 0.0
var qi_step_direction: Vector2 = Vector2.ZERO
var facing_left: bool = true
var presentation_theme: StringName = &"storm"

@onready var player: CharacterBody2D = (
	get_tree().get_first_node_in_group("player")
	as CharacterBody2D
)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	CombatFeedback.register_actor(self)
	current_hp = max_hp
	_update_facing_to_player()
	_play_idle_animation()

func configure_encounter_presentation(entry: Dictionary) -> void:
	presentation_theme = StringName(
		str(entry.get("presentation_theme", presentation_theme))
	)

func get_encounter_display_name() -> String:
	if has_meta("encounter_display_name"):
		return str(get_meta("encounter_display_name"))
	return "Storm Cultivator"

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null:
		velocity = Vector2.ZERO
		_play_idle_animation()
		return

	update_lightning_cooldown(delta)
	update_qi_step_cooldown(delta)

	if is_qi_stepping:
		update_qi_step(delta)
		return

	if is_casting:
		update_cast(delta)
		return

	update_combat_movement()


## Memperbarui facing dari arah gerak.
## Ini penting saat retreat dan Qi Step supaya Elite tidak moonwalk.
func _update_facing_from_motion(
	motion_direction: Vector2
) -> void:
	if motion_direction.x <= -FACING_HORIZONTAL_THRESHOLD:
		facing_left = true
	elif motion_direction.x >= FACING_HORIZONTAL_THRESHOLD:
		facing_left = false

## Mengunci facing ke posisi tertentu, misalnya target Lightning Cast.
func _update_facing_to_position(
	target_position: Vector2
) -> void:
	var horizontal_offset: float = (
		target_position.x - global_position.x
	)

	if horizontal_offset < 0.0:
		facing_left = true
	elif horizontal_offset > 0.0:
		facing_left = false

## Menghadap Player jika tersedia.
func _update_facing_to_player() -> void:
	if player == null or not is_instance_valid(player):
		return

	_update_facing_to_position(
		player.global_position
	)

## Mengembalikan nama animation directional.
func _directional_animation(
	prefix: String
) -> StringName:
	var suffix: String = "right"

	if facing_left:
		suffix = "left"

	return StringName(
		"%s_%s" % [prefix, suffix]
	)

## Memainkan idle.
func _play_idle_animation() -> void:
	_play_loop_animation(
		_directional_animation("idle")
	)

## Memainkan walk.
func _play_walk_animation() -> void:
	_play_loop_animation(
		_directional_animation("walk")
	)

## Memainkan Lightning Cast dan menyelaraskan animasi dengan telegraph 0.75s.
func _play_cast_animation() -> void:
	_play_timed_animation(
		_directional_animation("cast"),
		lightning_telegraph_duration
	)

## Memainkan Qi Step sesuai durasi gameplay 0.20s.
func _play_qi_step_animation() -> void:
	_play_timed_animation(
		_directional_animation("qi_step"),
		qi_step_duration
	)

## Helper loop animation supaya tidak restart tiap physics frame.
func _play_loop_animation(
	animation_name: StringName
) -> void:
	if animated_sprite == null:
		return

	if animated_sprite.sprite_frames == null:
		return

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		return

	if (
		animated_sprite.animation != animation_name
		or not animated_sprite.is_playing()
	):
		animated_sprite.play(animation_name)

## Menyelaraskan animasi non-loop dengan durasi mechanic aktual.
func _play_timed_animation(
	animation_name: StringName,
	target_duration: float
) -> void:
	if animated_sprite == null:
		return

	var sprite_frames: SpriteFrames = (
		animated_sprite.sprite_frames
	)

	if sprite_frames == null:
		return

	if not sprite_frames.has_animation(
		animation_name
	):
		return

	var frame_count: int = (
		sprite_frames.get_frame_count(
			animation_name
		)
	)

	var animation_fps: float = (
		sprite_frames.get_animation_speed(
			animation_name
		)
	)

	var base_duration: float = (
		float(frame_count)
		/ maxf(animation_fps, 0.001)
	)

	var safe_target_duration: float = maxf(
		target_duration,
		0.01
	)

	var custom_speed: float = (
		base_duration
		/ safe_target_duration
	)

	animated_sprite.play(
		animation_name,
		custom_speed
	)

## Mengatur movement dan keputusan ability berdasarkan jarak Player.
func update_combat_movement() -> void:
	var distance_to_player: float = global_position.distance_to(
		player.global_position
	)

	if distance_to_player < retreat_range:
		if try_begin_qi_step():
			return

		move_away_from_player()
		return

	if distance_to_player <= preferred_range:
		hold_position()
		try_begin_lightning_cast()
		return

	move_toward_player()

## Mendekati Player ketika berada di luar preferred range.
func move_toward_player() -> void:
	var direction: Vector2 = global_position.direction_to(
		player.global_position
	)

	_update_facing_from_motion(direction)
	velocity = direction * speed
	move_and_slide()
	_play_walk_animation()

## Menjauhi Player ketika Player memasuki retreat range
## sementara Qi Step belum tersedia.
func move_away_from_player() -> void:
	var direction: Vector2 = player.global_position.direction_to(
		global_position
	)

	_update_facing_from_motion(direction)
	velocity = direction * speed
	move_and_slide()
	_play_walk_animation()

## Menahan posisi ketika Elite berada pada jarak ideal.
func hold_position() -> void:
	velocity = Vector2.ZERO
	_play_idle_animation()

## Memulai Lightning Strike jika cooldown sudah selesai.
func try_begin_lightning_cast() -> void:
	if lightning_cooldown_timer > 0.0:
		return

	begin_lightning_cast()

## Mengunci posisi Player dan membuat telegraph Lightning Strike.
func begin_lightning_cast() -> void:
	if player == null:
		return

	if not is_instance_valid(player):
		return

	is_casting = true
	cast_timer = lightning_telegraph_duration
	cast_target_position = player.global_position
	velocity = Vector2.ZERO

	_update_facing_to_position(
		cast_target_position
	)
	_play_cast_animation()

	spawn_lightning_strike()

	DebugLogger.combat(
		"%s Lightning Cast Start | Target: %s"
		% [get_encounter_display_name(), str(cast_target_position)]
	)

## Membuat Lightning Strike pada posisi Player yang telah dikunci.
func spawn_lightning_strike() -> void:
	var lightning_strike: LightningStrike = (
		LIGHTNING_STRIKE.instantiate()
		as LightningStrike
	)

	if lightning_strike == null:
		push_error(
			"Lightning Strike scene gagal dibuat."
		)
		return

	lightning_strike.telegraph_duration = (
		lightning_telegraph_duration
	)

	lightning_strike.base_damage = lightning_damage
	lightning_strike.strike_radius = lightning_radius
	lightning_strike.presentation_theme = presentation_theme

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		lightning_strike.queue_free()
		return

	current_scene.add_child(
		lightning_strike
	)

	lightning_strike.global_position = (
		cast_target_position
	)

## Menahan Storm Cultivator selama proses casting.
func update_cast(delta: float) -> void:
	velocity = Vector2.ZERO
	cast_timer -= delta

	if cast_timer > 0.0:
		return

	complete_lightning_cast()

## Menyelesaikan cast dan memulai cooldown Lightning Strike.
func complete_lightning_cast() -> void:
	if not is_casting:
		return

	is_casting = false
	cast_timer = 0.0
	lightning_cooldown_timer = lightning_cooldown
	_play_idle_animation()

	DebugLogger.combat(
		"%s Lightning Cast Complete | Target: %s"
		% [get_encounter_display_name(), str(cast_target_position)]
	)

## Mengurangi cooldown Lightning Strike ketika Elite masih aktif.
func update_lightning_cooldown(delta: float) -> void:
	if lightning_cooldown_timer <= 0.0:
		return

	lightning_cooldown_timer = maxf(
		lightning_cooldown_timer - delta,
		0.0
	)

## Mencoba memulai Qi Step ketika ability tersedia.
## Mengembalikan true jika Qi Step berhasil dimulai.
func try_begin_qi_step() -> bool:
	if qi_step_cooldown_timer > 0.0:
		return false

	if qi_step_duration <= 0.0:
		return false

	if player == null:
		return false

	if not is_instance_valid(player):
		return false

	begin_qi_step()
	return true

## Mengunci arah menjauhi Player dan memulai burst movement.
func begin_qi_step() -> void:
	qi_step_direction = player.global_position.direction_to(
		global_position
	)

	if qi_step_direction.is_zero_approx():
		qi_step_direction = Vector2.RIGHT

	_update_facing_from_motion(
		qi_step_direction
	)
	_play_qi_step_animation()

	is_qi_stepping = true
	qi_step_timer = qi_step_duration

	DebugLogger.combat(
		"%s Qi Step Start | Direction: %s"
		% [get_encounter_display_name(), str(qi_step_direction)]
	)

## Menjalankan burst movement Qi Step.
func update_qi_step(delta: float) -> void:
	if not is_qi_stepping:
		return

	var qi_step_speed: float = (
		qi_step_distance
		/ qi_step_duration
	)

	velocity = qi_step_direction * qi_step_speed
	move_and_slide()

	qi_step_timer -= delta

	if qi_step_timer > 0.0:
		return

	complete_qi_step()

## Menyelesaikan Qi Step dan memulai cooldown.
func complete_qi_step() -> void:
	if not is_qi_stepping:
		return

	is_qi_stepping = false
	qi_step_timer = 0.0
	qi_step_cooldown_timer = qi_step_cooldown
	velocity = Vector2.ZERO
	_play_idle_animation()

	DebugLogger.combat(
		"%s Qi Step Complete" % get_encounter_display_name()
	)

## Mengurangi cooldown Qi Step ketika Elite masih aktif.
func update_qi_step_cooldown(delta: float) -> void:
	if qi_step_cooldown_timer <= 0.0:
		return

	qi_step_cooldown_timer = maxf(
		qi_step_cooldown_timer - delta,
		0.0
	)

## Mengurangi HP Storm Cultivator ketika menerima damage.
func take_damage(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	current_hp -= amount
	CombatFeedback.hit(self, amount)
	current_hp = maxf(
		current_hp,
		0.0
	)

	DebugLogger.combat(
		"Storm Cultivator HP: %.1f/%.1f"
		% [
			current_hp,
			max_hp
		]
	)

	if current_hp <= 0.0:
		die()

## Mengalahkan Storm Cultivator dan memberikan reward XP.
func die() -> void:
	if is_dead:
		return

	is_dead = true
	CombatFeedback.death(self)
	remove_from_group("enemy")
	is_casting = false
	is_qi_stepping = false
	cast_timer = 0.0
	qi_step_timer = 0.0
	velocity = Vector2.ZERO

	enemy_defeated.emit()
	drop_xp()

	DebugLogger.combat(
		"STORM CULTIVATOR DEFEATED"
	)

	call_deferred(
		"queue_free"
	)

## Menjatuhkan beberapa XP Gem sebagai reward Elite Enemy.
func drop_xp() -> void:
	for i in range(xp_drop_count):
		var xp_gem = XP_GEM.instantiate()

		xp_gem.position = position + Vector2(
			randf_range(-20.0, 20.0),
			randf_range(-20.0, 20.0)
		)

		get_parent().call_deferred(
			"add_child",
			xp_gem
		)
