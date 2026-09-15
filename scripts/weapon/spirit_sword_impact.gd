extends Node2D
class_name SpiritSwordImpact

## Pure presentation effect for an ACTUAL Spirit Sword hit.
## Critical / resonance variants only affect presentation.

const EFFECT_DURATION: float = 0.23
const RING_SEGMENTS: int = 36

var critical: bool = false
var resonance_projectile: bool = false


func setup(
	is_critical: bool,
	is_resonance: bool
) -> void:
	critical = is_critical
	resonance_projectile = is_resonance

	create_impact()

	await get_tree().create_timer(
		EFFECT_DURATION,
		false
	).timeout

	if is_inside_tree():
		queue_free()


func create_ring_points(radius: float) -> PackedVector2Array:
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


func create_impact() -> void:
	var main_color := Color(0.36, 0.96, 0.84, 0.94)
	var core_color := Color(0.84, 1.0, 0.96, 1.0)
	var accent := Color(0.30, 0.78, 1.0, 0.74)
	var impact_scale: float = 1.0

	if critical:
		main_color = Color(1.0, 0.78, 0.22, 1.0)
		core_color = Color(1.0, 0.98, 0.76, 1.0)
		accent = Color(0.46, 1.0, 0.84, 0.82)
		impact_scale = 1.35
	elif resonance_projectile:
		main_color = Color(0.36, 0.84, 1.0, 0.98)
		core_color = Color(0.86, 0.98, 1.0, 1.0)
		accent = Color(0.52, 0.96, 0.90, 0.80)
		impact_scale = 1.16

	var slash_a := _make_line(
		PackedVector2Array([
			Vector2(-18.0, 12.0),
			Vector2(19.0, -13.0)
		]),
		4.8 if critical else 3.6,
		core_color
	)

	var slash_b := _make_line(
		PackedVector2Array([
			Vector2(-12.0, -17.0),
			Vector2(13.0, 17.0)
		]),
		3.6 if critical else 2.6,
		main_color
	)

	var glow_slash := _make_line(
		PackedVector2Array([
			Vector2(-20.0, 13.0),
			Vector2(21.0, -14.0)
		]),
		10.0 if critical else 7.0,
		Color(
			main_color.r,
			main_color.g,
			main_color.b,
			0.18
		)
	)
	glow_slash.show_behind_parent = true

	var ring := _make_line(
		create_ring_points(10.0),
		4.0 if critical else 3.0,
		main_color
	)

	var outer_ring: Line2D = null
	if not SettingsManager.reduced_effects:
		outer_ring = _make_line(
			create_ring_points(15.0),
			1.7,
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.62
			)
		)

		for index in range(8):
			var direction := Vector2.RIGHT.rotated(
				float(index) * TAU / 8.0
			)
			var ray := _make_line(
				PackedVector2Array([
					direction * 8.0,
					direction * (
						27.0 * impact_scale
					)
				]),
				1.7 if index % 2 == 0 else 1.2,
				accent
			)

			var ray_tween := create_tween()
			ray_tween.tween_property(
				ray,
				"modulate:a",
				0.0,
				EFFECT_DURATION
			)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector2.ONE * 2.55 * impact_scale,
		EFFECT_DURATION
	)
	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		EFFECT_DURATION
	)

	if outer_ring != null:
		tween.tween_property(
			outer_ring,
			"scale",
			Vector2.ONE * 1.72 * impact_scale,
			EFFECT_DURATION
		)
		tween.tween_property(
			outer_ring,
			"modulate:a",
			0.0,
			EFFECT_DURATION
		)

	for slash in [slash_a, slash_b, glow_slash]:
		tween.tween_property(
			slash,
			"scale",
			Vector2.ONE * 1.30 * impact_scale,
			EFFECT_DURATION
		)
		tween.tween_property(
			slash,
			"modulate:a",
			0.0,
			EFFECT_DURATION
		)
