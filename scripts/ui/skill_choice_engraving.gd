extends Control
const Art = preload("res://scripts/effects/skill_signature_art.gd")
var skill_id: String = ""
var armament_id: String = ""
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
func _draw() -> void:
 if skill_id.is_empty(): return
 var center := Vector2(size.x-34,size.y-36)
 if not armament_id.is_empty():
  _draw_arsenal_seal(center)
 else:Art.draw_emblem(self,skill_id,center,23,0.0,.2)
 var ink: Color = Art.color_for(skill_id)
 draw_line(Vector2(size.x-62,size.y-8),Vector2(size.x-10,size.y-8),Color(ink,.65),1.4,true)

func _draw_arsenal_seal(at: Vector2) -> void:
 var ink:=Color(1,.57,.23,.35) if armament_id=="phoenix_war_fan" else Color(.73,.6,1,.35) if armament_id=="void_piercer_spear" else Color(1,.81,.39,.35)
 draw_arc(at,22,0,TAU,32,ink,1.0,true)
 if armament_id=="phoenix_war_fan":
  for i: int in range(5):
   var direction:=Vector2.UP.rotated((i-2)*.30)
   draw_line(at+Vector2(0,13),at+direction*20,ink,1.5,true)
  draw_arc(at+Vector2(0,13),28,PI*1.22,PI*1.78,22,ink,1.2,true)
 elif armament_id=="void_piercer_spear":
  draw_line(at+Vector2(-12,17),at+Vector2(12,-17),ink,2,true)
  draw_polyline(PackedVector2Array([at+Vector2(5,-12),at+Vector2(12,-17),at+Vector2(11,-8)]),ink,1.8,true)
 else:
  draw_polyline(PackedVector2Array([at+Vector2(-15,12),at+Vector2(-9,-14),at+Vector2(9,-14),at+Vector2(15,12),at+Vector2(-15,12)]),ink,1.5,true)
  draw_arc(at+Vector2(0,13),6,0,PI,12,ink,1.5,true)
