extends Control
const Art = preload("res://scripts/effects/skill_signature_art.gd")
var skill_id: String = ""
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
func _draw() -> void:
 if skill_id.is_empty(): return
 var center := Vector2(size.x-34,size.y-36)
 Art.draw_emblem(self,skill_id,center,23,0.0,.2)
 var ink: Color = Art.color_for(skill_id)
 draw_line(Vector2(size.x-62,size.y-8),Vector2(size.x-10,size.y-8),Color(ink,.65),1.4,true)
