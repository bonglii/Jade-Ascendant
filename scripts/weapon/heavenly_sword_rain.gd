extends Area2D
class_name HeavenlySwordRain

## Heavenly Sword Rain
## Satu instance celestial jian yang jatuh dari langit
## dan menghantam area di sekitar target.
##
## Semantic VFX:
## - Telegraph memperlihatkan radius strike sebelum damage.
## - Celestial jian benar-benar turun menuju titik impact.
## - Active impact muncul tepat ketika AoE damage aktif.
## - Successful impact signal contract tetap sama.

signal successful_impact(
	impact_position: Vector2,
	base_damage: float
)

const DEFAULT_TELEGRAPH_DURATION: float = 0.35
const DEFAULT_ACTIVE_DURATION: float = 0.10
const VFX_SEGMENTS: int = 36

const SWORD_START_Y: float = -64.0
const SWORD_IMPACT_Y: float = -6.0

var strike_damage: float = 0.0
var strike_radius: float = 32.0
var telegraph_duration: float = DEFAULT_TELEGRAPH_DURATION
var active_duration: float = DEFAULT_ACTIVE_DURATION
var player_stats: Node = null
var has_impacted: bool = false

var telegraph_ring: Line2D = null
var inner_marker: Line2D = null

@onready var collision_shape: CollisionShape2D = (
	get_node_or_null("CollisionShape2D")
)

@onready var sword_sprite: Sprite2D = (
	get_node_or_null("Sprite2D")
)

func _ready() -> void:
	## Player-owned telegraph/falling sword stays below Lin Yue.
	z_index = 2

	collision_layer = 0
	collision_mask = 2
	monitoring = true

	apply_strike_radius()
	create_telegraph_visual()

	await get_tree().create_timer(
		telegraph_duration,
		false
	).timeout

	impact()

	await get_tree().create_timer(
		active_duration,
		false
	).timeout

	queue_free()

func setup(
	damage: float,
	radius: float,
	stats: Node
) -> void:
	strike_damage = damage
	strike_radius = radius
	player_stats = stats

func apply_strike_radius() -> void:
	if collision_shape == null:
		push_error(
			"CollisionShape2D tidak ditemukan pada Heavenly Sword Rain."
		)
		return

	var source_shape := (
		collision_shape.shape
		as CircleShape2D
	)

	if source_shape == null:
		push_error(
			"Heavenly Sword Rain membutuhkan CircleShape2D."
		)
		return

	var circle_shape := (
		source_shape.duplicate()
		as CircleShape2D
	)

	if circle_shape == null:
		push_error(
			"CircleShape2D Heavenly Sword Rain gagal diduplikasi."
		)
		return

	collision_shape.shape = circle_shape
	circle_shape.radius = strike_radius

func create_ring_points(
	ring_radius: float,
	segment_count: int = VFX_SEGMENTS
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
			* ring_radius
		)

	return points

## Telegraph menunjukkan radius strike dan sword turun ke tanah.
func create_telegraph_visual() -> void:
	telegraph_ring = Line2D.new()
	telegraph_ring.width = 2.0
	telegraph_ring.default_color = Color(
		0.72,
		0.90,
		1.0,
		0.62
	)
	telegraph_ring.antialiased = true
	telegraph_ring.points = create_ring_points(
		strike_radius
	)
	add_child(telegraph_ring)

	inner_marker = Line2D.new()
	inner_marker.width = 1.0
	inner_marker.default_color = Color(
		0.84,
		0.96,
		1.0,
		0.34
	)
	inner_marker.antialiased = true
	inner_marker.points = create_ring_points(
		strike_radius * 0.42
	)
	add_child(inner_marker)

	telegraph_ring.scale = Vector2.ONE * 0.72
	inner_marker.scale = Vector2.ONE * 0.72

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		telegraph_ring,
		"scale",
		Vector2.ONE,
		telegraph_duration
	)

	tween.tween_property(
		inner_marker,
		"scale",
		Vector2.ONE,
		telegraph_duration
	)

	if sword_sprite != null:
		var target_scale: Vector2 = sword_sprite.scale

		sword_sprite.position.y = SWORD_START_Y
		sword_sprite.scale = target_scale * 0.86
		sword_sprite.modulate.a = 0.28

		tween.tween_property(
			sword_sprite,
			"position:y",
			SWORD_IMPACT_Y,
			telegraph_duration
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_IN
		)

		tween.tween_property(
			sword_sprite,
			"scale",
			target_scale,
			telegraph_duration
		)

		tween.tween_property(
			sword_sprite,
			"modulate:a",
			1.0,
			telegraph_duration
		)

func hide_telegraph_visual() -> void:
	if telegraph_ring != null:
		telegraph_ring.visible = false

	if inner_marker != null:
		inner_marker.visible = false

func create_impact_visual() -> void:
	var impact_ring := Line2D.new()
	## Parent is z=2, so relative +3 resolves to combat impact z=5.
	impact_ring.z_index = 3
	impact_ring.width = 5.0
	impact_ring.default_color = Color(
		0.82,
		0.96,
		1.0,
		0.94
	)
	impact_ring.antialiased = true

	var start_radius: float = maxf(
		strike_radius * 0.35,
		7.0
	)

	impact_ring.points = create_ring_points(
		start_radius
	)
	add_child(impact_ring)

	var streak := Line2D.new()
	streak.z_index = 3
	streak.width = 4.0
	streak.default_color = Color(
		0.92,
		0.98,
		1.0,
		0.92
	)
	streak.antialiased = true
	streak.points = PackedVector2Array([
		Vector2(0.0, -58.0),
		Vector2(0.0, 8.0)
	])
	add_child(streak)

	## Empat short Qi shards memberi rasa celestial impact,
	## tanpa menambah hitbox baru.
	for direction in [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN
	]:
		var shard := Line2D.new()
		shard.z_index = 3
		shard.width = 2.0
		shard.default_color = Color(
			0.72,
			0.96,
			1.0,
			0.78
		)
		shard.antialiased = true
		shard.points = PackedVector2Array([
			direction * 6.0,
			direction * minf(
				strike_radius * 0.72,
				28.0
			)
		])
		add_child(shard)

		var shard_tween := create_tween()
		shard_tween.tween_property(
			shard,
			"modulate:a",
			0.0,
			active_duration
		)

	var target_scale: float = (
		strike_radius / start_radius
	)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		impact_ring,
		"scale",
		Vector2.ONE * target_scale,
		active_duration
	)

	tween.tween_property(
		impact_ring,
		"modulate:a",
		0.0,
		active_duration
	)

	tween.tween_property(
		streak,
		"modulate:a",
		0.0,
		active_duration
	)

	if sword_sprite != null:
		tween.tween_property(
			sword_sprite,
			"modulate:a",
			0.0,
			active_duration
		)

func impact() -> void:
	if has_impacted:
		return

	has_impacted = true
	AudioManager.play_sfx("sword")

	hide_telegraph_visual()
	create_impact_visual()

	if player_stats == null:
		return

	var hit_successful: bool = false

	for body in get_overlapping_bodies():
		if damage_target(body):
			hit_successful = true

	if hit_successful:
		successful_impact.emit(
			global_position,
			strike_damage
		)

func damage_target(target: Node) -> bool:
	if target == null:
		return false

	if not is_instance_valid(target):
		return false

	if not target.has_method("take_damage"):
		return false

	var final_damage: float = (
		player_stats.calculate_damage(
			strike_damage
		)
	)

	target.take_damage(final_damage)

	DebugLogger.combat(
		"Heavenly Sword Rain Hit | Damage: %.1f"
		% final_damage
	)

	return true
