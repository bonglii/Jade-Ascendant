extends Control

## Pavilion redesign LAB backdrop.
## Presentation-only: a lightweight procedural "summon palace" environment.
## No gameplay/economy state is read or written here.

var _phase: float = 0.0

const SKY_TOP: Color = Color(0.004, 0.010, 0.022, 1.0)
const SKY_BOTTOM: Color = Color(0.012, 0.042, 0.060, 1.0)
const GOLD: Color = Color(0.98, 0.78, 0.30, 1.0)
const JADE: Color = Color(0.25, 0.82, 0.72, 1.0)
const SIDE_SIGNS: Array[float] = [-1.0, 1.0]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not SettingsManager.reduced_effects)
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.13, TAU)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	_draw_sky()
	_draw_moon()
	_draw_distant_palace()
	_draw_architecture()
	_draw_floor()
	_draw_motes()

func _draw_sky() -> void:
	var bands: int = 14
	for i in range(bands):
		var t: float = float(i) / float(bands - 1)
		var tint: Color = SKY_TOP.lerp(SKY_BOTTOM, t)
		var y_pos: float = size.y * t
		var band_height: float = size.y / float(bands) + 1.0
		draw_rect(Rect2(0.0, y_pos, size.x, band_height), tint)

	# Gentle jade haze behind the central ritual axis.
	for ring in range(4):
		var radius: float = minf(size.x, size.y) * (0.22 + float(ring) * 0.10)
		draw_circle(
			Vector2(size.x * 0.50, size.y * 0.39),
			radius,
			Color(JADE.r, JADE.g, JADE.b, 0.020 - float(ring) * 0.003)
		)

func _draw_moon() -> void:
	var moon_center: Vector2 = Vector2(size.x * 0.73, size.y * 0.17)
	var moon_radius: float = minf(size.x, size.y) * 0.105
	draw_circle(moon_center, moon_radius * 1.32, Color(1.0, 0.80, 0.38, 0.018))
	draw_circle(moon_center, moon_radius, Color(0.95, 0.85, 0.64, 0.075))
	draw_arc(
		moon_center,
		moon_radius * 1.08,
		0.0,
		TAU,
		96,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.08),
		1.0,
		true
	)

func _draw_distant_palace() -> void:
	var horizon: float = size.y * 0.42
	var center_x: float = size.x * 0.50
	var mist: Color = Color(0.16, 0.42, 0.43, 0.09)

	for layer in range(3):
		var y_pos: float = horizon + float(layer) * 34.0
		var palace_width: float = size.x * (0.38 - float(layer) * 0.055)
		var tint: Color = Color(0.03, 0.10, 0.13, 0.34 - float(layer) * 0.06)
		draw_rect(
			Rect2(center_x - palace_width * 0.5, y_pos, palace_width, 16.0),	
			tint
		)
		var roof: PackedVector2Array = PackedVector2Array([
			Vector2(center_x - palace_width * 0.58, y_pos),
			Vector2(center_x, y_pos - 28.0 - float(layer) * 4.0),
			Vector2(center_x + palace_width * 0.58, y_pos),
		])
		draw_colored_polygon(roof, tint)

	# Side towers in mist, intentionally low-contrast.
	for side_sign in SIDE_SIGNS:
		for idx in range(3):
			var x_pos: float = (
				center_x
				+ side_sign * (size.x * (0.18 + 0.105 * float(idx)))
			)
			var y_pos: float = horizon + 28.0 + float(idx % 2) * 12.0
			var tower_height: float = 70.0 - float(idx) * 7.0
			draw_rect(
				Rect2(x_pos - 10.0, y_pos - tower_height, 20.0, tower_height),
				Color(0.025, 0.075, 0.095, 0.26)
			)
			var roof: PackedVector2Array = PackedVector2Array([
				Vector2(x_pos - 22.0, y_pos - tower_height),
				Vector2(x_pos, y_pos - tower_height - 13.0),
				Vector2(x_pos + 22.0, y_pos - tower_height),
			])
			draw_colored_polygon(roof, Color(0.025, 0.075, 0.095, 0.30))

	for i in range(5):
		var cloud_y: float = horizon + 18.0 + float(i) * 16.0
		draw_arc(
			Vector2(center_x, cloud_y),
			size.x * (0.20 + float(i) * 0.045),
			PI * 1.05,
			PI * 1.95,
			48,
			mist,
			1.3,
			true
		)

func _draw_architecture() -> void:
	var column_color: Color = Color(0.014, 0.032, 0.044, 0.92)
	var edge: Color = Color(GOLD.r, GOLD.g, GOLD.b, 0.17)
	var inset: float = size.x * 0.035
	var column_width: float = maxf(20.0, size.x * 0.055)

	for side_index in range(2):
		var x_pos: float = (
			inset
			if side_index == 0
			else size.x - inset - column_width
		)
		draw_rect(Rect2(x_pos, 0.0, column_width, size.y), column_color)
		draw_line(Vector2(x_pos, 0.0), Vector2(x_pos, size.y), edge, 1.0)
		draw_line(
			Vector2(x_pos + column_width, 0.0),
			Vector2(x_pos + column_width, size.y),
			edge,
			1.0
		)

		var band_positions: Array[float] = [
			size.y * 0.18,
			size.y * 0.42,
			size.y * 0.68,
		]
		for y_pos in band_positions:
			draw_rect(
				Rect2(x_pos - 7.0, y_pos, column_width + 14.0, 7.0),
				Color(GOLD.r, GOLD.g, GOLD.b, 0.11)
			)

	# Giant ceremonial arch framing the summon zone.
	var center: Vector2 = Vector2(size.x * 0.50, size.y * 0.34)
	for ring in range(3):
		var radius: float = size.x * (0.43 - float(ring) * 0.025)
		var ring_alpha: float = 0.14 - float(ring) * 0.025
		var ring_width: float = 2.0 - float(ring) * 0.35
		draw_arc(
			center,
			radius,
			PI * 1.05,
			PI * 1.95,
			100,
			Color(GOLD.r, GOLD.g, GOLD.b, ring_alpha),
			ring_width,
			true
		)

	# Hanging standards.
	for side_sign in SIDE_SIGNS:
		var x_pos: float = center.x + side_sign * size.x * 0.34
		draw_line(
			Vector2(x_pos, size.y * 0.12),
			Vector2(x_pos, size.y * 0.31),
			Color(GOLD.r, GOLD.g, GOLD.b, 0.20),
			1.0
		)
		draw_rect(
			Rect2(x_pos - 8.0, size.y * 0.18, 16.0, size.y * 0.10),
			Color(0.02, 0.15, 0.16, 0.35)
		)

func _draw_floor() -> void:
	var floor_top: float = size.y * 0.57
	draw_rect(
		Rect2(0.0, floor_top, size.x, size.y - floor_top),
		Color(0.002, 0.012, 0.018, 0.45)
	)

	var center_x: float = size.x * 0.50
	for i in range(9):
		var t: float = float(i) / 8.0
		var x_pos: float = lerpf(size.x * 0.08, size.x * 0.92, t)
		draw_line(
			Vector2(center_x, floor_top),
			Vector2(x_pos, size.y),
			Color(GOLD.r, GOLD.g, GOLD.b, 0.055),
			1.0
		)

	for row in range(6):
		var t: float = float(row) / 5.0
		var y_pos: float = lerpf(floor_top, size.y, pow(t, 1.55))
		draw_line(
			Vector2(0.0, y_pos),
			Vector2(size.x, y_pos),
			Color(JADE.r, JADE.g, JADE.b, 0.035),
			1.0
		)

	# Central ritual reflection.
	for ring in range(4):
		var radius: float = size.x * (0.16 + float(ring) * 0.045)
		draw_arc(
			Vector2(center_x, floor_top + 40.0),
			radius,
			0.0,
			TAU,
			64,
			Color(GOLD.r, GOLD.g, GOLD.b, 0.10 - float(ring) * 0.018),
			1.2,
			true
		)

func _draw_motes() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_phase * 2.0)
	for i in range(20):
		var fx: float = fmod(float(i * 73 + 19), 997.0) / 997.0
		var fy: float = fmod(float(i * 131 + 53), 991.0) / 991.0
		var mote_position: Vector2 = Vector2(fx * size.x, fy * size.y)
		var tint: Color = GOLD if i % 4 == 0 else JADE
		draw_circle(
			mote_position,
			1.0 + float(i % 3) * 0.45,
			Color(tint.r, tint.g, tint.b, 0.08 + pulse * 0.025)
		)
