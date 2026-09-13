extends Area2D

## Boss Qi Shockwave
## Close-range AoE dengan telegraph sebelum impact.
##
## Semantic VFX:
## - Fill telegraph sangat tipis.
## - Outer boundary menunjukkan exact gameplay radius.
## - Inner charge ring menunjukkan wind-up dari pusat Boss.
## - Active shockwave adalah state paling terang.
## - Tidak ada permanent circle setelah effect selesai.

const ACTIVE_VISUAL_DURATION: float = 0.24

@export var shockwave_radius: float = 150.0
@export var telegraph_duration: float = 0.65
@export var base_damage: float = 6.0
@export var telegraph_segments: int = 40
@export var presentation_theme: String = ""

var has_impacted: bool = false

var telegraph_outline: Line2D = null
var charge_ring: Line2D = null

@onready var telegraph_visual: Polygon2D = $TelegraphVisual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemy_attack")

	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

	setup_collision_shape()
	setup_telegraph_visual()

	await get_tree().create_timer(
		telegraph_duration,
		false
	).timeout

	if not is_inside_tree():
		return

	impact()

func setup_collision_shape() -> void:
	var circle_shape: CircleShape2D = (
		collision_shape.shape
		as CircleShape2D
	)

	if circle_shape == null:
		circle_shape = CircleShape2D.new()
		collision_shape.shape = circle_shape

	circle_shape.radius = shockwave_radius

func create_ring_points(
	radius: float,
	segment_count: int = 40
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

## Telegraph = faint ground tint + exact outer danger boundary.
func setup_telegraph_visual() -> void:
	var segment_count: int = max(
		telegraph_segments,
		3
	)

	var points := PackedVector2Array()

	for index in range(segment_count):
		var angle: float = (
			TAU
			* float(index)
			/ float(segment_count)
		)

		points.append(
			Vector2.RIGHT.rotated(angle)
			* shockwave_radius
		)

	telegraph_visual.polygon = points
	telegraph_visual.z_index = 1

	## Previous build used 0.18 and became a large green disc.
	## 0.055 keeps spatial warning without washing out the arena.
	telegraph_visual.color = (
		Color(0.48, 0.24, 0.78, 0.055)
		if presentation_theme == "nine_heavens"
		else Color(0.20, 0.84, 0.54, 0.055)
	)

	telegraph_outline = Line2D.new()
	telegraph_outline.z_index = 6
	telegraph_outline.width = 2.4
	telegraph_outline.default_color = (
		Color(0.82, 0.60, 1.0, 0.78)
		if presentation_theme == "nine_heavens"
		else Color(0.46, 1.0, 0.70, 0.72)
	)
	telegraph_outline.antialiased = true
	telegraph_outline.points = create_ring_points(
		shockwave_radius,
		telegraph_segments
	)
	add_child(telegraph_outline)

	## Preparation cue from Boss center; never represents damage radius.
	charge_ring = Line2D.new()
	charge_ring.z_index = 5
	charge_ring.width = 2.0
	charge_ring.default_color = (
		Color(1.0, 0.82, 0.42, 0.40)
		if presentation_theme == "nine_heavens"
		else Color(0.66, 1.0, 0.78, 0.34)
	)
	charge_ring.antialiased = true

	var charge_start_radius: float = 24.0
	charge_ring.points = create_ring_points(
		charge_start_radius,
		32
	)
	add_child(charge_ring)

	var charge_target_radius: float = minf(
		shockwave_radius * 0.46,
		68.0
	)

	var target_scale: float = (
		charge_target_radius
		/ charge_start_radius
	)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		charge_ring,
		"scale",
		Vector2.ONE * target_scale,
		telegraph_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		charge_ring,
		"modulate:a",
		0.72,
		telegraph_duration
	)

	## Tiny boundary pulse: tells player "this is the dangerous edge"
	## without turning the whole area opaque.
	telegraph_outline.scale = Vector2.ONE * 0.985

	tween.tween_property(
		telegraph_outline,
		"scale",
		Vector2.ONE,
		telegraph_duration
	)

func impact() -> void:
	if has_impacted:
		return

	has_impacted = true

	hide_telegraph_visuals()
	create_active_shockwave()
	apply_damage_if_inside_radius()

	await get_tree().create_timer(
		ACTIVE_VISUAL_DURATION,
		false
	).timeout

	if is_inside_tree():
		queue_free()

func hide_telegraph_visuals() -> void:
	if telegraph_visual != null:
		telegraph_visual.visible = false

	if telegraph_outline != null:
		telegraph_outline.visible = false

	if charge_ring != null:
		charge_ring.visible = false

## Active damage = thick expanding jade shockwave.
func create_active_shockwave() -> void:
	var ring := Line2D.new()
	ring.z_index = 6
	ring.width = 6.0
	ring.default_color = (
		Color(0.76, 0.48, 1.0, 0.96)
		if presentation_theme == "nine_heavens"
		else Color(0.50, 1.0, 0.72, 0.94)
	)
	ring.antialiased = true

	var start_radius: float = 24.0
	ring.points = create_ring_points(
		start_radius,
		40
	)
	add_child(ring)

	## Secondary thinner ring gives wave-body depth but no extra hitbox.
	var secondary_ring := Line2D.new()
	secondary_ring.z_index = 6
	secondary_ring.width = 2.5
	secondary_ring.default_color = (
		Color(1.0, 0.82, 0.42, 0.62)
		if presentation_theme == "nine_heavens"
		else Color(0.76, 1.0, 0.84, 0.56)
	)
	secondary_ring.antialiased = true
	secondary_ring.points = create_ring_points(
		start_radius * 0.72,
		40
	)
	add_child(secondary_ring)

	var target_scale: float = (
		shockwave_radius
		/ start_radius
	)

	var secondary_target_scale: float = (
		shockwave_radius
		/ (start_radius * 0.72)
	)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector2.ONE * target_scale,
		0.22
	)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		ACTIVE_VISUAL_DURATION
	)

	tween.tween_property(
		secondary_ring,
		"scale",
		Vector2.ONE * secondary_target_scale,
		ACTIVE_VISUAL_DURATION
	)

	tween.tween_property(
		secondary_ring,
		"modulate:a",
		0.0,
		ACTIVE_VISUAL_DURATION
	)

## Damage contract remains unchanged.
func apply_damage_if_inside_radius() -> void:
	var player := (
		get_tree().get_first_node_in_group("player")
		as Node2D
	)

	if player == null or not is_instance_valid(player):
		return

	var distance_to_player: float = (
		global_position.distance_to(
			player.global_position
		)
	)

	if distance_to_player > shockwave_radius:
		DebugLogger.combat(
			"Boss Qi Shockwave Dodged | Distance: %.1f"
			% distance_to_player
		)
		return

	var player_health: PlayerHealth = (
		player.get_node_or_null("PlayerHealth")
		as PlayerHealth
	)

	if player_health == null:
		return

	player_health.take_damage(base_damage)

	DebugLogger.combat(
		"Boss Qi Shockwave Hit | Damage: %.1f | Distance: %.1f"
		% [
			base_damage,
			distance_to_player
		]
	)
