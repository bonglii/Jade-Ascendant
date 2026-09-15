extends Control

## Sacred Cultivation Formation.
## Pure presentation + selection layer. It never purchases or saves progression.

signal path_selected(path_id: String)

const PATH_IDS: Array[String] = ["vitality", "sword_power", "swift_qi"]
# A balanced triangular layout reads more like a deliberate cultivation diagram
# and keeps every path equally important around the Dao Core.
const NODE_POSITIONS: Dictionary = {
	# Keep the three outer meridians clearly separated from the Dao Core.
	# These positions preserve a balanced triangle while leaving enough breathing
	# room for the full card bounds, state badges, and core progress ring.
	"vitality": Vector2(0.17, 0.73),
	"sword_power": Vector2(0.50, 0.16),
	"swift_qi": Vector2(0.83, 0.73)
}
const NODE_TITLES: Dictionary = {
	"vitality": "VITALITY",
	"sword_power": "SWORD POWER",
	"swift_qi": "SWIFT QI"
}
const NODE_COLORS: Dictionary = {
	"vitality": Color(0.32, 0.96, 0.64, 1.0),
	"sword_power": Color(1.0, 0.75, 0.24, 1.0),
	"swift_qi": Color(0.28, 0.87, 1.0, 1.0)
}

# One shared card geometry keeps every meridian equally spacious. The extra
# vertical room is intentional: icon rings, title and level must never feel
# pressed against the border on the 405x860 mobile viewport.
const NODE_CARD_SIZE: Vector2 = Vector2(190.0, 152.0)
const NODE_HIT_SIZE: Vector2 = Vector2(198.0, 160.0)

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
	celebration_strength = maxf(celebration_strength - delta * 1.65, 0.0)
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
	core_title_label.add_theme_font_size_override("font_size", 17)
	core_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52, 1.0))
	core_title_label.text = "DAO CORE"
	add_child(core_title_label)

	core_level_label = Label.new()
	core_level_label.name = "CoreLevel"
	core_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	core_level_label.add_theme_font_size_override("font_size", 13)
	core_level_label.add_theme_color_override("font_color", Color(0.49, 0.98, 0.87, 1.0))
	add_child(core_level_label)

	for path_id: String in PATH_IDS:
		var button := Button.new()
		button.name = path_id.capitalize().replace("_", "") + "Hit"
		button.flat = true
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = NODE_HIT_SIZE
		_apply_empty_styles(button)
		button.pressed.connect(_on_path_pressed.bind(path_id))
		button.mouse_entered.connect(_on_hover_changed.bind(path_id, true))
		button.mouse_exited.connect(_on_hover_changed.bind(path_id, false))
		button.focus_entered.connect(_on_hover_changed.bind(path_id, true))
		button.focus_exited.connect(_on_hover_changed.bind(path_id, false))
		add_child(button)
		node_buttons[path_id] = button

		var title_label := Label.new()
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 16)
		title_label.text = tr(str(NODE_TITLES[path_id]))
		add_child(title_label)
		title_labels[path_id] = title_label

		var level_label := Label.new()
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 12)
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
		# Keep the Dao Core readout compact. The header already explains that this
		# number is total meridian mastery, so repeating an English status here only
		# creates visual noise and localization inconsistency.
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
		var affordable: bool = bool(path_state.get("affordable", false))
		var accent: Color = NODE_COLORS[path_id]

		# State is communicated by the badge and card accent. Keeping the level row
		# numeric prevents READY/PERFECTED copy from overflowing or mixing languages.
		level_label.text = "Lv.%d / %d" % [level, max_level]

		var title_color := Color(0.76, 0.83, 0.81, 0.98)
		var level_color := Color(0.54, 0.67, 0.64, 0.96)
		if selected:
			title_color = accent
			level_color = Color(1.0, 0.89, 0.61, 1.0)
		elif affordable:
			title_color = accent.lerp(Color.WHITE, 0.18)
			title_color.a = 0.98
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
	var core_center := Vector2(size.x * 0.50, size.y * 0.50)
	# Reserve the upper half of the core for the Dao glyph and the lower half for
	# text. This prevents the decorative diamond from drawing through the label.
	if core_title_label != null:
		core_title_label.position = Vector2(core_center.x - 76.0, core_center.y + 5.0)
		core_title_label.size = Vector2(152.0, 22.0)
	if core_level_label != null:
		core_level_label.position = Vector2(core_center.x - 74.0, core_center.y + 27.0)
		core_level_label.size = Vector2(148.0, 18.0)

	for path_id: String in PATH_IDS:
		var button: Button = node_buttons.get(path_id) as Button
		var title_label: Label = title_labels.get(path_id) as Label
		var level_label: Label = level_labels.get(path_id) as Label
		if button == null or title_label == null or level_label == null:
			continue
		var normalized: Vector2 = NODE_POSITIONS[path_id]
		var center := Vector2(size.x * normalized.x, size.y * normalized.y)
		button.position = center - NODE_HIT_SIZE * 0.5
		button.size = NODE_HIT_SIZE
		# Keep generous internal breathing room around icon, title and level. The
		# labels intentionally share the card width instead of using per-node offsets.
		title_label.position = Vector2(center.x - 84.0, center.y + 18.0)
		title_label.size = Vector2(168.0, 23.0)
		level_label.position = Vector2(center.x - 84.0, center.y + 42.0)
		level_label.size = Vector2(168.0, 17.0)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center := Vector2(size.x * 0.50, size.y * 0.50)
	var base_radius: float = minf(size.x, size.y) * 0.245
	_draw_sanctum(center, base_radius)
	_draw_channels(center)
	_draw_core(center, base_radius)
	_draw_nodes()

func _draw_sanctum(center: Vector2, radius: float) -> void:
	# Keep the sanctum readable: two main rings, six seals and a soft inner field.
	draw_circle(center, radius + 54.0, Color(0.0, 0.02, 0.03, 0.20))
	draw_circle(center, radius + 14.0, Color(0.01, 0.10, 0.10, 0.08))
	draw_arc(center, radius + 43.0, -PI * 0.44, PI * 0.24, 48, Color(0.30, 0.94, 0.80, 0.34), 1.5, true)
	draw_arc(center, radius + 43.0, PI * 0.56, PI * 1.24, 48, Color(0.30, 0.94, 0.80, 0.34), 1.5, true)
	draw_arc(center, radius + 19.0, 0.0, TAU, 96, Color(0.98, 0.80, 0.36, 0.30), 1.25, true)

	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0 - PI * 0.5
		var seal_position := center + Vector2(cos(angle), sin(angle)) * (radius + 43.0)
		_draw_seal(seal_position, angle, index)

func _draw_seal(seal_position: Vector2, angle: float, index: int) -> void:
	var tangent := Vector2(-sin(angle), cos(angle))
	var radial := Vector2(cos(angle), sin(angle))
	var jade := Color(0.38, 0.91, 0.80, 0.54)
	var gold := Color(0.98, 0.80, 0.36, 0.58)
	var color: Color = gold if index % 2 == 0 else jade
	var diamond := PackedVector2Array([
		seal_position - radial * 5.0,
		seal_position + tangent * 5.0,
		seal_position + radial * 5.0,
		seal_position - tangent * 5.0,
		seal_position - radial * 5.0
	])
	draw_polyline(diamond, color, 1.15, true)
	draw_circle(seal_position, 1.6, color)

func _draw_channels(center: Vector2) -> void:
	for path_id: String in PATH_IDS:
		var node_center := _get_node_center(path_id)
		if node_center == Vector2.ZERO:
			continue
		var selected: bool = path_id == selected_path
		var path_state: Dictionary = state.get(path_id, {})
		var level: int = int(path_state.get("level", 0))
		var max_level: int = maxi(int(path_state.get("max_level", 10)), 1)
		var progress: float = clampf(float(level) / float(max_level), 0.0, 1.0)
		var accent: Color = NODE_COLORS[path_id]
		var channel_color := Color(accent.r, accent.g, accent.b, 0.30)
		if selected:
			channel_color.a = 0.88
		draw_line(center, node_center, Color(0.0, 0.0, 0.0, 0.66), 7.0, true)
		draw_line(center, node_center, channel_color, 3.2 if selected else 2.1, true)
		var progress_end := center.lerp(node_center, progress)
		draw_line(center, progress_end, Color(0.99, 0.81, 0.36, 0.94), 1.5, true)
		_draw_channel_glyph(center.lerp(node_center, 0.62), selected, accent)

func _draw_channel_glyph(glyph_position: Vector2, selected: bool, accent: Color) -> void:
	var color := Color(0.96, 0.79, 0.36, 0.56)
	if selected:
		color = accent
	var points := PackedVector2Array([
		glyph_position + Vector2(0.0, -6.0),
		glyph_position + Vector2(6.0, 0.0),
		glyph_position + Vector2(0.0, 6.0),
		glyph_position + Vector2(-6.0, 0.0),
		glyph_position + Vector2(0.0, -6.0)
	])
	draw_polyline(points, color, 1.25, true)
	draw_circle(glyph_position, 1.8, color)

func _draw_core(center: Vector2, radius: float) -> void:
	var total_level: int = 0
	var total_max: int = 0
	for path_id: String in PATH_IDS:
		var path_state: Dictionary = state.get(path_id, {})
		total_level += int(path_state.get("level", 0))
		total_max += int(path_state.get("max_level", 10))
	var progress: float = 0.0 if total_max <= 0 else clampf(float(total_level) / float(total_max), 0.0, 1.0)
	var core_radius: float = radius * 0.48

	# A restrained prestige halo makes the core the clear focal point without ring clutter.
	for step: int in range(4, 0, -1):
		var glow_radius: float = core_radius + float(step) * 10.0
		draw_circle(center, glow_radius, Color(0.12, 0.80, 0.70, 0.014 * float(step)))
	draw_circle(center, core_radius + 14.0, Color(0.001, 0.022, 0.031, 0.98))
	draw_circle(center, core_radius + 3.0, Color(0.006, 0.068, 0.074, 0.96))
	draw_arc(center, core_radius + 14.0, 0.0, TAU, 96, Color(0.34, 0.96, 0.82, 0.66), 1.7, true)
	draw_arc(center, core_radius + 20.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 96, Color(1.0, 0.80, 0.30, 1.0), 4.0, true)

	# Dao glyph lives above the text instead of behind it. A smaller emblem keeps
	# the core prestigious without sacrificing readability at 405x860.
	var glyph_center := center + Vector2(0.0, -24.0)
	var diamond := PackedVector2Array([
		glyph_center + Vector2(0.0, -22.0),
		glyph_center + Vector2(19.0, 0.0),
		glyph_center + Vector2(0.0, 22.0),
		glyph_center + Vector2(-19.0, 0.0),
		glyph_center + Vector2(0.0, -22.0)
	])
	draw_colored_polygon(PackedVector2Array(diamond.slice(0, 4)), Color(0.025, 0.18, 0.18, 0.64))
	draw_polyline(diamond, Color(0.99, 0.81, 0.37, 0.90), 1.7, true)
	var inner_diamond := PackedVector2Array([
		glyph_center + Vector2(0.0, -13.0),
		glyph_center + Vector2(11.0, 0.0),
		glyph_center + Vector2(0.0, 13.0),
		glyph_center + Vector2(-11.0, 0.0),
		glyph_center + Vector2(0.0, -13.0)
	])
	draw_polyline(inner_diamond, Color(0.43, 0.98, 0.85, 0.58), 1.2, true)
	draw_circle(glyph_center, 7.0, Color(0.41, 1.0, 0.86, 0.90))
	draw_circle(glyph_center, 3.0, Color(1.0, 0.92, 0.58, 1.0))

func _draw_nodes() -> void:
	for path_id: String in PATH_IDS:
		var center := _get_node_center(path_id)
		if center == Vector2.ZERO:
			continue
		var path_state: Dictionary = state.get(path_id, {})
		var level: int = int(path_state.get("level", 0))
		var max_level: int = maxi(int(path_state.get("max_level", 10)), 1)
		var maxed: bool = bool(path_state.get("maxed", false))
		var affordable: bool = bool(path_state.get("affordable", false))
		var selected: bool = path_id == selected_path
		var hovered: bool = path_id == hovered_path
		var accent: Color = NODE_COLORS[path_id]
		var progress: float = clampf(float(level) / float(max_level), 0.0, 1.0)
		var card_rect := Rect2(center - NODE_CARD_SIZE * 0.5, NODE_CARD_SIZE)

		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.002, 0.025, 0.034, 0.94 if selected else 0.84)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		var border := Color(accent.r, accent.g, accent.b, 0.90 if selected else 0.38)
		if hovered:
			border.a = 0.74
		card_style.border_color = border
		card_style.corner_radius_top_left = 15
		card_style.corner_radius_top_right = 15
		card_style.corner_radius_bottom_left = 15
		card_style.corner_radius_bottom_right = 15
		card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
		card_style.shadow_size = 9 if selected else 5
		draw_style_box(card_style, card_rect)

		# Selected path receives one clean luminous cap instead of extra decorative rings.
		if selected:
			draw_line(
				Vector2(card_rect.position.x + 18.0, card_rect.position.y + 3.0),
				Vector2(card_rect.end.x - 18.0, card_rect.position.y + 3.0),
				Color(accent.r, accent.g, accent.b, 0.96),
				2.4,
				true
			)
		elif hovered:
			draw_line(
				Vector2(card_rect.position.x + 24.0, card_rect.position.y + 3.0),
				Vector2(card_rect.end.x - 24.0, card_rect.position.y + 3.0),
				Color(accent.r, accent.g, accent.b, 0.54),
				1.5,
				true
			)

		var icon_center := center + Vector2(0.0, -18.0)
		for glow_step: int in range(3, 0, -1):
			var glow_alpha: float = (0.020 if selected else 0.009) * float(glow_step)
			draw_circle(icon_center, 34.0 + glow_step * 5.0, Color(accent.r, accent.g, accent.b, glow_alpha))
		draw_circle(icon_center, 32.0, Color(0.002, 0.046, 0.057, 0.96))
		draw_arc(icon_center, 32.0, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.46), 1.6, true)
		draw_arc(icon_center, 37.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, accent, 3.2, true)
		_draw_path_icon(path_id, icon_center, accent)
		var badge_offset := Vector2(
			card_rect.size.x * 0.5 - 13.0,
			-card_rect.size.y * 0.5 + 14.0
		)
		_draw_state_badge(center + badge_offset, accent, affordable, maxed)

		if celebration_path == path_id and celebration_strength > 0.0:
			var burst_radius: float = 42.0 + (1.0 - celebration_strength) * 38.0
			draw_arc(icon_center, burst_radius, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, celebration_strength * 0.92), 3.2, true)
			draw_arc(icon_center, burst_radius + 11.0, 0.0, TAU, 64, Color(1.0, 0.82, 0.36, celebration_strength * 0.66), 1.6, true)

func _draw_state_badge(badge_position: Vector2, accent: Color, affordable: bool, maxed: bool) -> void:
	if not affordable and not maxed:
		return
	var fill := Color(0.05, 0.37, 0.29, 0.98)
	var border := Color(0.43, 1.0, 0.80, 0.96)
	if maxed:
		fill = Color(0.42, 0.29, 0.04, 0.98)
		border = Color(1.0, 0.83, 0.35, 0.98)
	draw_circle(badge_position, 9.0, fill)
	draw_arc(badge_position, 9.0, 0.0, TAU, 28, border, 1.4, true)
	if maxed:
		var diamond := PackedVector2Array([
			badge_position + Vector2(0.0, -4.0),
			badge_position + Vector2(4.0, 0.0),
			badge_position + Vector2(0.0, 4.0),
			badge_position + Vector2(-4.0, 0.0),
			badge_position + Vector2(0.0, -4.0)
		])
		draw_polyline(diamond, border, 1.2, true)
	else:
		draw_circle(badge_position, 3.0, accent.lerp(Color.WHITE, 0.28))

func _draw_path_icon(path_id: String, center: Vector2, color: Color) -> void:
	match path_id:
		"vitality":
			var heart := PackedVector2Array([
				center + Vector2(0.0, 17.0),
				center + Vector2(-16.0, 2.0),
				center + Vector2(-13.0, -11.0),
				center + Vector2(-3.0, -15.0),
				center,
				center + Vector2(3.0, -15.0),
				center + Vector2(13.0, -11.0),
				center + Vector2(16.0, 2.0),
				center + Vector2(0.0, 17.0)
			])
			draw_polyline(heart, color, 2.3, true)
			draw_line(center + Vector2(-8.0, 2.0), center + Vector2(-3.0, 2.0), Color(1, 1, 1, 0.75), 1.2, true)
			draw_line(center + Vector2(-3.0, 2.0), center + Vector2(0.0, -4.0), Color(1, 1, 1, 0.75), 1.2, true)
			draw_line(center + Vector2(0.0, -4.0), center + Vector2(4.0, 6.0), Color(1, 1, 1, 0.75), 1.2, true)
			draw_line(center + Vector2(4.0, 6.0), center + Vector2(9.0, 0.0), Color(1, 1, 1, 0.75), 1.2, true)
		"sword_power":
			draw_line(center + Vector2(0.0, -19.0), center + Vector2(0.0, 13.0), color, 3.0, true)
			draw_line(center + Vector2(-9.0, 7.0), center + Vector2(9.0, 7.0), color, 2.4, true)
			draw_line(center + Vector2(-5.0, 14.0), center + Vector2(5.0, 14.0), color, 2.4, true)
			var tip := PackedVector2Array([
				center + Vector2(0.0, -24.0),
				center + Vector2(-5.0, -15.0),
				center + Vector2(5.0, -15.0),
				center + Vector2(0.0, -24.0)
			])
			draw_polyline(tip, color, 2.0, true)
		"swift_qi":
			for ring_index: int in range(3):
				var ring_radius: float = 8.0 + ring_index * 6.0
				draw_arc(
					center,
					ring_radius,
					-PI * 0.80 + ring_index * 0.45,
					PI * 1.15 + ring_index * 0.35,
					28,
					Color(color.r, color.g, color.b, 0.95 - ring_index * 0.18),
					2.0,
					true
				)
			draw_circle(center, 3.5, Color(0.88, 1.0, 1.0, 1.0))

func _get_node_center(path_id: String) -> Vector2:
	if not NODE_POSITIONS.has(path_id):
		return Vector2.ZERO
	var normalized: Vector2 = NODE_POSITIONS[path_id]
	return Vector2(size.x * normalized.x, size.y * normalized.y)
