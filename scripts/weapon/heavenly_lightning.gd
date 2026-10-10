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
var _visual_elapsed: float = 0.0
var _visual_active: bool = false

@onready var collision_shape: CollisionShape2D = (
	get_node_or_null("CollisionShape2D")
)


func _ready() -> void:
	z_index = 5
	collision_layer = 0
	collision_mask = ENEMY_COLLISION_MASK
	monitoring = true
	set_process(false)

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


func create_impact_visual() -> void:
	# Instantaneous gameplay impact only. No fake wind-up or new damage area.
	# One CanvasItem draws the entire bounded visual; no per-strike Line2Ds.
	CombatFeedback.lightning(
		global_position + Vector2(0.0, -132.0),
		global_position,
		0.0,
		true
	)
	AudioManager.play_sfx("chain")
	_visual_elapsed = 0.0
	_visual_active = true
	set_process(true)
	queue_redraw()
	if not SettingsManager.reduced_effects:
		CombatFeedback.impulse(1.8)


func _process(delta: float) -> void:
	if not _visual_active:
		return
	_visual_elapsed = minf(_visual_elapsed + delta, IMPACT_VISUAL_DURATION)
	queue_redraw()
	if _visual_elapsed >= IMPACT_VISUAL_DURATION:
		_visual_active = false
		set_process(false)


func _draw() -> void:
	if not _visual_active:
		return
	var progress: float = clampf(
		_visual_elapsed / maxf(IMPACT_VISUAL_DURATION, 0.01),
		0.0, 1.0
	)
	var fade: float = (1.0 - progress) * (1.0 - progress)
	var reduced: bool = SettingsManager.reduced_effects
	var hit_radius: float = maxf(lightning_radius, 0.01)
	var expanding_radius: float = hit_radius * lerpf(0.45, 1.0, progress)

	# The outer ring never grows past the real physics query radius.
	if not reduced:
		draw_arc(
			Vector2.ZERO, expanding_radius, 0.0, TAU, 40,
			Color(0.26, 0.62, 1.0, 0.16 * fade), 10.0, true
		)
	draw_arc(
		Vector2.ZERO, expanding_radius, 0.0, TAU, 40,
		Color(0.66, 0.94, 1.0, 0.92 * fade), 3.0, true
	)
	draw_arc(
		Vector2.ZERO, expanding_radius * 0.46, 0.0, TAU, 28,
		Color(0.92, 1.0, 0.91, 0.86 * fade), 1.8, true
	)

	var ray_count: int = 4 if reduced else 10
	for index in range(ray_count):
		var direction: Vector2 = Vector2.RIGHT.rotated(
			TAU * float(index) / float(ray_count)
		)
		draw_line(
			direction * hit_radius * 0.12,
			direction * hit_radius * 0.86,
			Color(0.68, 0.93, 1.0, 0.72 * fade),
			1.8 if index % 2 == 0 else 1.2, true
		)

	# A small gold center identifies Tribulation as an empowered PLAYER hit.
	# It stays far inside the gameplay radius and does not suggest another AoE.
	if not reduced:
		draw_circle(
			Vector2.ZERO, minf(hit_radius * 0.10, 5.5),
			Color(1.0, 0.86, 0.45, 0.70 * fade)
		)


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
