extends Control

## Overlay-only presentation layer for the generated Pavilion palace background.
## It adds mobile readability/vignette and restrained motes without repainting
## or obscuring the authored background asset.

const GOLD: Color = Color(0.96, 0.73, 0.27, 1.0)
const JADE: Color = Color(0.22, 0.76, 0.68, 1.0)

var _phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not SettingsManager.reduced_effects)
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.10, TAU)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	# Readability veils: preserve the palace while keeping UI copy and navbar
	# contrast stable across mobile aspect ratios.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.008, 0.014, 0.12))
	draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.13), Color(0.0, 0.006, 0.012, 0.26))
	draw_rect(Rect2(0.0, size.y * 0.76, size.x, size.y * 0.24), Color(0.0, 0.006, 0.012, 0.34))

	# Soft side vignettes keep focus on the ritual axis.
	var side_width: float = maxf(22.0, size.x * 0.065)
	draw_rect(Rect2(0.0, 0.0, side_width, size.y), Color(0.0, 0.004, 0.008, 0.24))
	draw_rect(Rect2(size.x - side_width, 0.0, side_width, size.y), Color(0.0, 0.004, 0.008, 0.24))

	# Deterministic low-cost celestial motes. Reduced Effects disables motion.
	var pulse: float = 0.5 + 0.5 * sin(_phase * 2.0)
	for mote_index in range(18):
		var fx: float = fmod(float(mote_index * 83 + 17), 997.0) / 997.0
		var fy: float = fmod(float(mote_index * 149 + 41), 991.0) / 991.0
		var point: Vector2 = Vector2(fx * size.x, fy * size.y)
		var tint: Color = GOLD if mote_index % 5 == 0 else JADE
		var alpha: float = 0.035 + pulse * 0.020
		draw_circle(point, 0.8 + float(mote_index % 2) * 0.45, Color(tint.r, tint.g, tint.b, alpha))
