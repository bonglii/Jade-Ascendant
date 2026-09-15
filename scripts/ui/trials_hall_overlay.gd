extends Control
class_name TrialsHallOverlay

## Low-cost decorative overlay for the Trials Hub.
## Adds different visual language for daily disciplines vs eternal records.

@export_enum("daily", "records") var mode: String = "daily"

var elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not SettingsManager.reduced_effects)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, 1000.0)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var canvas_size: Vector2 = size
	if canvas_size.x <= 2.0 or canvas_size.y <= 2.0:
		return

	if mode == "records":
		_draw_records(canvas_size)
	else:
		_draw_daily(canvas_size)

	_draw_motes(canvas_size)
	_draw_edge_accents(canvas_size)


func _draw_daily(canvas_size: Vector2) -> void:
	var jade := Color(0.25, 0.92, 0.72, 0.11)
	var gold := Color(1.0, 0.78, 0.30, 0.10)
	var center := Vector2(canvas_size.x * 0.82, canvas_size.y * 0.20)
	var phase: float = 0.0 if SettingsManager.reduced_effects else elapsed * 0.10

	for ring_index in range(3):
		draw_arc(
			center,
			56.0 + float(ring_index) * 17.0,
			phase + float(ring_index) * 0.50,
			phase + PI * 1.28 + float(ring_index) * 0.50,
			30,
			jade if ring_index != 1 else gold,
			1.3,
			true
		)

	for seal_index in range(6):
		var angle: float = phase + float(seal_index) * TAU / 6.0
		var point := center + Vector2.RIGHT.rotated(angle) * 84.0
		draw_circle(point, 2.0, Color(0.45, 1.0, 0.84, 0.20))


func _draw_records(canvas_size: Vector2) -> void:
	var gold := Color(1.0, 0.78, 0.30, 0.12)
	var jade := Color(0.22, 0.84, 0.68, 0.10)
	var center := Vector2(canvas_size.x * 0.80, canvas_size.y * 0.21)

	for layer_index in range(3):
		var half_extent: float = 46.0 + float(layer_index) * 19.0
		var points := PackedVector2Array([
			center + Vector2(0.0, -half_extent),
			center + Vector2(half_extent, 0.0),
			center + Vector2(0.0, half_extent),
			center + Vector2(-half_extent, 0.0),
			center + Vector2(0.0, -half_extent)
		])
		draw_polyline(
			points,
			gold if layer_index % 2 == 0 else jade,
			1.2,
			true
		)

	draw_line(
		Vector2(canvas_size.x * 0.08, canvas_size.y * 0.31),
		Vector2(canvas_size.x * 0.32, canvas_size.y * 0.31),
		Color(0.92, 0.72, 0.30, 0.10),
		1.0,
		true
	)


func _draw_motes(canvas_size: Vector2) -> void:
	var positions: Array[Vector2] = [
		Vector2(0.10, 0.16),
		Vector2(0.19, 0.29),
		Vector2(0.36, 0.12),
		Vector2(0.51, 0.25),
		Vector2(0.67, 0.15),
		Vector2(0.86, 0.33),
		Vector2(0.24, 0.56),
		Vector2(0.72, 0.58),
		Vector2(0.91, 0.72)
	]

	for mote_index in range(positions.size()):
		var uv: Vector2 = positions[mote_index]
		var alpha: float = 0.11 + float(mote_index % 3) * 0.025
		draw_circle(
			Vector2(canvas_size.x * uv.x, canvas_size.y * uv.y),
			1.2 + float(mote_index % 2) * 0.8,
			Color(0.55, 0.96, 0.82, alpha)
		)


func _draw_edge_accents(canvas_size: Vector2) -> void:
	var jade := Color(0.28, 0.86, 0.72, 0.14)
	var gold := Color(0.96, 0.76, 0.31, 0.16)

	draw_line(
		Vector2(12.0, 16.0),
		Vector2(68.0, 16.0),
		gold,
		1.2,
		true
	)
	draw_line(
		Vector2(12.0, 16.0),
		Vector2(12.0, 70.0),
		gold,
		1.2,
		true
	)
	draw_line(
		Vector2(canvas_size.x - 12.0, canvas_size.y - 16.0),
		Vector2(canvas_size.x - 68.0, canvas_size.y - 16.0),
		jade,
		1.2,
		true
	)
