extends Button

## Reusable premium wuxia plaque button.
## Presentation-only. It does not own navigation or gameplay state.

enum PlaqueStyle {
	BACK,
	PRIMARY,
	REALM,
	STAGE
}

@export_enum("Back", "Primary", "Realm", "Stage") var plaque_style: int = PlaqueStyle.PRIMARY
@export var accent: Color = Color(0.298, 0.82, 0.647, 1.0)
@export var accent_soft: Color = Color(0.184, 0.62, 0.471, 1.0)
@export var gold: Color = Color(0.957, 0.78, 0.357, 1.0)
@export var selected_state: bool = false
@export var dimmed_state: bool = false

var _mouse_down: bool = false

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_queue_visual_refresh)
	mouse_exited.connect(_queue_visual_refresh)
	focus_entered.connect(_queue_visual_refresh)
	focus_exited.connect(_queue_visual_refresh)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func apply_visual_state(
	profile: Dictionary,
	is_selected: bool = false,
	is_dimmed: bool = false
) -> void:
	accent = profile.get("accent", accent)
	accent_soft = profile.get("accent_soft", accent_soft)
	gold = profile.get("gold", gold)
	selected_state = is_selected
	dimmed_state = is_dimmed
	queue_redraw()

func set_selected_visual(value: bool) -> void:
	selected_state = value
	queue_redraw()

func set_dimmed_visual(value: bool) -> void:
	dimmed_state = value
	queue_redraw()

func _queue_visual_refresh() -> void:
	queue_redraw()

func _on_button_down() -> void:
	_mouse_down = true
	queue_redraw()

func _on_button_up() -> void:
	_mouse_down = false
	queue_redraw()

func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	if width < 24.0 or height < 20.0:
		return

	var hovered: bool = is_hovered() and not disabled
	var focused: bool = has_focus() and not disabled
	var active: bool = hovered or focused or selected_state
	var pressed_now: bool = _mouse_down and not disabled
	var dim_factor: float = 0.48 if (disabled or dimmed_state) else 1.0
	var chamfer: float = _get_chamfer(height)
	var outer_rect: Rect2 = Rect2(Vector2(2.0, 3.0), Vector2(width - 4.0, height - 7.0))
	var inner_rect: Rect2 = outer_rect.grow(-4.0)
	var core_rect: Rect2 = inner_rect.grow(-2.0)

	var shadow_rect: Rect2 = Rect2(outer_rect.position + Vector2(0.0, 3.0), outer_rect.size)
	var shadow_points: PackedVector2Array = _make_chamfered_rect(shadow_rect, chamfer)
	draw_colored_polygon(shadow_points, Color(0.0, 0.0, 0.0, 0.42 * dim_factor))

	if active:
		var glow_points: PackedVector2Array = _close_polyline(
			_make_chamfered_rect(outer_rect.grow(1.5), chamfer + 1.5)
		)
		draw_polyline(
			glow_points,
			Color(accent.r, accent.g, accent.b, 0.16 * dim_factor),
			5.0,
			true
		)

	var body_top: Color = _get_body_top(active, pressed_now, dim_factor)
	var body_bottom: Color = _get_body_bottom(active, pressed_now, dim_factor)
	_draw_split_body(core_rect, maxf(chamfer - 5.0, 2.0), body_top, body_bottom)

	var outer_points: PackedVector2Array = _close_polyline(
		_make_chamfered_rect(outer_rect, chamfer)
	)
	var inner_points: PackedVector2Array = _close_polyline(
		_make_chamfered_rect(inner_rect, maxf(chamfer - 3.0, 2.0))
	)
	var frame_color: Color = Color(gold.r, gold.g, gold.b, (1.0 if active else 0.84) * dim_factor)
	var inner_color: Color = Color(accent.r, accent.g, accent.b, (0.92 if active else 0.48) * dim_factor)

	draw_polyline(outer_points, Color(0.005, 0.014, 0.018, 0.92 * dim_factor), 3.0, true)
	draw_polyline(outer_points, frame_color, 1.8, true)
	draw_polyline(inner_points, inner_color, 1.0, true)

	_draw_side_ornaments(width, height, frame_color, inner_color, dim_factor)
	_draw_corner_marks(width, height, frame_color, dim_factor)
	_draw_center_marks(width, height, frame_color, inner_color, dim_factor)
	_draw_native_content(width, height)

func _draw_native_content(width: float, height: float) -> void:
	if text.is_empty() and icon == null:
		return

	var font: Font = get_theme_font("font")
	var font_size: int = get_theme_font_size("font_size")
	var content_color: Color = _get_native_content_color()
	var font_height: float = font.get_height(font_size)
	var baseline_y: float = (height - font_height) * 0.5 + font.get_ascent(font_size)
	var text_width: float = 0.0
	if not text.is_empty():
		text_width = font.get_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x

	var icon_size: Vector2 = Vector2.ZERO
	if icon != null:
		icon_size = icon.get_size()
		var max_icon_width: float = icon_size.x
		var configured_icon_max_width: int = get_theme_constant("icon_max_width")
		if configured_icon_max_width > 0:
			max_icon_width = float(configured_icon_max_width)
		var max_icon_height: float = maxf(height * 0.54, 1.0)
		if expand_icon:
			max_icon_width = minf(max_icon_width, max_icon_height)
		if icon_size.x > 0.0 and icon_size.y > 0.0:
			var scale_factor: float = minf(
				max_icon_width / icon_size.x,
				max_icon_height / icon_size.y
			)
			scale_factor = minf(scale_factor, 1.0)
			icon_size *= scale_factor

	var gap: float = 9.0 if icon != null and not text.is_empty() else 0.0
	var total_width: float = icon_size.x + gap + text_width
	var start_x: float = (width - total_width) * 0.5
	var text_x: float = start_x

	if icon != null and icon_size.x > 0.0 and icon_size.y > 0.0:
		var icon_rect: Rect2 = Rect2(
			Vector2(start_x, (height - icon_size.y) * 0.5),
			icon_size
		)
		draw_texture_rect(icon, icon_rect, false, content_color)
		text_x += icon_size.x + gap

	if text.is_empty():
		return

	var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.78 * content_color.a)
	draw_string(
		font,
		Vector2(text_x + 1.0, baseline_y + 2.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		shadow_color
	)
	draw_string(
		font,
		Vector2(text_x, baseline_y),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		content_color
	)

func _get_native_content_color() -> Color:
	if disabled:
		return get_theme_color("font_disabled_color")
	if _mouse_down:
		return get_theme_color("font_pressed_color")
	if is_hovered():
		return get_theme_color("font_hover_color")
	if has_focus():
		return get_theme_color("font_focus_color")
	return get_theme_color("font_color")

func _get_chamfer(height: float) -> float:
	match plaque_style:
		PlaqueStyle.BACK:
			return minf(13.0, height * 0.28)
		PlaqueStyle.PRIMARY:
			return minf(15.0, height * 0.24)
		PlaqueStyle.REALM:
			return minf(16.0, height * 0.18)
		_:
			return minf(12.0, height * 0.18)

func _get_body_top(active: bool, pressed_now: bool, dim_factor: float) -> Color:
	var base: Color
	match plaque_style:
		PlaqueStyle.PRIMARY:
			base = Color(0.010, 0.128, 0.116, 0.96)
		PlaqueStyle.REALM:
			base = Color(0.008, 0.090, 0.086, 0.95)
		PlaqueStyle.STAGE:
			base = Color(0.006, 0.068, 0.080, 0.95)
		_:
			base = Color(0.004, 0.052, 0.068, 0.94)
	if active:
		base = base.lightened(0.12)
	if pressed_now:
		base = base.darkened(0.15)
	return Color(base.r, base.g, base.b, base.a * dim_factor)

func _get_body_bottom(active: bool, pressed_now: bool, dim_factor: float) -> Color:
	var base: Color
	match plaque_style:
		PlaqueStyle.PRIMARY:
			base = Color(0.006, 0.07, 0.085, 0.99)
		PlaqueStyle.REALM:
			base = Color(0.004, 0.058, 0.067, 0.99)
		PlaqueStyle.STAGE:
			base = Color(0.004, 0.047, 0.06, 0.99)
		_:
			base = Color(0.004, 0.038, 0.052, 0.99)
	if selected_state:
		base = Color(
			base.r + accent_soft.r * 0.10,
			base.g + accent_soft.g * 0.10,
			base.b + accent_soft.b * 0.10,
			base.a
		)
	if active:
		base = base.lightened(0.07)
	if pressed_now:
		base = base.darkened(0.12)
	return Color(base.r, base.g, base.b, base.a * dim_factor)

func _draw_split_body(
	rect: Rect2,
	chamfer: float,
	top_color: Color,
	bottom_color: Color
) -> void:
	var points: PackedVector2Array = _make_chamfered_rect(rect, chamfer)
	draw_colored_polygon(points, bottom_color)
	var upper_rect: Rect2 = Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.48))
	var upper_points: PackedVector2Array = PackedVector2Array([
		Vector2(upper_rect.position.x + chamfer, upper_rect.position.y),
		Vector2(upper_rect.end.x - chamfer, upper_rect.position.y),
		Vector2(upper_rect.end.x, upper_rect.position.y + chamfer),
		Vector2(upper_rect.end.x, upper_rect.end.y),
		Vector2(upper_rect.position.x, upper_rect.end.y),
		Vector2(upper_rect.position.x, upper_rect.position.y + chamfer)
	])
	draw_colored_polygon(upper_points, top_color)

func _draw_side_ornaments(
	width: float,
	height: float,
	frame_color: Color,
	inner_color: Color,
	dim_factor: float
) -> void:
	var center_y: float = height * 0.5
	var half_h: float = 6.0 if plaque_style != PlaqueStyle.REALM else 8.0
	var inset_x: float = 7.0
	var left_points: PackedVector2Array = PackedVector2Array([
		Vector2(1.5, center_y),
		Vector2(inset_x, center_y - half_h),
		Vector2(inset_x + 7.0, center_y),
		Vector2(inset_x, center_y + half_h)
	])
	var right_points: PackedVector2Array = PackedVector2Array([
		Vector2(width - 1.5, center_y),
		Vector2(width - inset_x, center_y - half_h),
		Vector2(width - inset_x - 7.0, center_y),
		Vector2(width - inset_x, center_y + half_h)
	])
	draw_colored_polygon(left_points, frame_color)
	draw_colored_polygon(right_points, frame_color)
	var jewel_color: Color = Color(inner_color.r, inner_color.g, inner_color.b, 0.92 * dim_factor)
	draw_circle(Vector2(inset_x, center_y), 2.0, jewel_color)
	draw_circle(Vector2(width - inset_x, center_y), 2.0, jewel_color)

func _draw_corner_marks(
	width: float,
	height: float,
	frame_color: Color,
	dim_factor: float
) -> void:
	var c: Color = Color(frame_color.r, frame_color.g, frame_color.b, 0.72 * dim_factor)
	var top_y: float = 7.0
	var bottom_y: float = height - 10.0
	var left_x: float = 18.0
	var right_x: float = width - 18.0
	var arm: float = 10.0
	draw_line(Vector2(left_x, top_y), Vector2(left_x + arm, top_y), c, 1.2, true)
	draw_line(Vector2(left_x, top_y), Vector2(left_x - 4.0, top_y + 4.0), c, 1.2, true)
	draw_line(Vector2(right_x, top_y), Vector2(right_x - arm, top_y), c, 1.2, true)
	draw_line(Vector2(right_x, top_y), Vector2(right_x + 4.0, top_y + 4.0), c, 1.2, true)
	draw_line(Vector2(left_x, bottom_y), Vector2(left_x + arm, bottom_y), c, 1.2, true)
	draw_line(Vector2(right_x, bottom_y), Vector2(right_x - arm, bottom_y), c, 1.2, true)

func _draw_center_marks(
	width: float,
	height: float,
	frame_color: Color,
	inner_color: Color,
	dim_factor: float
) -> void:
	if plaque_style == PlaqueStyle.BACK:
		return
	var center_x: float = width * 0.5
	var top_y: float = 4.5
	var bottom_y: float = height - 7.5
	var diamond: PackedVector2Array = PackedVector2Array([
		Vector2(center_x, top_y - 2.0),
		Vector2(center_x + 3.5, top_y + 1.5),
		Vector2(center_x, top_y + 5.0),
		Vector2(center_x - 3.5, top_y + 1.5)
	])
	draw_colored_polygon(diamond, frame_color)
	var bottom_diamond: PackedVector2Array = PackedVector2Array([
		Vector2(center_x, bottom_y - 3.5),
		Vector2(center_x + 3.0, bottom_y),
		Vector2(center_x, bottom_y + 3.5),
		Vector2(center_x - 3.0, bottom_y)
	])
	draw_colored_polygon(bottom_diamond, Color(inner_color.r, inner_color.g, inner_color.b, 0.78 * dim_factor))

func _make_chamfered_rect(rect: Rect2, chamfer: float) -> PackedVector2Array:
	var x0: float = rect.position.x
	var y0: float = rect.position.y
	var x1: float = rect.end.x
	var y1: float = rect.end.y
	var safe_chamfer: float = minf(chamfer, minf(rect.size.x, rect.size.y) * 0.45)
	return PackedVector2Array([
		Vector2(x0 + safe_chamfer, y0),
		Vector2(x1 - safe_chamfer, y0),
		Vector2(x1, y0 + safe_chamfer),
		Vector2(x1, y1 - safe_chamfer),
		Vector2(x1 - safe_chamfer, y1),
		Vector2(x0 + safe_chamfer, y1),
		Vector2(x0, y1 - safe_chamfer),
		Vector2(x0, y0 + safe_chamfer)
	])

func _close_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var closed: PackedVector2Array = points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed
