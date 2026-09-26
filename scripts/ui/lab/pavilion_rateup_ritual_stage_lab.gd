extends Control

## Transparent ritual ornament used by the Pavilion redesign LAB.
## It intentionally does not paint an opaque background so the palace remains visible.

const GOLD: Color = Color(0.98, 0.76, 0.28, 1.0)
const JADE: Color = Color(0.22, 0.82, 0.72, 1.0)
const STAR_POINTS: Array[Vector2] = [
	Vector2(0.12, 0.20), Vector2(0.19, 0.42), Vector2(0.28, 0.14),
	Vector2(0.37, 0.31), Vector2(0.51, 0.10), Vector2(0.63, 0.27),
	Vector2(0.75, 0.15), Vector2(0.84, 0.39), Vector2(0.90, 0.22),
	Vector2(0.16, 0.70), Vector2(0.30, 0.82), Vector2(0.72, 0.84),
	Vector2(0.86, 0.68)
]

var _phase: float = 0.0
var _accent: Color = GOLD

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not SettingsManager.reduced_effects)
	queue_redraw()

func set_accent(next_accent: Color) -> void:
	_accent = next_accent
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.22, TAU)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var center: Vector2 = Vector2(size.x * 0.50, size.y * 0.60)
	var base_radius: float = minf(size.x, size.y) * 0.25
	var pulse: float = 0.5 + 0.5 * sin(_phase * 2.6)

	# Restrained altar glow.
	for glow_index in range(5):
		var glow_radius: float = base_radius * (0.72 + float(glow_index) * 0.24)
		var glow_alpha: float = 0.036 - float(glow_index) * 0.005
		draw_circle(center, glow_radius, Color(_accent.r, _accent.g, _accent.b, glow_alpha))

	# Celestial rings around the focal relic.
	for ring_index in range(5):
		var ring_radius: float = base_radius * (0.72 + float(ring_index) * 0.18)
		var direction: float = 1.0 if ring_index % 2 == 0 else -0.68
		var start_angle: float = _phase * direction + float(ring_index) * 0.48
		var ring_alpha: float = 0.28 - float(ring_index) * 0.033 + pulse * 0.025
		var ring_tint: Color = _accent if ring_index in [0, 3] else GOLD
		draw_arc(
			center,
			ring_radius,
			start_angle,
			start_angle + TAU * 0.73,
			72,
			Color(ring_tint.r, ring_tint.g, ring_tint.b, ring_alpha),
			1.8,
			true
		)

	# Meridian spokes and orbit seals.
	for spoke_index in range(8):
		var spoke_angle: float = TAU * float(spoke_index) / 8.0 + _phase * 0.08
		var direction_vec: Vector2 = Vector2(cos(spoke_angle), sin(spoke_angle))
		var inner: Vector2 = center + direction_vec * base_radius * 0.88
		var outer: Vector2 = center + direction_vec * base_radius * 1.16
		draw_line(inner, outer, Color(GOLD.r, GOLD.g, GOLD.b, 0.22), 1.0, true)
		_draw_diamond(outer, 3.8, Color(_accent.r, _accent.g, _accent.b, 0.44))

	for star_index in range(STAR_POINTS.size()):
		var point: Vector2 = STAR_POINTS[star_index]
		var star_position: Vector2 = Vector2(point.x * size.x, point.y * size.y)
		var star_tint: Color = GOLD if star_index % 4 == 0 else _accent
		draw_circle(star_position, 1.0 + float(star_index % 2), Color(star_tint.r, star_tint.g, star_tint.b, 0.15 + pulse * 0.04))

	# Dao dais.
	var dais_y: float = size.y * 0.84
	for dais_index in range(3):
		var half_width: float = size.x * (0.20 + float(dais_index) * 0.055)
		var y_pos: float = dais_y + float(dais_index) * 7.0
		draw_line(
			Vector2(center.x - half_width, y_pos),
			Vector2(center.x + half_width, y_pos),
			Color(GOLD.r, GOLD.g, GOLD.b, 0.56 - float(dais_index) * 0.12),
			1.5,
			true
		)

func _draw_diamond(center_point: Vector2, half_size: float, tint: Color) -> void:
	var polygon: PackedVector2Array = PackedVector2Array([
		center_point + Vector2(0.0, -half_size),
		center_point + Vector2(half_size, 0.0),
		center_point + Vector2(0.0, half_size),
		center_point + Vector2(-half_size, 0.0),
	])
	draw_colored_polygon(polygon, tint)
