extends Control

## Lightweight scalable wuxia/xianxia realm backdrop.
## Drawn procedurally so it remains crisp across portrait aspect ratios.

var sky_top: Color = Color(0.006, 0.027, 0.047, 1.0)
var sky_bottom: Color = Color(0.016, 0.086, 0.094, 1.0)
var mountain_far: Color = Color(0.031, 0.122, 0.129, 0.82)
var mountain_near: Color = Color(0.012, 0.071, 0.075, 0.96)
var mist: Color = Color(0.286, 0.776, 0.82, 0.10)
var moon: Color = Color(0.941, 0.91, 0.827, 0.08)
var accent: Color = Color(0.353, 0.784, 0.843, 1.0)
var gold: Color = Color(0.941, 0.8, 0.439, 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func apply_profile(profile: Dictionary) -> void:
	sky_top = profile.get("sky_top", sky_top)
	sky_bottom = profile.get("sky_bottom", sky_bottom)
	mountain_far = profile.get("mountain_far", mountain_far)
	mountain_near = profile.get("mountain_near", mountain_near)
	mist = profile.get("mist", mist)
	moon = profile.get("moon", moon)
	accent = profile.get("accent", accent)
	gold = profile.get("gold", gold)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var canvas_size: Vector2 = size
	if canvas_size.x <= 1.0 or canvas_size.y <= 1.0:
		return

	_draw_sky(canvas_size)
	_draw_moon(canvas_size)
	_draw_far_mountains(canvas_size)
	_draw_mist_bands(canvas_size)
	_draw_near_mountains(canvas_size)
	_draw_spiritual_stream(canvas_size)
	_draw_motes(canvas_size)
	_draw_frame_accents(canvas_size)

func _draw_sky(canvas_size: Vector2) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(canvas_size.x, 0.0),
		Vector2(canvas_size.x, canvas_size.y),
		Vector2(0.0, canvas_size.y)
	])
	var colors: PackedColorArray = PackedColorArray([
		sky_top,
		sky_top,
		sky_bottom,
		sky_bottom
	])
	draw_polygon(points, colors)

func _draw_moon(canvas_size: Vector2) -> void:
	var radius: float = minf(canvas_size.x, canvas_size.y) * 0.115
	var center: Vector2 = Vector2(canvas_size.x * 0.78, canvas_size.y * 0.26)
	draw_circle(
		center,
		radius * 1.28,
		Color(moon.r, moon.g, moon.b, moon.a * 0.32)
	)
	draw_circle(center, radius, moon)

func _draw_far_mountains(canvas_size: Vector2) -> void:
	var y_base: float = canvas_size.y * 0.61
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, y_base),
		Vector2(canvas_size.x * 0.07, canvas_size.y * 0.48),
		Vector2(canvas_size.x * 0.17, canvas_size.y * 0.55),
		Vector2(canvas_size.x * 0.29, canvas_size.y * 0.40),
		Vector2(canvas_size.x * 0.38, canvas_size.y * 0.54),
		Vector2(canvas_size.x * 0.50, canvas_size.y * 0.43),
		Vector2(canvas_size.x * 0.61, canvas_size.y * 0.54),
		Vector2(canvas_size.x * 0.74, canvas_size.y * 0.38),
		Vector2(canvas_size.x * 0.86, canvas_size.y * 0.52),
		Vector2(canvas_size.x, canvas_size.y * 0.44),
		Vector2(canvas_size.x, canvas_size.y),
		Vector2(0.0, canvas_size.y)
	])
	draw_colored_polygon(points, mountain_far)

func _draw_near_mountains(canvas_size: Vector2) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, canvas_size.y * 0.74),
		Vector2(canvas_size.x * 0.12, canvas_size.y * 0.62),
		Vector2(canvas_size.x * 0.23, canvas_size.y * 0.70),
		Vector2(canvas_size.x * 0.37, canvas_size.y * 0.57),
		Vector2(canvas_size.x * 0.51, canvas_size.y * 0.72),
		Vector2(canvas_size.x * 0.67, canvas_size.y * 0.60),
		Vector2(canvas_size.x * 0.80, canvas_size.y * 0.71),
		Vector2(canvas_size.x, canvas_size.y * 0.58),
		Vector2(canvas_size.x, canvas_size.y),
		Vector2(0.0, canvas_size.y)
	])
	draw_colored_polygon(points, mountain_near)

func _draw_mist_bands(canvas_size: Vector2) -> void:
	var band_a: PackedVector2Array = PackedVector2Array([
		Vector2(-20.0, canvas_size.y * 0.50),
		Vector2(canvas_size.x * 0.28, canvas_size.y * 0.46),
		Vector2(canvas_size.x * 0.58, canvas_size.y * 0.50),
		Vector2(canvas_size.x + 20.0, canvas_size.y * 0.45),
		Vector2(canvas_size.x + 20.0, canvas_size.y * 0.51),
		Vector2(canvas_size.x * 0.58, canvas_size.y * 0.56),
		Vector2(canvas_size.x * 0.28, canvas_size.y * 0.52),
		Vector2(-20.0, canvas_size.y * 0.57)
	])
	draw_colored_polygon(band_a, mist)

	var band_b_color: Color = Color(mist.r, mist.g, mist.b, mist.a * 0.62)
	var band_b: PackedVector2Array = PackedVector2Array([
		Vector2(-20.0, canvas_size.y * 0.68),
		Vector2(canvas_size.x * 0.34, canvas_size.y * 0.63),
		Vector2(canvas_size.x * 0.65, canvas_size.y * 0.67),
		Vector2(canvas_size.x + 20.0, canvas_size.y * 0.62),
		Vector2(canvas_size.x + 20.0, canvas_size.y * 0.67),
		Vector2(canvas_size.x * 0.65, canvas_size.y * 0.72),
		Vector2(canvas_size.x * 0.34, canvas_size.y * 0.68),
		Vector2(-20.0, canvas_size.y * 0.73)
	])
	draw_colored_polygon(band_b, band_b_color)

func _draw_spiritual_stream(canvas_size: Vector2) -> void:
	var stream_color: Color = Color(accent.r, accent.g, accent.b, 0.16)
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-10.0, canvas_size.y * 0.78),
		Vector2(canvas_size.x * 0.17, canvas_size.y * 0.75),
		Vector2(canvas_size.x * 0.39, canvas_size.y * 0.81),
		Vector2(canvas_size.x * 0.58, canvas_size.y * 0.77),
		Vector2(canvas_size.x * 0.79, canvas_size.y * 0.82),
		Vector2(canvas_size.x + 10.0, canvas_size.y * 0.79)
	])
	for index: int in range(points.size() - 1):
		draw_line(points[index], points[index + 1], stream_color, 2.0, true)

func _draw_motes(canvas_size: Vector2) -> void:
	var mote_positions: Array[Vector2] = [
		Vector2(0.12, 0.24), Vector2(0.22, 0.33), Vector2(0.34, 0.19),
		Vector2(0.48, 0.29), Vector2(0.63, 0.18), Vector2(0.72, 0.37),
		Vector2(0.84, 0.22), Vector2(0.91, 0.43), Vector2(0.16, 0.58),
		Vector2(0.57, 0.58), Vector2(0.88, 0.65)
	]
	for index: int in range(mote_positions.size()):
		var uv: Vector2 = mote_positions[index]
		var radius: float = 1.2 + float(index % 3) * 0.65
		var mote_color: Color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.18 + float(index % 2) * 0.08
		)
		draw_circle(
			Vector2(canvas_size.x * uv.x, canvas_size.y * uv.y),
			radius,
			mote_color
		)

func _draw_frame_accents(canvas_size: Vector2) -> void:
	var gold_soft: Color = Color(gold.r, gold.g, gold.b, 0.30)
	var jade_soft: Color = Color(accent.r, accent.g, accent.b, 0.24)
	var inset: float = 14.0
	var corner: float = 48.0

	draw_line(Vector2(inset, inset), Vector2(inset + corner, inset), gold_soft, 1.5, true)
	draw_line(Vector2(inset, inset), Vector2(inset, inset + corner), gold_soft, 1.5, true)
	draw_line(Vector2(canvas_size.x - inset, inset), Vector2(canvas_size.x - inset - corner, inset), gold_soft, 1.5, true)
	draw_line(Vector2(canvas_size.x - inset, inset), Vector2(canvas_size.x - inset, inset + corner), gold_soft, 1.5, true)
	draw_line(Vector2(inset, canvas_size.y - inset), Vector2(inset + corner, canvas_size.y - inset), jade_soft, 1.5, true)
	draw_line(Vector2(canvas_size.x - inset, canvas_size.y - inset), Vector2(canvas_size.x - inset - corner, canvas_size.y - inset), jade_soft, 1.5, true)
