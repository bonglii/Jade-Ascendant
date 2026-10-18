extends "res://scripts/ui/trials_record_seal.gd"

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.47
	if radius < 1:
		return
	draw_circle(center + Vector2(0, 2), radius, Color(0, 0, 0, 0.65))
	draw_circle(center, radius - 1, Color("102c26"))
	draw_arc(center, radius - 2, 0, TAU, 48, Color("9e8954"), 2, true)
	draw_arc(center, radius - 6, 0, TAU, 48, Color("455d43"), 1, true)
	for index: int in range(8):
		var angle: float = index * TAU / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * (radius - 5), center + direction * (radius - 9), Color("c5ab6a"), 1, true)
	super._draw()
