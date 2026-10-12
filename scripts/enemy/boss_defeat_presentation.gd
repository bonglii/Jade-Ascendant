extends Node2D
## A brief visual remnant after the authoritative boss has already been removed.
var tint: Color = Color(0.5,0.95,0.8)
var left: float = 0.48
var ghost: Sprite2D
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 4
func setup(sprite: AnimatedSprite2D, color: Color) -> void:
	tint = color
	ghost = Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	ghost.position = sprite.position
	ghost.scale = sprite.scale
	ghost.rotation = sprite.rotation
	ghost.flip_h = sprite.flip_h
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.modulate = Color(tint,0.45)
	add_child(ghost)
func _process(delta: float) -> void:
	left = maxf(0,left-delta)
	if ghost != null:
		ghost.modulate.a = left/0.48*0.45
		if not SettingsManager.reduced_effects:
			ghost.position.y -= delta*35.0
	queue_redraw()
	if left <= 0.0: queue_free()
func _draw() -> void:
	if SettingsManager.reduced_effects: return
	var progress: float = 1.0-left/0.48
	var center := Vector2(0,-24)
	for i: int in range(12):
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU*i/12.0)
		var distance: float = 24.0+progress*50.0
		var at: Vector2 = center+direction*distance
		draw_line(at,at-direction*12.0,Color(tint,(1-progress)*0.7),2,true)
