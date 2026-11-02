extends Node2D
## Static contact outline uses the collider's own transform and shape.
## Attack telegraphs remain separate and keep their authored ranges.
func _ready() -> void:
 z_index=-2
 show_behind_parent=true
 set_process(false)
 queue_redraw()

func _draw() -> void:
 var collider:=get_parent() as CollisionShape2D
 if collider==null or collider.disabled or collider.shape==null:return
 var edge:=Color(.89,.77,.44,.55)
 var fill:=Color(.015,.025,.021,.14)
 if collider.shape is CapsuleShape2D:
  var capsule:=collider.shape as CapsuleShape2D
  var radius: float=capsule.radius
  var half_straight: float=maxf(capsule.height*.5-radius,0.0)
  draw_circle(Vector2(0,-half_straight),radius,fill)
  draw_circle(Vector2(0,half_straight),radius,fill)
  if half_straight>0:draw_rect(Rect2(-radius,-half_straight,radius*2,half_straight*2),fill)
  draw_arc(Vector2(0,-half_straight),radius,PI,TAU,24,edge,1.2,true)
  draw_arc(Vector2(0,half_straight),radius,0,PI,24,edge,1.2,true)
  draw_line(Vector2(-radius,-half_straight),Vector2(-radius,half_straight),edge,1.2,true)
  draw_line(Vector2(radius,-half_straight),Vector2(radius,half_straight),edge,1.2,true)
 elif collider.shape is CircleShape2D:
  var circle:=collider.shape as CircleShape2D
  draw_circle(Vector2.ZERO,circle.radius,fill)
  draw_arc(Vector2.ZERO,circle.radius,0,TAU,48,edge,1.2,true)
 elif collider.shape is RectangleShape2D:
  var rect:=collider.shape as RectangleShape2D
  draw_rect(Rect2(-rect.size*.5,rect.size),fill)
  draw_rect(Rect2(-rect.size*.5,rect.size),edge,false,1.2)
