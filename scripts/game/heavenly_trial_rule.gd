extends Node2D
## Authored one-shot weekly mark. Visible boundary and applied damage share geometry.
const HALO=preload("res://assets/ui/pavilion/vfx/shared/soft_halo_premium.png")
var theme_id: String="jade_wind"
var tier: int=1
var _time: float=0
var _impact: bool=false
var _warning: float=1.4
var _radius: float=68
var _redraw: float=0
var _ink: Color=Color("8ad7af")
func _ready() -> void:
 add_to_group("enemy_attack");z_index=5
 match theme_id:
  "scarlet_rite":_ink=Color("ff877b");_warning=1.55
  "starfall":_ink=Color("dfabff");_warning=1.25
  "froststep":_ink=Color("a5dcff");_warning=1.8
  "sunforge":_ink=Color("ffd17c");_warning=1.65;_radius=100
 if theme_id=="jade_wind":rotation=randf()*TAU
func contains_point(point: Vector2) -> bool:
 var local: Vector2=to_local(point)
 return absf(local.x)<=210 and absf(local.y)<=28 if theme_id=="jade_wind" else local.length_squared()<=_radius*_radius
func _process(delta: float) -> void:
 _time+=delta;_redraw+=delta
 var impact_at: float=_warning
 if theme_id=="scarlet_rite" and _impact:impact_at=_warning+.7
 if _time>=impact_at and (not _impact or theme_id=="scarlet_rite" and _time<impact_at+delta):
  _impact=true
  var actor: Node2D=get_tree().get_first_node_in_group("player") as Node2D
  if is_instance_valid(actor) and contains_point(actor.global_position):
   var health: Node=actor.get_node_or_null("PlayerHealth")
   if health!=null:health.take_damage(3.0+float(tier)*2)
 if _redraw>=1.0/30:_redraw=0;queue_redraw()
 if _time>=_warning+(1.0 if theme_id=="scarlet_rite" else .3):queue_free()
func _draw() -> void:
 var progress: float=clampf(_time/_warning,0,1)
 var color: Color=Color(_ink,.13 if not _impact else .8)
 if theme_id=="jade_wind":
  draw_style_box(_lane_style(color),Rect2(-210,-28,420,56))
  draw_line(Vector2(-210,-28),Vector2(210,-28),Color(_ink,.85),2,true);draw_line(Vector2(-210,28),Vector2(210,28),Color(_ink,.85),2,true)
  for offset: int in range(-3,4):
   var x: float=float(offset)*54+sin(_time*3)*8
   draw_arc(Vector2(x,0),19,-.9,.9,18,Color(_ink,progress),2,true)
 else:
  draw_circle(Vector2.ZERO,_radius,color)
  draw_arc(Vector2.ZERO,_radius,-PI*.5,-PI*.5+TAU*progress,64,Color(_ink,.95),3,true)
  draw_arc(Vector2.ZERO,_radius-8,0,TAU,64,Color(_ink,.45),1,true)
  var width: float=_radius*2*(.35+.65*progress)
  draw_texture_rect(HALO,Rect2(Vector2.ONE*-width*.5,Vector2.ONE*width),false,Color(_ink,.35 if not _impact else .9))
  if theme_id=="starfall":
   for index: int in range(4):
    var axis:=Vector2.from_angle(PI*.5*index-PI*.5);draw_line(axis*10,axis*(_radius*.55),Color(_ink,progress),2,true)
func _lane_style(color: Color) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(12);return style
