extends Control
class_name RealmLandmarkPreview

const JourneyVisualCatalog = preload("res://scripts/ui/journey_visual_catalog.gd")

var chapter_id: int = 1
var selected: bool = false
var locked: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	queue_redraw()

func set_state(
	new_chapter_id: int,
	is_selected: bool,
	is_locked: bool
) -> void:
	chapter_id = new_chapter_id
	selected = is_selected
	locked = is_locked
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var profile: Dictionary = JourneyVisualCatalog.get_chapter_profile(chapter_id)
	var accent: Color = profile.get("accent", Color(0.3, 0.82, 0.65, 1.0))
	var accent_soft: Color = profile.get("accent_soft", accent.darkened(0.25))
	var gold: Color = profile.get("gold", Color(0.96, 0.78, 0.36, 1.0))
	var sky_top: Color = profile.get("sky_top", Color(0.01, 0.03, 0.05, 1.0))
	var sky_bottom: Color = profile.get("sky_bottom", Color(0.02, 0.08, 0.09, 1.0))
	var motif: String = str(profile.get("realm_motif", "generic"))

	_draw_gradient_panel(sky_top, sky_bottom, accent)

	match motif:
		"verdant":
			_draw_verdant(accent, gold, accent_soft)
		"crimson":
			_draw_crimson(accent, gold, sky_bottom)
		"nine_heavens":
			_draw_nine_heavens(accent, gold)
		_:
			_draw_generic(accent, gold)

	var border_alpha: float = 0.92 if selected else 0.46
	if locked:
		border_alpha = 0.22

	draw_rect(
		Rect2(Vector2.ONE, size - Vector2.ONE * 2.0),
		Color(gold if selected else accent, border_alpha),
		false,
		2.0 if selected else 1.0
	)

	if locked:
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(0.01, 0.015, 0.018, 0.58)
		)

func _draw_gradient_panel(
	top: Color,
	bottom: Color,
	accent: Color
) -> void:
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y)
	])
	var colors := PackedColorArray([
		top,
		top,
		bottom,
		bottom
	])
	draw_polygon(points, colors)

	for index in range(4):
		var y: float = size.y * (0.18 + float(index) * 0.22)
		draw_line(
			Vector2(0.0, y),
			Vector2(size.x, y - size.y * 0.06),
			Color(accent, 0.035 + float(index) * 0.012),
			1.0,
			true
		)

func _draw_verdant(accent: Color, gold: Color, accent_soft: Color) -> void:
	var ground_y: float = size.y * 0.74
	var mountains := PackedVector2Array([
		Vector2(0.0, ground_y),
		Vector2(size.x * 0.18, size.y * 0.48),
		Vector2(size.x * 0.36, size.y * 0.66),
		Vector2(size.x * 0.55, size.y * 0.38),
		Vector2(size.x * 0.76, size.y * 0.64),
		Vector2(size.x, size.y * 0.46),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y)
	])
	draw_colored_polygon(mountains, Color(accent_soft, 0.55))

	var gate_center := Vector2(size.x * 0.54, size.y * 0.58)
	var gate_w: float = size.x * 0.38
	var gate_h: float = size.y * 0.30
	draw_line(
		gate_center + Vector2(-gate_w * 0.5, gate_h * 0.5),
		gate_center + Vector2(-gate_w * 0.5, -gate_h * 0.35),
		Color(gold, 0.82),
		2.0,
		true
	)
	draw_line(
		gate_center + Vector2(gate_w * 0.5, gate_h * 0.5),
		gate_center + Vector2(gate_w * 0.5, -gate_h * 0.35),
		Color(gold, 0.82),
		2.0,
		true
	)
	draw_line(
		gate_center + Vector2(-gate_w * 0.64, -gate_h * 0.35),
		gate_center + Vector2(gate_w * 0.64, -gate_h * 0.35),
		Color(gold, 0.90),
		2.2,
		true
	)

	for side in [-1.0, 1.0]:
		var x: float = size.x * (0.16 if side < 0.0 else 0.87)
		draw_line(
			Vector2(x, size.y * 0.35),
			Vector2(x - side * 3.0, size.y * 0.91),
			Color(accent, 0.58),
			3.0,
			true
		)
		for index in range(3):
			var y: float = size.y * (0.44 + float(index) * 0.12)
			draw_line(
				Vector2(x, y),
				Vector2(x - side * 14.0, y - 8.0),
				Color(accent, 0.48),
				1.6,
				true
			)

func _draw_crimson(accent: Color, gold: Color, ground: Color) -> void:
	var center := Vector2(size.x * 0.67, size.y * 0.37)
	var radius: float = minf(size.x, size.y) * 0.20
	draw_circle(center, radius * 1.35, Color(accent, 0.10))
	draw_circle(center, radius, Color(accent, 0.62))
	draw_circle(
		center + Vector2(radius * 0.42, -radius * 0.10),
		radius * 0.84,
		ground
	)

	var branch_color := Color(0.30, 0.055, 0.09, 0.88)
	draw_line(
		Vector2(-4.0, size.y * 0.78),
		Vector2(size.x * 0.36, size.y * 0.34),
		branch_color,
		4.0,
		true
	)
	draw_line(
		Vector2(size.x * 0.18, size.y * 0.60),
		Vector2(size.x * 0.06, size.y * 0.38),
		branch_color,
		2.2,
		true
	)
	draw_line(
		Vector2(size.x * 0.25, size.y * 0.51),
		Vector2(size.x * 0.42, size.y * 0.44),
		branch_color,
		2.0,
		true
	)

	var seal_center := Vector2(size.x * 0.40, size.y * 0.72)
	draw_rect(
		Rect2(seal_center - Vector2(8.0, 13.0), Vector2(16.0, 26.0)),
		Color(gold, 0.18),
		true
	)
	draw_rect(
		Rect2(seal_center - Vector2(8.0, 13.0), Vector2(16.0, 26.0)),
		Color(gold, 0.72),
		false,
		1.3
	)
	draw_line(
		seal_center + Vector2(-4.0, -5.0),
		seal_center + Vector2(5.0, 5.0),
		Color(accent, 0.82),
		1.4,
		true
	)

func _draw_nine_heavens(accent: Color, gold: Color) -> void:
	var palace_center := Vector2(size.x * 0.52, size.y * 0.60)
	var width: float = size.x * 0.46
	var height: float = size.y * 0.32

	draw_line(
		palace_center + Vector2(-width * 0.5, height * 0.5),
		palace_center + Vector2(-width * 0.5, -height * 0.25),
		Color(accent, 0.74),
		2.0,
		true
	)
	draw_line(
		palace_center + Vector2(width * 0.5, height * 0.5),
		palace_center + Vector2(width * 0.5, -height * 0.25),
		Color(accent, 0.74),
		2.0,
		true
	)
	draw_polyline(
		PackedVector2Array([
			palace_center + Vector2(-width * 0.62, -height * 0.25),
			palace_center + Vector2(0.0, -height * 0.66),
			palace_center + Vector2(width * 0.62, -height * 0.25)
		]),
		Color(gold, 0.82),
		2.0,
		true
	)

	var stars: Array[Vector2] = [
		Vector2(0.15, 0.22), Vector2(0.31, 0.14), Vector2(0.49, 0.27),
		Vector2(0.64, 0.12), Vector2(0.80, 0.25), Vector2(0.71, 0.40)
	]
	for index in range(stars.size()):
		var point := Vector2(size.x * stars[index].x, size.y * stars[index].y)
		draw_circle(point, 1.7, Color(gold, 0.90))
		if index > 0:
			var previous := Vector2(
				size.x * stars[index - 1].x,
				size.y * stars[index - 1].y
			)
			draw_line(previous, point, Color(accent, 0.38), 1.0, true)

	for index in range(3):
		var y: float = size.y * (0.76 + float(index) * 0.07)
		draw_arc(
			Vector2(size.x * (0.28 + float(index) * 0.20), y),
			size.x * 0.18,
			PI,
			TAU,
			18,
			Color(accent, 0.18),
			1.2,
			true
		)

func _draw_generic(accent: Color, gold: Color) -> void:
	var center := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.22
	draw_polyline(
		PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
			center + Vector2(0.0, -radius)
		]),
		Color(accent, 0.72),
		2.0,
		true
	)
	draw_circle(center, 3.0, Color(gold, 0.90))
