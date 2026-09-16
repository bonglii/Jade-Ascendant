extends CharacterBody2D

signal enemy_defeated

## Enemy 4 — Qi Caster
## Ranged area-denial enemy that locks Player position at cast start.
## Chapter encounter profiles can reshape the telegraph layout while keeping
## the proven explosion scene, timing, collision, and damage pipeline.

const XP_GEM: PackedScene = preload(
	"res://scenes/pickups/xp_gem.tscn"
)

const QI_EXPLOSION: PackedScene = preload(
	"res://scenes/enemy/qi_explosion.tscn"
)

const FACING_SWITCH_DISTANCE: float = 12.0

@export var speed: float = 65.0
@export var max_hp: float = 30.0
@export var cast_range: float = 230.0
@export var cast_cooldown: float = 3.0
@export var telegraph_duration: float = 0.8
@export var explosion_damage: float = 6.0
@export var explosion_radius: float = 42.0

var current_hp: float
var is_dead: bool = false
var is_casting: bool = false
var cast_timer: float = 0.0
var cast_cooldown_timer: float = 0.0
var cast_target_position: Vector2 = Vector2.ZERO
var facing_left: bool = true
var damage_reduction_sources: Dictionary = {}
var presentation_theme: StringName = &"verdant_qi"
var cast_pattern: StringName = &"single"
var pattern_spacing: float = 72.0

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

func configure_encounter_presentation(entry: Dictionary) -> void:
	presentation_theme = StringName(
		str(entry.get("presentation_theme", presentation_theme))
	)
	cast_pattern = StringName(
		str(entry.get("cast_pattern", cast_pattern))
	)
	pattern_spacing = maxf(
		float(entry.get("pattern_spacing", pattern_spacing)),
		explosion_radius * 1.25
	)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		_play_idle_animation()
		return

	update_cast_cooldown(delta)

	if is_casting:
		update_cast(delta)
		return

	_update_visual_facing()

	var distance_to_player: float = (
		global_position.distance_to(
			player.global_position
		)
	)

	if distance_to_player <= cast_range:
		velocity = Vector2.ZERO
		try_begin_cast()

		if not is_casting:
			_play_idle_animation()

		return

	move_toward_player()
	_play_walk_animation()

## Menjaga visual Qi Caster menghadap Player secara horizontal.
## Dead-zone mencegah facing flip-flop ketika hampir sejajar vertikal.
func _update_visual_facing() -> void:
	if player == null or not is_instance_valid(player):
		return

	_update_facing_from_position(
		player.global_position
	)

## Mengunci facing berdasarkan satu posisi target.
func _update_facing_from_position(
	target_position: Vector2
) -> void:
	var horizontal_offset: float = (
		target_position.x - global_position.x
	)

	if horizontal_offset <= -FACING_SWITCH_DISTANCE:
		facing_left = true
	elif horizontal_offset >= FACING_SWITCH_DISTANCE:
		facing_left = false

## Mengembalikan nama animasi sesuai facing horizontal.
func _get_directional_animation(
	prefix: String
) -> StringName:
	var suffix: String = "right"

	if facing_left:
		suffix = "left"

	return StringName(
		"%s_%s" % [prefix, suffix]
	)

## Memainkan idle sesuai facing terakhir.
func _play_idle_animation() -> void:
	_play_visual_animation(
		_get_directional_animation("idle")
	)

## Memainkan walk sesuai facing terakhir.
func _play_walk_animation() -> void:
	_play_visual_animation(
		_get_directional_animation("walk")
	)

## Memainkan cast dan menyelaraskan panjang animasi
## dengan telegraph_duration tanpa mengubah timing gameplay.
func _play_cast_animation() -> void:
	if animated_sprite == null:
		return

	var sprite_frames: SpriteFrames = (
		animated_sprite.sprite_frames
	)

	if sprite_frames == null:
		return

	var animation_name: StringName = (
		_get_directional_animation("cast")
	)

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

	var safe_telegraph_duration: float = maxf(
		telegraph_duration,
		0.01
	)

	var custom_speed: float = (
		base_duration
		/ safe_telegraph_duration
	)

	animated_sprite.play(
		animation_name,
		custom_speed
	)

## Memainkan animation tanpa me-restart setiap physics frame.
func _play_visual_animation(
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
		animated_sprite.play(
			animation_name
		)

## Menggerakkan Qi Caster menuju Player hingga memasuki cast range.
func move_toward_player() -> void:
	var direction: Vector2 = (
		global_position.direction_to(
			player.global_position
		)
	)

	velocity = direction * speed
	move_and_slide()

## Memulai cast ketika cooldown selesai.
func try_begin_cast() -> void:
	if cast_cooldown_timer > 0.0:
		return

	begin_cast()

## Mengunci posisi Player dan membuat telegraph serangan.
func begin_cast() -> void:
	if player == null:
		return

	if not is_instance_valid(player):
		return

	is_casting = true
	cast_timer = telegraph_duration
	cast_target_position = player.global_position
	velocity = Vector2.ZERO

	_update_facing_from_position(
		cast_target_position
	)

	_play_cast_animation()
	spawn_telegraph()

	DebugLogger.combat(
		"Qi Caster Cast Start | Pattern: %s | Target: %s"
		% [str(cast_pattern), str(cast_target_position)]
	)

## Membuat telegraph layout sesuai identity chapter.
## Chapter 1: single target.
## Crimson Moon: tiga segel melintang memotong jalur gerak.
## Nine Heavens: empat constellation seals mengurung target dengan safe center.
func spawn_telegraph() -> void:
	match cast_pattern:
		&"scarlet_trident":
			_spawn_scarlet_trident()
		&"constellation_ring":
			_spawn_constellation_ring()
		_:
			_spawn_qi_explosion_at(cast_target_position)

func _spawn_scarlet_trident() -> void:
	var forward: Vector2 = global_position.direction_to(cast_target_position)
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var perpendicular := Vector2(-forward.y, forward.x)

	_spawn_qi_explosion_at(cast_target_position)
	_spawn_qi_explosion_at(
		cast_target_position + perpendicular * pattern_spacing
	)
	_spawn_qi_explosion_at(
		cast_target_position - perpendicular * pattern_spacing
	)

func _spawn_constellation_ring() -> void:
	var base_direction: Vector2 = global_position.direction_to(
		cast_target_position
	)
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT

	## Rotate by 45 degrees so the formation reads as a celestial diamond,
	## not the same horizontal/vertical shape as Crimson Moon.
	base_direction = base_direction.rotated(PI * 0.25)

	for quarter_turn in range(4):
		var offset_direction: Vector2 = base_direction.rotated(
			float(quarter_turn) * PI * 0.5
		)
		_spawn_qi_explosion_at(
			cast_target_position + offset_direction * pattern_spacing
		)

func _spawn_qi_explosion_at(target_position: Vector2) -> void:
	var qi_explosion: QiExplosion = (
		QI_EXPLOSION.instantiate()
		as QiExplosion
	)

	if qi_explosion == null:
		push_error(
			"Qi Explosion scene gagal dibuat."
		)
		return

	qi_explosion.telegraph_duration = telegraph_duration
	qi_explosion.base_damage = explosion_damage
	qi_explosion.explosion_radius = explosion_radius
	qi_explosion.presentation_theme = presentation_theme

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		qi_explosion.queue_free()
		return

	current_scene.add_child(qi_explosion)
	qi_explosion.global_position = target_position

## Mengelola durasi cast sebelum serangan selesai.
func update_cast(delta: float) -> void:
	cast_timer -= delta
	velocity = Vector2.ZERO

	if cast_timer > 0.0:
		return

	complete_cast()

## Menyelesaikan casting state dan memulai cooldown.
func complete_cast() -> void:
	if not is_casting:
		return

	is_casting = false
	cast_timer = 0.0
	cast_cooldown_timer = cast_cooldown

	_play_idle_animation()

	DebugLogger.combat(
		"Qi Caster Cast Complete | Target: %s"
		% str(cast_target_position)
	)

## Mengurangi cooldown antar cast.
func update_cast_cooldown(delta: float) -> void:
	if cast_cooldown_timer <= 0.0:
		return

	cast_cooldown_timer = maxf(
		cast_cooldown_timer - delta,
		0.0
	)

## Menambahkan sumber damage reduction.
func add_damage_reduction_source(
	source: Object,
	multiplier: float
) -> void:
	if source == null:
		return

	damage_reduction_sources[
		source.get_instance_id()
	] = clampf(
		multiplier,
		0.0,
		1.0
	)

## Menghapus satu sumber damage reduction.
func remove_damage_reduction_source(
	source: Object
) -> void:
	if source == null:
		return

	damage_reduction_sources.erase(
		source.get_instance_id()
	)

## Mengembalikan multiplier damage terkuat yang sedang aktif.
func get_damage_taken_multiplier() -> float:
	var final_multiplier: float = 1.0

	for multiplier_value in damage_reduction_sources.values():
		final_multiplier = minf(
			final_multiplier,
			float(multiplier_value)
		)

	return final_multiplier

## Mengurangi HP Qi Caster ketika menerima damage.
func take_damage(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	var final_damage: float = (
		amount
		* get_damage_taken_multiplier()
	)

	current_hp -= final_damage
	CombatFeedback.hit(self, final_damage)

	DebugLogger.combat(
		"Qi Caster HP: %.1f"
		% current_hp
	)

	if current_hp <= 0.0:
		die()

## Menghapus Qi Caster dan menjatuhkan XP Gem.
func die() -> void:
	if is_dead:
		return

	is_dead = true
	CombatFeedback.death(self)
	remove_from_group("enemy")
	is_casting = false
	damage_reduction_sources.clear()
	velocity = Vector2.ZERO

	enemy_defeated.emit()

	var xp_gem: Node2D = (
		XP_GEM.instantiate()
		as Node2D
	)

	if xp_gem != null:
		xp_gem.position = position

		get_parent().call_deferred(
			"add_child",
			xp_gem
		)

	call_deferred("queue_free")
