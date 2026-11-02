extends RefCounted
## Organic qi: open tapered ribbons with vertex-alpha falloff and soft light.
## No outlines, closed ornaments, regular polygons or rings.
const IDS: Array[String] = ["jade_aura", "golden_aura", "astral_aura", "ascendant_aura"]
const MAX_CURVES: int = 40
const MAX_COMMANDS: int = 96
const FULL_SEGMENTS: int = 64
const REDUCED_SEGMENTS: int = 24
const PERIOD: float = 8.0

class AuraCurve:
	extends RefCounted
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var triangles := PackedInt32Array()

class AuraCommand:
	extends RefCounted
	var kind: int = 3 # 3 vertex-shaded ribbon; 2 feathered light texture
	var curve_index: int = -1
	var color: Color = Color.TRANSPARENT
	var point: Vector2 = Vector2.ZERO
	var axes: Vector2 = Vector2.ONE
	var rotation: float = 0.0

static var _light_texture: ImageTexture
var _curves: Array[AuraCurve] = []
var _commands: Array[AuraCommand] = []
var _strip_pool: Array[AuraCurve] = []
var curve_count: int = 0
var command_count: int = 0
var vertex_count: int = 0
var reduced: bool = false
var aura_id: String = "plain"
var buffer_resizes: int = 0

func _init() -> void:
	for index: int in MAX_CURVES: _curves.append(AuraCurve.new())
	for index: int in MAX_COMMANDS: _commands.append(AuraCommand.new())
	for index: int in 4: _strip_pool.append(_curves[index])
	if _light_texture == null:
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y: int in 64:
			for x: int in 64:
				var p := (Vector2(x, y) + Vector2.ONE * 0.5) / 32.0 - Vector2.ONE
				image.set_pixel(x, y, Color(1, 1, 1, pow(maxf(0.0, 1.0 - p.length()), 2.4)))
		_light_texture = ImageTexture.create_from_image(image)

static func tone(id: String) -> Color:
	match id:
		"jade_aura": return Color("65f3b1")
		"golden_aura": return Color("ffcb69")
		"astral_aura": return Color("83bfff")
		"ascendant_aura": return Color("66f5de")
	return Color.TRANSPARENT

func build(id: String, clock: float, low_effects: bool = false) -> void:
	aura_id = id; reduced = low_effects
	curve_count = 0; command_count = 0; vertex_count = 0
	if id not in IDS: return
	var phase: float = 0.0 if reduced else fposmod(clock, PERIOD) / PERIOD * TAU
	var primary: Color = tone(id)
	_light(Vector2(0, 35), Vector2(33, 9), primary, 0.34)
	_light(Vector2(0, -4), Vector2(29, 39), primary, 0.12)
	match id:
		"jade_aura":
			for side: float in [-1.0, 1.0]:
				_stream(0, side, 0, phase, primary, 5.3)
				if not reduced: _stream(0, side, 1, phase, Color("b5ffe0"), 2.6)
			if not reduced: _fireflies(phase, primary, 8, 31, 74)
		"golden_aura":
			_light(Vector2(0, -27), Vector2(30, 29), Color("ffe6a7"), 0.24)
			for side: float in [-1.0, 1.0]:
				_stream(1, side, 0, phase, primary, 5.6)
				if not reduced: _stream(1, side, 1, phase, Color("fff1b8"), 2.8)
			if not reduced: _fireflies(phase + PI, Color("ffe7a1"), 11, 29, 81)
		"astral_aura":
			for side: float in [-1.0, 1.0]:
				_stream(2, side, 0, phase, primary if side < 0 else Color("7aeadf"), 5.1)
				if not reduced: _stream(2, side, 1, phase, Color("bddeff"), 2.4)
			if not reduced: _fireflies(phase, Color("d2ecff"), 13, 34, 79, true)
		"ascendant_aura":
			for side: float in [-1.0, 1.0]:
				_stream(3, side, 0, phase, primary if side < 0 else Color("7ac8ff"), 6.0)
				if not reduced: _stream(3, side, 1, phase, Color("c5fff0"), 2.7)
			_light(Vector2(0, -35), Vector2(16, 18), Color("e6ffd1"), 0.20)
			if not reduced: _fireflies(phase, Color("ecf7b5"), 12, 31, 83)

func paint(canvas: CanvasItem, origin: Vector2 = Vector2.ZERO, scale_value: float = 1.0, opacity: float = 1.0) -> void:
	var fade: float = clampf(opacity, 0, 1)
	for index: int in command_count:
		var command: AuraCommand = _commands[index]
		if command.kind == 2:
			canvas.draw_set_transform(origin + command.point * scale_value, command.rotation, Vector2.ONE * scale_value)
			var tint: Color = command.color; tint.a *= fade
			canvas.draw_texture_rect(_light_texture, Rect2(-command.axes, command.axes * 2), false, tint)
		else:
			canvas.draw_set_transform(origin, 0, Vector2.ONE * scale_value)
			var curve: AuraCurve = _curves[command.curve_index]
			if fade < 1.0:
				for point_index: int in curve.colors.size():
					var shade: Color = curve.colors[point_index]; shade.a *= fade
					curve.colors[point_index] = shade
			RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), curve.triangles, curve.points, curve.colors)
	canvas.draw_set_transform(Vector2.ZERO)

func _curve(point_count: int) -> int:
	if curve_count >= MAX_CURVES: return -1
	var index: int = curve_count; curve_count += 1
	if _curves[index].points.size() != point_count:
		_curves[index].points.resize(point_count)
		_curves[index].colors.resize(point_count)
		var count: int = point_count / 2 - 1
		_curves[index].triangles.resize(count * 6)
		for segment: int in count:
			var offset: int = segment * 6
			var outer: int = point_count - 1 - segment
			_curves[index].triangles[offset] = segment
			_curves[index].triangles[offset + 1] = segment + 1
			_curves[index].triangles[offset + 2] = outer
			_curves[index].triangles[offset + 3] = segment + 1
			_curves[index].triangles[offset + 4] = outer - 1
			_curves[index].triangles[offset + 5] = outer
		buffer_resizes += 1
	vertex_count += point_count
	return index

func _light(point: Vector2, axes: Vector2, color: Color, alpha: float, rotation: float = 0.0) -> void:
	if command_count >= MAX_COMMANDS: return
	var command: AuraCommand = _commands[command_count]; command_count += 1
	command.kind = 2; command.point = point; command.axes = axes
	command.rotation = rotation; command.color = Color(color, alpha)

func _path(style: int, side: float, layer: int, t: float, phase: float) -> Vector2:
	var wave: float = sin(t * TAU * 1.1 - phase + side) * 1.6 + sin(t * TAU * 1.8 + phase * 2) * 0.45
	var x: float = 0.0
	var y: float = 32.0 - t * 77.0
	match style:
		0:
			x = side * (10 + sin(t * PI * 0.95) * (21 - layer * 5) + wave)
			y += layer * 8 + sin(t * PI) * sin(phase + side) * 2
		1:
			x = side * (7 + sin(t * PI * 0.78) * (27 - layer * 7) + wave * 0.7)
			y = 32 - t * (84 - layer * 12)
		2:
			x = side * (8 + sin(t * TAU * 0.85 - 0.45 + sin(phase) * 0.18) * (24 - layer * 5))
			y += sin(t * TAU + phase) * 3 + layer * 5
		3:
			x = side * sin(t * TAU * 1.15 - phase + side * 0.5) * (28 - layer * 7) + wave
			y = 33 - t * (85 - layer * 9)
	return Vector2(x, y)

func _tangent(style: int, side: float, layer: int, t: float, phase: float) -> Vector2:
	var wave: float = cos(t * TAU * 1.1 - phase + side) * 1.6 * TAU * 1.1 + cos(t * TAU * 1.8 + phase * 2) * 0.45 * TAU * 1.8
	match style:
		0: return Vector2(side * (cos(t * PI * 0.95) * PI * 0.95 * (21 - layer * 5) + wave), -77 + cos(t * PI) * PI * sin(phase + side) * 2)
		1: return Vector2(side * (cos(t * PI * 0.78) * PI * 0.78 * (27 - layer * 7) + wave * 0.7), -(84 - layer * 12))
		2: return Vector2(side * cos(t * TAU * 0.85 - 0.45 + sin(phase) * 0.18) * TAU * 0.85 * (24 - layer * 5), -77 + cos(t * TAU + phase) * TAU * 3)
	return Vector2(side * cos(t * TAU * 1.15 - phase + side * 0.5) * TAU * 1.15 * (28 - layer * 7) + wave, -(85 - layer * 9))

func _stream(style: int, side: float, layer: int, phase: float, color: Color, width: float) -> void:
	var count: int = REDUCED_SEGMENTS if reduced else FULL_SEGMENTS
	var bands: int = 2 if reduced else 4
	var core_ink: Color = color.lightened(0.34)
	for band: int in bands:
		var index: int = _curve((count + 1) * 2)
		if index < 0 or command_count >= MAX_COMMANDS: return
		_strip_pool[band] = _curves[index]
		var command: AuraCommand = _commands[command_count]; command_count += 1
		command.kind = 3; command.curve_index = index; command.color = core_ink if band >= 2 else color
	for point_index: int in range(count + 1):
		var t: float = float(point_index) / count
		var at: Vector2 = _path(style, side, layer, t, phase)
		var normal: Vector2 = _tangent(style, side, layer, t, phase).normalized().orthogonal()
		var envelope: float = pow(maxf(0.0, sin(t * PI)), 0.72)
		var flow: float = 0.60 + 0.40 * sin(t * TAU * 1.4 - phase * 2 + side)
		var outer: int = count * 2 + 1 - point_index
		for band: int in bands:
			var core: bool = band >= 2
			var ink: Color = core_ink if core else color
			var feather: float = width * (0.28 if core else 1.0) * (0.18 + envelope * 0.82)
			var alpha: float = envelope * flow * (0.44 if core else 0.33) * (0.65 if reduced else 1.0)
			var curve: AuraCurve = _strip_pool[band]
			curve.points[point_index] = at
			curve.colors[point_index] = Color(ink, alpha)
			curve.points[outer] = at + normal * feather * (-1.0 if band % 2 == 0 else 1.0)
			curve.colors[outer] = Color(ink, 0)

func _fireflies(phase: float, primary: Color, count: int, spread: float, height: float, starlight: bool = false) -> void:
	for index: int in count:
		var offset: float = float(index) / count * TAU
		var cycle: float = fposmod(phase + offset, TAU) / TAU
		var fade: float = pow(sin(cycle * PI), 1.5)
		var at := Vector2(sin(offset * 2.1 + phase) * spread, 30 - cycle * height)
		_light(at, Vector2.ONE * 3.4, primary, fade * 0.32)
		_light(at, Vector2(0.75, 1.3), primary.lightened(0.6), fade * 0.83)
		if starlight and index % 3 == 0: _light(at, Vector2(3.0, 0.38), Color("e4f4ff"), fade * 0.63)

func snapshot() -> Dictionary:
	var items: Array = []
	for index: int in command_count:
		var command: AuraCommand = _commands[index]
		var item: Dictionary = {"kind":command.kind, "color":[command.color.r, command.color.g, command.color.b, command.color.a]}
		if command.kind == 2:
			item["point"] = [command.point.x, command.point.y]
			item["axes"] = [command.axes.x, command.axes.y]; item["rotation"] = command.rotation
		else:
			var curve: AuraCurve = _curves[command.curve_index]
			var points: Array = []; var alphas: Array = []
			for p: Vector2 in curve.points: points.append([p.x, p.y])
			for c: Color in curve.colors: alphas.append(c.a)
			item["points"] = points; item["alphas"] = alphas
			item["triangles"] = Array(curve.triangles)
		items.append(item)
	return {"id":aura_id, "reduced":reduced, "commands":items, "curves":curve_count, "vertices":vertex_count}
