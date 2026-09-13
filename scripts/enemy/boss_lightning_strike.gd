extends Area2D

## Boss Heavenly Lightning
## Serangan AoE dengan telegraph sebelum impact.
## Telegraph memiliki arti gameplay nyata, jadi tetap terlihat.
## Impact lightning muncul tepat saat damage aktif.

@export var strike_radius: float = 60.0
@export var telegraph_duration: float = 0.85
@export var base_damage: float = 8.0
@export var telegraph_segments: int = 32
@export var presentation_theme: String = ""

var has_impacted: bool = false
var telegraph_outline: Line2D = null

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

## Menyesuaikan CircleShape2D dengan radius gameplay.
func setup_collision_shape() -> void:
	var circle_shape: CircleShape2D = (
		collision_shape.shape
		as CircleShape2D
	)

	if circle_shape == null:
		circle_shape = CircleShape2D.new()
		collision_shape.shape = circle_shape

	circle_shape.radius = strike_radius

## Telegraph Heavenly Lightning:
## warm ivory/gold agar berbeda dari Storm Cultivator.
func setup_telegraph_visual() -> void:
	var segment_count: int = max(
		telegraph_segments,
		3
	)

	var points := PackedVector2Array()
	var outline_points := PackedVector2Array()

	for i in range(segment_count):
		var angle: float = (
			TAU
			* float(i)
			/ float(segment_count)
		)

		var point := (
			Vector2.RIGHT.rotated(angle)
			* strike_radius
		)

		points.append(point)
		outline_points.append(point)

	if not outline_points.is_empty():
		outline_points.append(
			outline_points[0]
		)

	telegraph_visual.polygon = points
	telegraph_visual.z_index = 1
	var telegraph_fill := Color(0.95, 0.82, 0.42, 0.22)
	var telegraph_edge := Color(1.0, 0.91, 0.62, 0.90)
	if presentation_theme == "nine_heavens":
		telegraph_fill = Color(0.62, 0.31, 0.92, 0.20)
		telegraph_edge = Color(0.90, 0.72, 1.0, 0.94)
	telegraph_visual.color = telegraph_fill

	## Exact gameplay-radius boundary remains readable above dense weapon VFX.
	telegraph_outline = Line2D.new()
	telegraph_outline.z_index = 6
	telegraph_outline.width = 2.6
	telegraph_outline.default_color = telegraph_edge
	telegraph_outline.antialiased = true
	telegraph_outline.points = outline_points
	add_child(telegraph_outline)

## Impact selalu divisualkan, baik Player terkena maupun berhasil dodge.
func impact() -> void:
	if has_impacted:
		return

	has_impacted = true

	if telegraph_visual != null:
		telegraph_visual.visible = false

	if (
		telegraph_outline != null
		and is_instance_valid(telegraph_outline)
	):
		telegraph_outline.visible = false

	create_impact_visual()
	apply_damage_if_inside_radius()

	await get_tree().create_timer(
		0.16,
		false
	).timeout

	if is_inside_tree():
		queue_free()

## Sambaran heavenly lightning + flash.
func create_impact_visual() -> void:
	var bolt := Line2D.new()
	bolt.z_index = 6
	bolt.width = 8.0
	bolt.default_color = (
		Color(0.91, 0.76, 1.0, 1.0)
		if presentation_theme == "nine_heavens"
		else Color(1.0, 0.94, 0.76, 1.0)
	)
	bolt.antialiased = true

	bolt.points = PackedVector2Array([
		Vector2(-6.0, -150.0),
		Vector2(7.0, -120.0),
		Vector2(-8.0, -88.0),
		Vector2(8.0, -58.0),
		Vector2(-4.0, -28.0),
		Vector2.ZERO
	])

	add_child(bolt)

	var flash := Polygon2D.new()
	flash.z_index = 6
	var flash_points := PackedVector2Array()

	var segment_count: int = 32
	var flash_radius: float = minf(
		strike_radius,
		30.0
	)

	for i in range(segment_count):
		var angle: float = (
			TAU
			* float(i)
			/ float(segment_count)
		)

		flash_points.append(
			Vector2(
				cos(angle),
				sin(angle)
			) * flash_radius
		)

	flash.polygon = flash_points
	flash.color = (
		Color(0.78, 0.48, 1.0, 0.72)
		if presentation_theme == "nine_heavens"
		else Color(1.0, 0.90, 0.60, 0.72)
	)

	add_child(flash)

	var impact_ring := Line2D.new()
	impact_ring.z_index = 6
	impact_ring.width = 4.0
	impact_ring.default_color = (
		Color(1.0, 0.82, 0.42, 0.92)
		if presentation_theme == "nine_heavens"
		else Color(0.94, 0.82, 0.46, 0.90)
	)
	impact_ring.antialiased = true

	var ring_points := PackedVector2Array()

	for i in range(33):
		var angle: float = (
			TAU
			* float(i)
			/ 32.0
		)

		ring_points.append(
			Vector2.RIGHT.rotated(angle)
			* minf(
				strike_radius,
				34.0
			)
		)

	impact_ring.points = ring_points
	add_child(impact_ring)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		bolt,
		"modulate:a",
		0.0,
		0.16
	)

	tween.tween_property(
		flash,
		"modulate:a",
		0.0,
		0.16
	)

	tween.tween_property(
		impact_ring,
		"modulate:a",
		0.0,
		0.16
	)

## Damage contract tetap sama.
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

	if distance_to_player > strike_radius:
		DebugLogger.combat(
			"Boss Heavenly Lightning Dodged | Distance: %.1f"
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
		"Boss Heavenly Lightning Hit | Damage: %.1f | Distance: %.1f"
		% [
			base_damage,
			distance_to_player
		]
	)
