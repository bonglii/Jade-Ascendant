extends Node2D
class_name FireOrbImpact

## Pure presentation effect for an ACTUAL Fire Orb hit.
## No collision, no damage, no gameplay state.

const EFFECT_DURATION: float = 0.18
const RING_SEGMENTS: int = 32

func _ready() -> void:
	create_burst()

	await get_tree().create_timer(
		EFFECT_DURATION,
		false
	).timeout

	if is_inside_tree():
		queue_free()

func create_ring_points(
	radius: float,
	segment_count: int = RING_SEGMENTS
) -> PackedVector2Array:
	var points := PackedVector2Array()

	for index in range(segment_count + 1):
		var angle: float = (
			TAU
			* float(index)
			/ float(segment_count)
		)

		points.append(
			Vector2.RIGHT.rotated(angle)
			* radius
		)

	return points

func create_burst() -> void:
	var flash := Polygon2D.new()
	var flash_points := PackedVector2Array()

	for index in range(24):
		var angle: float = (
			TAU
			* float(index)
			/ 24.0
		)

		var radius: float = (
			10.0
			+ 3.0
			* sin(
				float(index) * 2.1
			)
		)

		flash_points.append(
			Vector2.RIGHT.rotated(angle)
			* radius
		)

	flash.polygon = flash_points
	flash.color = Color(
		1.0,
		0.54,
		0.12,
		0.84
	)
	add_child(flash)

	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(
		1.0,
		0.72,
		0.22,
		0.92
	)
	ring.antialiased = true
	ring.points = create_ring_points(
		9.0
	)
	add_child(ring)

	## Six outward flame streaks.
	for index in range(6):
		var angle: float = (
			TAU
			* float(index)
			/ 6.0
		)

		var direction := (
			Vector2.RIGHT.rotated(angle)
		)

		var streak := Line2D.new()
		streak.width = 3.0
		streak.default_color = Color(
			1.0,
			0.40,
			0.08,
			0.82
		)
		streak.antialiased = true
		streak.points = PackedVector2Array([
			direction * 5.0,
			direction * 19.0
		])
		add_child(streak)

		var streak_tween := create_tween()
		streak_tween.set_parallel(true)

		streak_tween.tween_property(
			streak,
			"scale",
			Vector2.ONE * 1.35,
			EFFECT_DURATION
		)

		streak_tween.tween_property(
			streak,
			"modulate:a",
			0.0,
			EFFECT_DURATION
		)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector2.ONE * 2.4,
		EFFECT_DURATION
	)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		EFFECT_DURATION
	)

	tween.tween_property(
		flash,
		"scale",
		Vector2.ONE * 1.25,
		EFFECT_DURATION
	)

	tween.tween_property(
		flash,
		"modulate:a",
		0.0,
		EFFECT_DURATION
	)
