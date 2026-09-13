extends Control

## Sacred Cultivation Formation.
## Pure presentation + selection layer. It never purchases or saves progression.

signal path_selected(path_id: String)

const PATH_IDS: Array[String] = ["vitality", "sword_power", "swift_qi"]
const NODE_POSITIONS: Dictionary = {
	"vitality": Vector2(0.22, 0.69),
	"sword_power": Vector2(0.76, 0.28),
	"swift_qi": Vector2(0.79, 0.72)
}
const NODE_TITLES: Dictionary = {
	"vitality": "VITALITY",
	"sword_power": "SWORD POWER",
	"swift_qi": "SWIFT QI"
}

var state: Dictionary = {}
var selected_path: String = "vitality"
var node_buttons: Dictionary = {}
var title_labels: Dictionary = {}
var level_labels: Dictionary = {}
var core_title_label: Label = null
var core_level_label: Label = null
var hovered_path: String = ""
var celebration_path: String = ""
var celebration_strength: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)
	_build_nodes()
	set_process(false)
	queue_redraw()

func set_state(new_state: Dictionary, new_selected_path: String) -> void:
	state = new_state.duplicate(true)
	selected_path = new_selected_path
	_refresh_labels()
	_layout_nodes()
	queue_redraw()

func set_selected_path(path_id: String) -> void:
	if not PATH_IDS.has(path_id):
		return
	selected_path = path_id
	_refresh_labels()
	queue_redraw()

func celebrate(path_id: String) -> void:
	if not PATH_IDS.has(path_id):
		return
	celebration_path = path_id
	celebration_strength = 1.0
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if celebration_strength <= 0.0:
		celebration_strength = 0.0
		celebration_path = ""
		set_process(false)
		queue_redraw()
		return
	celebration_strength = maxf(celebration_strength - delta * 1.8, 0.0)
	queue_redraw()

func _build_nodes() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	node_buttons.clear()
	title_labels.clear()
	level_labels.clear()

	core_title_label = Label.new()
	core_title_label.name = "CoreTitle"
	core_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	core_title_label.add_theme_font_size_override("font_size", 13)
	core_title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 0.96))
	core_title_label.text = "DAO CORE"
	add_child(core_title_label)

	core_level_label = Label.new()
	core_level_label.name = "CoreLevel"
	core_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	core_level_label.add_theme_font_size_override("font_size", 10)
	core_level_label.add_theme_color_override("font_color", Color(0.38, 0.94, 0.80, 0.96))
	add_child(core_level_label)

	for path_id: String in PATH_IDS:
		var button: Button = Button.new()
		button.name = path_id.capitalize().replace("_", "") + "Hit"
		button.flat = true
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = Vector2(142.0, 118.0)
		_apply_empty_styles(button)
		button.pressed.connect(_on_path_pressed.bind(path_id))
		button.mouse_entered.connect(_on_hover_changed.bind(path_id, true))
		button.mouse_exited.connect(_on_hover_changed.bind(path_id, false))
		button.focus_entered.connect(_on_hover_changed.bind(path_id, true))
		button.focus_exited.connect(_on_hover_changed.bind(path_id, false))
		add_child(button)
		node_buttons[path_id] = button

		var title_label: Label = Label.new()
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 13)
		title_label.text = str(NODE_TITLES[path_id])
		add_child(title_label)
		title_labels[path_id] = title_label

		var level_label: Label = Label.new()
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 10)
		add_child(level_label)
		level_labels[path_id] = level_label

	call_deferred("_layout_nodes")

func _apply_empty_styles(button: Button) -> void:
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())

func _refresh_labels() -> void:
	var total_level: int = 0
	var total_max: int = 0
	for path_id: String in PATH_IDS:
		var path_state_for_total: Dictionary = state.get(path_id, {})
		total_level += int(path_state_for_total.get("level", 0))
		total_max += int(path_state_for_total.get("max_level", 10))
	if core_level_label != null:
		core_level_label.text = "%d / %d" % [total_level, total_max]

	for path_id: String in PATH_IDS:
		var title_label: Label = title_labels.get(path_id) as Label
		var level_label: Label = level_labels.get(path_id) as Label
		if title_label == null or level_label == null:
			continue
		var path_state: Dictionary = state.get(path_id, {})
		var level: int = int(path_state.get("level", 0))
		var max_level: int = int(path_state.get("max_level", 10))
		var selected: bool = path_id == selected_path
		var maxed: bool = bool(path_state.get("maxed", false))
		var affordable: bool = bool(path_state.get("affordable", false))

		level_label.text = "Lv.%d / %d" % [level, max_level]
		if maxed:
			level_label.text += "  •  PERFECTED"
		elif affordable:
			level_label.text += "  •  READY"

		var title_color: Color = Color(0.78, 0.84, 0.80, 0.96)
		var level_color: Color = Color(0.50, 0.63, 0.59, 0.92)
		if selected:
			title_color = Color(1.0, 0.86, 0.48, 1.0)
			level_color = Color(0.36, 0.90, 0.76, 1.0)
		elif affordable:
			title_color = Color(0.74, 0.94, 0.86, 1.0)
			title_color.a = 0.96
		title_label.add_theme_color_override("font_color", title_color)
		level_label.add_theme_color_override("font_color", level_color)

func _on_path_pressed(path_id: String) -> void:
	set_selected_path(path_id)
	path_selected.emit(path_id)

func _on_hover_changed(path_id: String, hovered: bool) -> void:
	if hovered:
		hovered_path = path_id
	elif hovered_path == path_id:
		hovered_path = ""
	queue_redraw()

func _on_resized() -> void:
	_layout_nodes()
	queue_redraw()

func _layout_nodes() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var core_center: Vector2 = Vector2(size.x * 0.50, size.y * 0.50)
	if core_title_label != null:
		core_title_label.position = Vector2(core_center.x - 58.0, core_center.y - 5.0)
		core_title_label.size = Vector2(116.0, 20.0)
	if core_level_label != null:
		core_level_label.position = Vector2(core_center.x - 58.0, core_center.y + 14.0)
		core_level_label.size = Vector2(116.0, 18.0)

	for path_id: String in PATH_IDS:
		var button: Button = node_buttons.get(path_id) as Button
		var title_label: Label = title_labels.get(path_id) as Label
		var level_label: Label = level_labels.get(path_id) as Label
		if button == null or title_label == null or level_label == null:
			continue
		var normalized: Vector2 = NODE_POSITIONS[path_id]
		var center: Vector2 = Vector2(size.x * normalized.x, size.y * normalized.y)
		var button_size: Vector2 = Vector2(142.0, 118.0)
		button.position = center - button_size * 0.5
		button.size = button_size

		title_label.position = Vector2(center.x - 72.0, center.y + 43.0)
		title_label.size = Vector2(144.0, 20.0)
		level_label.position = Vector2(center.x - 80.0, center.y + 61.0)
		level_label.size = Vector2(160.0, 18.0)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center: Vector2 = Vector2(size.x * 0.50, size.y * 0.50)
	var base_radius: float = minf(size.x, size.y) * 0.30
	_draw_sanctum(center, base_radius)
	_draw_channels(center)
	_draw_core(center, base_radius)
	_draw_nodes()

func _draw_sanctum(center: Vector2, radius: float) -> void:
	draw_circle(center, radius + 58.0, Color(0.0, 0.02, 0.03, 0.28))
	draw_circle(center, radius + 16.0, Color(0.0, 0.08, 0.08, 0.18))
	draw_arc(center, radius + 44.0, 0.0, TAU, 96, Color(0.24, 0.90, 0.78, 0.22), 1.0, true)
	draw_arc(center, radius + 29.0, 0.0, TAU, 96, Color(0.98, 0.80, 0.36, 0.28), 1.0, true)
	draw_arc(center, radius + 8.0, 0.0, TAU, 96, Color(0.28, 0.96, 0.82, 0.42), 1.4, true)
	draw_arc(center, radius - 18.0, 0.0, TAU, 96, Color(0.96, 0.79, 0.36, 0.18), 1.0, true)

	for index: int in range(12):
		var angle: float = TAU * float(index) / 12.0 - PI * 0.5
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + 31.0)
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + 43.0)
		draw_line(inner, outer, Color(0.37, 0.88, 0.78, 0.30), 1.0, true)
		_draw_rune(outer, angle, index)

func _draw_rune(rune_position: Vector2, angle: float, index: int) -> void:
	var tangent: Vector2 = Vector2(-sin(angle), cos(angle))
	var radial: Vector2 = Vector2(cos(angle), sin(angle))
	var gold: Color = Color(0.96, 0.79, 0.36, 0.48)
	if index % 2 == 0:
		draw_line(rune_position - tangent * 4.0, rune_position + tangent * 4.0, gold, 1.0, true)
		draw_line(rune_position - radial * 3.0, rune_position + radial * 3.0, gold, 1.0, true)
	else:
		var points: PackedVector2Array = PackedVector2Array([
			rune_position + radial * -4.0,
			rune_position + tangent * 4.0,
			rune_position + radial * 4.0,
			rune_position - tangent * 4.0,
			rune_position + radial * -4.0
		])
		draw_polyline(points, gold, 1.0, true)

func _draw_channels(center: Vector2) -> void:
	for path_id: String in PATH_IDS:
		var node_center: Vector2 = _get_node_center(path_id)
		if node_center == Vector2.ZERO:
			continue
		var selected: bool = path_id == selected_path
		var path_state: Dictionary = state.get(path_id, {})
		var level: int = int(path_state.get("level", 0))
		var max_level: int = maxi(int(path_state.get("max_level", 10)), 1)
		var progress: float = clampf(float(level) / float(max_level), 0.0, 1.0)
		var channel_color: Color = Color(0.18, 0.54, 0.50, 0.42)
		if selected:
			channel_color = Color(0.31, 0.92, 0.78, 0.92)
		draw_line(center, node_center, Color(0.0, 0.0, 0.0, 0.58), 5.0, true)
		draw_line(center, node_center, channel_color, 2.0, true)
		var progress_end: Vector2 = center.lerp(node_center, progress)
		draw_line(center, progress_end, Color(0.98, 0.80, 0.36, 0.90), 1.2, true)
		_draw_channel_glyph(center.lerp(node_center, 0.58), selected)

func _draw_channel_glyph(glyph_position: Vector2, selected: bool) -> void:
	var color: Color = Color(0.96, 0.79, 0.36, 0.56)
	if selected:
		color = Color(0.38, 0.96, 0.82, 0.90)
	var points: PackedVector2Array = PackedVector2Array([
		glyph_position + Vector2(0.0, -5.0),
		glyph_position + Vector2(5.0, 0.0),
		glyph_position + Vector2(0.0, 5.0),
		glyph_position + Vector2(-5.0, 0.0),
		glyph_position + Vector2(0.0, -5.0)
	])
	draw_polyline(points, color, 1.2, true)
	draw_circle(glyph_position, 1.5, color)

func _draw_core(center: Vector2, radius: float) -> void:
	var core_radius: float = radius * 0.37
	draw_circle(center + Vector2(0.0, 4.0), core_radius + 8.0, Color(0.0, 0.0, 0.0, 0.54))
	draw_circle(center, core_radius + 7.0, Color(0.01, 0.10, 0.10, 0.86))
	draw_arc(center, core_radius + 7.0, 0.0, TAU, 64, Color(0.96, 0.79, 0.36, 0.72), 2.0, true)
	draw_arc(center, core_radius, 0.0, TAU, 64, Color(0.32, 0.92, 0.79, 0.78), 2.0, true)
	draw_circle(center, core_radius * 0.68, Color(0.02, 0.22, 0.19, 0.82))
	draw_arc(center, core_radius + 15.0, 0.0, TAU, 72, Color(0.27, 0.90, 0.78, 0.20), 1.2, true)
	_draw_core_lotus(center, core_radius * 0.88)
	_draw_core_symbol(center + Vector2(0.0, -16.0), core_radius * 0.40)

func _draw_core_lotus(center: Vector2, radius: float) -> void:
	var jade: Color = Color(0.32, 0.92, 0.79, 0.30)
	var gold: Color = Color(0.96, 0.79, 0.36, 0.26)
	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0 - PI * 0.5
		var radial: Vector2 = Vector2(cos(angle), sin(angle))
		var tangent: Vector2 = Vector2(-sin(angle), cos(angle))
		var base: Vector2 = center + radial * (radius * 0.72)
		var tip: Vector2 = center + radial * (radius * 1.10)
		var left: Vector2 = base + tangent * (radius * 0.17)
		var right: Vector2 = base - tangent * (radius * 0.17)
		var petal: PackedVector2Array = PackedVector2Array([left, tip, right])
		draw_polyline(petal, jade if index % 2 == 0 else gold, 1.1, true)

func _draw_core_symbol(center: Vector2, radius: float) -> void:
	var gold: Color = Color(1.0, 0.84, 0.43, 0.94)
	var jade: Color = Color(0.34, 0.96, 0.82, 0.92)
	draw_arc(center + Vector2(0.0, -radius * 0.22), radius * 0.48, 0.0, PI, 32, gold, 2.0, true)
	draw_arc(center + Vector2(0.0, radius * 0.22), radius * 0.48, PI, TAU, 32, jade, 2.0, true)
	draw_circle(center + Vector2(-radius * 0.18, 0.0), 2.4, jade)
	draw_circle(center + Vector2(radius * 0.18, 0.0), 2.4, gold)

func _draw_nodes() -> void:
	for path_id: String in PATH_IDS:
		var center: Vector2 = _get_node_center(path_id)
		if center == Vector2.ZERO:
			continue
		var path_state: Dictionary = state.get(path_id, {})
		var level: int = int(path_state.get("level", 0))
		var max_level: int = maxi(int(path_state.get("max_level", 10)), 1)
		var maxed: bool = bool(path_state.get("maxed", false))
		var affordable: bool = bool(path_state.get("affordable", false))
		var selected: bool = path_id == selected_path
		var hovered: bool = path_id == hovered_path
		var radius: float = 32.0

		if selected or hovered:
			draw_circle(center, radius + 13.0, Color(0.26, 0.90, 0.75, 0.14))
		if path_id == celebration_path and celebration_strength > 0.0:
			draw_circle(
				center,
				radius + 18.0 * celebration_strength,
				Color(0.42, 1.0, 0.82, 0.24 * celebration_strength)
			)

		var body: Color = Color(0.01, 0.055, 0.065, 0.98)
		var frame: Color = Color(0.46, 0.54, 0.50, 0.74)
		var inner: Color = Color(0.20, 0.50, 0.45, 0.60)
		if level > 0:
			body = Color(0.01, 0.13, 0.11, 0.98)
			frame = Color(0.96, 0.79, 0.36, 0.82)
			inner = Color(0.30, 0.86, 0.73, 0.72)
		if affordable:
			frame = Color(0.98, 0.83, 0.43, 0.98)
		if selected:
			body = Color(0.015, 0.20, 0.17, 1.0)
			frame = Color(1.0, 0.86, 0.48, 1.0)
			inner = Color(0.38, 0.98, 0.83, 1.0)
		if maxed:
			frame = Color(0.95, 0.90, 0.64, 1.0)

		draw_circle(center + Vector2(0.0, 4.0), radius + 4.0, Color(0.0, 0.0, 0.0, 0.60))
		draw_circle(center, radius + 3.0, Color(0.002, 0.015, 0.020, 0.98))
		draw_circle(center, radius, body)
		draw_arc(center, radius, 0.0, TAU, 48, frame, 2.0, true)
		draw_arc(center, radius - 7.0, 0.0, TAU, 48, inner, 1.0, true)

		var progress: float = clampf(float(level) / float(max_level), 0.0, 1.0)
		if progress > 0.0:
			draw_arc(
				center,
				radius + 5.5,
				-PI * 0.5,
				-PI * 0.5 + TAU * progress,
				48,
				Color(0.96, 0.79, 0.36, 0.96),
				2.0,
				true
			)
		_draw_path_icon(path_id, center, selected)

func _draw_path_icon(path_id: String, center: Vector2, selected: bool) -> void:
	var color: Color = Color(0.72, 0.84, 0.79, 0.94)
	if selected:
		color = Color(1.0, 0.88, 0.52, 1.0)
	match path_id:
		"vitality":
			var points: PackedVector2Array = PackedVector2Array([
				center + Vector2(0.0, -11.0),
				center + Vector2(9.0, -3.0),
				center + Vector2(6.0, 8.0),
				center + Vector2(0.0, 13.0),
				center + Vector2(-6.0, 8.0),
				center + Vector2(-9.0, -3.0),
				center + Vector2(0.0, -11.0)
			])
			draw_polyline(points, color, 2.0, true)
			draw_circle(center, 3.0, color)
		"sword_power":
			draw_line(center + Vector2(-8.0, 10.0), center + Vector2(7.0, -10.0), color, 2.4, true)
			draw_line(center + Vector2(-4.0, 3.0), center + Vector2(4.0, 9.0), color, 1.8, true)
			draw_line(center + Vector2(4.0, 9.0), center + Vector2(8.0, 4.0), color, 1.8, true)
		"swift_qi":
			draw_arc(center + Vector2(-4.0, 0.0), 10.0, -1.2, 1.8, 24, color, 2.0, true)
			draw_arc(center + Vector2(5.0, 1.0), 8.0, 1.9, 4.9, 24, color, 2.0, true)
			draw_circle(center, 2.5, color)

func _get_node_center(path_id: String) -> Vector2:
	if not NODE_POSITIONS.has(path_id):
		return Vector2.ZERO
	var normalized: Vector2 = NODE_POSITIONS[path_id]
	return Vector2(size.x * normalized.x, size.y * normalized.y)
