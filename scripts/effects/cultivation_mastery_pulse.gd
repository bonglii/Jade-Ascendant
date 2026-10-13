extends Node2D
var age: float=0
func _process(delta: float) -> void:
 age+=delta;queue_redraw()
 if age>=.4:queue_free()
func _draw() -> void:
 var alpha: float=1-age/.4
 draw_arc(Vector2.ZERO,20+age*150,0,TAU,48,Color(.36,.96,.77,alpha),2,true)
 draw_arc(Vector2.ZERO,16+age*150,0,TAU,48,Color(.98,.79,.32,alpha*.7),1,true)
