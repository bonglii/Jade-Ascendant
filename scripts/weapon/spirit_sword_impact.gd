extends Node2D
class_name SpiritSwordImpact

## Pure presentation effect for an ACTUAL Spirit Sword hit.
## Critical hits are brighter/larger, but damage and resonance
## are still controlled entirely by Spirit Sword gameplay code.

const EFFECT_DURATION: float = 0.16
const RING_SEGMENTS: int = 28

var critical: bool = false
var resonance_projectile: bool = false

func setup(
	is_critical: bool,
	is_resonance_projectile: bool
) -> void:
	critical = is_critical
	resonance_projectile = is_resonance_projectile

	create_impact()

	await get_tree().create_timer(
		EFFECT_DURATION,
		false
	).timeout

	if is_inside_tree():
		queue_free()

func create_ring_points(
	radius: float
) -> PackedVector2Array:
	var points := PackedVector2Array()

	for index in range(RING_SEGMENTS + 1):
		var angle: float = (
			TAU
			* float(index)
			/ float(RING_SEGMENTS)
		)

		points.append(
			Vector2.RIGHT.rotated(angle)
			* radius
		)

	return points

func create_impact() -> void:
	var main_color := Color(
		0.42,
		0.94,
		0.86,
		0.88
	)

	var core_color := Color(
		0.78,
		1.0,
		0.94,
		0.94
	)

	var ring_scale: float = 1.0

	if critical:
		main_color = Color(
			0.96,
			0.84,
			0.38,
			0.96
		)

		core_color = Color(
			1.0,
			0.97,
			0.78,
			1.0
		)

		ring_scale = 1.35
	elif resonance_projectile:
		main_color = Color(
			0.48,
			0.90,
			1.0,
			0.94
		)

	var slash_a := Line2D.new()
	slash_a.width = (
		4.0
		if critical
		else 3.0
	)
	slash_a.default_color = core_color
	slash_a.antialiased = true
	slash_a.points = PackedVector2Array([
		Vector2(-13.0, 9.0),
		Vector2(14.0, -10.0)
	])
	add_child(slash_a)

	var slash_b := Line2D.new()
	slash_b.width = (
		3.0
		if critical
		else 2.0
	)
	slash_b.default_color = main_color
	slash_b.antialiased = true
	slash_b.points = PackedVector2Array([
		Vector2(-8.0, -12.0),
		Vector2(9.0, 12.0)
	])
	add_child(slash_b)

	var ring := Line2D.new()
	ring.width = (
		3.5
		if critical
		else 2.5
	)
	ring.default_color = main_color
	ring.antialiased = true
	ring.points = create_ring_points(
		8.0
	)
	add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector2.ONE
		* 2.0
		* ring_scale,
		EFFECT_DURATION
	)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		EFFECT_DURATION
	)

	for slash in [
		slash_a,
		slash_b
	]:
		tween.tween_property(
			slash,
			"scale",
			Vector2.ONE * 1.20,
			EFFECT_DURATION
		)

		tween.tween_property(
			slash,
			"modulate:a",
			0.0,
			EFFECT_DURATION
		)
