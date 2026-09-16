extends Control

## Premium presentation-only summon reveal field.
## The Pavilion screen owns the resolved summon result. This control renders
## anticipation, rarity omens and the celestial impact without gameplay state.

var accent: Color = Color(0.28, 0.95, 0.78, 1.0)
var secondary: Color = Color(0.98, 0.78, 0.30, 1.0)
var rarity: String = "common"
var revealed: bool = false
var omen_active: bool = false
var _phase: float = 0.0
var _burst: float = 0.0
var _omen_elapsed: float = 0.0
var _impact_elapsed: float = 0.0

const STAR_POINTS: Array[Vector2] = [
	Vector2(0.05, 0.08), Vector2(0.12, 0.22), Vector2(0.19, 0.11),
	Vector2(0.27, 0.31), Vector2(0.35, 0.07), Vector2(0.43, 0.18),
	Vector2(0.52, 0.09), Vector2(0.60, 0.23), Vector2(0.69, 0.06),
	Vector2(0.77, 0.18), Vector2(0.86, 0.10), Vector2(0.94, 0.25),
	Vector2(0.08, 0.46), Vector2(0.92, 0.44), Vector2(0.13, 0.67),
	Vector2(0.88, 0.66), Vector2(0.20, 0.84), Vector2(0.34, 0.92),
	Vector2(0.52, 0.95), Vector2(0.70, 0.89), Vector2(0.84, 0.82)
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not SettingsManager.reduced_effects)
	queue_redraw()

func configure(next_accent: Color, next_rarity: String, is_revealed: bool) -> void:
	accent = next_accent
	rarity = next_rarity
	revealed = is_revealed
	omen_active = false
	secondary = _secondary_for_rarity(rarity)
	_burst = 0.28 if revealed and SettingsManager.reduced_effects else 0.0
	_omen_elapsed = 0.0
	_impact_elapsed = 0.0
	set_process(not SettingsManager.reduced_effects)
	queue_redraw()

func prepare_omen(next_rarity: String) -> void:
	rarity = next_rarity
	secondary = _secondary_for_rarity(rarity)
	revealed = false
	omen_active = true
	_burst = 0.0
	_omen_elapsed = 0.0
	_impact_elapsed = 0.0
	queue_redraw()

func trigger_reveal() -> void:
	revealed = true
	omen_active = false
	_burst = 1.0 if not SettingsManager.reduced_effects else 0.28
	_impact_elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	var speed: float = 0.34
	if omen_active:
		speed = 0.58 if rarity == "legendary" else (0.46 if rarity == "epic" else 0.38)
		_omen_elapsed += delta
	if revealed:
		_impact_elapsed += delta
	_phase = fmod(_phase + delta * speed, TAU)
	_burst = maxf(_burst - delta * 0.58, 0.0)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var center_point := Vector2(size.x * 0.50, size.y * 0.44)
	var base_radius: float = minf(size.x, size.y) * 0.225
	var omen_progress: float = 0.0
	if omen_active:
		omen_progress = clampf(_omen_elapsed / _omen_duration(), 0.0, 1.0)
		omen_progress = omen_progress * omen_progress * (3.0 - 2.0 * omen_progress)
	var impact_progress: float = clampf(1.0 - (_impact_elapsed / 0.92), 0.0, 1.0) if revealed else 0.0
	var pulse: float = 0.5 + 0.5 * sin(_phase * (6.0 if omen_active else 3.0))
	var rarity_gain: float = 1.34 if rarity == "legendary" else (1.14 if rarity == "epic" else 1.0)
	var atmosphere: float = 0.38
	if omen_active:
		atmosphere = 0.46 + omen_progress * 0.54
	elif revealed:
		atmosphere = 0.82 + impact_progress * 0.18

	_draw_void_backdrop(center_point, base_radius, omen_progress, impact_progress)

	for star_index: int in range(STAR_POINTS.size()):
		var point := STAR_POINTS[star_index]
		var star_point := Vector2(point.x * size.x, point.y * size.y)
		var star_color: Color = secondary if star_index % 4 == 0 else accent
		var star_alpha: float = (0.10 + float(star_index % 4) * 0.045 + pulse * 0.045) * atmosphere * rarity_gain
		var star_size: float = 0.9 + float(star_index % 3) * 0.72
		if rarity == "legendary" and (omen_active or revealed) and star_index % 5 == 0:
			star_size += 1.1 * maxf(omen_progress, impact_progress)
		draw_circle(star_point, star_size, Color(star_color.r, star_color.g, star_color.b, star_alpha))

	var ring_count: int = 8 if rarity == "legendary" else (7 if rarity == "epic" else 6)
	for ring_index: int in range(ring_count):
		var ring_radius: float = base_radius * (0.62 + float(ring_index) * 0.16) * (1.0 + _burst * 0.18)
		var direction: float = 1.0 if ring_index % 2 == 0 else -0.74
		var ring_speed: float = 1.0 + omen_progress * (1.35 if rarity == "legendary" else 0.72)
		var angle_start: float = _phase * direction * ring_speed + float(ring_index) * 0.39
		var ring_color: Color = secondary if ring_index in [1, 4, 6] else accent
		var ring_alpha: float = (0.09 + omen_progress * 0.18 + impact_progress * 0.20) * atmosphere
		draw_arc(center_point, ring_radius, angle_start, angle_start + TAU * 0.72, 96, Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha), 1.5 + impact_progress * 1.0, true)
		draw_arc(center_point, ring_radius, angle_start + PI, angle_start + PI + TAU * 0.13, 24, Color(secondary.r, secondary.g, secondary.b, ring_alpha * 0.86), 1.0, true)

	var seal_count: int = 16 if rarity == "legendary" else (12 if rarity == "epic" else 8)
	for seal_index: int in range(seal_count):
		var seal_angle: float = -_phase * (0.54 + omen_progress * 0.36) + TAU * float(seal_index) / float(seal_count)
		var seal_radius: float = base_radius * (1.48 + _burst * 0.10)
		var seal_center := center_point + Vector2(cos(seal_angle), sin(seal_angle)) * seal_radius
		var seal_size: float = 4.0 + omen_progress * 2.2 + impact_progress * 2.0
		if rarity == "legendary":
			seal_size += 1.4
		_draw_diamond(seal_center, seal_size, Color(secondary.r, secondary.g, secondary.b, (0.16 + omen_progress * 0.45 + impact_progress * 0.38) * atmosphere))

	if omen_active:
		_draw_rarity_omen(center_point, base_radius, omen_progress, pulse)
	if revealed:
		_draw_reveal_impact(center_point, base_radius, impact_progress, pulse)

func _draw_void_backdrop(center_point: Vector2, base_radius: float, omen_progress: float, impact_progress: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.00035, 0.0025, 0.008, 1.0))

	var light_gain: float = omen_progress * 0.72 + impact_progress
	for beam_index: int in range(10):
		var beam_width: float = size.x * (0.045 + float(beam_index) * 0.035)
		var beam_alpha: float = maxf(0.0, 0.050 - float(beam_index) * 0.0043) * light_gain
		draw_rect(
			Rect2(Vector2(center_point.x - beam_width * 0.5, 0.0), Vector2(beam_width, size.y * 0.80)),
			Color(secondary.r, secondary.g, secondary.b, beam_alpha)
		)

	var aura_gain: float = 0.05 + omen_progress * 0.10 + impact_progress * 0.14
	draw_circle(center_point, base_radius * 2.62, Color(accent.r * 0.040, accent.g * 0.040, accent.b * 0.040, 0.88))
	draw_circle(center_point, base_radius * 2.05, Color(secondary.r, secondary.g, secondary.b, aura_gain))
	draw_circle(center_point, base_radius * 1.48, Color(accent.r, accent.g, accent.b, 0.018 + aura_gain * 0.25))

func _draw_rarity_omen(center_point: Vector2, base_radius: float, progress: float, pulse: float) -> void:
	match rarity:
		"legendary":
			_draw_legendary_omen(center_point, base_radius, progress, pulse)
		"epic":
			_draw_epic_omen(center_point, base_radius, progress, pulse)
		"rare":
			_draw_rare_omen(center_point, base_radius, progress)
		_:
			draw_arc(center_point, base_radius * (1.34 + progress * 0.18), -_phase, -_phase + TAU * 0.48, 58, Color(accent.r, accent.g, accent.b, 0.22 + progress * 0.22), 1.5, true)

func _draw_legendary_omen(center_point: Vector2, base_radius: float, progress: float, pulse: float) -> void:
	var gold_alpha: float = 0.22 + progress * 0.72
	for curtain_index: int in range(5):
		var offset_x: float = (float(curtain_index) - 2.0) * base_radius * 0.38
		var curtain_alpha: float = (0.035 + progress * 0.075) * (1.0 - absf(float(curtain_index) - 2.0) * 0.10)
		draw_rect(
			Rect2(
				Vector2(center_point.x + offset_x - base_radius * 0.15, 0.0),
				Vector2(base_radius * 0.30, size.y * (0.78 + progress * 0.12))
			),
			Color(secondary.r, secondary.g, secondary.b, curtain_alpha)
		)

	for omen_index: int in range(5):
		var omen_radius: float = base_radius * (1.58 + float(omen_index) * 0.17 + progress * 0.10)
		var omen_start: float = _phase * (0.92 if omen_index % 2 == 0 else -0.72) + float(omen_index) * 0.44
		draw_arc(center_point, omen_radius, omen_start, omen_start + TAU * (0.16 + progress * 0.10), 42, Color(secondary.r, secondary.g, secondary.b, gold_alpha - float(omen_index) * 0.10), 2.1 + progress * 1.2, true)

	for cardinal_index: int in range(8):
		var cardinal_angle: float = PI * 0.125 + TAU * float(cardinal_index) / 8.0
		var cardinal_point := center_point + Vector2(cos(cardinal_angle), sin(cardinal_angle)) * base_radius * (1.72 + progress * 0.14)
		var cardinal_size: float = 4.0 + progress * 7.0 + pulse * 1.2
		_draw_diamond(cardinal_point, cardinal_size, Color(secondary.r, secondary.g, secondary.b, 0.24 + progress * 0.70))

	var cross_alpha: float = progress * 0.34
	draw_line(center_point + Vector2(-base_radius * 1.92, 0.0), center_point + Vector2(base_radius * 1.92, 0.0), Color(secondary.r, secondary.g, secondary.b, cross_alpha), 1.4 + progress * 1.0, true)
	draw_line(center_point + Vector2(0.0, -base_radius * 1.92), center_point + Vector2(0.0, base_radius * 1.92), Color(secondary.r, secondary.g, secondary.b, cross_alpha), 1.4 + progress * 1.0, true)

	if progress > 0.58:
		var crown_progress: float = clampf((progress - 0.58) / 0.42, 0.0, 1.0)
		_draw_legendary_crown(center_point, base_radius, crown_progress, pulse)

func _draw_epic_omen(center_point: Vector2, base_radius: float, progress: float, pulse: float) -> void:
	var epic_alpha: float = 0.18 + progress * 0.52
	for arc_index: int in range(3):
		var arc_radius: float = base_radius * (1.48 + float(arc_index) * 0.20)
		var arc_start: float = _phase * (1.0 if arc_index % 2 == 0 else -0.82) + float(arc_index) * 0.75
		draw_arc(center_point, arc_radius, arc_start, arc_start + TAU * 0.48, 72, Color(secondary.r, secondary.g, secondary.b, epic_alpha - float(arc_index) * 0.08), 1.8 + progress, true)
	for point_index: int in range(6):
		var angle: float = TAU * float(point_index) / 6.0 + _phase * 0.22
		var rune_point := center_point + Vector2(cos(angle), sin(angle)) * base_radius * (1.58 + progress * 0.08)
		_draw_diamond(rune_point, 4.0 + progress * 4.0 + pulse, Color(secondary.r, secondary.g, secondary.b, 0.22 + progress * 0.54))

func _draw_rare_omen(center_point: Vector2, base_radius: float, progress: float) -> void:
	draw_arc(center_point, base_radius * (1.42 + progress * 0.12), -_phase, -_phase + TAU * 0.62, 70, Color(secondary.r, secondary.g, secondary.b, 0.18 + progress * 0.42), 1.7 + progress * 0.6, true)
	for point_index: int in range(4):
		var angle: float = PI * 0.25 + TAU * float(point_index) / 4.0
		var rune_point := center_point + Vector2(cos(angle), sin(angle)) * base_radius * 1.52
		_draw_diamond(rune_point, 3.5 + progress * 3.0, Color(secondary.r, secondary.g, secondary.b, 0.18 + progress * 0.42))

func _draw_reveal_impact(center_point: Vector2, base_radius: float, impact: float, pulse: float) -> void:
	var halo_alpha: float = 0.12 + impact * 0.36
	draw_circle(center_point, base_radius * (0.72 + impact * 0.34), Color(accent.r, accent.g, accent.b, halo_alpha))
	var ray_count: int = 20 if rarity == "legendary" else (14 if rarity == "epic" else 10)
	for ray_index: int in range(ray_count):
		var ray_angle: float = TAU * float(ray_index) / float(ray_count) + _phase * 0.08
		var ray_dir := Vector2(cos(ray_angle), sin(ray_angle))
		var inner_point := center_point + ray_dir * base_radius * 0.92
		var outer_point := center_point + ray_dir * base_radius * (1.34 + impact * (0.74 if rarity == "legendary" else 0.42))
		var ray_color: Color = secondary if ray_index % 2 == 0 else accent
		draw_line(inner_point, outer_point, Color(ray_color.r, ray_color.g, ray_color.b, impact * (0.56 if rarity == "legendary" else 0.34)), 1.2 + impact * 1.7, true)
	if rarity == "legendary":
		draw_circle(center_point, base_radius * (0.92 + impact * 0.20), Color(1.0, 0.88, 0.52, 0.05 + impact * 0.20))
		_draw_legendary_crown(center_point, base_radius, 1.0, pulse)

func _draw_legendary_crown(center_point: Vector2, base_radius: float, progress: float, pulse: float) -> void:
	var crown_y: float = center_point.y - base_radius * (1.62 + progress * 0.08)
	var crown_half: float = base_radius * 0.72
	var crown_tint := Color(secondary.r, secondary.g, secondary.b, (0.32 + progress * 0.64) * (0.92 + pulse * 0.08))
	draw_line(Vector2(center_point.x - crown_half, crown_y + 24.0), Vector2(center_point.x - crown_half * 0.24, crown_y - 4.0), crown_tint, 2.8, true)
	draw_line(Vector2(center_point.x - crown_half * 0.24, crown_y - 4.0), Vector2(center_point.x, crown_y - 18.0), crown_tint, 2.8, true)
	draw_line(Vector2(center_point.x, crown_y - 18.0), Vector2(center_point.x + crown_half * 0.24, crown_y - 4.0), crown_tint, 2.8, true)
	draw_line(Vector2(center_point.x + crown_half * 0.24, crown_y - 4.0), Vector2(center_point.x + crown_half, crown_y + 24.0), crown_tint, 2.8, true)
	_draw_diamond(Vector2(center_point.x, crown_y - 18.0), 6.0 + progress * 4.0 + pulse * 1.2, crown_tint)

func _omen_duration() -> float:
	match rarity:
		"legendary":
			return 1.55
		"epic":
			return 0.78
		"rare":
			return 0.42
		_:
			return 0.20

func _draw_diamond(center_point: Vector2, half_size: float, tint: Color) -> void:
	var polygon := PackedVector2Array([
		center_point + Vector2(0.0, -half_size),
		center_point + Vector2(half_size, 0.0),
		center_point + Vector2(0.0, half_size),
		center_point + Vector2(-half_size, 0.0)
	])
	draw_colored_polygon(polygon, tint)

func _secondary_for_rarity(rarity_id: String) -> Color:
	match rarity_id:
		"legendary":
			return Color(1.0, 0.72, 0.20, 1.0)
		"epic":
			return Color(0.86, 0.62, 1.0, 1.0)
		"rare":
			return Color(0.32, 0.86, 1.0, 1.0)
		_:
			return Color(0.62, 0.84, 0.76, 1.0)
