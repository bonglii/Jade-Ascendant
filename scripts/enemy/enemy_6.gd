extends CharacterBody2D

signal enemy_defeated

## Enemy 6 — Qi Guardian
## Defensive support enemy yang menjaga jarak menengah dari Player.
## Guardian Aura mengurangi incoming damage normal enemy di sekitarnya.
## Qi Pulse menjadi serangan radial defensif ketika Player terlalu dekat.
##
## Beberapa Guardian dapat melindungi enemy yang sama tanpa membuat
## damage reduction menumpuk secara multiplikatif.

const XP_GEM: PackedScene = preload(
	"res://scenes/pickups/xp_gem.tscn"
)

const GUARDIAN_DAMAGE_MULTIPLIER: float = 0.70
const ENEMY_COLLISION_MASK: int = 2
const FACING_HORIZONTAL_THRESHOLD: float = 0.05
const PULSE_VISUAL_DURATION: float = 0.22
const VFX_RING_SEGMENTS: int = 40

const VERDANT_GUARDIAN_STATUS := Color(0.34, 0.86, 0.62, 0.38)
const CRIMSON_GUARDIAN_STATUS := Color(0.78, 0.18, 0.24, 0.42)
const VERDANT_PULSE_TELEGRAPH := Color(0.46, 1.0, 0.72, 0.48)
const CRIMSON_PULSE_TELEGRAPH := Color(0.96, 0.30, 0.28, 0.58)
const VERDANT_PULSE_IMPACT := Color(0.54, 1.0, 0.72, 0.92)
const CRIMSON_PULSE_IMPACT := Color(1.0, 0.28, 0.30, 0.94)
const VERDANT_PULSE_FLASH := Color(0.78, 1.0, 0.88, 0.82)
const CRIMSON_PULSE_FLASH := Color(1.0, 0.68, 0.42, 0.86)
const NINE_HEAVENS_GUARDIAN_STATUS := Color(0.58, 0.52, 0.92, 0.44)
const NINE_HEAVENS_PULSE_TELEGRAPH := Color(0.90, 0.78, 0.50, 0.60)
const NINE_HEAVENS_PULSE_IMPACT := Color(0.78, 0.62, 1.0, 0.94)
const NINE_HEAVENS_PULSE_FLASH := Color(0.98, 0.90, 0.68, 0.88)

@export var speed: float = 65.0
@export var max_hp: float = 60.0
@export var preferred_range: float = 220.0
@export var retreat_range: float = 150.0
@export var qi_pulse_damage: float = 6.0
@export var qi_pulse_radius: float = 90.0
@export var qi_pulse_wind_up: float = 0.5
@export var qi_pulse_cooldown: float = 3.0

var current_hp: float
var is_dead: bool = false
var is_pulse_winding_up: bool = false
var qi_pulse_wind_up_timer: float = 0.0
var qi_pulse_cooldown_timer: float = 0.0
var facing_left: bool = true
var protected_enemies: Dictionary = {}
var presentation_theme: StringName = &"verdant_qi"

var qi_pulse_telegraph_ring: Line2D = null
var guardian_status_ring: Line2D = null

@onready var player: CharacterBody2D = (
	get_tree().get_first_node_in_group("player")
	as CharacterBody2D
)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var guardian_aura: Area2D = $GuardianAura
@onready var qi_pulse_area: Area2D = $QiPulseArea
@onready var qi_pulse_collision: CollisionShape2D = (
	$QiPulseArea/CollisionShape2D
)

func configure_encounter_presentation(entry: Dictionary) -> void:
	presentation_theme = StringName(
		str(entry.get("presentation_theme", presentation_theme))
	)

func _presentation_color(
	verdant: Color,
	crimson: Color,
	nine_heavens: Color
) -> Color:
	if presentation_theme == &"crimson_moon":
		return crimson
	if presentation_theme == &"nine_heavens":
		return nine_heavens
	return verdant

func _ready() -> void:
	CombatFeedback.register_actor(self)
	current_hp = max_hp

	setup_guardian_aura()
	setup_qi_pulse_area()
	setup_guardian_status_visual()
	_play_idle_animation()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_qi_pulse_cooldown(delta)

	if is_pulse_winding_up:
		update_qi_pulse_wind_up(delta)
		return

	if player == null or not is_instance_valid(player):
		stop_movement()
		_play_idle_animation()
		return

	var distance_to_player: float = (
		global_position.distance_to(
			player.global_position
		)
	)

	if (
		distance_to_player <= qi_pulse_radius
		and qi_pulse_cooldown_timer <= 0.0
	):
		begin_qi_pulse_wind_up()
		return

	if distance_to_player > preferred_range:
		move_toward_player()
		_play_walk_animation()
		return

	if distance_to_player < retreat_range:
		move_away_from_player()
		_play_walk_animation()
		return

	stop_movement()
	_play_idle_animation()

func _exit_tree() -> void:
	remove_all_guardian_protection()

## Menyiapkan collision contract Guardian Aura.
func setup_guardian_aura() -> void:
	if guardian_aura == null:
		return

	guardian_aura.collision_layer = 0
	guardian_aura.collision_mask = ENEMY_COLLISION_MASK
	guardian_aura.monitoring = true
	guardian_aura.monitorable = true

	if not guardian_aura.body_entered.is_connected(
		_on_guardian_aura_body_entered
	):
		guardian_aura.body_entered.connect(
			_on_guardian_aura_body_entered
		)

	if not guardian_aura.body_exited.is_connected(
		_on_guardian_aura_body_exited
	):
		guardian_aura.body_exited.connect(
			_on_guardian_aura_body_exited
		)

## Menyamakan radius CollisionShape Qi Pulse dengan nilai gameplay.
func setup_qi_pulse_area() -> void:
	if qi_pulse_area == null:
		return

	qi_pulse_area.collision_layer = 0
	qi_pulse_area.monitoring = true
	qi_pulse_area.monitorable = true

	if qi_pulse_collision == null:
		return

	var circle_shape: CircleShape2D = (
		qi_pulse_collision.shape
		as CircleShape2D
	)

	if circle_shape == null:
		push_error(
			"Qi Guardian membutuhkan CircleShape2D pada QiPulseArea."
		)
		return

	circle_shape.radius = qi_pulse_radius


## Membuat points lingkaran tertutup untuk VFX.
func create_vfx_ring_points(
	radius: float,
	segment_count: int = VFX_RING_SEGMENTS
) -> PackedVector2Array:
	var points := PackedVector2Array()

	var safe_segment_count: int = max(
		segment_count,
		3
	)

	for index in range(safe_segment_count + 1):
		var angle: float = (
			TAU
			* float(index)
			/ float(safe_segment_count)
		)

		points.append(
			Vector2.RIGHT.rotated(angle)
			* radius
		)

	return points

## Guardian Aura adalah SUPPORT mechanic, bukan danger AoE.
## Karena itu kita TIDAK menggambar radius 150 permanen di lantai.
## Hanya status halo kecil yang muncul ketika Guardian benar-benar
## sedang melindungi minimal satu enemy.
func setup_guardian_status_visual() -> void:
	guardian_status_ring = Line2D.new()
	guardian_status_ring.z_index = -1
	guardian_status_ring.width = 2.0
	guardian_status_ring.default_color = _presentation_color(
		VERDANT_GUARDIAN_STATUS,
		CRIMSON_GUARDIAN_STATUS,
		NINE_HEAVENS_GUARDIAN_STATUS
	)
	guardian_status_ring.antialiased = true
	guardian_status_ring.points = create_vfx_ring_points(
		18.0,
		24
	)
	guardian_status_ring.position = Vector2(
		0.0,
		-8.0
	)
	guardian_status_ring.visible = false

	add_child(guardian_status_ring)

## Menampilkan status halo hanya ketika aura sedang melindungi enemy.
func update_guardian_status_visual() -> void:
	if guardian_status_ring == null:
		return

	guardian_status_ring.visible = (
		not is_dead
		and not protected_enemies.is_empty()
	)

## Telegraph Qi Pulse menggunakan radius gameplay 90.
## Hanya muncul selama wind-up 0.5 detik.
func create_qi_pulse_telegraph_visual() -> void:
	remove_qi_pulse_telegraph_visual()

	qi_pulse_telegraph_ring = Line2D.new()
	qi_pulse_telegraph_ring.z_index = 6
	qi_pulse_telegraph_ring.width = 2.2
	qi_pulse_telegraph_ring.default_color = _presentation_color(
		VERDANT_PULSE_TELEGRAPH,
		CRIMSON_PULSE_TELEGRAPH,
		NINE_HEAVENS_PULSE_TELEGRAPH
	)
	qi_pulse_telegraph_ring.antialiased = true
	qi_pulse_telegraph_ring.points = create_vfx_ring_points(
		qi_pulse_radius
	)

	add_child(qi_pulse_telegraph_ring)

	## Sedikit scale-in membuat wind-up lebih terbaca,
	## tetapi final ring tetap tepat ke radius gameplay.
	qi_pulse_telegraph_ring.scale = Vector2.ONE * 0.84

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		qi_pulse_telegraph_ring,
		"scale",
		Vector2.ONE,
		qi_pulse_wind_up
	)

	tween.tween_property(
		qi_pulse_telegraph_ring,
		"modulate:a",
		0.78,
		qi_pulse_wind_up
	)

## Menghapus telegraph saat active pulse dimulai / Guardian mati.
func remove_qi_pulse_telegraph_visual() -> void:
	if (
		qi_pulse_telegraph_ring != null
		and is_instance_valid(
			qi_pulse_telegraph_ring
		)
	):
		qi_pulse_telegraph_ring.queue_free()

	qi_pulse_telegraph_ring = null

## Active Pulse selalu terlihat saat damage window aktif,
## walaupun Player berhasil keluar radius.
func create_qi_pulse_impact_visual() -> void:
	var pulse_ring := Line2D.new()
	pulse_ring.z_index = 6
	pulse_ring.width = 6.0
	pulse_ring.default_color = _presentation_color(
		VERDANT_PULSE_IMPACT,
		CRIMSON_PULSE_IMPACT,
		NINE_HEAVENS_PULSE_IMPACT
	)
	pulse_ring.antialiased = true

	var start_radius: float = 22.0

	pulse_ring.points = create_vfx_ring_points(
		start_radius
	)

	add_child(pulse_ring)

	var inner_flash := Line2D.new()
	inner_flash.z_index = 6
	inner_flash.width = 3.0
	inner_flash.default_color = _presentation_color(
		VERDANT_PULSE_FLASH,
		CRIMSON_PULSE_FLASH,
		NINE_HEAVENS_PULSE_FLASH
	)
	inner_flash.antialiased = true
	inner_flash.points = create_vfx_ring_points(
		14.0,
		28
	)

	add_child(inner_flash)

	var target_scale: float = (
		qi_pulse_radius
		/ start_radius
	)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		pulse_ring,
		"scale",
		Vector2.ONE * target_scale,
		PULSE_VISUAL_DURATION
	)

	tween.tween_property(
		pulse_ring,
		"modulate:a",
		0.0,
		PULSE_VISUAL_DURATION
	)

	tween.tween_property(
		inner_flash,
		"scale",
		Vector2.ONE * 1.75,
		PULSE_VISUAL_DURATION
	)

	tween.tween_property(
		inner_flash,
		"modulate:a",
		0.0,
		PULSE_VISUAL_DURATION
	)

	tween.finished.connect(
		func() -> void:
			if is_instance_valid(pulse_ring):
				pulse_ring.queue_free()

			if is_instance_valid(inner_flash):
				inner_flash.queue_free()
	)

## Menggerakkan Qi Guardian menuju Player ketika berada terlalu jauh.
## Facing mengikuti arah GERAK agar movement tidak terlihat moonwalk.
func move_toward_player() -> void:
	var direction: Vector2 = (
		global_position.direction_to(
			player.global_position
		)
	)

	_update_facing_from_motion(direction)

	velocity = direction * speed
	move_and_slide()

## Menggerakkan Qi Guardian menjauh ketika Player terlalu dekat.
## Facing tetap mengikuti arah GERAK retreat.
func move_away_from_player() -> void:
	var direction: Vector2 = (
		player.global_position.direction_to(
			global_position
		)
	)

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	_update_facing_from_motion(direction)

	velocity = direction * speed
	move_and_slide()

## Menghentikan pergerakan Qi Guardian.
func stop_movement() -> void:
	velocity = Vector2.ZERO

## Mengubah facing dari arah gerak horizontal.
func _update_facing_from_motion(
	motion_direction: Vector2
) -> void:
	if motion_direction.x <= -FACING_HORIZONTAL_THRESHOLD:
		facing_left = true
	elif motion_direction.x >= FACING_HORIZONTAL_THRESHOLD:
		facing_left = false

## Mengunci facing ke Player ketika Pulse wind-up dimulai.
func _update_facing_to_player() -> void:
	if player == null or not is_instance_valid(player):
		return

	var horizontal_offset: float = (
		player.global_position.x - global_position.x
	)

	if horizontal_offset < 0.0:
		facing_left = true
	elif horizontal_offset > 0.0:
		facing_left = false

## Mengembalikan nama animasi directional.
func _directional_animation(
	prefix: String
) -> StringName:
	var suffix: String = "right"

	if facing_left:
		suffix = "left"

	return StringName(
		"%s_%s" % [prefix, suffix]
	)

## Memainkan idle tanpa restart tiap physics frame.
func _play_idle_animation() -> void:
	_play_loop_animation(
		_directional_animation("idle")
	)

## Memainkan walk tanpa restart tiap physics frame.
func _play_walk_animation() -> void:
	_play_loop_animation(
		_directional_animation("walk")
	)

## Memainkan pulse animation dan menyelaraskan durasinya
## dengan qi_pulse_wind_up.
func _play_pulse_animation() -> void:
	if animated_sprite == null:
		return

	var sprite_frames: SpriteFrames = animated_sprite.sprite_frames

	if sprite_frames == null:
		return

	var animation_name: StringName = (
		_directional_animation("pulse")
	)

	if not sprite_frames.has_animation(animation_name):
		return

	var frame_count: int = (
		sprite_frames.get_frame_count(animation_name)
	)

	var animation_fps: float = (
		sprite_frames.get_animation_speed(animation_name)
	)

	var base_duration: float = (
		float(frame_count)
		/ maxf(animation_fps, 0.001)
	)

	var safe_wind_up: float = maxf(
		qi_pulse_wind_up,
		0.01
	)

	var custom_speed: float = (
		base_duration
		/ safe_wind_up
	)

	animated_sprite.play(
		animation_name,
		custom_speed
	)

## Helper untuk animation loop.
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

## Memulai wind-up Qi Pulse ketika Player masuk radius serangan.
func begin_qi_pulse_wind_up() -> void:
	if is_pulse_winding_up:
		return

	if qi_pulse_cooldown_timer > 0.0:
		return

	if player == null or not is_instance_valid(player):
		return

	is_pulse_winding_up = true
	qi_pulse_wind_up_timer = qi_pulse_wind_up
	stop_movement()

	_update_facing_to_player()
	_play_pulse_animation()
	create_qi_pulse_telegraph_visual()

	DebugLogger.combat(
		"Qi Guardian Pulse Wind-Up Start"
	)

## Menahan Guardian selama wind-up sebelum Qi Pulse dilepaskan.
func update_qi_pulse_wind_up(delta: float) -> void:
	stop_movement()

	qi_pulse_wind_up_timer = maxf(
		qi_pulse_wind_up_timer - delta,
		0.0
	)

	if qi_pulse_wind_up_timer > 0.0:
		return

	complete_qi_pulse_wind_up()

## Menyelesaikan wind-up lalu melepaskan Qi Pulse.
func complete_qi_pulse_wind_up() -> void:
	if not is_pulse_winding_up:
		return

	is_pulse_winding_up = false
	qi_pulse_wind_up_timer = 0.0

	execute_qi_pulse()

	qi_pulse_cooldown_timer = qi_pulse_cooldown
	_play_idle_animation()

## Melepaskan Qi Pulse radial dan memberi damage jika Player
## masih berada di dalam radius ketika pulse terjadi.
func execute_qi_pulse() -> void:
	remove_qi_pulse_telegraph_visual()
	create_qi_pulse_impact_visual()

	if player == null or not is_instance_valid(player):
		return

	var distance_to_player: float = (
		global_position.distance_to(
			player.global_position
		)
	)

	if distance_to_player > qi_pulse_radius:
		DebugLogger.combat(
			"Qi Guardian Pulse Miss"
		)
		return

	damage_player_from_qi_pulse()

## Mengirim damage Qi Pulse melalui PlayerHealth.
func damage_player_from_qi_pulse() -> void:
	if player == null or not is_instance_valid(player):
		return

	var player_health: PlayerHealth = (
		player.get_node_or_null("PlayerHealth")
		as PlayerHealth
	)

	if player_health == null:
		push_error(
			"Qi Guardian tidak menemukan PlayerHealth."
		)
		return

	player_health.take_damage(
		qi_pulse_damage
	)

	DebugLogger.combat(
		"Qi Guardian Pulse Hit | Damage: %.1f"
		% qi_pulse_damage
	)

## Mengurangi cooldown Qi Pulse.
func update_qi_pulse_cooldown(delta: float) -> void:
	if qi_pulse_cooldown_timer <= 0.0:
		return

	qi_pulse_cooldown_timer = maxf(
		qi_pulse_cooldown_timer - delta,
		0.0
	)

## Menambahkan proteksi ketika normal enemy memasuki Guardian Aura.
func _on_guardian_aura_body_entered(body: Node) -> void:
	if is_dead:
		return

	if body == null or not is_instance_valid(body):
		return

	if body == self:
		return

	if not body.has_method(
		"add_damage_reduction_source"
	):
		return

	if not body.has_method(
		"remove_damage_reduction_source"
	):
		return

	var enemy_id: int = body.get_instance_id()

	if protected_enemies.has(enemy_id):
		return

	body.add_damage_reduction_source(
		self,
		GUARDIAN_DAMAGE_MULTIPLIER
	)

	protected_enemies[enemy_id] = body
	update_guardian_status_visual()

## Menghapus proteksi ketika normal enemy keluar dari Guardian Aura.
func _on_guardian_aura_body_exited(body: Node) -> void:
	if body == null:
		return

	var enemy_id: int = body.get_instance_id()

	if not protected_enemies.has(enemy_id):
		return

	var protected_enemy: Variant = protected_enemies.get(
		enemy_id,
		null
	)

	if (
		protected_enemy != null
		and is_instance_valid(protected_enemy)
		and protected_enemy.has_method(
			"remove_damage_reduction_source"
		)
	):
		protected_enemy.remove_damage_reduction_source(
			self
		)

	protected_enemies.erase(enemy_id)
	update_guardian_status_visual()

## Menghapus seluruh proteksi milik Guardian ini.
func remove_all_guardian_protection() -> void:
	for enemy_id: Variant in protected_enemies.keys():
		var enemy: Variant = protected_enemies.get(
			enemy_id,
			null
		)

		if enemy == null:
			continue

		if not is_instance_valid(enemy):
			continue

		if not enemy.has_method(
			"remove_damage_reduction_source"
		):
			continue

		enemy.remove_damage_reduction_source(self)

	protected_enemies.clear()
	update_guardian_status_visual()

## Mengurangi HP Qi Guardian ketika menerima damage.
func take_damage(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	current_hp -= amount
	CombatFeedback.hit(self, amount)

	DebugLogger.combat(
		"Qi Guardian HP: %.1f"
		% current_hp
	)

	if current_hp <= 0.0:
		die()

## Menghapus Qi Guardian, melepas seluruh aura,
## dan menjatuhkan XP Gem.
func die() -> void:
	if is_dead:
		return

	is_dead = true
	CombatFeedback.death(self)
	remove_from_group("enemy")
	is_pulse_winding_up = false
	qi_pulse_wind_up_timer = 0.0
	qi_pulse_cooldown_timer = 0.0
	velocity = Vector2.ZERO

	remove_qi_pulse_telegraph_visual()
	remove_all_guardian_protection()

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
