extends Control
signal travel_finished
const TILE = preload("res://assets/ui/liveops/odyssey/tile.png")
const TEMPLE = preload("res://assets/ui/liveops/odyssey/temple.png")
const FRAMES = preload("res://assets/character/player/player_lin_yue_idle_walk_spriteframes.tres")
const STONE = preload("res://assets/ui/shared/resources/spirit_stone_premium.png")
const JADE = preload("res://assets/ui/shared/resources/celestial_jade_premium.png")
const SEAL = preload("res://assets/ui/shared/resources/pavilion_seal_premium.png")
const TYPES: Array[String] = ["LOTUS","STONE","SCROLL","CHEST","STONE","GATE","JADE","STONE","LOTUS","CHEST","SCROLL","STONE","GATE","JADE","STONE","CHEST","LOTUS","SCROLL","STONE","GATE"]
var token: AnimatedSprite2D
var selected: int = 0
var animation: Tween
var coordinates: Array[Vector2i] = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for x: int in range(6): coordinates.append(Vector2i(x,0))
	for y: int in range(1,6): coordinates.append(Vector2i(5,y))
	for x: int in range(4,-1,-1): coordinates.append(Vector2i(x,5))
	for y: int in range(4,0,-1): coordinates.append(Vector2i(0,y))
	token = AnimatedSprite2D.new(); token.sprite_frames = FRAMES; token.scale = Vector2.ONE * 0.42
	token.play("idle_down"); token.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; add_child(token)
	resized.connect(_layout); _layout()
func point(index: int) -> Vector2:
	if coordinates.is_empty(): return size * 0.5
	var c: Vector2i = coordinates[posmod(index,20)]
	return Vector2(size.x * 0.5 + (c.x - c.y) * size.x / 13.0, size.y * 0.5 - size.x * 5.0 / 26.0 + (c.x + c.y) * size.x / 26.0)
func _layout() -> void:
	if token != null: token.position = point(selected) - Vector2(0,18)
	queue_redraw()
func is_travelling() -> bool:
	return animation != null and animation.is_running()
func show_position(index: int, steps: int = 0) -> void:
	if animation != null and animation.is_running(): animation.kill()
	if token == null: selected = index; return
	if steps < 1:
		selected = index; _layout(); return
	animation = create_tween(); token.play("walk_down")
	for step: int in range(1, steps + 1): animation.tween_property(token, "position", point(selected + step) - Vector2(0,18), 0.15)
	selected = index
	animation.tween_callback(func() -> void: token.play("idle_down"); animation = null; queue_redraw(); travel_finished.emit())
func _tile(index: int) -> void:
	var center: Vector2 = point(index)
	var tile_size: Vector2 = Vector2(size.x / 6.6, size.x / 9.9)
	draw_texture_rect(TILE, Rect2(center - tile_size * 0.5, tile_size), false)
	var icon: Texture2D = JADE if TYPES[index] == "JADE" else SEAL if TYPES[index] == "GATE" else STONE
	var icon_size: float = clampf(size.x * 0.038,16,25)
	draw_texture_rect(icon,Rect2(center-Vector2.ONE*icon_size*0.5-Vector2(0,4),Vector2.ONE*icon_size),false)
	if index == selected: draw_arc(center + Vector2(0,1), tile_size.x * 0.28, 0, TAU, 32, Color(0.9,0.86,0.5,0.7), 2, true)
func _draw() -> void:
	if coordinates.is_empty(): return
	for i: int in range(20):
		if coordinates[i].x + coordinates[i].y <= 5: _tile(i)
	var width: float = size.x * 0.44
	draw_texture_rect(TEMPLE, Rect2(Vector2(size.x * 0.5 - width * 0.5, size.y * 0.5 - width * 0.76), Vector2.ONE * width), false)
	for i: int in range(20):
		if coordinates[i].x + coordinates[i].y > 5: _tile(i)
