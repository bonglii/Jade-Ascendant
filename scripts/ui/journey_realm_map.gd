extends Control

## Compact realm-path presentation for the Journey Hub.
## JourneyManager remains the authority for unlock, clear and selection state.
## This version intentionally draws the route in one parent Control so the map
## stays readable and stable across portrait aspect ratios.

signal stage_selected(chapter_id: int, stage_id: int)

const NORMAL_NODE_SIZE: Vector2 = Vector2(72.0, 72.0)
const BOSS_NODE_SIZE: Vector2 = Vector2(82.0, 82.0)
const STAGE_SELECTED_TEXTURE: Texture2D = preload("res://assets/ui/wuxia/stage_selected.png")
const STAGE_SOON_TEXTURE: Texture2D = preload("res://assets/ui/wuxia/stage_soon.png")
const STAGE_LOCKED_TEXTURE: Texture2D = preload("res://assets/ui/wuxia/stage_locked.png")
const STAGE_BOSS_TEXTURE: Texture2D = preload("res://assets/ui/wuxia/stage_boss.png")
const DEFAULT_POSITIONS: Array = [
	Vector2(0.27, 0.83),
	Vector2(0.72, 0.69),
	Vector2(0.36, 0.52),
	Vector2(0.76, 0.35),
	Vector2(0.42, 0.18)
]

var chapter_id: int = 1
var realm_profile: Dictionary = {}
var stage_buttons: Dictionary = {}
var number_labels: Dictionary = {}
var state_labels: Dictionary = {}
var hovered_stage_id: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)
	queue_redraw()

func setup(new_chapter_id: int, profile: Dictionary) -> void:
	chapter_id = new_chapter_id
	realm_profile = profile.duplicate(true)
	_rebuild_stage_nodes()

func refresh() -> void:
	if stage_buttons.is_empty():
		_rebuild_stage_nodes()
		return
	var stage_ids: Array = JourneyManager.get_stage_ids(chapter_id)
	for raw_stage_id: Variant in stage_ids:
		var stage_id: int = int(raw_stage_id)
		_refresh_stage_node(stage_id)
	_layout_nodes()
	queue_redraw()

func _rebuild_stage_nodes() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	stage_buttons.clear()
	number_labels.clear()
	state_labels.clear()

	var stage_ids: Array = JourneyManager.get_stage_ids(chapter_id)
	for raw_stage_id: Variant in stage_ids:
		var stage_id: int = int(raw_stage_id)
		var stage_data: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
		var is_boss: bool = bool(stage_data.get("is_chapter_boss", false))
		var node_size: Vector2 = BOSS_NODE_SIZE if is_boss else NORMAL_NODE_SIZE

		var hit_button: Button = Button.new()
		hit_button.name = "StageHit_%d" % stage_id
		hit_button.flat = true
		hit_button.text = ""
		hit_button.focus_mode = Control.FOCUS_ALL
		hit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit_button.custom_minimum_size = node_size
		hit_button.size = node_size
		_apply_empty_button_styles(hit_button)
		hit_button.pressed.connect(_on_stage_pressed.bind(stage_id))
		hit_button.mouse_entered.connect(_on_stage_hover_changed.bind(stage_id, true))
		hit_button.mouse_exited.connect(_on_stage_hover_changed.bind(stage_id, false))
		hit_button.focus_entered.connect(_on_stage_hover_changed.bind(stage_id, true))
		hit_button.focus_exited.connect(_on_stage_hover_changed.bind(stage_id, false))
		add_child(hit_button)
		stage_buttons[stage_id] = hit_button

		var number_label: Label = Label.new()
		number_label.name = "StageNumber_%d" % stage_id
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number_label.add_theme_font_size_override("font_size", 22 if is_boss else 20)
		add_child(number_label)
		number_labels[stage_id] = number_label

		var state_label: Label = Label.new()
		state_label.name = "StageState_%d" % stage_id
		state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state_label.add_theme_font_size_override("font_size", 11)
		add_child(state_label)
		state_labels[stage_id] = state_label

		_refresh_stage_node(stage_id)

	call_deferred("_layout_nodes")
	queue_redraw()

func _apply_empty_button_styles(button: Button) -> void:
	var empty_normal: StyleBoxEmpty = StyleBoxEmpty.new()
	var empty_hover: StyleBoxEmpty = StyleBoxEmpty.new()
	var empty_pressed: StyleBoxEmpty = StyleBoxEmpty.new()
	var empty_focus: StyleBoxEmpty = StyleBoxEmpty.new()
	var empty_disabled: StyleBoxEmpty = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_normal)
	button.add_theme_stylebox_override("hover", empty_hover)
	button.add_theme_stylebox_override("pressed", empty_pressed)
	button.add_theme_stylebox_override("focus", empty_focus)
	button.add_theme_stylebox_override("disabled", empty_disabled)

func _refresh_stage_node(stage_id: int) -> void:
	if not stage_buttons.has(stage_id):
		return
	var hit_button: Button = stage_buttons[stage_id] as Button
	var number_label: Label = number_labels.get(stage_id) as Label
	var state_label: Label = state_labels.get(stage_id) as Label
	if hit_button == null or number_label == null or state_label == null:
		return

	var stage_data: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
	var is_boss: bool = bool(stage_data.get("is_chapter_boss", false))
	var state: String = _get_stage_state(stage_id)
	var selected: bool = (
		JourneyManager.selected_chapter_id == chapter_id
		and JourneyManager.selected_stage_id == stage_id
	)

	hit_button.disabled = state == "LOCKED" or state == "COMING SOON"
	hit_button.tooltip_text = _build_tooltip(stage_id, state, is_boss)
	number_label.text = "%02d" % stage_id
	state_label.text = _get_state_label(state, selected, is_boss)
	state_label.visible = not state_label.text.is_empty()
	_apply_label_colors(number_label, state_label, state, selected)

func _get_stage_state(stage_id: int) -> String:
	if not JourneyManager.is_stage_unlocked(chapter_id, stage_id):
		return "LOCKED"
	if not JourneyManager.is_stage_implemented(chapter_id, stage_id):
		return "COMING SOON"
	if JourneyManager.is_stage_cleared(chapter_id, stage_id):
		return "CLEARED"
	return "AVAILABLE"

func _get_state_label(state: String, selected: bool, is_boss: bool) -> String:
	if selected and state != "COMING SOON" and state != "LOCKED":
		return "SELECTED"
	if is_boss:
		if state == "LOCKED":
			return "BOSS GATE"
		if state == "COMING SOON":
			return "BOSS • SOON"
	match state:
		"CLEARED":
			return "CLEARED"
		"AVAILABLE":
			return "READY"
		"COMING SOON":
			return "SOON"
		_:
			return ""

func _apply_label_colors(
	number_label: Label,
	state_label: Label,
	state: String,
	selected: bool
) -> void:
	var accent: Color = realm_profile.get(
		"accent",
		Color(0.298, 0.82, 0.647, 1.0)
	)
	var gold: Color = realm_profile.get(
		"gold",
		Color(0.957, 0.78, 0.357, 1.0)
	)
	var number_color: Color = Color(0.78, 0.80, 0.75, 0.88)
	var state_color: Color = Color(0.48, 0.54, 0.52, 0.90)

	if selected:
		number_color = Color(1.0, 0.94, 0.74, 1.0)
		state_color = gold
	elif state == "CLEARED" or state == "AVAILABLE":
		number_color = Color(0.92, 0.94, 0.86, 1.0)
		state_color = accent
	elif state == "COMING SOON":
		number_color = Color(gold.r, gold.g, gold.b, 0.62)
		state_color = Color(gold.r, gold.g, gold.b, 0.58)

	number_label.add_theme_color_override("font_color", number_color)
	state_label.add_theme_color_override("font_color", state_color)

func _build_tooltip(stage_id: int, state: String, is_boss: bool) -> String:
	var stage_data: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
	var display_name: String = str(
		stage_data.get("display_name", tr("Stage %d-%d") % [chapter_id, stage_id])
	)
	var trial_name: String = "Boss Gate" if is_boss else str(
		realm_profile.get("trial_label", "Cultivation Trial")
	)
	return "%s\n%s • %s" % [
		display_name,
		tr(trial_name),
		tr(_get_state_label(state, false, is_boss))
	]

func _on_stage_pressed(stage_id: int) -> void:
	if not JourneyManager.is_stage_unlocked(chapter_id, stage_id):
		return
	if not JourneyManager.is_stage_implemented(chapter_id, stage_id):
		return
	if not JourneyManager.select_stage(chapter_id, stage_id):
		return
	refresh()
	stage_selected.emit(chapter_id, stage_id)

func _on_stage_hover_changed(stage_id: int, hovered: bool) -> void:
	if hovered:
		hovered_stage_id = stage_id
	elif hovered_stage_id == stage_id:
		hovered_stage_id = -1
	queue_redraw()

func _on_resized() -> void:
	_layout_nodes()
	queue_redraw()

func _layout_nodes() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var stage_ids: Array = JourneyManager.get_stage_ids(chapter_id)
	var total: int = stage_ids.size()
	for index: int in range(total):
		var stage_id: int = int(stage_ids[index])
		var hit_button: Button = stage_buttons.get(stage_id) as Button
		var number_label: Label = number_labels.get(stage_id) as Label
		var state_label: Label = state_labels.get(stage_id) as Label
		if hit_button == null or number_label == null or state_label == null:
			continue

		var stage_data: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
		var is_boss: bool = bool(stage_data.get("is_chapter_boss", false))
		var node_size: Vector2 = BOSS_NODE_SIZE if is_boss else NORMAL_NODE_SIZE
		var normalized: Vector2 = _get_normalized_position(index, total)
		var center: Vector2 = Vector2(size.x * normalized.x, size.y * normalized.y)

		hit_button.size = node_size
		hit_button.position = center - node_size * 0.5

		number_label.size = node_size
		number_label.position = hit_button.position

		state_label.size = Vector2(88.0, 16.0)
		state_label.position = Vector2(
			center.x - state_label.size.x * 0.5,
			hit_button.position.y + node_size.y + 3.0
		)

func _get_normalized_position(index: int, total: int) -> Vector2:
	if index >= 0 and index < DEFAULT_POSITIONS.size():
		return DEFAULT_POSITIONS[index]
	if total <= 1:
		return Vector2(0.5, 0.5)
	var ratio: float = float(index) / float(maxi(total - 1, 1))
	var x: float = 0.5 + sin(ratio * PI * 3.0) * 0.22
	var y: float = 0.84 - ratio * 0.68
	return Vector2(x, y)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var accent: Color = realm_profile.get(
		"accent",
		Color(0.298, 0.82, 0.647, 1.0)
	)
	var gold: Color = realm_profile.get(
		"gold",
		Color(0.957, 0.78, 0.357, 1.0)
	)

	_draw_map_backplate(accent, gold)
	_draw_route(accent, gold)
	_draw_stage_nodes(accent, gold)

func _draw_map_backplate(accent: Color, gold: Color) -> void:
	var panel_rect: Rect2 = Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	draw_rect(panel_rect, Color(0.002, 0.018, 0.026, 0.06), true)
	draw_line(
		Vector2(size.x - 1.0, 22.0),
		Vector2(size.x - 1.0, size.y - 22.0),
		Color(gold.r, gold.g, gold.b, 0.08),
		1.0,
		true
	)
	draw_line(
		Vector2(1.0, size.y * 0.22),
		Vector2(1.0, size.y * 0.78),
		Color(accent.r, accent.g, accent.b, 0.08),
		1.0,
		true
	)

func _draw_route(accent: Color, gold: Color) -> void:
	var stage_ids: Array = JourneyManager.get_stage_ids(chapter_id)
	if stage_ids.size() < 2:
		return
	for index: int in range(stage_ids.size() - 1):
		var from_stage_id: int = int(stage_ids[index])
		var to_stage_id: int = int(stage_ids[index + 1])
		var from_center: Vector2 = _get_stage_center(from_stage_id)
		var to_center: Vector2 = _get_stage_center(to_stage_id)
		if from_center == Vector2.ZERO or to_center == Vector2.ZERO:
			continue

		draw_line(from_center, to_center, Color(0.0, 0.0, 0.0, 0.72), 8.0, true)
		draw_line(
			from_center,
			to_center,
			Color(accent.r, accent.g, accent.b, 0.42),
			4.0,
			true
		)
		if JourneyManager.is_stage_cleared(chapter_id, from_stage_id):
			draw_line(
				from_center,
				to_center,
				Color(gold.r, gold.g, gold.b, 0.82),
				1.5,
				true
			)
		_draw_path_rune(from_center.lerp(to_center, 0.5), accent, gold)

func _draw_stage_nodes(accent: Color, gold: Color) -> void:
	var stage_ids: Array = JourneyManager.get_stage_ids(chapter_id)
	for raw_stage_id: Variant in stage_ids:
		var stage_id: int = int(raw_stage_id)
		var hit_button: Button = stage_buttons.get(stage_id) as Button
		if hit_button == null:
			continue

		var stage_data: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
		var is_boss: bool = bool(stage_data.get("is_chapter_boss", false))
		var state: String = _get_stage_state(stage_id)
		var selected: bool = (
			JourneyManager.selected_chapter_id == chapter_id
			and JourneyManager.selected_stage_id == stage_id
		)
		var hovered: bool = hovered_stage_id == stage_id and not hit_button.disabled
		var center: Vector2 = hit_button.position + hit_button.size * 0.5
		var texture: Texture2D = _get_stage_texture(state, selected, is_boss)
		var draw_rect_value: Rect2 = Rect2(hit_button.position, hit_button.size)

		if selected or hovered:
			draw_circle(
				center,
				hit_button.size.x * 0.53,
				Color(accent.r, accent.g, accent.b, 0.13 if hovered else 0.20)
			)

		if texture != null:
			draw_texture_rect(texture, draw_rect_value, false)

		if selected:
			draw_arc(
				center,
				hit_button.size.x * 0.48,
				0.0,
				TAU,
				40,
				Color(gold.r, gold.g, gold.b, 0.88),
				1.6,
				true
			)

func _get_stage_texture(state: String, selected: bool, is_boss: bool) -> Texture2D:
	if is_boss:
		return STAGE_BOSS_TEXTURE
	if selected or state == "CLEARED" or state == "AVAILABLE":
		return STAGE_SELECTED_TEXTURE
	if state == "COMING SOON":
		return STAGE_SOON_TEXTURE
	return STAGE_LOCKED_TEXTURE

func _get_node_core_color(state: String, selected: bool, hovered: bool) -> Color:
	var color: Color
	match state:
		"CLEARED":
			color = Color(0.014, 0.16, 0.12, 0.98)
		"AVAILABLE":
			color = Color(0.012, 0.10, 0.13, 0.98)
		"COMING SOON":
			color = Color(0.038, 0.047, 0.050, 0.94)
		_:
			color = Color(0.025, 0.032, 0.034, 0.94)
	if selected or hovered:
		color = color.lightened(0.12)
	return color

func _get_node_frame_color(
	state: String,
	selected: bool,
	hovered: bool,
	gold: Color
) -> Color:
	if state == "LOCKED":
		return Color(0.30, 0.32, 0.31, 0.72)
	if state == "COMING SOON":
		return Color(gold.r, gold.g, gold.b, 0.52)
	if selected or hovered or state == "CLEARED":
		return gold
	return Color(gold.r, gold.g, gold.b, 0.80)

func _get_node_ring_color(
	state: String,
	selected: bool,
	hovered: bool,
	accent: Color
) -> Color:
	if state == "LOCKED" or state == "COMING SOON":
		return Color(0.28, 0.35, 0.33, 0.54)
	if selected or hovered:
		return accent
	return Color(accent.r, accent.g, accent.b, 0.68)

func _draw_node_marks(center: Vector2, radius: float, frame_color: Color) -> void:
	var mark_color: Color = Color(frame_color.r, frame_color.g, frame_color.b, 0.94)
	var mark_radius: float = 1.8
	draw_circle(center + Vector2(0.0, -radius), mark_radius, mark_color)
	draw_circle(center + Vector2(radius, 0.0), mark_radius, mark_color)
	draw_circle(center + Vector2(0.0, radius), mark_radius, mark_color)
	draw_circle(center + Vector2(-radius, 0.0), mark_radius, mark_color)

func _draw_boss_mark(center: Vector2, radius: float, frame_color: Color) -> void:
	var y: float = center.y - radius - 7.0
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(center.x - 11.0, y + 8.0),
		Vector2(center.x - 6.0, y),
		Vector2(center.x, y + 5.0),
		Vector2(center.x + 6.0, y),
		Vector2(center.x + 11.0, y + 8.0)
	])
	draw_polyline(points, frame_color, 2.0, true)

func _draw_clear_mark(
	center: Vector2,
	radius: float,
	accent: Color,
	gold: Color
) -> void:
	var badge_center: Vector2 = center + Vector2(radius * 0.69, -radius * 0.69)
	draw_circle(badge_center, 6.5, Color(0.004, 0.045, 0.038, 0.98))
	draw_arc(badge_center, 6.5, 0.0, TAU, 20, gold, 1.4, true)
	draw_line(
		badge_center + Vector2(-2.8, 0.0),
		badge_center + Vector2(-0.5, 2.4),
		accent,
		1.6,
		true
	)
	draw_line(
		badge_center + Vector2(-0.5, 2.4),
		badge_center + Vector2(3.2, -2.6),
		accent,
		1.6,
		true
	)

func _get_stage_center(stage_id: int) -> Vector2:
	var hit_button: Button = stage_buttons.get(stage_id) as Button
	if hit_button == null:
		return Vector2.ZERO
	return hit_button.position + hit_button.size * 0.5

func _draw_path_rune(rune_position: Vector2, accent: Color, gold: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		rune_position + Vector2(0.0, -4.0),
		rune_position + Vector2(4.0, 0.0),
		rune_position + Vector2(0.0, 4.0),
		rune_position + Vector2(-4.0, 0.0),
		rune_position + Vector2(0.0, -4.0)
	])
	draw_polyline(points, Color(gold.r, gold.g, gold.b, 0.72), 1.3, true)
	draw_circle(rune_position, 1.4, Color(accent.r, accent.g, accent.b, 0.92))
