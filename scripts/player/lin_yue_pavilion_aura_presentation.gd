extends Node2D
class_name LinYuePavilionAuraPresentation

## Single gameplay authority for Jade Pavilion cosmetic auras.
##
## Presentation only:
## - reads PavilionManager cosmetic state
## - no collision, damage, stats, cooldown, targeting, or save mutation
## - bounded CanvasItem drawing; no per-frame transient Nodes/particles
## - Reduced Effects keeps the cosmetic visible but freezes motion
##
## The player scene already positions this Node2D on Lin Yue's sprite anchor.
## BODY_CENTER shifts the visual mass slightly toward the actual body/feet so
## the aura reads centered around the character rather than around the atlas cell.

const CIRCLE_SEGMENTS: int = 48
const ELLIPSE_SEGMENTS: int = 44
const BODY_CENTER: Vector2 = Vector2(0.0, 5.0)
const GROUND_CENTER: Vector2 = Vector2(0.0, 31.0)

var aura_id: String = "plain"
var elapsed: float = 0.0
var reduced_effects: bool = false


func _ready() -> void:
	_refresh_from_managers()

	if not PavilionManager.pavilion_changed.is_connected(_on_pavilion_changed):
		PavilionManager.pavilion_changed.connect(_on_pavilion_changed)

	if not SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if PavilionManager.pavilion_changed.is_connected(_on_pavilion_changed):
		PavilionManager.pavilion_changed.disconnect(_on_pavilion_changed)

	if SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.disconnect(_on_settings_changed)


func _on_pavilion_changed() -> void:
	_refresh_from_managers()


func _on_settings_changed() -> void:
	_refresh_from_managers()


func _refresh_from_managers() -> void:
	aura_id = PavilionManager.get_cosmetic_id()
	reduced_effects = SettingsManager.reduced_effects

	# Wandering Cultivator / plain is intentionally the no-aura baseline.
	set_process(aura_id != "plain" and not reduced_effects)
	queue_redraw()

	DebugLogger.system(
		"Pavilion Aura Runtime: %s | Reduced Effects: %s"
		% [aura_id, str(reduced_effects)]
	)


func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, 1000.0)
	queue_redraw()


func _draw() -> void:
	match aura_id:
		"jade_aura":
			_draw_shrinekeeper_aura()
		"golden_aura":
			_draw_sovereign_aura()
		"astral_aura":
			_draw_astral_aura()
		"ascendant_aura":
			_draw_ascendant_aura()
		_:
			pass


func _phase(speed: float = 1.0) -> float:
	if reduced_effects:
		return 0.0
	return elapsed * speed


func _pulse(minimum: float, maximum: float, speed: float) -> float:
	if reduced_effects:
		return (minimum + maximum) * 0.5

	var wave: float = (sin(_phase(speed)) + 1.0) * 0.5
	return lerpf(minimum, maximum, wave)


func _ellipse_points(
	center: Vector2,
	radius_x: float,
	radius_y: float,
	angle_offset: float = 0.0
) -> PackedVector2Array:
	var points := PackedVector2Array()

	for index in range(ELLIPSE_SEGMENTS + 1):
		var angle: float = (
			TAU
			* float(index)
			/ float(ELLIPSE_SEGMENTS)
		)
		var point := Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		).rotated(angle_offset)
		points.append(center + point)

	return points


func _draw_soft_body_presence(
	primary: Color,
	secondary: Color,
	radius: float
) -> void:
	# Filled translucent layers sit behind the AnimatedSprite2D (aura z=2,
	# character z=3), adding visual mass without covering Lin Yue.
	var slow_pulse: float = _pulse(0.90, 1.04, 1.45)

	draw_circle(
		BODY_CENTER,
		radius * 1.12 * slow_pulse,
		Color(primary.r, primary.g, primary.b, 0.035)
	)
	draw_circle(
		BODY_CENTER,
		radius * 0.86 * slow_pulse,
		Color(secondary.r, secondary.g, secondary.b, 0.050)
	)
	draw_circle(
		BODY_CENTER,
		radius * 0.58,
		Color(primary.r, primary.g, primary.b, 0.065)
	)


func _draw_ground_sigil(
	main_color: Color,
	secondary_color: Color,
	radius_x: float,
	radius_y: float,
	angle_offset: float,
	spokes: int
) -> void:
	var alpha: float = _pulse(0.28, 0.46, 1.55)

	draw_polyline(
		_ellipse_points(
			GROUND_CENTER,
			radius_x,
			radius_y,
			angle_offset
		),
		Color(
			main_color.r,
			main_color.g,
			main_color.b,
			alpha
		),
		2.6,
		true
	)
	draw_polyline(
		_ellipse_points(
			GROUND_CENTER,
			radius_x * 0.72,
			radius_y * 0.72,
			-angle_offset
		),
		Color(
			secondary_color.r,
			secondary_color.g,
			secondary_color.b,
			alpha * 0.78
		),
		1.55,
		true
	)

	for index in range(spokes):
		var angle: float = (
			angle_offset
			+ float(index) * TAU / float(spokes)
		)
		var outer := Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		)
		var inner := outer * 0.55

		draw_line(
			GROUND_CENTER + inner,
			GROUND_CENTER + outer,
			Color(
				main_color.r,
				main_color.g,
				main_color.b,
				alpha * 0.72
			),
			1.25,
			true
		)


func _draw_orbit_diamond(
	center: Vector2,
	radial: Vector2,
	tangent: Vector2,
	size: float,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array([
		center + radial * size,
		center + tangent * size * 0.76,
		center - radial * size,
		center - tangent * size * 0.76,
		center + radial * size
	])
	draw_polyline(points, color, width, true)


func _draw_vertical_wisps(
	color: Color,
	count: int,
	base_radius: float,
	height: float,
	speed: float
) -> void:
	for index in range(count):
		var ratio: float = (
			float(index)
			/ float(maxi(count, 1))
		)
		var angle: float = ratio * TAU + _phase(speed)
		var base := (
			BODY_CENTER
			+ Vector2(
				cos(angle) * base_radius,
				16.0 + sin(angle) * 6.0
			)
		)
		var sway: float = (
			sin(_phase(1.7) + float(index) * 1.7)
			* 5.0
		)
		var top := Vector2(
			base.x + sway,
			base.y - height
		)
		var mid := (
			base.lerp(top, 0.52)
			+ Vector2(-sway * 0.36, 0.0)
		)

		draw_polyline(
			PackedVector2Array([base, mid, top]),
			color,
			1.35,
			true
		)


func _draw_cardinal_glints(
	color: Color,
	radius: float,
	angle_offset: float,
	count: int
) -> void:
	for index in range(count):
		var angle: float = (
			angle_offset
			+ float(index) * TAU / float(count)
		)
		var direction := Vector2.RIGHT.rotated(angle)
		var center := BODY_CENTER + direction * radius
		var tangent := direction.rotated(PI * 0.5)

		draw_line(
			center - direction * 3.8,
			center + direction * 3.8,
			color,
			1.45,
			true
		)
		draw_line(
			center - tangent * 2.6,
			center + tangent * 2.6,
			color,
			1.15,
			true
		)


func _draw_shrinekeeper_aura() -> void:
	var jade := Color(0.16, 1.0, 0.72, 0.92)
	var cyan := Color(0.34, 0.94, 1.0, 0.70)
	var pale := Color(0.84, 1.0, 0.94, 0.88)
	var rotation_offset: float = _phase(0.42)

	_draw_soft_body_presence(jade, cyan, 42.0)
	_draw_ground_sigil(
		jade,
		cyan,
		55.0,
		20.0,
		rotation_offset * 0.13,
		4
	)

	var outer_radius: float = _pulse(43.0, 46.0, 1.65)
	draw_arc(
		BODY_CENTER,
		outer_radius,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(jade.r, jade.g, jade.b, 0.76),
		3.6,
		true
	)
	draw_arc(
		BODY_CENTER,
		35.0,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(cyan.r, cyan.g, cyan.b, 0.48),
		2.0,
		true
	)
	draw_arc(
		BODY_CENTER,
		27.0,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(pale.r, pale.g, pale.b, 0.28),
		1.2,
		true
	)

	for index in range(4):
		var angle: float = (
			rotation_offset
			+ float(index) * PI * 0.5
		)
		var radial := Vector2.RIGHT.rotated(angle)
		var tangent := radial.rotated(PI * 0.5)
		var center := BODY_CENTER + radial * 42.0

		_draw_orbit_diamond(
			center,
			radial,
			tangent,
			5.0,
			Color(pale.r, pale.g, pale.b, 0.88),
			1.8
		)

	_draw_vertical_wisps(
		Color(jade.r, jade.g, jade.b, 0.36),
		6,
		38.0,
		48.0,
		0.14
	)


func _draw_sovereign_aura() -> void:
	var gold := Color(1.0, 0.73, 0.14, 0.98)
	var warm := Color(1.0, 0.94, 0.60, 0.88)
	var jade := Color(0.20, 0.92, 0.70, 0.48)
	var rotation_offset: float = _phase(0.25)

	_draw_soft_body_presence(gold, warm, 44.0)
	_draw_ground_sigil(
		gold,
		jade,
		59.0,
		21.0,
		-rotation_offset * 0.11,
		8
	)

	var halo_radius: float = _pulse(46.0, 49.0, 1.35)
	draw_arc(
		BODY_CENTER,
		halo_radius,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(gold.r, gold.g, gold.b, 0.86),
		4.0,
		true
	)
	draw_arc(
		BODY_CENTER,
		38.0,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(warm.r, warm.g, warm.b, 0.50),
		2.2,
		true
	)
	draw_arc(
		BODY_CENTER,
		29.0,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(jade.r, jade.g, jade.b, 0.30),
		1.4,
		true
	)

	for index in range(12):
		var angle: float = (
			rotation_offset
			+ float(index) * TAU / 12.0
		)
		var direction := Vector2.RIGHT.rotated(angle)
		var start := BODY_CENTER + direction * 51.0
		var length: float = 10.0 if index % 2 == 0 else 6.0

		draw_line(
			start,
			BODY_CENTER + direction * (51.0 + length),
			Color(
				warm.r,
				warm.g,
				warm.b,
				0.82 if index % 2 == 0 else 0.50
			),
			2.0,
			true
		)

	# Strong floating sovereign crown.
	var crown_y: float = (
		BODY_CENTER.y
		- 56.0
		+ sin(_phase(1.25))
		* (0.0 if reduced_effects else 1.8)
	)
	var crown_points := PackedVector2Array([
		Vector2(-15.0, crown_y + 2.0),
		Vector2(-10.0, crown_y - 6.0),
		Vector2(-4.0, crown_y - 1.0),
		Vector2(0.0, crown_y - 10.0),
		Vector2(5.0, crown_y - 1.0),
		Vector2(11.0, crown_y - 7.0),
		Vector2(15.0, crown_y + 2.0),
		Vector2(13.0, crown_y + 7.0),
		Vector2(-13.0, crown_y + 7.0),
		Vector2(-15.0, crown_y + 2.0)
	])
	draw_polyline(
		crown_points,
		Color(gold.r, gold.g, gold.b, 0.96),
		2.2,
		true
	)

	_draw_cardinal_glints(
		Color(warm.r, warm.g, warm.b, 0.78),
		57.0,
		-rotation_offset * 0.72,
		4
	)
	_draw_vertical_wisps(
		Color(gold.r, gold.g, gold.b, 0.30),
		7,
		42.0,
		55.0,
		-0.10
	)


func _draw_astral_aura() -> void:
	var violet := Color(0.69, 0.38, 1.0, 0.96)
	var blue := Color(0.28, 0.78, 1.0, 0.76)
	var star := Color(0.94, 0.86, 1.0, 0.94)
	var rotation_offset: float = _phase(0.31)

	_draw_soft_body_presence(violet, blue, 45.0)
	_draw_ground_sigil(
		violet,
		blue,
		60.0,
		21.0,
		rotation_offset * 0.12,
		6
	)

	var outer_radius: float = _pulse(47.0, 50.0, 1.2)
	draw_arc(
		BODY_CENTER,
		outer_radius,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(violet.r, violet.g, violet.b, 0.82),
		3.6,
		true
	)
	draw_arc(
		BODY_CENTER,
		39.0,
		PI * 0.05,
		PI * 1.90,
		38,
		Color(blue.r, blue.g, blue.b, 0.54),
		2.0,
		true
	)
	draw_arc(
		BODY_CENTER,
		30.0,
		PI * 0.26,
		PI * 1.68,
		30,
		Color(star.r, star.g, star.b, 0.32),
		1.3,
		true
	)

	var crescent_center := BODY_CENTER + Vector2(0.0, -37.0)
	draw_arc(
		crescent_center,
		18.0,
		-PI * 0.62,
		PI * 0.62,
		24,
		Color(star.r, star.g, star.b, 0.92),
		2.3,
		true
	)
	draw_arc(
		crescent_center + Vector2(6.0, 0.0),
		15.0,
		-PI * 0.64,
		PI * 0.60,
		24,
		Color(0.05, 0.03, 0.13, 0.88),
		3.8,
		true
	)

	for index in range(9):
		var angle: float = (
			rotation_offset
			+ float(index) * TAU / 9.0
		)
		var radius: float = (
			55.0 if index % 2 == 0 else 44.0
		)
		var point := BODY_CENTER + Vector2.RIGHT.rotated(angle) * radius
		var size: float = (
			3.2 if index % 2 == 0 else 2.0
		)
		var alpha: float = (
			0.90 if index % 2 == 0 else 0.62
		)

		draw_line(
			point + Vector2(-size, 0.0),
			point + Vector2(size, 0.0),
			Color(star.r, star.g, star.b, alpha),
			1.45,
			true
		)
		draw_line(
			point + Vector2(0.0, -size),
			point + Vector2(0.0, size),
			Color(star.r, star.g, star.b, alpha),
			1.45,
			true
		)

	_draw_vertical_wisps(
		Color(violet.r, violet.g, violet.b, 0.31),
		8,
		43.0,
		58.0,
		0.09
	)


func _draw_ascendant_aura() -> void:
	var cyan := Color(0.10, 0.96, 1.0, 0.98)
	var gold := Color(1.0, 0.78, 0.18, 0.98)
	var pale := Color(0.88, 1.0, 0.97, 0.92)
	var violet := Color(0.67, 0.48, 1.0, 0.52)
	var rotation_offset: float = _phase(0.34)

	_draw_soft_body_presence(cyan, gold, 49.0)
	_draw_ground_sigil(
		cyan,
		gold,
		65.0,
		23.0,
		-rotation_offset * 0.09,
		8
	)

	var outer_radius: float = _pulse(51.0, 55.0, 1.30)
	draw_arc(
		BODY_CENTER,
		outer_radius,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(gold.r, gold.g, gold.b, 0.88),
		4.2,
		true
	)
	draw_arc(
		BODY_CENTER,
		43.0,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(cyan.r, cyan.g, cyan.b, 0.82),
		3.2,
		true
	)
	draw_arc(
		BODY_CENTER,
		33.0,
		0.0,
		TAU,
		CIRCLE_SEGMENTS,
		Color(pale.r, pale.g, pale.b, 0.34),
		1.5,
		true
	)

	for index in range(8):
		var angle: float = (
			rotation_offset
			+ float(index) * TAU / 8.0
		)
		var radial := Vector2.RIGHT.rotated(angle)
		var tangent := radial.rotated(PI * 0.5)
		var point := BODY_CENTER + radial * 49.0
		var mote_color: Color = (
			gold if index % 2 == 0 else cyan
		)

		draw_circle(
			point,
			3.0 if index % 2 == 0 else 2.4,
			Color(
				mote_color.r,
				mote_color.g,
				mote_color.b,
				0.90
			)
		)

		if index % 2 == 0:
			_draw_orbit_diamond(
				point,
				radial,
				tangent,
				4.7,
				Color(pale.r, pale.g, pale.b, 0.76),
				1.5
			)

	for index in range(4):
		var angle: float = (
			-rotation_offset * 0.70
			+ PI * 0.25
			+ float(index) * PI * 0.5
		)
		var radial := Vector2.RIGHT.rotated(angle)
		var tangent := radial.rotated(PI * 0.5)
		var center := BODY_CENTER + radial * 59.0

		_draw_orbit_diamond(
			center,
			radial,
			tangent,
			5.3,
			Color(gold.r, gold.g, gold.b, 0.82),
			1.7
		)

	var crown_center := BODY_CENTER + Vector2(0.0, -59.0)
	draw_arc(
		crown_center,
		15.0,
		PI * 0.08,
		PI * 0.92,
		20,
		Color(gold.r, gold.g, gold.b, 0.98),
		2.6,
		true
	)
	draw_arc(
		crown_center + Vector2(0.0, 1.0),
		9.5,
		PI * 0.10,
		PI * 0.90,
		18,
		Color(cyan.r, cyan.g, cyan.b, 0.90),
		1.9,
		true
	)
	draw_circle(
		crown_center + Vector2(0.0, 2.0),
		2.7,
		Color(pale.r, pale.g, pale.b, 0.96)
	)

	_draw_vertical_wisps(
		Color(cyan.r, cyan.g, cyan.b, 0.38),
		9,
		47.0,
		63.0,
		0.10
	)
	_draw_vertical_wisps(
		Color(violet.r, violet.g, violet.b, 0.26),
		6,
		38.0,
		54.0,
		-0.07
	)

	var pillar_alpha: float = _pulse(0.32, 0.50, 1.65)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var x: float = BODY_CENTER.x + side * 56.0

		draw_line(
			Vector2(x, BODY_CENTER.y + 24.0),
			Vector2(
				x + side * 5.0,
				BODY_CENTER.y - 40.0
			),
			Color(
				cyan.r,
				cyan.g,
				cyan.b,
				pillar_alpha
			),
			2.0,
			true
		)
		draw_line(
			Vector2(
				x + side * 6.0,
				BODY_CENTER.y + 18.0
			),
			Vector2(
				x + side * 10.0,
				BODY_CENTER.y - 30.0
			),
			Color(
				gold.r,
				gold.g,
				gold.b,
				pillar_alpha * 0.82
			),
			1.4,
			true
		)
