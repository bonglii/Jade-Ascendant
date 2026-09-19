extends Control

const StageMotifs = preload("res://scripts/world/stage_motifs.gd")
const JourneyVisualCatalog = preload("res://scripts/ui/journey_visual_catalog.gd")

const REALM_TEXTURES: Dictionary = {
	1: preload("res://assets/ui/journey/realm_01_verdant.png"),
	2: preload("res://assets/ui/journey/realm_02_crimson.png"),
	3: preload("res://assets/ui/journey/realm_03_nine_heavens.png"),
}

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

	var stage_data: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
	var realm_profile: Dictionary = JourneyVisualCatalog.get_chapter_profile(chapter_id)
	var ground: Color = stage_data.get("ground", realm_profile.get("sky_bottom", Color(0.016, 0.086, 0.094, 1.0)))
	var accent: Color = stage_data.get("accent", realm_profile.get("accent", Color(0.353, 0.784, 0.843, 1.0)))
	var gold: Color = realm_profile.get("gold", Color(0.941, 0.8, 0.439, 1.0))
	var moss: Color = stage_data.get("moss", accent.darkened(0.42))
	var stone: Color = stage_data.get("stone", ground.lightened(0.10))
	var stage_mist: Color = stage_data.get("mist", accent.darkened(0.35))
	var is_boss: bool = bool(stage_data.get("is_chapter_boss", false))

	_draw_stage_background(ground, accent, stage_mist)
	_draw_stage_depth(moss, stone, accent)
	_draw_celestial_disc(accent, gold, ground)

	var chapter_texture: Texture2D = REALM_TEXTURES.get(chapter_id) as Texture2D
	if chapter_texture != null:
		_draw_authored_stage_icon(chapter_texture, accent, gold, is_boss)
		_draw_stage_identity_marks(accent, gold, is_boss)
	else:
		_draw_procedural_stage_mark(stage_id, accent, gold, ground)

	_draw_corner_marks(accent, gold)
	_draw_stage_seal(accent, gold)

	if is_boss:
		_draw_boss_crown(gold, accent)

	var border_color: Color = gold if is_boss else accent
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), Color(border_color.r, border_color.g, border_color.b, 0.66 if is_boss else 0.44), false, 1.7 if is_boss else 1.0)


func _draw_authored_stage_icon(texture: Texture2D, accent: Color, gold: Color, is_boss: bool) -> void:
	var frame := Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
	var art_bounds := frame.grow_individual(-2.0, -2.0, -2.0, -2.0)
	var art_rect: Rect2 = _fit_texture_rect(texture, art_bounds)

	draw_rect(frame, Color(0.0, 0.02, 0.03, 0.28), true)
	draw_texture_rect(texture, art_rect, false, Color(1.0, 1.0, 1.0, 0.97))
	draw_rect(art_rect, Color(0.0, 0.02, 0.03, 0.10), true)

	var halo_center := Vector2(size.x * 0.50, size.y * 0.55)
	var halo_radius: float = minf(size.x, size.y) * 0.38
	draw_circle(halo_center, halo_radius, Color(accent.r, accent.g, accent.b, 0.035))
	draw_arc(halo_center, halo_radius * 0.84, 0.0, TAU, 40, Color(gold.r, gold.g, gold.b, 0.18 if is_boss else 0.10), 1.2, true)

	var glaze_top := PackedVector2Array([
		frame.position,
		Vector2(frame.end.x, frame.position.y),
		Vector2(frame.end.x, frame.position.y + frame.size.y * 0.48),
		Vector2(frame.position.x, frame.position.y + frame.size.y * 0.28)
	])
	var glaze_colors := PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.16),
		Color(1.0, 1.0, 1.0, 0.08),
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.02)
	])
	draw_polygon(glaze_top, glaze_colors)


func _draw_stage_identity_marks(accent: Color, gold: Color, is_boss: bool) -> void:
	var stage_band_y: float = size.y * 0.80
	draw_line(Vector2(size.x * 0.18, stage_band_y), Vector2(size.x * 0.82, stage_band_y), Color(accent.r, accent.g, accent.b, 0.22), 1.1, true)
	var stage_pip_count: int = clampi(stage_id, 1, 5)
	var spacing: float = minf(size.x * 0.085, 10.0)
	var start_x: float = size.x * 0.50 - spacing * float(stage_pip_count - 1) * 0.5
	for pip_index in range(stage_pip_count):
		var pip_center := Vector2(start_x + float(pip_index) * spacing, stage_band_y)
		draw_circle(pip_center, 1.4, Color(gold.r, gold.g, gold.b, 0.92))
	if is_boss:
		draw_arc(Vector2(size.x * 0.50, size.y * 0.34), minf(size.x, size.y) * 0.20, PI, TAU, 20, Color(gold.r, gold.g, gold.b, 0.34), 1.4, true)


func _draw_procedural_stage_mark(target_stage_id: int, accent: Color, gold: Color, ground: Color) -> void:
	if chapter_id == 1:
		var motif_scale: float = 0.50 if target_stage_id != 5 else 0.39
		StageMotifs.draw_motif(self, target_stage_id, Vector2(size.x * 0.5, size.y * 0.73), motif_scale)
		_draw_verdant_detail(target_stage_id, accent, gold)
	elif chapter_id == 2:
		_draw_crimson_moon_mark(target_stage_id, accent, gold, ground)
	elif chapter_id == 3:
		_draw_nine_heavens_mark(target_stage_id, accent, gold, ground)
	else:
		_draw_generic_realm_mark(accent, gold)


func _draw_stage_background(ground: Color, accent: Color, stage_mist: Color) -> void:
	var top: Color = ground.darkened(0.28)
	var bottom: Color = ground.lerp(accent, 0.12)
	var panel_points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y)
	])
	var panel_colors := PackedColorArray([top, top.lightened(0.02), bottom, bottom.darkened(0.08)])
	draw_polygon(panel_points, panel_colors)

	for band_index in range(3):
		var y_value: float = size.y * (0.24 + float(band_index) * 0.22)
		draw_line(
			Vector2(-4.0, y_value),
			Vector2(size.x + 4.0, y_value - 4.0),
			Color(stage_mist.r, stage_mist.g, stage_mist.b, 0.055 + float(band_index) * 0.018),
			1.0,
			true
		)

	for mote_index in range(5):
		var x_ratio: float = float((mote_index * 29 + stage_id * 13) % 83) / 83.0
		var y_ratio: float = float((mote_index * 17 + chapter_id * 11) % 61) / 61.0
		draw_circle(Vector2(size.x * (0.12 + x_ratio * 0.76), size.y * (0.12 + y_ratio * 0.32)), 1.0, Color(accent.r, accent.g, accent.b, 0.24))


func _draw_stage_depth(moss: Color, stone: Color, accent: Color) -> void:
	var far_points := PackedVector2Array([
		Vector2(0.0, size.y * 0.66),
		Vector2(size.x * 0.22, size.y * 0.48),
		Vector2(size.x * 0.40, size.y * 0.63),
		Vector2(size.x * 0.61, size.y * 0.43),
		Vector2(size.x * 0.82, size.y * 0.61),
		Vector2(size.x, size.y * 0.50),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y)
	])
	draw_colored_polygon(far_points, Color(moss.r, moss.g, moss.b, 0.35))

	var near_points := PackedVector2Array([
		Vector2(0.0, size.y * 0.82),
		Vector2(size.x * 0.18, size.y * 0.70),
		Vector2(size.x * 0.40, size.y * 0.79),
		Vector2(size.x * 0.63, size.y * 0.66),
		Vector2(size.x * 0.81, size.y * 0.77),
		Vector2(size.x, size.y * 0.68),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y)
	])
	draw_colored_polygon(near_points, Color(stone.r, stone.g, stone.b, 0.48))
	draw_line(Vector2(0.0, size.y * 0.81), Vector2(size.x, size.y * 0.69), Color(accent.r, accent.g, accent.b, 0.08), 1.0, true)


func _draw_celestial_disc(accent: Color, gold: Color, ground: Color) -> void:
	var disc_center := Vector2(size.x * 0.76, size.y * 0.24)
	var radius: float = minf(size.x, size.y) * 0.10
	var disc_color: Color = accent if chapter_id == 2 else gold
	draw_circle(disc_center, radius * 1.38, Color(disc_color.r, disc_color.g, disc_color.b, 0.06))
	draw_circle(disc_center, radius, Color(disc_color.r, disc_color.g, disc_color.b, 0.15))
	if chapter_id == 2:
		draw_circle(disc_center + Vector2(radius * 0.40, -radius * 0.08), radius * 0.78, ground)


func _draw_verdant_detail(target_stage_id: int, accent: Color, gold: Color) -> void:
	match target_stage_id:
		1:
			for x_ratio in [0.20, 0.83]:
				draw_line(Vector2(size.x * x_ratio, size.y * 0.42), Vector2(size.x * x_ratio, size.y * 0.91), Color(accent.r, accent.g, accent.b, 0.36), 2.2, true)
		2:
			draw_arc(Vector2(size.x * 0.50, size.y * 0.64), minf(size.x, size.y) * 0.20, PI, TAU, 22, Color(gold.r, gold.g, gold.b, 0.46), 1.4, true)
		3:
			for seal_index in range(3):
				var seal_point := Vector2(size.x * (0.31 + float(seal_index) * 0.19), size.y * 0.72)
				draw_circle(seal_point, 3.0, Color(accent.r, accent.g, accent.b, 0.60))
		4:
			for step_index in range(3):
				var step_y: float = size.y * (0.80 - float(step_index) * 0.08)
				draw_line(Vector2(size.x * (0.25 + float(step_index) * 0.07), step_y), Vector2(size.x * (0.75 - float(step_index) * 0.07), step_y), Color(gold.r, gold.g, gold.b, 0.34), 1.4, true)
		5:
			draw_arc(Vector2(size.x * 0.50, size.y * 0.56), minf(size.x, size.y) * 0.22, 0.0, TAU, 32, Color(gold.r, gold.g, gold.b, 0.42), 1.4, true)


func _draw_crimson_moon_mark(target_stage_id: int, accent: Color, gold: Color, ground: Color) -> void:
	var center := Vector2(size.x * 0.50, size.y * 0.58)
	var radius: float = minf(size.x, size.y) * 0.24

	match target_stage_id:
		1:
			for side_value in [-1.0, 1.0]:
				var side: float = float(side_value)
				draw_line(center + Vector2(0.0, radius * 0.44), center + Vector2(side * radius * 0.78, radius * 1.04), Color(gold.r, gold.g, gold.b, 0.76), 1.8, true)
		2:
			draw_line(center + Vector2(-radius, radius * 0.82), center + Vector2(radius, radius * 0.28), Color(gold.r, gold.g, gold.b, 0.72), 1.7, true)
			draw_line(center + Vector2(-radius, radius * 0.24), center + Vector2(radius, radius * 0.82), Color(accent.r, accent.g, accent.b, 0.86), 1.7, true)
		3:
			for inset in [0.48, 0.76]:
				var square_radius: float = radius * float(inset)
				draw_rect(Rect2(center - Vector2(square_radius, square_radius), Vector2(square_radius * 2.0, square_radius * 2.0)), Color(gold.r, gold.g, gold.b, 0.62), false, 1.5)
		4:
			for step_index in range(4):
				var step_y: float = center.y + radius * 0.92 - float(step_index) * radius * 0.34
				var half_width: float = radius * 0.94 - float(step_index) * radius * 0.14
				draw_line(Vector2(center.x - half_width, step_y), Vector2(center.x + half_width, step_y), Color(gold.r, gold.g, gold.b, 0.70), 1.6, true)
		5:
			var gate_radius: float = radius * 0.90
			draw_polyline(
				PackedVector2Array([
					center + Vector2(-gate_radius, gate_radius),
					center + Vector2(-gate_radius, -gate_radius * 0.34),
					center + Vector2(gate_radius, -gate_radius * 0.34),
					center + Vector2(gate_radius, gate_radius)
				]),
				Color(gold.r, gold.g, gold.b, 0.80),
				1.9,
				true
			)
			draw_line(center + Vector2(-gate_radius * 1.12, -gate_radius * 0.38), center + Vector2(gate_radius * 1.12, -gate_radius * 0.38), Color(gold.r, gold.g, gold.b, 0.86), 2.0, true)
		_:
			draw_circle(center, radius * 0.08, Color(accent.r, accent.g, accent.b, 0.82))

	draw_line(Vector2(-2.0, size.y * 0.82), Vector2(size.x * 0.28, size.y * 0.44), Color(0.34, 0.045, 0.085, 0.74), 3.0, true)


func _draw_nine_heavens_mark(target_stage_id: int, accent: Color, gold: Color, ground: Color) -> void:
	var center := Vector2(size.x * 0.50, size.y * 0.57)
	var radius: float = minf(size.x, size.y) * 0.25

	match target_stage_id:
		1:
			var gate_points := PackedVector2Array([
				center + Vector2(-radius, radius * 0.72),
				center + Vector2(-radius, -radius * 0.42),
				center + Vector2(0.0, -radius),
				center + Vector2(radius, -radius * 0.42),
				center + Vector2(radius, radius * 0.72)
			])
			draw_polyline(gate_points, Color(accent.r, accent.g, accent.b, 0.86), 2.0, true)
			draw_line(center + Vector2(-radius * 1.12, -radius * 0.38), center + Vector2(radius * 1.12, -radius * 0.38), Color(gold.r, gold.g, gold.b, 0.86), 1.8, true)
		2:
			draw_circle(center, radius * 0.88, Color(accent.r, accent.g, accent.b, 0.10))
			draw_arc(center, radius * 0.88, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.84), 1.9, true)
			draw_circle(center + Vector2(radius * 0.24, -radius * 0.10), radius * 0.62, ground)
			draw_line(center + Vector2(-radius * 0.72, radius * 0.48), center + Vector2(radius * 0.66, -radius * 0.46), Color(gold.r, gold.g, gold.b, 0.80), 1.7, true)
		3:
			draw_arc(center, radius, 0.0, TAU, 36, Color(accent.r, accent.g, accent.b, 0.72), 1.8, true)
			var constellation: Array[Vector2] = [
				Vector2(-0.62, -0.18), Vector2(-0.22, -0.62), Vector2(0.34, -0.34),
				Vector2(0.62, 0.12), Vector2(0.12, 0.58), Vector2(-0.48, 0.42)
			]
			for star_index in range(constellation.size()):
				var star_point := center + constellation[star_index] * radius
				draw_circle(star_point, 2.0, Color(gold.r, gold.g, gold.b, 0.94))
				if star_index > 0:
					var previous_point := center + constellation[star_index - 1] * radius
					draw_line(previous_point, star_point, Color(accent.r, accent.g, accent.b, 0.64), 1.3, true)
		4:
			for step_index in range(5):
				var step_y: float = center.y + radius * 0.78 - float(step_index) * radius * 0.34
				var half_width: float = radius * 0.92 - float(step_index) * radius * 0.13
				draw_line(Vector2(center.x - half_width, step_y), Vector2(center.x + half_width, step_y), Color(gold.r, gold.g, gold.b, 0.80), 1.7, true)
			draw_line(center + Vector2(0.0, radius * 0.76), center + Vector2(0.0, -radius * 0.82), Color(accent.r, accent.g, accent.b, 0.60), 1.4, true)
		5:
			draw_arc(center, radius, 0.0, TAU, 40, Color(accent.r, accent.g, accent.b, 0.74), 1.8, true)
			for star_index in range(9):
				var angle: float = -PI * 0.5 + TAU * float(star_index) / 9.0
				var star_point := center + Vector2.RIGHT.rotated(angle) * radius * 0.72
				draw_circle(star_point, 1.9, Color(gold.r, gold.g, gold.b, 0.96))
			var throne_points := PackedVector2Array([
				center + Vector2(-radius * 0.42, radius * 0.52),
				center + Vector2(-radius * 0.34, -radius * 0.18),
				center + Vector2(0.0, -radius * 0.48),
				center + Vector2(radius * 0.34, -radius * 0.18),
				center + Vector2(radius * 0.42, radius * 0.52)
			])
			draw_polyline(throne_points, Color(gold.r, gold.g, gold.b, 0.86), 1.9, true)
		_:
			draw_arc(center, radius, 0.0, TAU, 36, Color(accent.r, accent.g, accent.b, 0.72), 1.8, true)

	for orbit_index in range(4):
		var orbit_angle: float = TAU * float(orbit_index) / 4.0
		var orbit_star := center + Vector2.RIGHT.rotated(orbit_angle) * radius * 0.50
		draw_circle(orbit_star, 1.6, Color(gold.r, gold.g, gold.b, 0.82))


func _draw_generic_realm_mark(accent: Color, gold: Color) -> void:
	var center := Vector2(size.x * 0.50, size.y * 0.56)
	var radius: float = minf(size.x, size.y) * 0.24
	draw_polyline(
		PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
			center + Vector2(0.0, -radius)
		]),
		Color(accent.r, accent.g, accent.b, 0.74),
		2.0,
		true
	)
	draw_circle(center, 3.0, Color(gold.r, gold.g, gold.b, 0.92))


func _draw_corner_marks(accent: Color, gold: Color) -> void:
	var inset: float = 6.0
	var length: float = minf(size.x, size.y) * 0.16
	var accent_color := Color(accent.r, accent.g, accent.b, 0.46)
	var gold_color := Color(gold.r, gold.g, gold.b, 0.42)
	draw_line(Vector2(inset, inset), Vector2(inset + length, inset), accent_color, 1.1, true)
	draw_line(Vector2(inset, inset), Vector2(inset, inset + length), accent_color, 1.1, true)
	draw_line(Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset - length, size.y - inset), gold_color, 1.1, true)
	draw_line(Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset, size.y - inset - length), gold_color, 1.1, true)


func _draw_stage_seal(accent: Color, gold: Color) -> void:
	var seal_center := Vector2(size.x * 0.16, size.y * 0.17)
	var seal_radius: float = minf(size.x, size.y) * 0.055
	draw_arc(seal_center, seal_radius, 0.0, TAU, 20, Color(gold.r, gold.g, gold.b, 0.30), 1.0, true)
	draw_line(seal_center + Vector2(-seal_radius * 0.62, 0.0), seal_center + Vector2(seal_radius * 0.62, 0.0), Color(accent.r, accent.g, accent.b, 0.32), 1.0, true)
	draw_circle(seal_center, 1.4, Color(gold.r, gold.g, gold.b, 0.60))


func _draw_boss_crown(gold: Color, accent: Color) -> void:
	var crown_center := Vector2(size.x * 0.50, size.y * 0.15)
	var crown_width: float = minf(size.x * 0.30, 30.0)
	var crown_height: float = 8.0
	var crown_points := PackedVector2Array([
		crown_center + Vector2(-crown_width * 0.5, crown_height * 0.45),
		crown_center + Vector2(-crown_width * 0.28, -crown_height * 0.5),
		crown_center + Vector2(0.0, crown_height * 0.08),
		crown_center + Vector2(crown_width * 0.28, -crown_height * 0.5),
		crown_center + Vector2(crown_width * 0.5, crown_height * 0.45)
	])
	draw_polyline(crown_points, Color(gold.r, gold.g, gold.b, 0.90), 1.7, true)
	draw_circle(crown_center + Vector2(0.0, 1.0), 1.9, Color(accent.r, accent.g, accent.b, 0.92))


func _fit_texture_rect(texture: Texture2D, bounds: Rect2) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return bounds

	var scale_value: float = minf(bounds.size.x / texture_size.x, bounds.size.y / texture_size.y)
	var target_size: Vector2 = texture_size * scale_value
	return Rect2(bounds.position + (bounds.size - target_size) * 0.5, target_size)
