extends Node2D
class_name FireOrbImpact

## Pure presentation effect for an ACTUAL Fire Orb hit.
## It does not imply or add AoE gameplay.

const EFFECT_DURATION: float = 0.25
const RING_SEGMENTS: int = 36


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


func create_burst() -> void:
	var flash := Polygon2D.new()
	var flash_points := PackedVector2Array()

	for index in range(28):
		var angle: float = (
			TAU
			* float(index)
			/ 28.0
		)
		var radius: float = (
			13.0
			+ 4.0 * sin(float(index) * 2.15)
		)
		flash_points.append(
			Vector2.RIGHT.rotated(angle)
			* radius
		)

	flash.polygon = flash_points
	flash.color = Color(1.0, 0.40, 0.06, 0.88)
	add_child(flash)

	var core := Polygon2D.new()
	var core_points := PackedVector2Array()
	for index in range(20):
		var angle: float = TAU * float(index) / 20.0
		core_points.append(
			Vector2.RIGHT.rotated(angle) * 7.0
		)
	core.polygon = core_points
	core.color = Color(1.0, 0.92, 0.48, 0.90)
	add_child(core)

	var ring := _make_line(
		create_ring_points(11.0),
		5.0,
		Color(1.0, 0.72, 0.20, 0.96)
	)

	var outer_ring: Line2D = null
	if not SettingsManager.reduced_effects:
		outer_ring = _make_line(
			create_ring_points(17.0),
			2.0,
			Color(1.0, 0.28, 0.04, 0.60)
		)

	var streak_count: int = (
		6 if SettingsManager.reduced_effects else 10
	)

	for index in range(streak_count):
		var angle: float = (
			TAU
			* float(index)
			/ float(streak_count)
		)
		var direction := Vector2.RIGHT.rotated(angle)

		var streak := _make_line(
			PackedVector2Array([
				direction * 7.0,
				direction * (
					26.0
					if index % 2 == 0
					else 21.0
				)
			]),
			3.2 if index % 2 == 0 else 2.0,
			Color(
				1.0,
				0.36,
				0.05,
				0.86
			)
		)

		var streak_tween := create_tween()
		streak_tween.set_parallel(true)
		streak_tween.tween_property(
			streak,
			"scale",
			Vector2.ONE * 1.45,
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
		Vector2.ONE * 2.8,
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
			Vector2.ONE * 2.0,
			EFFECT_DURATION
		)
		tween.tween_property(
			outer_ring,
			"modulate:a",
			0.0,
			EFFECT_DURATION
		)

	tween.tween_property(
		flash,
		"scale",
		Vector2.ONE * 1.55,
		EFFECT_DURATION
	)
	tween.tween_property(
		flash,
		"modulate:a",
		0.0,
		EFFECT_DURATION
	)

	tween.tween_property(
		core,
		"scale",
		Vector2.ONE * 1.90,
		EFFECT_DURATION
	)
	tween.tween_property(
		core,
		"modulate:a",
		0.0,
		EFFECT_DURATION
	)
