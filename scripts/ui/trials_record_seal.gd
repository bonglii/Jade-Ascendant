extends Control
class_name TrialsRecordSeal

## Lightweight category seal used by Daily Trials and Eternal Records.
## Presentation only.

var category: String = "trial"
var record_state: String = "in_progress"
var daily_variant: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(
	new_category: String,
	new_state: String,
	is_daily: bool
) -> void:
	category = new_category.to_lower()
	record_state = new_state.to_lower()
	daily_variant = is_daily
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var canvas_size: Vector2 = size
	if canvas_size.x <= 2.0 or canvas_size.y <= 2.0:
		return

	var center: Vector2 = canvas_size * 0.5
	var radius: float = minf(canvas_size.x, canvas_size.y) * 0.34
	var accent: Color = _get_category_color()
	var state_alpha: float = 0.98

	if record_state == "claimed":
		state_alpha = 0.56
	elif record_state == "in_progress":
		state_alpha = 0.80

	var soft := Color(accent.r, accent.g, accent.b, 0.10 * state_alpha)
	var border := Color(accent.r, accent.g, accent.b, 0.72 * state_alpha)
	var bright := Color(
		minf(accent.r + 0.22, 1.0),
		minf(accent.g + 0.22, 1.0),
		minf(accent.b + 0.22, 1.0),
		0.96 * state_alpha
	)

	draw_circle(center, radius * 1.15, soft)
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		32,
		border,
		2.0,
		true
	)

	if daily_variant:
		draw_arc(
			center,
			radius * 0.78,
			-PI * 0.78,
			PI * 0.36,
			20,
			Color(bright.r, bright.g, bright.b, 0.46),
			1.1,
			true
		)
	else:
		_draw_record_diamond(center, radius * 0.83, border)

	match category:
		"combat":
			_draw_combat(center, radius, bright)
		"progression":
			_draw_progression(center, radius, bright)
		"journey":
			_draw_journey(center, radius, bright)
		"boss":
			_draw_boss(center, radius, bright)
		"cultivation":
			_draw_cultivation(center, radius, bright)
		_:
			_draw_cultivation(center, radius, bright)

	if record_state == "reward_ready":
		_draw_reward_star(
			center + Vector2(radius * 0.72, -radius * 0.72),
			radius * 0.22,
			Color(1.0, 0.80, 0.30, 1.0)
		)
	elif record_state == "claimed":
		_draw_check(
			center + Vector2(radius * 0.68, -radius * 0.68),
			radius * 0.24,
			Color(0.55, 0.92, 0.75, 0.90)
		)


func _get_category_color() -> Color:
	match category:
		"combat":
			return Color(0.94, 0.34, 0.28, 1.0)
		"progression":
			return Color(0.30, 0.80, 0.98, 1.0)
		"journey":
			return Color(0.25, 0.90, 0.66, 1.0)
		"boss":
			return Color(1.0, 0.70, 0.20, 1.0)
		"cultivation":
			return Color(0.70, 0.50, 1.0, 1.0)
		_:
			return Color(0.32, 0.86, 0.76, 1.0)


func _draw_record_diamond(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
		center + Vector2(0.0, -radius)
	])
	draw_polyline(points, Color(color.r, color.g, color.b, 0.28), 1.0, true)


func _draw_combat(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	var length: float = radius * 0.72
	var tangent := Vector2(0.0, radius * 0.16)

	draw_line(
		center + Vector2(-length * 0.52, length * 0.52),
		center + Vector2(length * 0.52, -length * 0.52),
		color,
		2.2,
		true
	)
	draw_line(
		center + Vector2(-length * 0.52, -length * 0.52),
		center + Vector2(length * 0.52, length * 0.52),
		color,
		2.2,
		true
	)

	draw_line(
		center + Vector2(-length * 0.35, length * 0.35) - tangent,
		center + Vector2(-length * 0.35, length * 0.35) + tangent,
		color,
		1.5,
		true
	)
	draw_line(
		center + Vector2(length * 0.35, length * 0.35) - tangent,
		center + Vector2(length * 0.35, length * 0.35) + tangent,
		color,
		1.5,
		true
	)


func _draw_progression(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	var base_y: float = center.y + radius * 0.48
	var top_y: float = center.y - radius * 0.54

	draw_line(
		Vector2(center.x, base_y),
		Vector2(center.x, top_y),
		color,
		2.4,
		true
	)
	draw_line(
		Vector2(center.x, top_y),
		Vector2(center.x - radius * 0.28, center.y - radius * 0.18),
		color,
		2.0,
		true
	)
	draw_line(
		Vector2(center.x, top_y),
		Vector2(center.x + radius * 0.28, center.y - radius * 0.18),
		color,
		2.0,
		true
	)

	for level_index in range(3):
		var y_value: float = base_y - float(level_index) * radius * 0.26
		draw_line(
			Vector2(center.x - radius * 0.28, y_value),
			Vector2(center.x + radius * 0.28, y_value),
			Color(color.r, color.g, color.b, 0.55),
			1.1,
			true
		)


func _draw_journey(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	var left := center + Vector2(-radius * 0.58, radius * 0.34)
	var peak := center + Vector2(-radius * 0.12, -radius * 0.38)
	var right := center + Vector2(radius * 0.58, radius * 0.34)

	draw_polyline(
		PackedVector2Array([left, peak, right]),
		color,
		2.0,
		true
	)

	draw_polyline(
		PackedVector2Array([
			center + Vector2(-radius * 0.36, radius * 0.54),
			center + Vector2(-radius * 0.10, radius * 0.18),
			center + Vector2(radius * 0.12, radius * 0.34),
			center + Vector2(radius * 0.40, -radius * 0.04)
		]),
		Color(color.r, color.g, color.b, 0.76),
		1.5,
		true
	)


func _draw_boss(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	var y_value: float = center.y + radius * 0.20
	var points := PackedVector2Array([
		center + Vector2(-radius * 0.60, y_value - center.y),
		center + Vector2(-radius * 0.38, -radius * 0.38),
		center + Vector2(-radius * 0.10, -radius * 0.02),
		center + Vector2(radius * 0.10, -radius * 0.48),
		center + Vector2(radius * 0.36, -radius * 0.02),
		center + Vector2(radius * 0.60, -radius * 0.38),
		center + Vector2(radius * 0.60, radius * 0.30),
		center + Vector2(-radius * 0.60, radius * 0.30),
		center + Vector2(-radius * 0.60, y_value - center.y)
	])
	draw_polyline(points, color, 2.0, true)


func _draw_cultivation(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	var petal_radius: float = radius * 0.48

	for petal_index in range(4):
		var angle: float = float(petal_index) * PI * 0.5
		var direction := Vector2.RIGHT.rotated(angle)
		var tangent := direction.rotated(PI * 0.5)
		var tip := center + direction * petal_radius

		draw_polyline(
			PackedVector2Array([
				center,
				tip + tangent * radius * 0.18,
				tip,
				tip - tangent * radius * 0.18,
				center
			]),
			color,
			1.7,
			true
		)

	draw_circle(center, radius * 0.12, color)


func _draw_reward_star(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	draw_circle(
		center,
		radius * 1.55,
		Color(color.r, color.g, color.b, 0.14)
	)

	for ray_index in range(4):
		var direction := Vector2.RIGHT.rotated(float(ray_index) * PI * 0.5)
		draw_line(
			center - direction * radius,
			center + direction * radius,
			color,
			1.5,
			true
		)


func _draw_check(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	draw_line(
		center + Vector2(-radius, 0.0),
		center + Vector2(-radius * 0.18, radius * 0.70),
		color,
		1.7,
		true
	)
	draw_line(
		center + Vector2(-radius * 0.18, radius * 0.70),
		center + Vector2(radius, -radius * 0.70),
		color,
		1.7,
		true
	)
