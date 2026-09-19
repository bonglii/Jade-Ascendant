extends Control

## Sacred Cultivation Formation.
## Pure presentation + selection layer. ProgressionManager remains the authority.
## Authored-icon pass: generated Jade Ascendant icon family replaces prototype glyphs.

signal path_selected(path_id: String)

const PATH_IDS: Array[String] = ["vitality", "sword_power", "swift_qi"]
const NODE_POSITIONS: Dictionary = {
	"vitality": Vector2(0.20, 0.69),
	"sword_power": Vector2(0.50, 0.18),
	"swift_qi": Vector2(0.80, 0.69),
}
const NODE_TITLES: Dictionary = {
	"vitality": "VITALITY",
	"sword_power": "SWORD POWER",
	"swift_qi": "SWIFT QI",
}
const NODE_COLORS: Dictionary = {
	"vitality": Color(0.32, 0.96, 0.64, 1.0),
	"sword_power": Color(1.0, 0.75, 0.24, 1.0),
	"swift_qi": Color(0.28, 0.87, 1.0, 1.0),
}
const PATH_ICONS: Dictionary = {
	"vitality": preload("res://assets/ui/cultivation/meridian_vitality.png"),
	"sword_power": preload("res://assets/ui/cultivation/meridian_sword_power.png"),
	"swift_qi": preload("res://assets/ui/cultivation/meridian_swift_qi.png"),
}
const CORE_ICON: Texture2D = preload("res://assets/ui/cultivation/meridian_dao_core.png")

var state: Dictionary = {}
var selected_path: String = "vitality"
var hovered_path: String = ""
var celebration_path: String = ""
var celebration_strength: float = 0.0

var node_buttons: Dictionary = {}
var title_labels: Dictionary = {}
var level_labels: Dictionary = {}
var icon_rects: Dictionary = {}
var core_icon_rect: TextureRect = null
var core_title_label: Label = null
var core_level_label: Label = null


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
	celebration_strength = maxf(celebration_strength - delta * 1.55, 0.0)
	queue_redraw()


func _build_nodes() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	node_buttons.clear()
	title_labels.clear()
	level_labels.clear()
	icon_rects.clear()

	core_icon_rect = _make_icon_rect(CORE_ICON)
	core_icon_rect.name = "DaoCoreIcon"
	add_child(core_icon_rect)

	core_title_label = _make_center_label("DAO CORE", 16, Color(1.0, 0.88, 0.52, 1.0))
	core_title_label.name = "CoreTitle"
	add_child(core_title_label)
	core_level_label = _make_center_label("0 / 30", 12, Color(0.49, 0.98, 0.87, 1.0))
	core_level_label.name = "CoreLevel"
	add_child(core_level_label)

	for path_id: String in PATH_IDS:
		var button := Button.new()
		button.name = path_id.capitalize().replace("_", "") + "Hit"
		button.flat = true
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_empty_styles(button)
		button.pressed.connect(_on_path_pressed.bind(path_id))
		button.mouse_entered.connect(_on_hover_changed.bind(path_id, true))
		button.mouse_exited.connect(_on_hover_changed.bind(path_id, false))
		button.focus_entered.connect(_on_hover_changed.bind(path_id, true))
		button.focus_exited.connect(_on_hover_changed.bind(path_id, false))
		add_child(button)
		node_buttons[path_id] = button

		var icon := _make_icon_rect(PATH_ICONS[path_id] as Texture2D)
		icon.name = path_id.capitalize().replace("_", "") + "Icon"
		add_child(icon)
		icon_rects[path_id] = icon

		var title := _make_center_label(tr(str(NODE_TITLES[path_id])), 15, Color(0.76, 0.83, 0.81, 0.98))
		add_child(title)
		title_labels[path_id] = title

		var level := _make_center_label("Lv.0 / 10", 11, Color(0.54, 0.67, 0.64, 0.96))
		add_child(level)
		level_labels[path_id] = level

	call_deferred("_layout_nodes")


func _make_icon_rect(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func _make_center_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	label.text = value
	return label


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
		var path_state: Dictionary = state.get(path_id, {})
		total_level += int(path_state.get("level", 0))
		total_max += int(path_state.get("max_level", 10))
	if core_level_label != null:
		core_level_label.text = "%d / %d" % [total_level, total_max]

	for path_id: String in PATH_IDS:
		var title: Label = title_labels.get(path_id) as Label
		var level_label: Label = level_labels.get(path_id) as Label
		if title == null or level_label == null:
			continue
		var path_state: Dictionary = state.get(path_id, {})
		var level: int = int(path_state.get("level", 0))
		var max_level: int = int(path_state.get("max_level", 10))
		var selected: bool = path_id == selected_path
		var affordable: bool = bool(path_state.get("affordable", false))
		var accent: Color = NODE_COLORS[path_id]
		level_label.text = "Lv.%d / %d" % [level, max_level]
		title.add_theme_color_override("font_color", accent if selected else Color(0.80, 0.87, 0.85, 0.98))
		level_label.add_theme_color_override("font_color", Color(1.0, 0.89, 0.61, 1.0) if selected else (accent.lerp(Color.WHITE, 0.25) if affordable else Color(0.60, 0.72, 0.69, 0.96)))


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


func _round_vec2(value: Vector2) -> Vector2:
	return Vector2(roundf(value.x), roundf(value.y))


func _get_core_center() -> Vector2:
	if core_icon_rect != null:
		return _round_vec2(core_icon_rect.position + core_icon_rect.size * 0.5)
	return _round_vec2(Vector2(size.x * 0.50, size.y * 0.50))


func _get_visual_node_center(path_id: String) -> Vector2:
	var icon: TextureRect = icon_rects.get(path_id) as TextureRect
	if icon != null:
		return _round_vec2(icon.position + icon.size * 0.5)
	return _get_node_center(path_id)


func _layout_nodes() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var basis: float = minf(size.x, size.y)
	var node_size: float = clampf(basis * 0.225, 88.0, 120.0)
	var hit_size: float = node_size + 28.0
	var core_size: float = clampf(basis * 0.205, 82.0, 112.0)
	var label_width: float = clampf(size.x * 0.30, 110.0, 166.0)
	var core_center := _round_vec2(Vector2(size.x * 0.50, size.y * 0.50))

	if core_icon_rect != null:
		core_icon_rect.position = core_center - Vector2.ONE * core_size * 0.5
		core_icon_rect.size = Vector2.ONE * core_size
	if core_title_label != null:
		core_title_label.position = Vector2(core_center.x - 72.0, core_center.y + core_size * 0.48)
		core_title_label.size = Vector2(144.0, 22.0)
	if core_level_label != null:
		core_level_label.position = Vector2(core_center.x - 68.0, core_center.y + core_size * 0.48 + 21.0)
		core_level_label.size = Vector2(136.0, 18.0)

	for path_id: String in PATH_IDS:
		var center := _get_node_center(path_id)
		var button: Button = node_buttons.get(path_id) as Button
		var icon: TextureRect = icon_rects.get(path_id) as TextureRect
		var title: Label = title_labels.get(path_id) as Label
		var level_label: Label = level_labels.get(path_id) as Label
		if button == null or icon == null or title == null or level_label == null:
			continue
		button.position = center - Vector2.ONE * hit_size * 0.5
		button.size = Vector2.ONE * hit_size
		icon.position = center - Vector2.ONE * node_size * 0.5
		icon.size = Vector2.ONE * node_size
		title.position = Vector2(center.x - label_width * 0.5, center.y + node_size * 0.42)
		title.size = Vector2(label_width, 23.0)
		level_label.position = Vector2(center.x - label_width * 0.5, center.y + node_size * 0.42 + 22.0)
		level_label.size = Vector2(label_width, 18.0)


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var center := _get_core_center()
	var radius: float = minf(size.x, size.y) * 0.245
	_draw_sanctum(center, radius)
	_draw_channels(center)
	_draw_core_state(center, radius)
	_draw_node_states()


func _draw_sanctum(center: Vector2, radius: float) -> void:
	draw_circle(center, radius + 44.0, Color(0.0, 0.02, 0.03, 0.15))
	draw_arc(center, radius + 34.0, 0.0, TAU, 96, Color(0.30, 0.94, 0.80, 0.24), 1.4, true)
	draw_arc(center, radius + 13.0, 0.0, TAU, 96, Color(0.98, 0.80, 0.36, 0.20), 1.2, true)
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0 - PI * 0.5
		var point := center + Vector2(cos(angle), sin(angle)) * (radius + 34.0)
		var color := Color(0.98, 0.80, 0.36, 0.54) if index % 2 == 0 else Color(0.38, 0.91, 0.80, 0.50)
		draw_circle(point, 2.2, color)


func _draw_channels(center: Vector2) -> void:
	for path_id: String in PATH_IDS:
		var node_center := _get_visual_node_center(path_id)
		var selected: bool = path_id == selected_path
		var path_state: Dictionary = state.get(path_id, {})
		var level: int = int(path_state.get("level", 0))
		var max_level: int = maxi(int(path_state.get("max_level", 10)), 1)
		var progress: float = clampf(float(level) / float(max_level), 0.0, 1.0)
		var accent: Color = NODE_COLORS[path_id]
		draw_line(center, node_center, Color(0.0, 0.0, 0.0, 0.64), 6.0, true)
		draw_line(center, node_center, Color(accent.r, accent.g, accent.b, 0.70 if selected else 0.28), 3.0 if selected else 2.0, true)
		draw_line(center, center.lerp(node_center, progress), Color(0.99, 0.81, 0.36, 0.90), 1.4, true)


func _draw_core_state(center: Vector2, radius: float) -> void:
	var total_level: int = 0
	var total_max: int = 0
	for path_id: String in PATH_IDS:
		var path_state: Dictionary = state.get(path_id, {})
		total_level += int(path_state.get("level", 0))
		total_max += int(path_state.get("max_level", 10))
	var progress: float = 0.0 if total_max <= 0 else clampf(float(total_level) / float(total_max), 0.0, 1.0)
	var core_radius: float = clampf(radius * 0.46, 46.0, 66.0)
	for step: int in range(3, 0, -1):
		draw_circle(center, core_radius + float(step) * 8.0, Color(0.12, 0.80, 0.70, 0.018 * float(step)))
	draw_arc(center, core_radius + 9.0, 0.0, TAU, 72, Color(0.34, 0.96, 0.82, 0.45), 1.5, true)
	draw_arc(center, core_radius + 13.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 72, Color(1.0, 0.80, 0.30, 0.96), 3.0, true)


func _draw_node_states() -> void:
	var basis: float = minf(size.x, size.y)
	var node_radius: float = clampf(basis * 0.125, 48.0, 66.0)
	for path_id: String in PATH_IDS:
		var center := _get_visual_node_center(path_id)
		var path_state: Dictionary = state.get(path_id, {})
		var level: int = int(path_state.get("level", 0))
		var max_level: int = maxi(int(path_state.get("max_level", 10)), 1)
		var progress: float = clampf(float(level) / float(max_level), 0.0, 1.0)
		var selected: bool = path_id == selected_path
		var hovered: bool = path_id == hovered_path
		var affordable: bool = bool(path_state.get("affordable", false))
		var maxed: bool = bool(path_state.get("maxed", false))
		var accent: Color = NODE_COLORS[path_id]

		if selected or hovered:
			draw_circle(center, node_radius + 8.0, Color(accent.r, accent.g, accent.b, 0.07 if selected else 0.035))
		draw_arc(center, node_radius + 6.0, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.92 if selected else 0.34), 2.4 if selected else 1.3, true)
		draw_arc(center, node_radius + 11.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, Color(1.0, 0.82, 0.36, 0.94), 2.5, true)

		if affordable or maxed:
			var badge_position := center + Vector2(node_radius * 0.73, -node_radius * 0.73)
			var badge_fill := Color(0.05, 0.37, 0.29, 0.98) if not maxed else Color(0.42, 0.29, 0.04, 0.98)
			var badge_border := Color(0.43, 1.0, 0.80, 0.96) if not maxed else Color(1.0, 0.83, 0.35, 0.98)
			draw_circle(badge_position, 8.0, badge_fill)
			draw_arc(badge_position, 8.0, 0.0, TAU, 24, badge_border, 1.4, true)
			draw_circle(badge_position, 2.7, badge_border)

		if celebration_path == path_id and celebration_strength > 0.0:
			var burst_radius: float = node_radius + 12.0 + (1.0 - celebration_strength) * 36.0
			draw_arc(center, burst_radius, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, celebration_strength * 0.92), 3.0, true)
			draw_arc(center, burst_radius + 9.0, 0.0, TAU, 64, Color(1.0, 0.82, 0.36, celebration_strength * 0.62), 1.4, true)


func _get_node_center(path_id: String) -> Vector2:
	if not NODE_POSITIONS.has(path_id):
		return Vector2.ZERO
	var normalized: Vector2 = NODE_POSITIONS[path_id]
	return _round_vec2(Vector2(size.x * normalized.x, size.y * normalized.y))
