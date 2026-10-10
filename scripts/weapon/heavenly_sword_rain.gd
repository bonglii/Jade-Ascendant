extends Area2D
class_name HeavenlySwordRain

signal successful_impact(
	impact_position: Vector2,
	base_damage: float
)

const DEFAULT_TELEGRAPH_DURATION: float = 0.35
const DEFAULT_ACTIVE_DURATION: float = 0.12
const VFX_SEGMENTS: int = 40

const SWORD_START_Y: float = -76.0
const SWORD_IMPACT_Y: float = -6.0

var strike_damage: float = 0.0
var strike_radius: float = 32.0
var telegraph_duration: float = DEFAULT_TELEGRAPH_DURATION
var active_duration: float = DEFAULT_ACTIVE_DURATION
var player_stats: Node = null
var has_impacted: bool = false
var _impact_visual_elapsed: float = 0.0

var telegraph_ring: Line2D = null
var middle_ring: Line2D = null
var inner_marker: Line2D = null
var descent_glow: Line2D = null

@onready var collision_shape: CollisionShape2D = (
	get_node_or_null("CollisionShape2D")
)
@onready var sword_sprite: Sprite2D = (
	get_node_or_null("Sprite2D")
)


func _ready() -> void:
	z_index = 2
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	set_process(false)

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


func create_telegraph_visual() -> void:
	# Outer ring is EXACT gameplay radius: no false telegraph.
	telegraph_ring = _make_line(
		create_ring_points(strike_radius),
		2.6,
		Color(0.66, 0.90, 1.0, 0.74)
	)
	middle_ring = _make_line(
		create_ring_points(strike_radius * 0.70),
		1.5,
		Color(0.80, 0.95, 1.0, 0.46)
	)
	inner_marker = _make_line(
		create_ring_points(strike_radius * 0.34),
		1.2,
		Color(0.92, 0.99, 1.0, 0.42)
	)

	for ring in [
		telegraph_ring,
		middle_ring,
		inner_marker
	]:
		ring.scale = Vector2.ONE * 0.70

	if not SettingsManager.reduced_effects:
		for index in range(8):
			var direction := Vector2.RIGHT.rotated(
				float(index) * TAU / 8.0
			)
			_make_line(
				PackedVector2Array([
					direction * strike_radius * 0.74,
					direction * strike_radius * 0.94
				]),
				1.3,
				Color(0.74, 0.94, 1.0, 0.50)
			)

		descent_glow = _make_line(
			PackedVector2Array([
				Vector2(0.0, SWORD_START_Y - 12.0),
				Vector2(0.0, SWORD_IMPACT_Y + 8.0)
			]),
			8.0,
			Color(0.52, 0.86, 1.0, 0.14)
		)
		descent_glow.z_index = 2

	var tween := create_tween()
	tween.set_parallel(true)

	for ring in [
		telegraph_ring,
		middle_ring,
		inner_marker
	]:
		tween.tween_property(
			ring,
			"scale",
			Vector2.ONE,
			telegraph_duration
		)

	if sword_sprite != null:
		var target_scale: Vector2 = sword_sprite.scale

		sword_sprite.position.y = SWORD_START_Y
		sword_sprite.scale = target_scale * 0.78
		sword_sprite.modulate.a = 0.22

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
			target_scale * 1.06,
			telegraph_duration
		)
		tween.tween_property(
			sword_sprite,
			"modulate:a",
			1.0,
			telegraph_duration
		)


func hide_telegraph_visual() -> void:
	for line in [
		telegraph_ring,
		middle_ring,
		inner_marker,
		descent_glow
	]:
		if line != null:
			line.visible = false


func create_impact_visual() -> void:
	# The impact is a single bounded CanvasItem drawing; no per-hit Line2Ds.
	# Radius never exceeds strike_radius / the actual CircleShape2D hit area.
	_impact_visual_elapsed = 0.0
	set_process(true)
	queue_redraw()

	if sword_sprite != null:
		var fade := create_tween()
		fade.tween_property(
			sword_sprite, "modulate:a", 0.0, active_duration
		)


func _process(delta: float) -> void:
	if not has_impacted:
		return
	_impact_visual_elapsed += delta
	queue_redraw()
	if _impact_visual_elapsed >= active_duration:
		set_process(false)


func _draw() -> void:
	if not has_impacted:
		return

	var progress: float = clampf(
		_impact_visual_elapsed / maxf(active_duration, 0.01),
		0.0, 1.0
	)
	var remaining: float = 1.0 - progress
	var alpha: float = remaining * remaining
	var reduced: bool = SettingsManager.reduced_effects
	var ring_radius: float = strike_radius * lerpf(0.28, 1.0, progress)

	if not reduced:
		draw_arc(
			Vector2.ZERO, ring_radius, 0.0, TAU, VFX_SEGMENTS,
			Color(0.40, 0.80, 1.0, 0.17 * alpha), 9.0, true
		)
	draw_arc(
		Vector2.ZERO, ring_radius, 0.0, TAU, VFX_SEGMENTS,
		Color(0.82, 0.96, 1.0, 0.96 * alpha), 4.8, true
	)
	# The vertical streak communicates the falling sword, not damage width.
	draw_line(
		Vector2(0.0, -82.0), Vector2(0.0, 10.0),
		Color(0.94, 0.99, 1.0, 0.92 * alpha), 4.8, true
	)

	var shard_count: int = 4 if reduced else 8
	for index in range(shard_count):
		var direction: Vector2 = Vector2.RIGHT.rotated(
			TAU * float(index) / float(shard_count)
		)
		var shard_tip: float = minf(strike_radius * 0.82, 34.0)
		draw_line(
			direction * 7.0, direction * shard_tip,
			Color(0.66, 0.94, 1.0, 0.82 * alpha),
			2.3 if index % 2 == 0 else 1.6, true
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
