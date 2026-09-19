extends Control
class_name RealmLandmarkPreview

const JourneyVisualCatalog = preload("res://scripts/ui/journey_visual_catalog.gd")

const REALM_TEXTURES: Dictionary = {
	1: preload("res://assets/ui/journey/realm_01_verdant.png"),
	2: preload("res://assets/ui/journey/realm_02_crimson.png"),
	3: preload("res://assets/ui/journey/realm_03_nine_heavens.png"),
}

var chapter_id: int = 1
var selected: bool = false
var locked: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	queue_redraw()


func set_state(
	new_chapter_id: int,
	is_selected: bool,
	is_locked: bool
) -> void:
	chapter_id = new_chapter_id
	selected = is_selected
	locked = is_locked
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var profile: Dictionary = JourneyVisualCatalog.get_chapter_profile(chapter_id)
	var accent: Color = profile.get("accent", Color(0.30, 0.82, 0.65, 1.0))
	var gold: Color = profile.get("gold", Color(0.96, 0.78, 0.36, 1.0))
	var sky_top: Color = profile.get("sky_top", Color(0.01, 0.03, 0.05, 1.0))
	var sky_bottom: Color = profile.get("sky_bottom", Color(0.02, 0.08, 0.09, 1.0))

	_draw_gradient_panel(sky_top, sky_bottom, accent)

	var texture: Texture2D = REALM_TEXTURES.get(chapter_id) as Texture2D
	if texture != null:
		_draw_authored_realm(texture)
	else:
		_draw_fallback_realm(accent, gold)

	if selected and not locked:
		draw_circle(
			size * 0.5,
			minf(size.x, size.y) * 0.43,
			Color(accent.r, accent.g, accent.b, 0.045)
		)

	var border_color: Color = gold if selected else accent
	var border_alpha: float = 0.92 if selected else 0.46
	var border_width: float = 2.0 if selected else 1.0
	if locked:
		border_color = accent.darkened(0.45)
		border_alpha = 0.26
		border_width = 1.0

	draw_rect(
		Rect2(Vector2.ONE, size - Vector2.ONE * 2.0),
		Color(
			border_color.r,
			border_color.g,
			border_color.b,
			border_alpha
		),
		false,
		border_width
	)

	if locked:
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(0.0, 0.008, 0.012, 0.30),
			true
		)


func _draw_authored_realm(texture: Texture2D) -> void:
	var bounds := Rect2(
		Vector2(3.0, 3.0),
		size - Vector2(6.0, 6.0)
	)
	var destination: Rect2 = _fit_texture_rect(texture, bounds)
	var tint := Color.WHITE
	if locked:
		tint = Color(0.48, 0.51, 0.52, 0.62)
	elif not selected:
		tint = Color(0.92, 0.95, 0.94, 0.95)
	draw_texture_rect(texture, destination, false, tint)


func _draw_gradient_panel(
	top: Color,
	bottom: Color,
	accent: Color
) -> void:
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y),
	])
	var colors := PackedColorArray([
		top,
		top,
		bottom,
		bottom,
	])
	draw_polygon(points, colors)

	for index: int in range(3):
		var y: float = size.y * (0.24 + float(index) * 0.24)
		draw_line(
			Vector2(0.0, y),
			Vector2(size.x, y - size.y * 0.05),
			Color(accent.r, accent.g, accent.b, 0.028),
			1.0,
			true
		)


func _draw_fallback_realm(accent: Color, gold: Color) -> void:
	# Future chapters keep a valid visual instead of accidentally reusing Realm 1.
	var center := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.22
	draw_polyline(
		PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
			center + Vector2(0.0, -radius),
		]),
		Color(accent.r, accent.g, accent.b, 0.72),
		2.0,
		true
	)
	draw_circle(center, 3.0, Color(gold.r, gold.g, gold.b, 0.90))


func _fit_texture_rect(
	texture: Texture2D,
	bounds: Rect2
) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return bounds

	var scale_value: float = minf(
		bounds.size.x / texture_size.x,
		bounds.size.y / texture_size.y
	)
	var target_size: Vector2 = texture_size * scale_value
	return Rect2(
		bounds.position + (bounds.size - target_size) * 0.5,
		target_size
	)
