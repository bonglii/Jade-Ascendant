extends RefCounted

## Shared, deterministic vector art for the actual cast and its UI preview.
## Jade links, gold ferrules and knot geometry remain readable on mobile.
const SEAL = preload("res://assets/vfx/jade_binding/binding_seal.png")
const JADE = Color(0.22, 0.92, 0.67)
const GOLD = Color(1.0, 0.79, 0.38)
const CORE = Color(0.80, 1.0, 0.86)

static func seal(canvas: CanvasItem, center: Vector2, radius: float, age: float, alpha: float, reduced: bool) -> void:
	canvas.draw_circle(center, radius, Color(0.02, 0.30, 0.21, alpha * 0.10))
	canvas.draw_set_transform(center, 0.0 if reduced else age * 0.08, Vector2.ONE)
	canvas.draw_texture_rect(SEAL, Rect2(Vector2(-radius, -radius), Vector2.ONE * radius * 2.0), false, Color(1, 1, 1, alpha * 0.48))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	canvas.draw_arc(center, radius, 0, TAU, 48, Color(GOLD, alpha * 0.68), 1.4, true)
	canvas.draw_arc(center, radius * 0.91, 0, TAU, 48, Color(JADE, alpha * 0.40), 1.0, true)
	var spin: float = 0.0 if reduced else age * 0.24
	for i: int in range(8):
		var angle: float = TAU * i / 8.0 + spin
		var ray: Vector2 = Vector2.RIGHT.rotated(angle)
		var tangent: Vector2 = ray.orthogonal()
		var p: Vector2 = center + ray * radius * 0.79
		canvas.draw_line(p - tangent * 3.0, p + tangent * 3.0, Color(GOLD, alpha * 0.85), 2.0, true)
		canvas.draw_line(p - ray * 4.0, p + ray * 4.0, Color(GOLD, alpha * 0.85), 1.0, true)
		if not reduced:
			canvas.draw_arc(center, radius * 0.64, angle, angle + 0.32, 9, Color(JADE, alpha * 0.50), 2.0, true)
	knot(canvas, center, 12.0, alpha)

static func knot(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	for i: int in range(4):
		var angle: float = PI * 0.25 + i * PI * 0.5
		var points := PackedVector2Array()
		for j: int in range(25):
			var theta: float = TAU * j / 24.0
			points.append(center + Vector2(cos(theta) * radius, sin(theta) * radius * 0.42).rotated(angle))
		canvas.draw_polyline(points, Color(0.04, 0.25, 0.17, alpha), 5.0, true)
		canvas.draw_polyline(points, Color(GOLD if i % 2 else JADE, alpha), 2.2, true)
	canvas.draw_circle(center, 2.4, Color(CORE, alpha))

static func chain(canvas: CanvasItem, start: Vector2, finish: Vector2, age: float, alpha: float, reduced: bool) -> void:
	var distance: float = start.distance_to(finish)
	var direction: Vector2 = start.direction_to(finish)
	var count: int = clampi(int(distance / 12.0), 2, 24)
	for i: int in range(count):
		var t: float = (float(i) + 0.5) / count
		var bow: float = sin(t * PI) * (6.0 if reduced else 9.0 * sin(age * 5.0))
		var p: Vector2 = start.lerp(finish, t) + direction.orthogonal() * bow
		var link := PackedVector2Array()
		for j: int in range(13):
			var a: float = TAU * j / 12.0
			link.append(p + Vector2(cos(a) * 6.3, sin(a) * (2.2 if i % 2 else 3.7)).rotated(direction.angle()))
		canvas.draw_polyline(link, Color(0.02, 0.16, 0.12, alpha), 4.0, true)
		canvas.draw_polyline(link, Color(GOLD if i % 2 else JADE, alpha), 2.0, true)
		if not reduced:
			canvas.draw_line(p - direction * 3.0, p + direction * 3.0, Color(CORE, alpha * 0.72), 0.9, true)

static func burst(canvas: CanvasItem, center: Vector2, progress: float, reduced: bool) -> void:
	var alpha: float = clampf(1.0 - progress, 0.0, 1.0)
	canvas.draw_arc(center, 12.0 + 38.0 * progress, 0, TAU, 32, Color(GOLD, alpha * 0.85), 2.8 * alpha + 0.5, true)
	knot(canvas, center, 9.0 + progress * 5.0, alpha)
	if reduced: return
	canvas.draw_arc(center, 7.0 + 23.0 * progress, 0, TAU, 24, Color(JADE, alpha * 0.65), 1.4, true)
	for i: int in range(6):
		var ray: Vector2 = Vector2.RIGHT.rotated(TAU * i / 6.0 + 0.3)
		canvas.draw_line(center + ray * (14 + 28 * progress), center + ray * (19 + 37 * progress), Color(GOLD, alpha), 1.6, true)
