extends Control
class_name EndRunAtmosphere

## Lightweight end-of-run atmosphere. Presentation only.
## No gameplay, reward, save, checkpoint, or progression authority.

@export_enum("victory", "defeat") var mode: String = "victory"

var elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not SettingsManager.reduced_effects)
	queue_redraw()


func configure(new_mode: String) -> void:
	mode = "defeat" if new_mode == "defeat" else "victory"
	queue_redraw()


func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, 1000.0)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var canvas_size: Vector2 = get_rect().size
	if canvas_size.x <= 2.0 or canvas_size.y <= 2.0:
		return

	if mode == "defeat":
		_draw_defeat(canvas_size)
	else:
		_draw_victory(canvas_size)


func _draw_victory(canvas_size: Vector2) -> void:
	var center := Vector2(canvas_size.x * 0.50, canvas_size.y * 0.205)
	var motion: float = 0.0 if SettingsManager.reduced_effects else elapsed

	for ring_index in range(4):
		var radius_value: float = 68.0 + float(ring_index) * 26.0
		var ring_alpha: float = 0.14 - float(ring_index) * 0.022
		draw_arc(
			center,
			radius_value,
			motion * (0.09 + float(ring_index) * 0.018),
			TAU * 0.70 + motion * (0.09 + float(ring_index) * 0.018),
			42,
			Color(0.53, 0.96, 0.80, ring_alpha),
			1.25,
			true
		)
		draw_arc(
			center,
			radius_value + 8.0,
			PI + motion * 0.055,
			PI * 1.52 + motion * 0.055,
			24,
			Color(0.98, 0.79, 0.32, ring_alpha * 0.82),
			1.0,
			true
		)

	var mote_uvs: Array[Vector2] = [
		Vector2(0.14, 0.18), Vector2(0.23, 0.29), Vector2(0.34, 0.14),
		Vector2(0.44, 0.31), Vector2(0.56, 0.12), Vector2(0.68, 0.26),
		Vector2(0.79, 0.16), Vector2(0.87, 0.34), Vector2(0.18, 0.52),
		Vector2(0.72, 0.49), Vector2(0.88, 0.61), Vector2(0.39, 0.56)
	]
	for mote_index in range(mote_uvs.size()):
		var uv: Vector2 = mote_uvs[mote_index]
		var drift: float = 0.0
		if not SettingsManager.reduced_effects:
			drift = sin(motion * 0.75 + float(mote_index) * 1.77) * 7.0
		var point := Vector2(
			canvas_size.x * uv.x,
			canvas_size.y * uv.y - drift
		)
		var mote_color := (
			Color(1.0, 0.82, 0.35, 0.32)
			if mote_index % 3 == 0
			else Color(0.48, 0.96, 0.80, 0.28)
		)
		draw_circle(point, 1.7 + float(mote_index % 2) * 0.7, mote_color)

	for stream_index in range(5):
		var x_value: float = canvas_size.x * (0.18 + float(stream_index) * 0.16)
		var stream_offset: float = 0.0
		if not SettingsManager.reduced_effects:
			stream_offset = fmod(
				motion * (13.0 + float(stream_index) * 2.0),
				canvas_size.y * 0.28
			)
		var y_start: float = canvas_size.y * 0.66 - stream_offset
		draw_line(
			Vector2(x_value, y_start),
			Vector2(x_value + 9.0, y_start - 54.0),
			Color(0.46, 0.95, 0.78, 0.075),
			1.2,
			true
		)

	_draw_lower_mist(
		canvas_size,
		Color(0.36, 0.87, 0.72, 0.095),
		Color(0.95, 0.75, 0.30, 0.055)
	)


func _draw_defeat(canvas_size: Vector2) -> void:
	var center := Vector2(canvas_size.x * 0.50, canvas_size.y * 0.215)
	var motion: float = 0.0 if SettingsManager.reduced_effects else elapsed

	draw_arc(
		center,
		112.0,
		-PI * 0.92,
		-PI * 0.08,
		34,
		Color(0.92, 0.38, 0.30, 0.14),
		1.4,
		true
	)
	draw_arc(
		center,
		136.0,
		PI * 0.16,
		PI * 0.92,
		30,
		Color(0.56, 0.36, 0.47, 0.10),
		1.1,
		true
	)

	var fracture_targets: Array[Vector2] = [
		Vector2(0.18, 0.36), Vector2(0.30, 0.49),
		Vector2(0.74, 0.37), Vector2(0.85, 0.53),
		Vector2(0.45, 0.47)
	]
	for fracture_index in range(fracture_targets.size()):
		var target_uv: Vector2 = fracture_targets[fracture_index]
		var target := Vector2(
			canvas_size.x * target_uv.x,
			canvas_size.y * target_uv.y
		)
		var direction: Vector2 = center.direction_to(target)
		var normal_vec: Vector2 = direction.orthogonal()
		var midpoint: Vector2 = center.lerp(target, 0.54)
		var jag: float = 9.0 if fracture_index % 2 == 0 else -8.0
		draw_polyline(
			PackedVector2Array([
				center + direction * 72.0,
				midpoint + normal_vec * jag,
				target
			]),
			Color(0.82, 0.31, 0.28, 0.075),
			1.0,
			true
		)

	var ember_uvs: Array[Vector2] = [
		Vector2(0.16, 0.27), Vector2(0.28, 0.39), Vector2(0.41, 0.18),
		Vector2(0.60, 0.30), Vector2(0.74, 0.20), Vector2(0.84, 0.42),
		Vector2(0.22, 0.58), Vector2(0.64, 0.56), Vector2(0.82, 0.65)
	]
	for ember_index in range(ember_uvs.size()):
		var uv: Vector2 = ember_uvs[ember_index]
		var fall: float = 0.0
		if not SettingsManager.reduced_effects:
			fall = fmod(
				motion * (7.0 + float(ember_index % 3) * 2.5),
				54.0
			)
		var point := Vector2(
			canvas_size.x * uv.x,
			canvas_size.y * uv.y + fall
		)
		draw_circle(
			point,
			1.4 + float(ember_index % 2) * 0.6,
			Color(0.91, 0.36, 0.27, 0.25)
		)

	_draw_lower_mist(
		canvas_size,
		Color(0.36, 0.56, 0.58, 0.055),
		Color(0.75, 0.26, 0.25, 0.050)
	)


func _draw_lower_mist(
	canvas_size: Vector2,
	primary_color: Color,
	secondary_color: Color
) -> void:
	var base_y: float = canvas_size.y * 0.79
	for band_index in range(4):
		var points := PackedVector2Array()
		var step_count: int = 28
		for point_index in range(step_count + 1):
			var ratio: float = float(point_index) / float(step_count)
			var x_value: float = canvas_size.x * ratio
			var wave_y: float = (
				base_y
				+ float(band_index) * 34.0
				+ sin(ratio * TAU * 1.6 + float(band_index)) * 12.0
			)
			points.append(Vector2(x_value, wave_y))
		draw_polyline(
			points,
			primary_color if band_index % 2 == 0 else secondary_color,
			3.0 if band_index == 0 else 1.5,
			true
		)
