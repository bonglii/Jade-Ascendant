extends Button

## Interactive realm-map node for one Journey stage.
## Presentation-only: JourneyManager remains the authority for unlock/state.

var chapter_id: int = 0
var stage_id: int = 0
var state_name: String = "LOCKED"
var is_selected_stage: bool = false
var is_boss_stage: bool = false
var accent: Color = Color(0.298, 0.82, 0.647, 1.0)
var accent_soft: Color = Color(0.184, 0.62, 0.471, 1.0)
var gold: Color = Color(0.957, 0.78, 0.357, 1.0)
var _pressed_visual: bool = false

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", 19 if not is_boss_stage else 20)
	add_theme_color_override("font_color", Color(0.96, 0.93, 0.78, 1.0))
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", Color(0.48, 0.52, 0.50, 0.92))
	mouse_entered.connect(_queue_refresh)
	mouse_exited.connect(_queue_refresh)
	focus_entered.connect(_queue_refresh)
	focus_exited.connect(_queue_refresh)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	queue_redraw()

func configure(
	new_chapter_id: int,
	new_stage_id: int,
	new_state_name: String,
	selected: bool,
	boss_stage: bool,
	profile: Dictionary
) -> void:
	chapter_id = new_chapter_id
	stage_id = new_stage_id
	state_name = new_state_name
	is_selected_stage = selected
	is_boss_stage = boss_stage
	accent = profile.get("accent", accent)
	accent_soft = profile.get("accent_soft", accent_soft)
	gold = profile.get("gold", gold)
	text = "%02d" % stage_id
	disabled = state_name == "LOCKED" or state_name == "COMING SOON"
	custom_minimum_size = Vector2(94.0, 94.0) if is_boss_stage else Vector2(82.0, 82.0)
	add_theme_font_size_override("font_size", 20 if is_boss_stage else 19)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _queue_refresh() -> void:
	queue_redraw()

func _on_button_down() -> void:
	_pressed_visual = true
	queue_redraw()

func _on_button_up() -> void:
	_pressed_visual = false
	queue_redraw()

func _draw() -> void:
	var diameter: float = minf(size.x, size.y)
	if diameter < 24.0:
		return
	var center: Vector2 = size * 0.5
	var radius: float = diameter * 0.43
	var hovered: bool = is_hovered() and not disabled
	var active: bool = hovered or has_focus() or is_selected_stage
	var dim_factor: float = 0.46 if disabled else 1.0
	var core_color: Color = _get_core_color(active)
	var frame_color: Color = _get_frame_color(active)
	var ring_color: Color = _get_ring_color(active)

	if is_selected_stage:
		draw_circle(
			center,
			radius + 8.0,
			Color(accent.r, accent.g, accent.b, 0.10)
		)
		draw_circle(
			center,
			radius + 4.0,
			Color(gold.r, gold.g, gold.b, 0.08)
		)

	draw_circle(
		center + Vector2(0.0, 3.0),
		radius + 2.5,
		Color(0.0, 0.0, 0.0, 0.58 * dim_factor)
	)
	draw_circle(center, radius + 2.5, Color(0.008, 0.018, 0.020, 0.96 * dim_factor))
	draw_circle(center, radius, Color(core_color.r, core_color.g, core_color.b, core_color.a * dim_factor))
	draw_arc(center, radius, 0.0, TAU, 48, Color(frame_color.r, frame_color.g, frame_color.b, frame_color.a * dim_factor), 3.0, true)
	draw_arc(center, radius - 6.0, 0.0, TAU, 48, Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * dim_factor), 1.5, true)

	_draw_cardinal_marks(center, radius, frame_color, dim_factor)
	if is_boss_stage:
		_draw_boss_crown(center, radius, frame_color, dim_factor)
	elif state_name == "CLEARED":
		_draw_clear_mark(center, radius, dim_factor)

func _get_core_color(active: bool) -> Color:
	var color: Color
	match state_name:
		"CLEARED":
			color = Color(0.018, 0.20, 0.15, 0.98)
		"AVAILABLE":
			color = Color(0.014, 0.13, 0.16, 0.98)
		"COMING SOON":
			color = Color(0.055, 0.062, 0.065, 0.96)
		_:
			color = Color(0.030, 0.040, 0.042, 0.96)
	if active:
		color = color.lightened(0.12)
	if _pressed_visual:
		color = color.darkened(0.14)
	return color

func _get_frame_color(active: bool) -> Color:
	if state_name == "LOCKED":
		return Color(0.32, 0.34, 0.32, 0.72)
	if state_name == "COMING SOON":
		return Color(gold.r, gold.g, gold.b, 0.54)
	if active or state_name == "CLEARED":
		return gold
	return Color(gold.r, gold.g, gold.b, 0.82)

func _get_ring_color(active: bool) -> Color:
	if state_name == "LOCKED" or state_name == "COMING SOON":
		return Color(0.29, 0.36, 0.34, 0.55)
	if active:
		return accent
	return Color(accent.r, accent.g, accent.b, 0.68)

func _draw_cardinal_marks(
	center: Vector2,
	radius: float,
	frame_color: Color,
	dim_factor: float
) -> void:
	var mark_color: Color = Color(
		frame_color.r,
		frame_color.g,
		frame_color.b,
		0.92 * dim_factor
	)
	var mark_radius: float = 2.1
	draw_circle(center + Vector2(0.0, -radius), mark_radius, mark_color)
	draw_circle(center + Vector2(radius, 0.0), mark_radius, mark_color)
	draw_circle(center + Vector2(0.0, radius), mark_radius, mark_color)
	draw_circle(center + Vector2(-radius, 0.0), mark_radius, mark_color)

func _draw_boss_crown(
	center: Vector2,
	radius: float,
	frame_color: Color,
	dim_factor: float
) -> void:
	var y: float = center.y - radius - 7.0
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(center.x - 12.0, y + 8.0),
		Vector2(center.x - 7.0, y - 1.0),
		Vector2(center.x, y + 5.0),
		Vector2(center.x + 7.0, y - 1.0),
		Vector2(center.x + 12.0, y + 8.0)
	])
	draw_polyline(
		points,
		Color(frame_color.r, frame_color.g, frame_color.b, 0.95 * dim_factor),
		2.0,
		true
	)

func _draw_clear_mark(
	center: Vector2,
	radius: float,
	dim_factor: float
) -> void:
	var badge_center: Vector2 = center + Vector2(radius * 0.66, -radius * 0.66)
	draw_circle(badge_center, 7.0, Color(0.01, 0.08, 0.06, 0.96 * dim_factor))
	draw_arc(badge_center, 7.0, 0.0, TAU, 24, Color(gold.r, gold.g, gold.b, 0.94 * dim_factor), 1.5, true)
	draw_line(
		badge_center + Vector2(-3.0, 0.0),
		badge_center + Vector2(-0.5, 2.8),
		Color(accent.r, accent.g, accent.b, dim_factor),
		1.8,
		true
	)
	draw_line(
		badge_center + Vector2(-0.5, 2.8),
		badge_center + Vector2(3.5, -2.8),
		Color(accent.r, accent.g, accent.b, dim_factor),
		1.8,
		true
	)
