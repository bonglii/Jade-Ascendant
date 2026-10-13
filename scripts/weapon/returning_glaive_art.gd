extends RefCounted

const TEXTURE = preload("res://assets/ui/equipment/final/celestial_returning_glaive.png")
const CYAN = Color(0.20, 0.88, 0.94)
const GOLD = Color(1.0, 0.78, 0.34)

static func disc(canvas: CanvasItem, center: Vector2, angle: float, returning: bool, reduced: bool, size: float = 58.0, empowered: bool = false) -> void:
	var color: Color = GOLD if returning else CYAN
	canvas.draw_arc(center, size * 0.40, angle, angle + PI * 1.5, 24, Color(color, 0.55), 1.6, true)
	if not reduced:
		canvas.draw_arc(center, size * 0.47, angle + PI, angle + PI * 1.7, 16, Color(color, 0.30), 3.0, true)
	canvas.draw_set_transform(center, 0.0 if reduced else angle, Vector2.ONE)
	canvas.draw_texture_rect(TEXTURE, Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size), false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if empowered:
		canvas.draw_arc(center, size * 0.54, 0, TAU, 32, Color(GOLD, 0.8), 1.4, true)

static func trail(canvas: CanvasItem, points: PackedVector2Array, returning: bool, reduced: bool) -> void:
	var color: Color = GOLD if returning else CYAN
	for i: int in range(1, points.size()):
		var alpha: float = float(i) / points.size()
		if not reduced: canvas.draw_line(points[i-1], points[i], Color(color, alpha * 0.12), 8.0, true)
		canvas.draw_line(points[i-1], points[i], Color(color, alpha * 0.66), 2.2, true)
		canvas.draw_line(points[i-1], points[i], Color(0.88, 1.0, 0.94, alpha * 0.7), 0.9, true)

static func closure(canvas: CanvasItem, center: Vector2, age: float, reduced: bool, radius: float = 58.0) -> void:
	var t: float = clampf(age / 0.32, 0.0, 1.0)
	var r: float = radius * (0.35 + t * 0.65)
	canvas.draw_arc(center, r, 0, TAU, 40, Color(GOLD, (1.0-t)*0.82), 2.4, true)
	if reduced: return
	for i: int in range(3):
		var a: float = TAU * i / 3.0 + age * 4.0
		canvas.draw_arc(center, r * 0.83, a, a + 0.65, 12, Color(CYAN, (1.0-t)*0.60), 1.6, true)
