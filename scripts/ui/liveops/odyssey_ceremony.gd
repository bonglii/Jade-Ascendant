extends Control
## Bounded continuous animation: twelve board tiles fold into the event relic.
const TILE = preload("res://assets/ui/liveops/odyssey/tile.png")
const COMPASS = preload("res://assets/ui/liveops/odyssey/compass.png")
const DRAGON = preload("res://assets/ui/liveops/odyssey/dragon.png")
var age: float = 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE; custom_minimum_size.y = 260
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _process(delta: float) -> void:
	age = minf(age + delta, 4.0); queue_redraw()
	if age >= 4.0: set_process(false)
func _draw() -> void:
	var center: Vector2 = size * 0.5
	var fold: float = smoothstep(0.0,1.4,age)
	var reveal: float = smoothstep(1.0,2.2,age)
	for i: int in range(12):
		var angle: float = float(i) * TAU / 12.0
		var fold_radius: float = (1.0 - fold) * minf(size.x * 0.38,118.0)
		var tile_size: Vector2 = Vector2(40,27) * (1.0 - fold * 0.65)
		var point: Vector2 = center + Vector2(cos(angle)*fold_radius,sin(angle)*fold_radius*0.6)
		draw_texture_rect(TILE,Rect2(point-tile_size*0.5,tile_size),false,Color(1,1,1,1-fold))
	var reveal_radius: float = 84.0 + sin(age * 2) * 2.0
	for i: int in range(3): draw_arc(center,reveal_radius+float(i)*13.0,-age*0.3+float(i),TAU-age*0.3+float(i),64,Color(0.7,0.92,0.68,reveal*0.18),1,true)
	var relic_size: float = 150.0 * (0.78 + reveal * 0.22)
	draw_texture_rect(COMPASS,Rect2(center-Vector2.ONE*relic_size*0.5,Vector2.ONE*relic_size),false,Color(1,1,1,reveal))
	if age > 1.2 and age < 3.5:
		var t: float = (age-1.2)/2.3
		var orbit: Vector2 = center+Vector2(cos(t*TAU)*102,sin(t*TAU)*42)
		draw_texture_rect(DRAGON,Rect2(orbit-Vector2(36,18),Vector2(72,36)),false,Color(1,1,1,sin(t*PI)*0.88))
	if not SettingsManager.reduced_effects:
		for i: int in range(12):
			var angle: float = float(i) * TAU/12.0 + age * 0.14
			var point: Vector2 = center+Vector2.from_angle(angle)*(86+float(i%3)*9)
			draw_circle(point,1.5,Color(1,0.83,0.5,reveal*0.65))
