extends Control

## Production chapter-aware stage thumbnail presentation.
## Asset selection is presentation-only and never owns progression state.

const JourneyArtCatalog = preload("res://scripts/ui/journey_art_catalog.gd")

var chapter_id: int = 1
var stage_id: int = 1
var _texture: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	_reload_texture()
	queue_redraw()


func set_stage(next_chapter_id: int, next_stage_id: int) -> void:
	chapter_id = next_chapter_id
	stage_id = next_stage_id
	_reload_texture()
	queue_redraw()


func _reload_texture() -> void:
	var path: String = JourneyArtCatalog.get_stage_art_path(chapter_id, stage_id)
	if path.is_empty():
		path = JourneyArtCatalog.get_realm_vista_path(chapter_id)
	_texture = ResourceLoader.load(path, "Texture2D") as Texture2D


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0 or _texture == null:
		return
	var bounds := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	_draw_cover_texture(_texture, bounds)
	draw_rect(
		Rect2(Vector2.ONE, size - Vector2.ONE * 2.0),
		Color(0.86, 0.72, 0.34, 0.52),
		false,
		1.0
	)


func _draw_cover_texture(texture: Texture2D, bounds: Rect2) -> void:
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale_value: float = maxf(
		bounds.size.x / source_size.x,
		bounds.size.y / source_size.y
	)
	var visible_size: Vector2 = bounds.size / scale_value
	var source_position: Vector2 = (source_size - visible_size) * 0.5
	draw_texture_rect_region(
		texture,
		bounds,
		Rect2(source_position, visible_size),
		Color.WHITE
	)
