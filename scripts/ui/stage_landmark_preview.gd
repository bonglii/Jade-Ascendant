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

	draw_rect(Rect2(Vector2.ZERO, size), ground)
	for index: int in range(4):
		var y: float = size.y * index / 4.0
		draw_rect(
			Rect2(0.0, y, size.x, size.y / 4.0 + 1.0),
			Color(accent, 0.035 * float(4 - index))
		)

	if chapter_id == 1:
		var scale_factor: float = 0.48 if stage_id != 5 else 0.36
		StageMotifs.draw_motif(
			self,
			stage_id,
			Vector2(size.x * 0.5, size.y * 0.78),
			scale_factor
		)
	elif chapter_id == 2:
		_draw_crimson_moon_mark(stage_id, accent, gold, ground)
	elif chapter_id == 3:
		_draw_nine_heavens_mark(stage_id, accent, gold, ground)
	else:
		_draw_generic_realm_mark(accent, gold)

	draw_rect(
		Rect2(Vector2.ONE, size - Vector2.ONE * 2.0),
		Color(accent, 0.40),
		false,
		1.0
	)

func _draw_crimson_moon_mark(
	target_stage_id: int,
	accent: Color,
	gold: Color,
	ground: Color
) -> void:
	var center: Vector2 = Vector2(
		size.x * 0.50,
		size.y * 0.50
	)
	var radius: float = minf(
		size.x,
		size.y
	) * 0.23

	# Shared crescent anchors the Chapter identity.
	draw_circle(
		center,
		radius,
		Color(accent, 0.42)
	)
	draw_circle(
		center + Vector2(
			radius * 0.38,
			-radius * 0.16
		),
		radius * 0.82,
		ground
	)

	match target_stage_id:
		1:
			for side: int in [-1, 1]:
				draw_line(
					center + Vector2(
						0.0,
						radius * 0.48
					),
					center + Vector2(
						float(side) * radius * 0.72,
						radius * 1.02
					),
					Color(gold, 0.62),
					1.5,
					true
				)
		2:
			draw_line(
				center + Vector2(-radius, radius * 0.88),
				center + Vector2(radius, radius * 0.36),
				Color(gold, 0.58),
				1.4,
				true
			)
			draw_line(
				center + Vector2(-radius, radius * 0.30),
				center + Vector2(radius, radius * 0.82),
				Color(accent, 0.70),
				1.4,
				true
			)
		3:
			for inset: float in [0.50, 0.78]:
				var r: float = radius * inset
				draw_rect(
					Rect2(
						center - Vector2(r, r),
						Vector2(r * 2.0, r * 2.0)
					),
					Color(gold, 0.46),
					false,
					1.2
				)
		4:
			for step: int in range(4):
				var y: float = (
					center.y
					+ radius * 0.95
					- float(step) * radius * 0.35
				)
				var half_w: float = (
					radius * 0.92
					- float(step) * radius * 0.14
				)
				draw_line(
					Vector2(center.x - half_w, y),
					Vector2(center.x + half_w, y),
					Color(gold, 0.55),
					1.4,
					true
				)
		5:
			var gate_r: float = radius * 0.92
			draw_polyline(
				PackedVector2Array([
					center + Vector2(-gate_r, gate_r),
					center + Vector2(-gate_r, -gate_r * 0.35),
					center + Vector2(gate_r, -gate_r * 0.35),
					center + Vector2(gate_r, gate_r),
				]),
				Color(gold, 0.66),
				1.6,
				true
			)
			draw_line(
				center + Vector2(-gate_r * 1.12, -gate_r * 0.38),
				center + Vector2(gate_r * 1.12, -gate_r * 0.38),
				Color(gold, 0.72),
				1.8,
				true
			)

func _draw_nine_heavens_mark(
	target_stage_id: int,
	accent: Color,
	gold: Color,
	ground: Color
) -> void:
	var center: Vector2 = Vector2(size.x * 0.50, size.y * 0.53)
	var r: float = minf(size.x, size.y) * 0.24

	# Every trial keeps the Nine Heavens star language but owns one readable
	# landmark silhouette, matching the stage-specific identity rule.
	match target_stage_id:
		1:
			var gate: PackedVector2Array = PackedVector2Array([
				center + Vector2(-r, r * 0.72),
				center + Vector2(-r, -r * 0.42),
				center + Vector2(0.0, -r),
				center + Vector2(r, -r * 0.42),
				center + Vector2(r, r * 0.72),
			])
			draw_polyline(gate, Color(accent, 0.70), 1.8, true)
			draw_line(
				center + Vector2(-r * 1.12, -r * 0.38),
				center + Vector2(r * 1.12, -r * 0.38),
				Color(gold, 0.72), 1.6, true
			)
		2:
			draw_circle(center, r * 0.88, Color(accent, 0.10))
			draw_arc(center, r * 0.88, 0.0, TAU, 32, Color(accent, 0.70), 1.7, true)
			draw_circle(center + Vector2(r * 0.24, -r * 0.10), r * 0.62, ground)
			draw_line(
				center + Vector2(-r * 0.72, r * 0.48),
				center + Vector2(r * 0.66, -r * 0.46),
				Color(gold, 0.66), 1.5, true
			)
		3:
			draw_arc(center, r, 0.0, TAU, 36, Color(accent, 0.54), 1.5, true)
			var stars: Array[Vector2] = [
				Vector2(-0.62, -0.18), Vector2(-0.22, -0.62),
				Vector2(0.34, -0.34), Vector2(0.62, 0.12),
				Vector2(0.12, 0.58), Vector2(-0.48, 0.42),
			]
			for index: int in range(stars.size()):
				var point: Vector2 = center + stars[index] * r
				draw_circle(point, 1.7, Color(gold, 0.82))
				if index > 0:
					var previous: Vector2 = center + stars[index - 1] * r
					draw_line(previous, point, Color(accent, 0.48), 1.1, true)
		4:
			for step: int in range(5):
				var y: float = center.y + r * 0.78 - float(step) * r * 0.34
				var half_w: float = r * 0.92 - float(step) * r * 0.13
				draw_line(
					Vector2(center.x - half_w, y),
					Vector2(center.x + half_w, y),
					Color(gold, 0.66), 1.5, true
				)
			draw_line(
				center + Vector2(0.0, r * 0.76),
				center + Vector2(0.0, -r * 0.82),
				Color(accent, 0.42), 1.2, true
			)
		5:
			draw_arc(center, r, 0.0, TAU, 40, Color(accent, 0.54), 1.5, true)
			for index: int in range(9):
				var angle: float = -PI * 0.5 + TAU * float(index) / 9.0
				var star: Vector2 = center + Vector2.RIGHT.rotated(angle) * r * 0.72
				draw_circle(star, 1.6, Color(gold, 0.82))
			var throne: PackedVector2Array = PackedVector2Array([
				center + Vector2(-r * 0.42, r * 0.52),
				center + Vector2(-r * 0.34, -r * 0.18),
				center + Vector2(0.0, -r * 0.48),
				center + Vector2(r * 0.34, -r * 0.18),
				center + Vector2(r * 0.42, r * 0.52),
			])
			draw_polyline(throne, Color(gold, 0.72), 1.7, true)
		_:
			draw_arc(center, r, 0.0, TAU, 36, Color(accent, 0.58), 1.6, true)

	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0
		var star: Vector2 = center + Vector2.RIGHT.rotated(angle) * r * 0.50
		draw_circle(star, 1.4, Color(gold, 0.62))

func _draw_generic_realm_mark(accent: Color, gold: Color) -> void:
	var center: Vector2 = Vector2(size.x * 0.50, size.y * 0.54)
	var r: float = minf(size.x, size.y) * 0.22
	draw_polyline(
		PackedVector2Array([
			center + Vector2(0.0, -r),
			center + Vector2(r, 0.0),
			center + Vector2(0.0, r),
			center + Vector2(-r, 0.0),
			center + Vector2(0.0, -r),
		]),
		Color(accent, 0.62),
		1.8,
		true
	)
	draw_circle(center, 2.0, Color(gold, 0.82))
