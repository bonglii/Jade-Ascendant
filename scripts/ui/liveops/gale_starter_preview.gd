extends Control

const CLOSED = preload("res://assets/ui/equipment/galeweave/parasol_closed.png")
const OPEN = preload("res://assets/ui/equipment/galeweave/parasol_open.png")

var canopy: bool = false
var _age: float = 0.0

func _process(delta: float) -> void:
	if not SettingsManager.reduced_effects:
		_age = fmod(_age + delta, 2.0)
		queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var edge: float = minf(size.x, size.y)
	var phase: float = _age * 0.5
	var art: Texture2D = OPEN if canopy else CLOSED
	draw_circle(center, edge * 0.38, Color("#12322c"), true, -1.0, true)
	if canopy:
		for band in range(3):
			var progress: float = fmod(phase + band / 3.0, 1.0)
			var radius: float = edge * lerpf(0.25, 0.47, progress)
			draw_arc(center, radius, -phase, TAU - phase, 40,
				Color(0.47, 0.91, 0.69, (1.0 - progress) * 0.62), 2.0, true)
	else:
		for index in range(3):
			var progress: float = fmod(phase + index / 3.0, 1.0)
			var head: Vector2 = center + Vector2(lerpf(9, size.x * 0.43, progress), -16 + index * 14)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-18, 0), head + Vector2(-6, -2.5),
				head, head + Vector2(-6, 2.5)]), Color(0.75, 0.98, 0.65, 1.0 - progress * 0.6))
	var image_side: float = edge * (0.76 if canopy else 0.70)
	var art_origin: Vector2 = center - Vector2.ONE * image_side * 0.5
	if not canopy:
		art_origin.x -= edge * 0.10
	draw_texture_rect(art, Rect2(art_origin, Vector2.ONE * image_side), false)
