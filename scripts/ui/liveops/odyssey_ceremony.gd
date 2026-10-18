extends Control
## Only presents an already confirmed milestone; never grants the weapon.
const Art=preload("res://scripts/ui/liveops/odyssey_art.gd")
const TILE=preload("res://assets/ui/liveops/odyssey/tile.png")
const COMPASS=preload("res://assets/ui/liveops/odyssey/compass.png")
const DRAGON=preload("res://assets/ui/liveops/odyssey/dragon.png")
const SPARK=preload("res://assets/ui/main_menu/polish/path_spark.svg")
var age: float=0.0
var glow: GradientTexture2D
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; custom_minimum_size.y=300; texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var gradient:=Gradient.new(); gradient.set_color(0,Color(0.3,0.95,0.75,0.45)); gradient.set_color(1,Color(0.1,0.4,0.3,0))
	glow=GradientTexture2D.new(); glow.gradient=gradient; glow.width=256; glow.height=256; glow.fill=GradientTexture2D.FILL_RADIAL; glow.fill_from=Vector2(0.5,0.5); glow.fill_to=Vector2(1,0.5)
func _process(delta: float) -> void:
	age=minf(age+delta,4.0); queue_redraw()
	if age>=4.0: set_process(false)
func _dragon(center: Vector2, phase: float, alpha: float) -> void:
	var point:=center+Vector2(cos(phase*TAU)*92,sin(phase*TAU)*38)
	var span:=Vector2(210,110); draw_texture_rect(DRAGON,Rect2(point-span*0.5,span),false,Color(1,1,1,alpha))
func _draw() -> void:
	var center: Vector2=size*0.5; var reduced: bool=Art.reduced(self)
	var fold: float=smoothstep(0,1.1,age); var reveal: float=smoothstep(0.7,1.7,age) if not reduced else smoothstep(0,0.2,age)
	if glow!=null: draw_texture_rect(glow,Rect2(center-Vector2(170,140),Vector2(340,280)),false,Color(1,1,1,reveal))
	if not reduced:
		for i: int in range(10):
			var angle: float=float(i)*TAU/10.0+age*0.14; var radius: float=(1-fold)*minf(size.x*0.35,140)
			var point:=center+Vector2(cos(angle)*radius,sin(angle)*radius*0.55); var span:=Vector2(48,34)*(1-fold*0.6)
			draw_texture_rect(TILE,Rect2(point-span*0.5,span),false,Color(1,1,1,1-fold))
	var phase: float=clampf((age-0.8)/2.5,0,1); var alpha: float=sin(phase*PI)*0.85 if not reduced else 0.0
	if phase<0.5: _dragon(center,phase,alpha)
	var side: float=215*(0.78+reveal*0.22)
	draw_texture_rect(COMPASS,Rect2(center-Vector2.ONE*side*0.5,Vector2.ONE*side),false,Color(1,1,1,reveal))
	if phase>=0.5: _dragon(center,phase,alpha)
	if not reduced:
		for i: int in range(10):
			var angle: float=float(i)*TAU/10.0; var radius: float=70+float(i%3)*22+age*6
			var point:=center+Vector2(cos(angle)*radius,sin(angle)*radius*0.75)
			draw_texture_rect(SPARK,Rect2(point-Vector2.ONE*6,Vector2.ONE*12),false,Color(1,0.87,0.55,reveal*maxf(0,1-age/4)))
