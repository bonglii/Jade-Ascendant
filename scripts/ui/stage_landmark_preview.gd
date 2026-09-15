extends Control

const StageMotifs = preload("res://scripts/world/stage_motifs.gd")
const JourneyVisualCatalog = preload("res://scripts/ui/journey_visual_catalog.gd")

var chapter_id: int = 1
var stage_id: int = 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var profile: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
	var realm_profile: Dictionary = JourneyVisualCatalog.get_chapter_profile(chapter_id)
	var ground: Color = profile.get(
		"ground",
		realm_profile.get("sky_bottom", Color(0.016, 0.086, 0.094, 1.0))
	)
	var accent: Color = profile.get(
		"accent",
		realm_profile.get("accent", Color(0.353, 0.784, 0.843, 1.0))
	)
	var gold: Color = realm_profile.get("gold", Color(0.941, 0.8, 0.439, 1.0))
	var is_boss: bool = bool(profile.get("is_chapter_boss", false))

	_draw_stage_background(ground, accent)

	if chapter_id == 1:
		var scale_factor: float = 0.54 if stage_id != 5 else 0.42
		StageMotifs.draw_motif(
			self,
			stage_id,
			Vector2(size.x * 0.5, size.y * 0.76),
			scale_factor
		)
	elif chapter_id == 2:
		_draw_crimson_moon_mark(stage_id, accent, gold, ground)
	elif chapter_id == 3:
		_draw_nine_heavens_mark(stage_id, accent, gold, ground)
	else:
		_draw_generic_realm_mark(accent, gold)

	_draw_corner_marks(accent, gold)

	if is_boss:
		_draw_boss_crown(gold, accent)

	draw_rect(
		Rect2(Vector2.ONE, size - Vector2.ONE * 2.0),
		Color(gold if is_boss else accent, 0.58 if is_boss else 0.42),
		false,
		1.5 if is_boss else 1.0
	)

func _draw_stage_background(ground: Color, accent: Color) -> void:
	var top: Color = ground.darkened(0.22)
	var bottom: Color = ground.lerp(accent, 0.10)
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y)
	])
	var colors := PackedColorArray([top, top, bottom, bottom])
	draw_polygon(points, colors)

	for index in range(4):
		var y: float = size.y * (0.18 + float(index) * 0.22)
		draw_line(
			Vector2(0.0, y),
			Vector2(size.x, y - 5.0),
			Color(accent, 0.035 + float(index) * 0.012),
			1.0,
			true
		)

func _draw_corner_marks(accent: Color, gold: Color) -> void:
	var inset: float = 6.0
	var length: float = minf(size.x, size.y) * 0.16
	var c1 := Color(accent, 0.42)
	var c2 := Color(gold, 0.38)

	draw_line(Vector2(inset, inset), Vector2(inset + length, inset), c1, 1.1, true)
	draw_line(Vector2(inset, inset), Vector2(inset, inset + length), c1, 1.1, true)
	draw_line(Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset - length, size.y - inset), c2, 1.1, true)
	draw_line(Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset, size.y - inset - length), c2, 1.1, true)

func _draw_boss_crown(gold: Color, accent: Color) -> void:
	var center := Vector2(size.x * 0.50, size.y * 0.16)
	var width: float = minf(size.x * 0.30, 28.0)
	var height: float = 8.0
	var points := PackedVector2Array([
		center + Vector2(-width * 0.5, height * 0.45),
		center + Vector2(-width * 0.28, -height * 0.5),
		center + Vector2(0.0, height * 0.08),
		center + Vector2(width * 0.28, -height * 0.5),
		center + Vector2(width * 0.5, height * 0.45)
	])
	draw_polyline(points, Color(gold, 0.88), 1.6, true)
	draw_circle(center + Vector2(0.0, 1.0), 1.8, Color(accent, 0.90))

func _draw_crimson_moon_mark(
	target_stage_id: int,
	accent: Color,
	gold: Color,
	ground: Color
) -> void:
	var center: Vector2 = Vector2(size.x * 0.50, size.y * 0.52)
	var radius: float = minf(size.x, size.y) * 0.25

	draw_circle(center, radius * 1.30, Color(accent, 0.075))
	draw_circle(center, radius, Color(accent, 0.50))
	draw_circle(
		center + Vector2(radius * 0.38, -radius * 0.16),
		radius * 0.82,
		ground
	)

	match target_stage_id:
		1:
			for side: int in [-1, 1]:
				draw_line(
					center + Vector2(0.0, radius * 0.48),
					center + Vector2(float(side) * radius * 0.76, radius * 1.06),
					Color(gold, 0.72),
					1.7,
					true
				)
		2:
			draw_line(
				center + Vector2(-radius, radius * 0.88),
				center + Vector2(radius, radius * 0.32),
				Color(gold, 0.70),
				1.6,
				true
			)
			draw_line(
				center + Vector2(-radius, radius * 0.26),
				center + Vector2(radius, radius * 0.84),
				Color(accent, 0.82),
				1.6,
				true
			)
		3:
			for inset: float in [0.48, 0.76]:
				var r: float = radius * inset
				draw_rect(
					Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)),
					Color(gold, 0.60),
					false,
					1.5
				)
		4:
			for step: int in range(4):
				var y: float = center.y + radius * 0.95 - float(step) * radius * 0.35
				var half_w: float = radius * 0.94 - float(step) * radius * 0.14
				draw_line(
					Vector2(center.x - half_w, y),
					Vector2(center.x + half_w, y),
					Color(gold, 0.68),
					1.6,
					true
				)
		5:
			var gate_r: float = radius * 0.92
			draw_polyline(
				PackedVector2Array([
					center + Vector2(-gate_r, gate_r),
					center + Vector2(-gate_r, -gate_r * 0.35),
					center + Vector2(gate_r, -gate_r * 0.35),
					center + Vector2(gate_r, gate_r)
				]),
				Color(gold, 0.78),
				1.9,
				true
			)
			draw_line(
				center + Vector2(-gate_r * 1.12, -gate_r * 0.38),
				center + Vector2(gate_r * 1.12, -gate_r * 0.38),
				Color(gold, 0.84),
				2.0,
				true
			)

func _draw_nine_heavens_mark(
	target_stage_id: int,
	accent: Color,
	gold: Color,
	ground: Color
) -> void:
	var center: Vector2 = Vector2(size.x * 0.50, size.y * 0.54)
	var r: float = minf(size.x, size.y) * 0.26

	match target_stage_id:
		1:
			var gate: PackedVector2Array = PackedVector2Array([
				center + Vector2(-r, r * 0.72),
				center + Vector2(-r, -r * 0.42),
				center + Vector2(0.0, -r),
				center + Vector2(r, -r * 0.42),
				center + Vector2(r, r * 0.72)
			])
			draw_polyline(gate, Color(accent, 0.84), 2.0, true)
			draw_line(
				center + Vector2(-r * 1.12, -r * 0.38),
				center + Vector2(r * 1.12, -r * 0.38),
				Color(gold, 0.84), 1.8, true
			)
		2:
			draw_circle(center, r * 0.88, Color(accent, 0.10))
			draw_arc(center, r * 0.88, 0.0, TAU, 32, Color(accent, 0.82), 1.9, true)
			draw_circle(center + Vector2(r * 0.24, -r * 0.10), r * 0.62, ground)
			draw_line(
				center + Vector2(-r * 0.72, r * 0.48),
				center + Vector2(r * 0.66, -r * 0.46),
				Color(gold, 0.78), 1.7, true
			)
		3:
			draw_arc(center, r, 0.0, TAU, 36, Color(accent, 0.70), 1.8, true)
			var stars: Array[Vector2] = [
				Vector2(-0.62, -0.18), Vector2(-0.22, -0.62),
				Vector2(0.34, -0.34), Vector2(0.62, 0.12),
				Vector2(0.12, 0.58), Vector2(-0.48, 0.42)
			]
			for index: int in range(stars.size()):
				var point: Vector2 = center + stars[index] * r
				draw_circle(point, 2.0, Color(gold, 0.92))
				if index > 0:
					var previous: Vector2 = center + stars[index - 1] * r
					draw_line(previous, point, Color(accent, 0.62), 1.3, true)
		4:
			for step: int in range(5):
				var y: float = center.y + r * 0.78 - float(step) * r * 0.34
				var half_w: float = r * 0.92 - float(step) * r * 0.13
				draw_line(
					Vector2(center.x - half_w, y),
					Vector2(center.x + half_w, y),
					Color(gold, 0.78), 1.7, true
				)
			draw_line(
				center + Vector2(0.0, r * 0.76),
				center + Vector2(0.0, -r * 0.82),
				Color(accent, 0.58), 1.4, true
			)
		5:
			draw_arc(center, r, 0.0, TAU, 40, Color(accent, 0.70), 1.8, true)
			for index: int in range(9):
				var angle: float = -PI * 0.5 + TAU * float(index) / 9.0
				var star: Vector2 = center + Vector2.RIGHT.rotated(angle) * r * 0.72
				draw_circle(star, 1.9, Color(gold, 0.94))
			var throne: PackedVector2Array = PackedVector2Array([
				center + Vector2(-r * 0.42, r * 0.52),
				center + Vector2(-r * 0.34, -r * 0.18),
				center + Vector2(0.0, -r * 0.48),
				center + Vector2(r * 0.34, -r * 0.18),
				center + Vector2(r * 0.42, r * 0.52)
			])
			draw_polyline(throne, Color(gold, 0.84), 1.9, true)
		_:
			draw_arc(center, r, 0.0, TAU, 36, Color(accent, 0.70), 1.8, true)

	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0
		var star: Vector2 = center + Vector2.RIGHT.rotated(angle) * r * 0.50
		draw_circle(star, 1.6, Color(gold, 0.78))

func _draw_generic_realm_mark(accent: Color, gold: Color) -> void:
	var center: Vector2 = Vector2(size.x * 0.50, size.y * 0.54)
	var r: float = minf(size.x, size.y) * 0.24
	draw_polyline(
		PackedVector2Array([
			center + Vector2(0.0, -r),
			center + Vector2(r, 0.0),
			center + Vector2(0.0, r),
			center + Vector2(-r, 0.0),
			center + Vector2(0.0, -r)
		]),
		Color(accent, 0.74),
		2.0,
		true
	)
	draw_circle(center, 2.2, Color(gold, 0.92))
