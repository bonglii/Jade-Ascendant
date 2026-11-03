extends Control
## Xianxia vector illustration, never an input surface or gameplay collider.
func _ready() -> void:mouse_filter=MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
func _draw() -> void:
 var center: Vector2=size*.5;var radius: float=minf(size.x*.25,85)
 draw_circle(center,radius,Color(.8,.36,.2,.12));draw_arc(center,radius,0,TAU,48,Color("f1d18a"),3,true)
 for i: int in range(8):
  var angle: float=float(i)*TAU/8
  draw_line(center+Vector2.RIGHT.rotated(angle)*radius*.2,center+Vector2.RIGHT.rotated(angle)*radius*.8,Color("f39787"),2,true)
 var safe_point: Vector2=center+Vector2(radius+48,0)
 draw_arc(safe_point,20,0,TAU,32,Color("77dfbb"),3,true);draw_line(center+Vector2(radius*.65,0),safe_point-Vector2(24,0),Color("77dfbb"),3,true)
 draw_string(ThemeDB.fallback_font,center+Vector2(-5,7),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("f1d18a"))
