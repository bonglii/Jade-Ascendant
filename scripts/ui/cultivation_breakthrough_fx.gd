extends Control

## Cultivation breakthrough ritual atmosphere — production presentation only.
## No progression/save/economy authority.

const GOLD := Color(0.98, 0.79, 0.32, 1.0)
const JADE := Color(0.28, 0.93, 0.73, 1.0)

var accent: Color = GOLD
var phase: float = 0.0
var burst_strength: float = 0.0
var redraw_elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func configure(new_accent: Color) -> void:
	accent = new_accent
	queue_redraw()


func celebrate() -> void:
	burst_strength = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if not _reduced_effects_enabled():
		phase = fmod(phase + delta, 1000.0)
	if burst_strength > 0.0:
		burst_strength = maxf(burst_strength - delta * 0.72, 0.0)
	redraw_elapsed += delta
	if redraw_elapsed >= 0.05:
		redraw_elapsed = 0.0
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return

	var center := Vector2(size.x * 0.5, size.y * 0.39)
	var basis := minf(size.x, size.y)
	var pulse: float = 0.0
	if not _reduced_effects_enabled():
		pulse = sin(phase * 1.65) * 0.5 + 0.5

	_draw_vertical_beam(center, basis, pulse)
	_draw_ritual_rings(center, basis, pulse)
	_draw_constellation(center, basis, pulse)
	_draw_burst(center, basis)
	_draw_edge_seals(pulse)


func _draw_vertical_beam(center: Vector2, basis: float, pulse: float) -> void:
	for beam_index: int in range(7, 0, -1):
		var ratio := float(beam_index) / 7.0
		var half_width := basis * (0.015 + ratio * 0.018)
		var alpha := (0.010 + ratio * 0.010) + pulse * 0.003
		draw_rect(
			Rect2(
				Vector2(center.x - half_width, size.y * 0.08),
				Vector2(half_width * 2.0, size.y * 0.69)
			),
			Color(0.94, 1.0, 0.99, alpha)
		)


func _draw_ritual_rings(center: Vector2, basis: float, pulse: float) -> void:
	var base_radius := basis * 0.205
	var ring_rotation := 0.0 if _reduced_effects_enabled() else phase * 0.045
	for ring_index: int in range(7):
		var radius := base_radius + float(ring_index) * basis * 0.028
		var ring_color := accent if ring_index % 2 == 0 else GOLD
		var alpha := 0.12 - float(ring_index) * 0.010 + pulse * 0.012
		draw_arc(
			center,
			radius,
			ring_rotation + float(ring_index) * 0.34,
			ring_rotation + PI * 1.42 + float(ring_index) * 0.34,
			96,
			Color(ring_color.r, ring_color.g, ring_color.b, maxf(alpha, 0.03)),
			1.4 if ring_index < 2 else 1.0,
			true
		)

	for spoke_index: int in range(12):
		var angle := ring_rotation * 0.7 + TAU * float(spoke_index) / 12.0
		var inner := center + Vector2.RIGHT.rotated(angle) * base_radius * 0.70
		var outer := center + Vector2.RIGHT.rotated(angle) * base_radius * 1.58
		draw_line(
			inner,
			outer,
			Color(accent.r, accent.g, accent.b, 0.045),
			1.0,
			true
		)


func _draw_constellation(center: Vector2, basis: float, pulse: float) -> void:
	var positions: Array[Vector2] = [
		Vector2(-0.33, -0.21), Vector2(-0.24, 0.17), Vector2(-0.12, -0.34),
		Vector2(0.12, -0.31), Vector2(0.27, -0.12), Vector2(0.34, 0.18),
		Vector2(-0.31, 0.34), Vector2(-0.06, 0.40), Vector2(0.19, 0.36),
	]
	for point_index: int in range(positions.size()):
		var uv := positions[point_index]
		var point := center + Vector2(uv.x * basis, uv.y * basis)
		var radius := 1.7 + float(point_index % 3) * 0.55 + pulse * 0.25
		var c := GOLD if point_index % 3 == 0 else accent
		draw_circle(point, radius, Color(c.r, c.g, c.b, 0.42))


func _draw_burst(center: Vector2, basis: float) -> void:
	if burst_strength <= 0.0:
		return
	var progress := 1.0 - burst_strength
	var radius := basis * (0.16 + progress * 0.40)
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		96,
		Color(accent.r, accent.g, accent.b, burst_strength * 0.70),
		3.0,
		true
	)
	draw_arc(
		center,
		radius + 14.0,
		0.0,
		TAU,
		96,
		Color(GOLD.r, GOLD.g, GOLD.b, burst_strength * 0.48),
		1.5,
		true
	)


func _draw_edge_seals(pulse: float) -> void:
	var y := size.y * 0.52
	for side: float in [-1.0, 1.0]:
		var x := size.x * (0.085 if side < 0.0 else 0.915)
		var center := Vector2(x, y)
		for ring_index: int in range(3):
			draw_arc(
				center,
				18.0 + float(ring_index) * 9.0,
				-PI * 0.72,
				PI * 0.72,
				28,
				Color(accent.r, accent.g, accent.b, 0.08 + pulse * 0.01),
				1.0,
				true
			)


func _reduced_effects_enabled() -> bool:
	return is_instance_valid(SettingsManager) and bool(SettingsManager.reduced_effects)
