extends Control

## Premium presentation-only Celestial Armory stage.
## Economy state remains owned by PavilionManager. This control only renders
## deterministic ornament, depth and motion without spawning particles/nodes.

var accent: Color = Color(0.72, 0.48, 0.96, 1.0)
var secondary: Color = Color(0.98, 0.78, 0.30, 1.0)
var active: bool = true
var fate_active: bool = false
var _phase: float = 0.0

const STAR_POINTS: Array[Vector2] = [
	Vector2(0.07, 0.16), Vector2(0.12, 0.41), Vector2(0.18, 0.26),
	Vector2(0.25, 0.09), Vector2(0.31, 0.36), Vector2(0.39, 0.18),
	Vector2(0.48, 0.08), Vector2(0.57, 0.19), Vector2(0.66, 0.11),
	Vector2(0.74, 0.34), Vector2(0.82, 0.17), Vector2(0.90, 0.29),
	Vector2(0.94, 0.55), Vector2(0.08, 0.67), Vector2(0.17, 0.82),
	Vector2(0.31, 0.91), Vector2(0.69, 0.88), Vector2(0.86, 0.77)
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not SettingsManager.reduced_effects)
	queue_redraw()

func configure(next_accent: Color, next_secondary: Color, is_active: bool, has_fate: bool) -> void:
	accent = next_accent
	secondary = next_secondary
	active = is_active
	fate_active = has_fate
	set_process(active and not SettingsManager.reduced_effects)
	queue_redraw()

func _process(delta: float) -> void:
	var speed: float = 0.24 if fate_active else 0.15
	_phase = fmod(_phase + delta * speed, TAU)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var center := Vector2(size.x * 0.50, size.y * 0.46)
	var base_radius: float = minf(size.x, size.y) * 0.255
	var active_gain: float = 1.0 if active else 0.42
	var pulse: float = 0.5 + 0.5 * sin(_phase * 3.0)

	# Layered obsidian void with restrained celestial shafts. The old wide
	# nested rectangles accumulated into two opaque gold slabs on narrow mobile
	# viewports, obscuring the featured relic. These shafts frame the relic instead.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.001, 0.005, 0.014, 1.0))
	var beam_height: float = size.y * 0.76
	var beam_offset: float = base_radius * 0.48
	for beam_side: float in [-1.0, 1.0]:
		var beam_x: float = center.x + beam_side * beam_offset
		draw_rect(
			Rect2(Vector2(beam_x - 7.0, 0.0), Vector2(14.0, beam_height)),
			Color(secondary.r, secondary.g, secondary.b, 0.018 * active_gain)
		)
		draw_rect(
			Rect2(Vector2(beam_x - 2.0, 0.0), Vector2(4.0, beam_height)),
			Color(secondary.r, secondary.g, secondary.b, 0.060 * active_gain)
		)
	draw_rect(
		Rect2(Vector2(center.x - 3.0, 0.0), Vector2(6.0, beam_height * 0.90)),
		Color(accent.r, accent.g, accent.b, 0.020 * active_gain)
	)
	draw_circle(center, base_radius * 1.90, Color(accent.r * 0.035, accent.g * 0.035, accent.b * 0.035, 0.88))
	draw_circle(center, base_radius * 1.48, Color(secondary.r * 0.030, secondary.g * 0.030, secondary.b * 0.030, 0.66))

	# Star dust: bounded and deterministic for mobile.
	for star_index: int in range(STAR_POINTS.size()):
		var point := STAR_POINTS[star_index]
		var star_point := Vector2(point.x * size.x, point.y * size.y)
		var star_color: Color = secondary if star_index % 5 == 0 else accent
		var star_alpha: float = (0.20 + float(star_index % 4) * 0.055 + pulse * 0.04) * active_gain
		draw_circle(star_point, 1.0 + float(star_index % 3) * 0.58, Color(star_color.r, star_color.g, star_color.b, star_alpha))

	# Six counter-rotating Dao rings with gold break-lines.
	for ring_index: int in range(6):
		var ring_radius: float = base_radius * (0.58 + float(ring_index) * 0.16)
		var direction: float = 1.0 if ring_index % 2 == 0 else -0.68
		var angle_start: float = _phase * direction + float(ring_index) * 0.43
		var ring_color: Color = secondary if ring_index in [1, 4] else accent
		var ring_alpha: float = (0.19 - float(ring_index) * 0.014 + pulse * 0.025) * active_gain
		draw_arc(center, ring_radius, angle_start, angle_start + TAU * 0.70, 84, Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha), 2.0, true)
		draw_arc(center, ring_radius, angle_start + PI, angle_start + PI + TAU * 0.12, 20, Color(secondary.r, secondary.g, secondary.b, ring_alpha * 0.92), 1.0, true)

	# Twelve celestial seals orbit the relic like a refined Bagua-array language.
	for rune_index: int in range(12):
		var rune_angle: float = -_phase * 0.34 + TAU * float(rune_index) / 12.0
		var rune_center := center + Vector2(cos(rune_angle), sin(rune_angle)) * base_radius * 1.31
		var rune_size: float = 3.8 if rune_index % 3 else 5.0
		_draw_diamond(rune_center, rune_size, Color(secondary.r, secondary.g, secondary.b, (0.30 + pulse * 0.09) * active_gain))

	# Eight meridian spokes, with a doubled gold marker at cardinal points.
	for spoke_index: int in range(8):
		var spoke_angle: float = _phase * 0.10 + TAU * float(spoke_index) / 8.0
		var spoke_dir := Vector2(cos(spoke_angle), sin(spoke_angle))
		var inner_point := center + spoke_dir * base_radius * 0.96
		var outer_point := center + spoke_dir * base_radius * (1.14 + 0.05 * float(spoke_index % 2))
		draw_line(inner_point, outer_point, Color(secondary.r, secondary.g, secondary.b, 0.30 * active_gain), 1.2, true)
		if spoke_index % 2 == 0:
			var tangent := Vector2(-spoke_dir.y, spoke_dir.x) * 4.0
			draw_line(outer_point - tangent, outer_point + tangent, Color(accent.r, accent.g, accent.b, 0.28 * active_gain), 1.0, true)

	# Ceremonial dais and cloud-like horizon keep the featured relic grounded.
	var dais_y: float = size.y * 0.78
	var dais_half: float = size.x * 0.26
	draw_line(Vector2(center.x - dais_half, dais_y), Vector2(center.x + dais_half, dais_y), Color(secondary.r, secondary.g, secondary.b, 0.66 * active_gain), 2.0, true)
	draw_line(Vector2(center.x - dais_half * 0.72, dais_y + 9.0), Vector2(center.x + dais_half * 0.72, dais_y + 9.0), Color(accent.r, accent.g, accent.b, 0.36 * active_gain), 1.0, true)
	for cloud_index: int in range(3):
		var cloud_radius: float = 34.0 + float(cloud_index) * 16.0
		var cloud_alpha: float = (0.12 - float(cloud_index) * 0.02) * active_gain
		draw_arc(Vector2(center.x, dais_y + 18.0), cloud_radius, PI * 1.05, PI * 1.95, 28, Color(accent.r, accent.g, accent.b, cloud_alpha), 1.2, true)

	_draw_corner_brackets(active_gain)

	if fate_active:
		# Wish Fate gets a prestigious gold crown and four cardinal stars.
		var crown_y: float = center.y - base_radius * 1.46
		var crown_half: float = base_radius * 0.55
		draw_line(Vector2(center.x - crown_half, crown_y + 18.0), Vector2(center.x, crown_y - 9.0), Color(secondary.r, secondary.g, secondary.b, 0.95), 2.4, true)
		draw_line(Vector2(center.x, crown_y - 9.0), Vector2(center.x + crown_half, crown_y + 18.0), Color(secondary.r, secondary.g, secondary.b, 0.95), 2.4, true)
		for cardinal_index: int in range(4):
			var cardinal_angle: float = PI * 0.25 + TAU * float(cardinal_index) / 4.0
			var cardinal_point := center + Vector2(cos(cardinal_angle), sin(cardinal_angle)) * base_radius * 1.55
			_draw_diamond(cardinal_point, 6.0 + pulse * 1.8, Color(secondary.r, secondary.g, secondary.b, 0.82))

func _draw_diamond(center_point: Vector2, half_size: float, tint: Color) -> void:
	var polygon := PackedVector2Array([
		center_point + Vector2(0.0, -half_size),
		center_point + Vector2(half_size, 0.0),
		center_point + Vector2(0.0, half_size),
		center_point + Vector2(-half_size, 0.0)
	])
	draw_colored_polygon(polygon, tint)

func _draw_corner_brackets(gain: float) -> void:
	var inset: float = 12.0
	var arm: float = 28.0
	var tint := Color(secondary.r, secondary.g, secondary.b, 0.48 * gain)
	var points: Array[Vector2] = [
		Vector2(inset, inset), Vector2(size.x - inset, inset),
		Vector2(inset, size.y - inset), Vector2(size.x - inset, size.y - inset)
	]
	for corner_index: int in range(points.size()):
		var corner := points[corner_index]
		var horizontal_sign: float = 1.0 if corner_index in [0, 2] else -1.0
		var vertical_sign: float = 1.0 if corner_index in [0, 1] else -1.0
		draw_line(corner, corner + Vector2(arm * horizontal_sign, 0.0), tint, 1.5, true)
		draw_line(corner, corner + Vector2(0.0, arm * vertical_sign), tint, 1.5, true)
