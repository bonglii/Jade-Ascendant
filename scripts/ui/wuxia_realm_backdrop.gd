extends Control

## Lightweight scalable wuxia/xianxia realm backdrop.
## Procedural and chapter-aware so every realm owns a distinct visual identity.

var sky_top: Color = Color(0.006, 0.027, 0.047, 1.0)
var sky_bottom: Color = Color(0.016, 0.086, 0.094, 1.0)
var mountain_far: Color = Color(0.031, 0.122, 0.129, 0.82)
var mountain_near: Color = Color(0.012, 0.071, 0.075, 0.96)
var mist: Color = Color(0.286, 0.776, 0.82, 0.10)
var moon: Color = Color(0.941, 0.91, 0.827, 0.08)
var accent: Color = Color(0.353, 0.784, 0.843, 1.0)
var gold: Color = Color(0.941, 0.8, 0.439, 1.0)
var realm_motif: String = "generic"

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
	realm_motif = str(profile.get("realm_motif", realm_motif))
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
	_draw_realm_identity(canvas_size)
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
	var center: Vector2 = Vector2(canvas_size.x * 0.78, canvas_size.y * 0.22)
	var glow_alpha: float = 0.32
	if realm_motif == "crimson":
		glow_alpha = 0.62
	elif realm_motif == "nine_heavens":
		glow_alpha = 0.42

	draw_circle(
		center,
		radius * 1.40,
		Color(moon.r, moon.g, moon.b, moon.a * glow_alpha)
	)
	draw_circle(center, radius, moon)

	if realm_motif == "crimson":
		draw_circle(
			center + Vector2(radius * 0.44, -radius * 0.10),
			radius * 0.82,
			Color(sky_top.r, sky_top.g, sky_top.b, 0.98)
		)

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

func _draw_realm_identity(canvas_size: Vector2) -> void:
	match realm_motif:
		"verdant":
			_draw_verdant_identity(canvas_size)
		"crimson":
			_draw_crimson_identity(canvas_size)
		"nine_heavens":
			_draw_nine_heavens_identity(canvas_size)
		_:
			pass

func _draw_verdant_identity(canvas_size: Vector2) -> void:
	# Bamboo silhouettes on the outer edges make the Valley instantly readable.
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var x: float = canvas_size.x * (0.075 if side < 0.0 else 0.925)
		var stalk_color := Color(accent.r, accent.g, accent.b, 0.13)
		draw_line(
			Vector2(x, canvas_size.y * 0.16),
			Vector2(x - side * 18.0, canvas_size.y * 0.78),
			stalk_color,
			5.0,
			true
		)
		for index in range(5):
			var y: float = canvas_size.y * (0.26 + float(index) * 0.105)
			var branch_end := Vector2(x - side * 35.0, y - 16.0)
			draw_line(Vector2(x, y), branch_end, stalk_color, 2.0, true)
			draw_line(
				branch_end,
				branch_end + Vector2(-side * 14.0, -8.0),
				Color(accent.r, accent.g, accent.b, 0.09),
				4.0,
				true
			)

	var gate_center := Vector2(canvas_size.x * 0.50, canvas_size.y * 0.34)
	var gate_w: float = canvas_size.x * 0.19
	var gate_h: float = canvas_size.y * 0.085
	draw_line(
		gate_center + Vector2(-gate_w, gate_h),
		gate_center + Vector2(-gate_w, -gate_h * 0.25),
		Color(gold.r, gold.g, gold.b, 0.12),
		2.0,
		true
	)
	draw_line(
		gate_center + Vector2(gate_w, gate_h),
		gate_center + Vector2(gate_w, -gate_h * 0.25),
		Color(gold.r, gold.g, gold.b, 0.12),
		2.0,
		true
	)
	draw_line(
		gate_center + Vector2(-gate_w * 1.16, -gate_h * 0.25),
		gate_center + Vector2(gate_w * 1.16, -gate_h * 0.25),
		Color(gold.r, gold.g, gold.b, 0.15),
		2.2,
		true
	)

func _draw_crimson_identity(canvas_size: Vector2) -> void:
	# Bloodwood branches and hanging seals distinguish Chapter 2 from a recolor.
	var branch := Color(0.34, 0.045, 0.085, 0.22)
	draw_line(
		Vector2(-18.0, canvas_size.y * 0.44),
		Vector2(canvas_size.x * 0.31, canvas_size.y * 0.17),
		branch,
		8.0,
		true
	)
	draw_line(
		Vector2(canvas_size.x * 0.16, canvas_size.y * 0.30),
		Vector2(canvas_size.x * 0.36, canvas_size.y * 0.25),
		branch,
		4.0,
		true
	)
	draw_line(
		Vector2(canvas_size.x * 0.08, canvas_size.y * 0.36),
		Vector2(canvas_size.x * 0.03, canvas_size.y * 0.22),
		branch,
		3.0,
		true
	)

	for index in range(3):
		var center := Vector2(
			canvas_size.x * (0.20 + float(index) * 0.11),
			canvas_size.y * (0.27 + float(index % 2) * 0.05)
		)
		draw_line(
			center + Vector2(0.0, -22.0),
			center + Vector2(0.0, -5.0),
			Color(gold.r, gold.g, gold.b, 0.13),
			1.2,
			true
		)
		draw_rect(
			Rect2(center - Vector2(6.0, 5.0), Vector2(12.0, 22.0)),
			Color(accent.r, accent.g, accent.b, 0.07),
			true
		)
		draw_rect(
			Rect2(center - Vector2(6.0, 5.0), Vector2(12.0, 22.0)),
			Color(gold.r, gold.g, gold.b, 0.12),
			false,
			1.0
		)

func _draw_nine_heavens_identity(canvas_size: Vector2) -> void:
	# Constellation lines and cloud-palace geometry anchor the celestial chapter.
	var star_uvs: Array[Vector2] = [
		Vector2(0.12, 0.18), Vector2(0.24, 0.12), Vector2(0.38, 0.22),
		Vector2(0.52, 0.13), Vector2(0.68, 0.20), Vector2(0.83, 0.11),
		Vector2(0.90, 0.28), Vector2(0.73, 0.33)
	]
	for index in range(star_uvs.size()):
		var point := Vector2(
			canvas_size.x * star_uvs[index].x,
			canvas_size.y * star_uvs[index].y
		)
		draw_circle(point, 2.0, Color(gold.r, gold.g, gold.b, 0.24))
		if index > 0:
			var previous := Vector2(
				canvas_size.x * star_uvs[index - 1].x,
				canvas_size.y * star_uvs[index - 1].y
			)
			draw_line(
				previous,
				point,
				Color(accent.r, accent.g, accent.b, 0.11),
				1.2,
				true
			)

	var palace_center := Vector2(canvas_size.x * 0.5, canvas_size.y * 0.41)
	var half_w: float = canvas_size.x * 0.13
	var half_h: float = canvas_size.y * 0.045
	draw_polyline(
		PackedVector2Array([
			palace_center + Vector2(-half_w, half_h),
			palace_center + Vector2(-half_w, -half_h),
			palace_center + Vector2(0.0, -half_h * 2.1),
			palace_center + Vector2(half_w, -half_h),
			palace_center + Vector2(half_w, half_h)
		]),
		Color(accent.r, accent.g, accent.b, 0.13),
		2.0,
		true
	)
	draw_line(
		palace_center + Vector2(-half_w * 1.22, -half_h),
		palace_center + Vector2(half_w * 1.22, -half_h),
		Color(gold.r, gold.g, gold.b, 0.15),
		1.8,
		true
	)

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
