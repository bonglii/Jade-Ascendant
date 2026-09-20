extends Control

## Stage thumbnail presentation. Chapter 1 now uses authored scene art instead of
## prototype line motifs. Future chapters keep a safe realm-specific fallback.

const JourneyVisualCatalog = preload("res://scripts/ui/journey_visual_catalog.gd")

const STAGE_TEXTURES: Dictionary = {
	"1:1": preload("res://assets/ui/journey/stages/stage_1_1_verdant_awakening.png"),
	"1:2": preload("res://assets/ui/journey/stages/stage_1_2_bamboo_mist_pass.png"),
	"1:3": preload("res://assets/ui/journey/stages/stage_1_3_ruined_jade_shrine.png"),
	"1:4": preload("res://assets/ui/journey/stages/stage_1_4_storm_peak_approach.png"),
	"1:5": preload("res://assets/ui/journey/stages/stage_1_5_sovereigns_celestial_gate.png"),
	"1:6": preload("res://assets/ui/journey/stages/stage_1_6_heart_of_verdant_heaven.svg"),
}

const REALM_TEXTURES: Dictionary = {
	1: preload("res://assets/ui/journey/realm_01_verdant.png"),
	2: preload("res://assets/ui/journey/realm_02_crimson.png"),
	3: preload("res://assets/ui/journey/realm_03_nine_heavens.png"),
}

var chapter_id: int = 1
var stage_id: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var stage_data: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
	var realm_profile: Dictionary = JourneyVisualCatalog.get_chapter_profile(chapter_id)
	var ground: Color = stage_data.get(
		"ground",
		realm_profile.get("sky_bottom", Color(0.016, 0.086, 0.094, 1.0))
	)
	var accent: Color = stage_data.get(
		"accent",
		realm_profile.get("accent", Color(0.353, 0.784, 0.843, 1.0))
	)
	var gold: Color = realm_profile.get("gold", Color(0.941, 0.8, 0.439, 1.0))
	var is_boss: bool = bool(stage_data.get("is_chapter_boss", false))

	_draw_background(ground, accent)

	var authored_texture: Texture2D = STAGE_TEXTURES.get(_stage_key()) as Texture2D
	if authored_texture != null:
		_draw_authored_stage(authored_texture, accent, gold, is_boss)
	else:
		var realm_texture: Texture2D = REALM_TEXTURES.get(chapter_id) as Texture2D
		if realm_texture != null:
			_draw_realm_fallback(realm_texture, accent, gold)
		else:
			_draw_generic_fallback(accent, gold)

	_draw_corner_marks(accent, gold)
	_draw_stage_progress_marks(accent, gold)
	if is_boss:
		_draw_boss_mark(gold, accent)

	var border_color: Color = gold if is_boss else accent
	draw_rect(
		Rect2(Vector2.ONE, size - Vector2.ONE * 2.0),
		Color(border_color.r, border_color.g, border_color.b, 0.78 if is_boss else 0.50),
		false,
		2.0 if is_boss else 1.1
	)


func _stage_key() -> String:
	return "%d:%d" % [chapter_id, stage_id]


func _draw_background(ground: Color, accent: Color) -> void:
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	var colors := PackedColorArray([
		ground.darkened(0.30),
		ground.darkened(0.18),
		ground.lerp(accent, 0.10),
		ground.darkened(0.24),
	])
	draw_polygon(points, colors)


func _draw_authored_stage(
	texture: Texture2D,
	_accent: Color,
	gold: Color,
	is_boss: bool
) -> void:
	var bounds := Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0))

	# The authored image is the hero. Stage cards are small portrait containers,
	# so filling the available seal is more readable than letterboxing the scene.
	draw_texture_rect(texture, bounds, false, Color.WHITE)

	# Soft cinematic edge shade keeps index / status overlays readable.
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0.0, 0.008, 0.014, 0.10),
		true
	)
	var accent_alpha: float = 0.18 if is_boss else 0.10
	draw_line(
		Vector2(size.x * 0.14, size.y * 0.88),
		Vector2(size.x * 0.86, size.y * 0.88),
		Color(gold.r, gold.g, gold.b, accent_alpha),
		1.2,
		true
	)


func _draw_realm_fallback(texture: Texture2D, accent: Color, gold: Color) -> void:
	var bounds := Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
	var destination: Rect2 = _fit_texture_rect(texture, bounds)
	draw_texture_rect(texture, destination, false, Color(0.92, 0.96, 0.95, 0.90))
	_draw_generic_stage_symbol(accent, gold)


func _draw_generic_fallback(accent: Color, gold: Color) -> void:
	_draw_generic_stage_symbol(accent, gold)


func _draw_generic_stage_symbol(accent: Color, gold: Color) -> void:
	var center := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.22
	draw_arc(center, radius, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.58), 1.7, true)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.66),
		center + Vector2(radius * 0.66, 0.0),
		center + Vector2(0.0, radius * 0.66),
		center + Vector2(-radius * 0.66, 0.0),
		center + Vector2(0.0, -radius * 0.66),
	])
	draw_polyline(diamond, Color(gold.r, gold.g, gold.b, 0.76), 1.5, true)


func _draw_stage_progress_marks(accent: Color, gold: Color) -> void:
	var count: int = clampi(stage_id, 1, 6)
	var spacing: float = minf(size.x * 0.085, 9.0)
	var y: float = size.y * 0.91
	var start_x: float = size.x * 0.5 - spacing * float(count - 1) * 0.5
	for index: int in range(count):
		var color := Color(gold.r, gold.g, gold.b, 0.82)
		if index < count - 1:
			color = Color(accent.r, accent.g, accent.b, 0.64)
		draw_circle(Vector2(start_x + spacing * float(index), y), 1.3, color)


func _draw_corner_marks(accent: Color, gold: Color) -> void:
	var inset: float = 6.0
	var length: float = minf(size.x, size.y) * 0.14
	var jade := Color(accent.r, accent.g, accent.b, 0.52)
	var warm := Color(gold.r, gold.g, gold.b, 0.46)
	draw_line(Vector2(inset, inset), Vector2(inset + length, inset), jade, 1.1, true)
	draw_line(Vector2(inset, inset), Vector2(inset, inset + length), jade, 1.1, true)
	draw_line(Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset - length, size.y - inset), warm, 1.1, true)
	draw_line(Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset, size.y - inset - length), warm, 1.1, true)


func _draw_boss_mark(gold: Color, accent: Color) -> void:
	var center := Vector2(size.x * 0.50, size.y * 0.13)
	var width: float = minf(size.x * 0.28, 26.0)
	var height: float = 7.0
	var points := PackedVector2Array([
		center + Vector2(-width * 0.5, height * 0.45),
		center + Vector2(-width * 0.28, -height * 0.5),
		center + Vector2(0.0, height * 0.08),
		center + Vector2(width * 0.28, -height * 0.5),
		center + Vector2(width * 0.5, height * 0.45),
	])
	draw_polyline(points, Color(gold.r, gold.g, gold.b, 0.92), 1.6, true)
	draw_circle(center + Vector2(0.0, 1.0), 1.7, Color(accent.r, accent.g, accent.b, 0.92))


func _fit_texture_rect(texture: Texture2D, bounds: Rect2) -> Rect2:
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
