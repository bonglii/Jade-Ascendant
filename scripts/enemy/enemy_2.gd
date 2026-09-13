extends CharacterBody2D

signal enemy_defeated

## Enemy 2
## Ranged enemy yang mengejar Player sampai berada dalam jarak serang.

const XP_GEM: PackedScene = preload(
	"res://scenes/pickups/xp_gem.tscn"
)

const ENEMY_PROJECTILE: PackedScene = preload(
	"res://scenes/enemy/enemy_projectile.tscn"
)

const CAST_VISUAL_DURATION: float = 0.6
const FACING_SWITCH_DISTANCE: float = 12.0

@export var speed: float = 60.0
@export var max_hp: float = 20.0
@export var attack_range: float = 250.0
@export var attack_cooldown: float = 2.0

@onready var player: CharacterBody2D = (
	get_parent().get_node("player_1")
)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_hp: float
var is_dead: bool = false
var attack_timer: float = 0.0
var cast_visual_timer: float = 0.0
var facing_left: bool = false
var damage_reduction_sources: Dictionary = {}
var projectile_sprite_frames: SpriteFrames = null

func _ready() -> void:
	CombatFeedback.register_actor(self)
	current_hp = max_hp
	_update_visual_facing()
	_play_idle_animation()

func configure_encounter_presentation(entry: Dictionary) -> void:
	var frames := entry.get("projectile_frames") as SpriteFrames
	if frames != null:
		projectile_sprite_frames = frames

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null:
		velocity = Vector2.ZERO
		_play_idle_animation()
		return

	if attack_timer > 0.0:
		attack_timer = maxf(
			0.0,
			attack_timer - delta
		)

	if cast_visual_timer > 0.0:
		cast_visual_timer = maxf(
			0.0,
			cast_visual_timer - delta
		)

	_update_visual_facing()

	var distance_to_player: float = (
		global_position.distance_to(
			player.global_position
		)
	)

	if distance_to_player <= attack_range:
		velocity = Vector2.ZERO

		if attack_timer <= 0.0:
			try_attack()
		elif cast_visual_timer <= 0.0:
			_play_idle_animation()

		return

	move_toward_player()
	_play_walk_animation()

## Menjaga visual Enemy 2 menghadap Player secara horizontal.
## Dead-zone mencegah walk_left / walk_right berganti cepat
## ketika Enemy hampir sejajar secara vertikal dengan Player.
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

## Memainkan idle sesuai facing terakhir.
func _play_idle_animation() -> void:
	_play_visual_animation(
		_get_directional_animation("idle")
	)

## Memainkan walk sesuai arah horizontal target.
func _play_walk_animation() -> void:
	_play_visual_animation(
		_get_directional_animation("walk")
	)

## Memainkan cast tanpa loop saat projectile ditembakkan.
func _play_cast_animation() -> void:
	_play_visual_animation(
		_get_directional_animation("cast"),
		true
	)

## Membentuk nama animasi directional yang tersedia di SpriteFrames.
func _get_directional_animation(prefix: String) -> StringName:
	var suffix: String = "right"

	if facing_left:
		suffix = "left"

	return StringName(
		"%s_%s" % [prefix, suffix]
	)

## Memainkan animation hanya jika resource memilikinya.
func _play_visual_animation(
	animation_name: StringName,
	restart: bool = false
) -> void:
	if animated_sprite == null:
		return

	if animated_sprite.sprite_frames == null:
		return

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		return

	if restart:
		animated_sprite.play(animation_name)
		return

	if (
		animated_sprite.animation != animation_name
		or not animated_sprite.is_playing()
	):
		animated_sprite.play(animation_name)

## Menggerakkan Enemy menuju Player sampai memasuki attack range.
func move_toward_player() -> void:
	var direction: Vector2 = (
		global_position.direction_to(
			player.global_position
		)
	)

	velocity = direction * speed
	move_and_slide()

## Menjalankan ranged attack ketika cooldown selesai.
func try_attack() -> void:
	if attack_timer > 0.0:
		return

	_play_cast_animation()
	cast_visual_timer = CAST_VISUAL_DURATION

	shoot_projectile()
	attack_timer = attack_cooldown

## Menembakkan projectile menuju posisi Player.
func shoot_projectile() -> void:
	if player == null or not is_instance_valid(player):
		return

	var projectile: Node = ENEMY_PROJECTILE.instantiate()

	if (
		projectile_sprite_frames != null
		and projectile.has_method("configure_sprite_frames")
	):
		projectile.call(
			"configure_sprite_frames",
			projectile_sprite_frames
		)

	get_parent().add_child(projectile)

	if projectile is Node2D:
		(projectile as Node2D).global_position = global_position

	if projectile.has_method("setup"):
		projectile.call(
			"setup",
			player.global_position
		)

	DebugLogger.system(str("ENEMY 2 PROJECTILE FIRED!"))

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

## Mengurangi HP Enemy ketika menerima damage.
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

	DebugLogger.system(str("Enemy 2 HP: ", current_hp))

	if current_hp <= 0.0:
		die()

## Menghapus Enemy dan menjatuhkan XP Gem.
func die() -> void:
	if is_dead:
		return

	is_dead = true
	CombatFeedback.death(self)
	remove_from_group("enemy")
	damage_reduction_sources.clear()

	enemy_defeated.emit()
	velocity = Vector2.ZERO

	var xp_gem: Node = XP_GEM.instantiate()

	if xp_gem is Node2D:
		(xp_gem as Node2D).position = position

	get_parent().call_deferred(
		"add_child",
		xp_gem
	)

	call_deferred("queue_free")
