extends Area2D
class_name HeavenlyLightning

## Heavenly Lightning
## Serangan AoE spiritual yang dipanggil oleh
## Heavenly Tribulation.
##
## Semantic VFX:
## - Mechanic ini tidak memiliki wind-up/telegraph.
## - Karena itu kita TIDAK menambahkan telegraph palsu.
## - Lightning impact visual muncul tepat ketika damage aktif.
## - Radius gameplay tetap digunakan untuk hit query.

const DEFAULT_RADIUS: float = 64.0
const ENEMY_COLLISION_MASK: int = 2
const MAX_QUERY_RESULTS: int = 64
const IMPACT_VISUAL_DURATION: float = 0.16

var lightning_damage: float = 0.0
var lightning_radius: float = DEFAULT_RADIUS
var player_stats: Node = null
var has_impacted: bool = false

@onready var collision_shape: CollisionShape2D = (
	get_node_or_null("CollisionShape2D")
)

func _ready() -> void:
	## Player-owned instantaneous impact layer.
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
	segment_count: int = 36
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

## Active visual coincides exactly with impact.
func create_impact_visual() -> void:
	CombatFeedback.lightning(global_position + Vector2(0.0, -116.0), global_position, 0.0, true)
	CombatFeedback.pulse(global_position, "talisman")
	AudioManager.play_sfx("chain")

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
