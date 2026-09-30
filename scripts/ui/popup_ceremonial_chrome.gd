extends Control

## Pure CanvasItem ornamentation for the three end-of-run modal surfaces.
## No timers, processing, collision, save state, gameplay input, or reward logic.
## The hosting PanelContainer owns geometry and typography; this only draws.

var motif: String = "victory"
var main_ink: Color = Color(0.94, 0.75, 0.37, 1.0)
var secondary_ink: Color = Color(0.24, 0.78, 0.66, 1.0)


func configure(kind: String) -> void:
	motif = kind
	match motif:
		"defeat", "recovery":
			main_ink = Color(0.93, 0.46, 0.34, 1.0)
			secondary_ink = Color(0.98, 0.69, 0.37, 1.0)
		"warning", "warning_crest":
			main_ink = Color(1.0, 0.74, 0.36, 1.0)
			secondary_ink = Color(0.96, 0.37, 0.27, 1.0)
		"reward":
			main_ink = Color(0.97, 0.76, 0.34, 1.0)
			secondary_ink = Color(0.26, 0.83, 0.68, 1.0)
		_:
			main_ink = Color(0.97, 0.77, 0.39, 1.0)
			secondary_ink = Color(0.29, 0.84, 0.73, 1.0)
	if is_inside_tree():
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var frame_width: float = size.x
	var frame_height: float = size.y
	if frame_width < 24.0 or frame_height < 24.0:
		return
	match motif:
		"warning_crest":
			_draw_warning_crest(frame_width, frame_height)
		"reward", "recovery":
			_draw_reward_engraving(frame_width, frame_height)
		_:
			_draw_modal_engraving(frame_width, frame_height)


func _draw_modal_engraving(frame_width: float, frame_height: float) -> void:
	var is_victory: bool = motif == "victory"
	var is_warning: bool = motif == "warning"
	var ornament_color: Color = main_ink
	var side_color: Color = secondary_ink

	# Several static, translucent plates add material depth without shaders.
	var glow_center := Vector2(frame_width * 0.5, 130.0 if not is_warning else 94.0)
	for ring_index: int in range(8, 0, -1):
		var radius: float = float(ring_index) * 24.0
		var alpha: float = (0.008 if is_victory else 0.0055) + float(9 - ring_index) * 0.002
		draw_circle(
			glow_center,
			radius,
			Color(side_color.r, side_color.g, side_color.b, alpha)
		)

	# Inner bezel: the existing StyleBox is the outer polished metal frame.
	var frame_inner := Rect2(
			Vector2(11.0, 11.0),
			Vector2(frame_width - 22.0, frame_height - 22.0)
	)
	draw_rect(
		frame_inner,
		Color(ornament_color.r, ornament_color.g, ornament_color.b, 0.25),
		false,
		1.0,
		true
	)
	var second_inner := Rect2(
			Vector2(16.0, 16.0),
			Vector2(frame_width - 32.0, frame_height - 32.0)
	)
	draw_rect(
		second_inner,
		Color(side_color.r, side_color.g, side_color.b, 0.12),
		false,
		1.0,
		true
	)

	# Engraved L-shaped corner fittings and their triangular cut gemstones.
	for side_index: int in range(2):
		var direction: float = 1.0 if side_index == 0 else -1.0
		var anchor_x: float = 22.0 if side_index == 0 else frame_width - 22.0
		var corner_ink := Color(
			ornament_color.r, ornament_color.g, ornament_color.b, 0.85
		)
		var corner_shadow := Color(
			side_color.r, side_color.g, side_color.b, 0.39
		)
		draw_line(
			Vector2(anchor_x, 25.0),
			Vector2(anchor_x + direction * 64.0, 25.0),
			corner_ink, 2.3, true
		)
		draw_line(
			Vector2(anchor_x, 25.0),
			Vector2(anchor_x, 99.0),
			corner_shadow, 1.8, true
		)
		draw_line(
			Vector2(anchor_x, frame_height - 25.0),
			Vector2(anchor_x + direction * 64.0, frame_height - 25.0),
			corner_ink, 2.3, true
		)
		draw_line(
			Vector2(anchor_x, frame_height - 25.0),
			Vector2(anchor_x, frame_height - 99.0),
			corner_shadow, 1.8, true
		)
		_draw_diamond(
			Vector2(anchor_x + direction * 73.0, 25.0),
			4.0,
			Color(side_color.r, side_color.g, side_color.b, 0.80)
		)
		_draw_diamond(
			Vector2(anchor_x + direction * 73.0, frame_height - 25.0),
			4.0,
			Color(side_color.r, side_color.g, side_color.b, 0.80)
		)

	# Subtle vertical inscriptions: reminiscent of carved sect/gate borders.
	var rail_alpha: float = 0.20 if is_victory else 0.23
	draw_line(
		Vector2(22.0, 125.0), Vector2(22.0, frame_height - 126.0),
		Color(side_color.r, side_color.g, side_color.b, rail_alpha), 1.0, true
	)
	draw_line(
		Vector2(frame_width - 22.0, 125.0),
		Vector2(frame_width - 22.0, frame_height - 126.0),
		Color(side_color.r, side_color.g, side_color.b, rail_alpha), 1.0, true
	)

	if is_warning:
		_draw_warning_streaks(frame_width, frame_height)
	else:
		_draw_medallion_aura(frame_width, is_victory)

	# Signed central base medallion, restrained so that button remains focal.
	var lower_center := Vector2(frame_width * 0.5, frame_height - 24.0)
	_draw_diamond(lower_center, 6.0, ornament_color)
	for segment: int in range(2):
		var offset: float = 18.0 + float(segment) * 9.0
		draw_line(
			lower_center + Vector2(-offset - 31.0, 0.0),
			lower_center + Vector2(-offset, 0.0),
			Color(side_color.r, side_color.g, side_color.b, 0.45),
			1.3, true
		)
		draw_line(
			lower_center + Vector2(offset, 0.0),
			lower_center + Vector2(offset + 31.0, 0.0),
			Color(side_color.r, side_color.g, side_color.b, 0.45),
			1.3, true
		)


func _draw_medallion_aura(frame_width: float, is_victory: bool) -> void:
	var orbit_center := Vector2(frame_width * 0.5, 132.0)
	var ring_color := secondary_ink
	var luminance: float = 0.43 if is_victory else 0.29
	for layer_index: int in range(3):
		var ring_radius: float = 61.0 + float(layer_index) * 15.0
		var start_angle: float = 0.16 + float(layer_index) * 0.47
		draw_arc(
			orbit_center, ring_radius,
			start_angle, start_angle + PI * 1.42,
			64,
			Color(ring_color.r, ring_color.g, ring_color.b,
				luminance / float(layer_index + 1)),
			1.3, true
		)
	if not is_victory:
		# Split the outer ring to distinguish a broken dao seal from Victory.
		draw_line(
			orbit_center + Vector2(-52.0, -63.0),
			orbit_center + Vector2(-29.0, -84.0),
			Color(0.97, 0.49, 0.33, 0.56), 1.8, true
		)
		draw_line(
			orbit_center + Vector2(-29.0, -84.0),
			orbit_center + Vector2(-35.0, -49.0),
			Color(0.97, 0.49, 0.33, 0.54), 1.8, true
		)
	else:
		# Triangular qi rays give the ascension seal a star-like corona.
		for ray_index: int in range(10):
			var angle: float = float(ray_index) * TAU / 10.0
			var direction := Vector2(cos(angle), sin(angle))
			draw_line(
				orbit_center + direction * 85.0,
				orbit_center + direction * 96.0,
				Color(1.0, 0.79, 0.39, 0.33), 1.0, true
			)


func _draw_warning_streaks(frame_width: float, frame_height: float) -> void:
	var left_x: float = frame_width * 0.5 - 128.0
	var right_x: float = frame_width * 0.5 + 128.0
	var line_color := Color(0.98, 0.50, 0.35, 0.28)
	draw_line(Vector2(30.0, 135.0), Vector2(left_x, 135.0), line_color, 1.3, true)
	draw_line(Vector2(right_x, 135.0), Vector2(frame_width - 30.0, 135.0), line_color, 1.3, true)
	for detail_index: int in range(3):
		var y_coord: float = frame_height - 60.0 - float(detail_index) * 12.0
		draw_line(
			Vector2(24.0, y_coord),
			Vector2(42.0, y_coord - 11.0),
			Color(0.97, 0.48, 0.35, 0.17), 1.2, true
		)
		draw_line(
			Vector2(frame_width - 24.0, y_coord),
			Vector2(frame_width - 42.0, y_coord - 11.0),
			Color(0.97, 0.48, 0.35, 0.17), 1.2, true
		)


func _draw_reward_engraving(frame_width: float, frame_height: float) -> void:
	var outer := Rect2(Vector2(8.0, 8.0), Vector2(frame_width - 16.0, frame_height - 16.0))
	draw_rect(outer, Color(main_ink.r, main_ink.g, main_ink.b, 0.36), false, 1.0, true)
	draw_line(
		Vector2(28.0, 13.0), Vector2(frame_width - 28.0, 13.0),
		Color(secondary_ink.r, secondary_ink.g, secondary_ink.b, 0.21), 1.0, true
	)
	for side_index: int in range(2):
		var left_side: bool = side_index == 0
		var emblem_x: float = 20.0 if left_side else frame_width - 20.0
		_draw_diamond(
			Vector2(emblem_x, frame_height * 0.5),
			5.5,
			Color(main_ink.r, main_ink.g, main_ink.b, 0.38)
		)


func _draw_warning_crest(frame_width: float, frame_height: float) -> void:
	# Oath-seal focal artwork: a fractured jade ward inside a ceremonial
	# six-sided metal mount. Entirely static and invisible to input handling.
	var seal_center := Vector2(frame_width * 0.5, frame_height * 0.50)
	var gold_ink := Color(1.0, 0.80, 0.43, 0.93)
	var ember_ink := Color(1.0, 0.46, 0.32, 0.89)
	var jade_ink := Color(0.27, 0.80, 0.67, 0.92)

	for n: int in range(6, 0, -1):
		var aura_radius: float = 40.0 + float(n) * 7.0
		draw_circle(
			seal_center, aura_radius,
			Color(0.80, 0.20, 0.12, (7.0 - float(n)) * 0.007)
		)

	# Floating lacquered seal and discontinuous bronze halo.
	draw_circle(seal_center, 49.0, Color(0.09, 0.026, 0.025, 0.96))
	for segment: int in range(4):
		var beginning: float = float(segment) * TAU / 4.0 + 0.13
		draw_arc(
			seal_center, 49.0, beginning, beginning + 1.24,
			32, gold_ink, 2.7, true
		)
		draw_arc(
			seal_center, 54.0, beginning + 0.16, beginning + 0.76,
			24, Color(ember_ink.r, ember_ink.g, ember_ink.b, 0.43), 1.0, true
		)
	var facets := PackedVector2Array()
	for vertex_index: int in range(6):
		var angle: float = float(vertex_index) * TAU / 6.0 - PI * 0.5
		facets.append(seal_center + Vector2(cos(angle), sin(angle)) * 38.0)
	for edge: int in range(6):
		draw_line(
			facets[edge], facets[(edge + 1) % 6],
			Color(gold_ink.r, gold_ink.g, gold_ink.b, 0.56), 1.6, true
		)

	# Suspended jade tablet, broken down the middle.
	var jade_plate := PackedVector2Array([
		seal_center + Vector2(0.0, -27.0),
		seal_center + Vector2(23.0, -6.0),
		seal_center + Vector2(16.0, 28.0),
		seal_center + Vector2(-16.0, 28.0),
		seal_center + Vector2(-23.0, -6.0),
	])
	draw_colored_polygon(jade_plate, Color(0.055, 0.23, 0.21, 0.94))
	for edge: int in range(jade_plate.size()):
		draw_line(
			jade_plate[edge], jade_plate[(edge + 1) % jade_plate.size()],
			Color(jade_ink.r, jade_ink.g, jade_ink.b, 0.78), 2.1, true
		)
	draw_line(
		seal_center + Vector2(-6.0, -25.0),
		seal_center + Vector2(6.0, -1.0),
		Color(1.0, 0.89, 0.65, 0.92), 3.2, true
	)
	draw_line(
		seal_center + Vector2(6.0, -1.0),
		seal_center + Vector2(-9.0, 12.0),
		Color(1.0, 0.89, 0.65, 0.92), 3.2, true
	)
	draw_line(
		seal_center + Vector2(-9.0, 12.0),
		seal_center + Vector2(4.0, 26.0),
		Color(1.0, 0.89, 0.65, 0.92), 3.2, true
	)
	_draw_diamond(
		seal_center + Vector2(0.0, 42.0), 3.0, ember_ink
	)

	# Symmetrical sect filigree directs the eye into the seal without creating
	# fake buttons or anything that could intercept a mobile touch.
	for side: int in range(2):
		var direction: float = -1.0 if side == 0 else 1.0
		var start_x: float = frame_width * 0.5 + direction * 63.0
		var finish_x: float = frame_width * 0.5 + direction * 170.0
		draw_line(
			Vector2(start_x, seal_center.y),
			Vector2(finish_x, seal_center.y),
			Color(gold_ink.r, gold_ink.g, gold_ink.b, 0.65), 1.5, true
		)
		draw_line(
			Vector2(start_x + direction * 17.0, seal_center.y - 10.0),
			Vector2(finish_x - direction * 18.0, seal_center.y - 10.0),
			Color(ember_ink.r, ember_ink.g, ember_ink.b, 0.38), 1.2, true
		)
		draw_line(
			Vector2(start_x + direction * 17.0, seal_center.y + 10.0),
			Vector2(finish_x - direction * 18.0, seal_center.y + 10.0),
			Color(ember_ink.r, ember_ink.g, ember_ink.b, 0.38), 1.2, true
		)
		_draw_diamond(
			Vector2(finish_x, seal_center.y), 5.0,
			Color(1.0, 0.69, 0.39, 0.80)
		)
		_draw_diamond(
			Vector2(start_x + direction * 38.0, seal_center.y),
			2.2, jade_ink
		)


func _draw_diamond(center_point: Vector2, radius: float, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center_point + Vector2(0.0, -radius),
		center_point + Vector2(radius, 0.0),
		center_point + Vector2(0.0, radius),
		center_point + Vector2(-radius, 0.0),
	]), tint)
