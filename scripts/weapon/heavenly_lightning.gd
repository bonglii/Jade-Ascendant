extends Area2D
class_name HeavenlyLightning

## Instantaneous AoE called by Heavenly Tribulation.
## No fake wind-up is added. Premium visuals exist only at actual impact time.

const DEFAULT_RADIUS: float = 64.0
const ENEMY_COLLISION_MASK: int = 2
const MAX_QUERY_RESULTS: int = 64
const IMPACT_VISUAL_DURATION: float = 0.20

var lightning_damage: float = 0.0
var lightning_radius: float = DEFAULT_RADIUS
var player_stats: Node = null
var has_impacted: bool = false

@onready var collision_shape: CollisionShape2D = (
	get_node_or_null("CollisionShape2D")
)


func _ready() -> void:
	z_index = 5
	collision_layer = 0
	collision_mask = ENEMY_COLLISION_MASK
	monitoring = true

	apply_lightning_radius()

	await get_tree().physics_frame

	impact()

	await get_tree().create_timer(
		IMPACT_VISUAL_DURATION,
		false
	).timeout

	if is_inside_tree():
		queue_free()


func setup(
	base_damage: float,
	radius: float,
	stats: Node
) -> void:
	lightning_damage = base_damage
	lightning_radius = radius
	player_stats = stats


func apply_lightning_radius() -> void:
	if collision_shape == null:
		push_error(
			"CollisionShape2D tidak ditemukan pada Heavenly Lightning."
		)
		return

	var source_shape := (
		collision_shape.shape
		as CircleShape2D
	)
	if source_shape == null:
		push_error(
			"Heavenly Lightning membutuhkan CircleShape2D."
		)
		return

	var circle_shape := (
		source_shape.duplicate()
		as CircleShape2D
	)
	if circle_shape == null:
		push_error(
			"CircleShape2D Heavenly Lightning gagal diduplikasi."
		)
		return

	collision_shape.shape = circle_shape
	circle_shape.radius = lightning_radius


func create_ring_points(
	ring_radius: float,
	segments: int = 40
) -> PackedVector2Array:
	var points := PackedVector2Array()

	for index in range(segments + 1):
		var angle: float = (
			TAU * float(index) / float(segments)
		)
		points.append(
			Vector2.RIGHT.rotated(angle)
			* ring_radius
		)

	return points


func _make_line(
	points: PackedVector2Array,
	width: float,
	color: Color
) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.antialiased = true
	line.points = points
	add_child(line)
	return line


func create_impact_visual() -> void:
	CombatFeedback.lightning(
		global_position + Vector2(0.0, -132.0),
		global_position,
		0.0,
		true
	)
	AudioManager.play_sfx("chain")

	# This ring appears only when damage becomes active and matches actual radius.
	var outer := _make_line(
		create_ring_points(lightning_radius),
		3.0,
		Color(0.58, 0.90, 1.0, 0.80)
	)
	var glow := _make_line(
		create_ring_points(lightning_radius),
		10.0,
		Color(0.24, 0.62, 1.0, 0.12)
	)
	var inner := _make_line(
		create_ring_points(lightning_radius * 0.46),
		2.0,
		Color(0.88, 0.98, 1.0, 0.84)
	)

	var ray_count: int = (
		4 if SettingsManager.reduced_effects else 10
	)
	for index in range(ray_count):
		var direction := Vector2.RIGHT.rotated(
			float(index) * TAU / float(ray_count)
		)
		var ray := _make_line(
			PackedVector2Array([
				direction * 8.0,
				direction * lightning_radius * 0.86
			]),
			1.8 if index % 2 == 0 else 1.2,
			Color(0.66, 0.92, 1.0, 0.72)
		)

		var ray_tween := create_tween()
		ray_tween.tween_property(
			ray,
			"modulate:a",
			0.0,
			IMPACT_VISUAL_DURATION
		)

	var tween := create_tween()
	tween.set_parallel(true)

	for ring in [outer, glow, inner]:
		ring.scale = Vector2.ONE * 0.45
		tween.tween_property(
			ring,
			"scale",
			Vector2.ONE,
			IMPACT_VISUAL_DURATION
		)
		tween.tween_property(
			ring,
			"modulate:a",
			0.0,
			IMPACT_VISUAL_DURATION
		)

	if not SettingsManager.reduced_effects:
		CombatFeedback.impulse(1.8)


func impact() -> void:
	if has_impacted:
		return

	has_impacted = true
	create_impact_visual()

	if player_stats == null:
		push_error(
			"PlayerStats tidak tersedia untuk Heavenly Lightning."
		)
		return

	var query_shape := CircleShape2D.new()
	query_shape.radius = lightning_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(
		0.0,
		global_position
	)
	query.collision_mask = ENEMY_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var space_state: PhysicsDirectSpaceState2D = (
		get_world_2d().direct_space_state
	)

	var results: Array[Dictionary] = (
		space_state.intersect_shape(
			query,
			MAX_QUERY_RESULTS
		)
	)

	for result in results:
		var target: Node = result.get(
			"collider"
		) as Node

		damage_target(target)


func damage_target(target: Node) -> void:
	if target == null:
		return
	if not is_instance_valid(target):
		return
	if not target.has_method("take_damage"):
		return

	var final_damage: float = (
		player_stats.calculate_damage(
			lightning_damage
		)
	)

	target.take_damage(final_damage)

	DebugLogger.combat(
		"Heavenly Lightning Hit | Damage: %.1f"
		% final_damage
	)
