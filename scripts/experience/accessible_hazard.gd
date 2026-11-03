extends Node2D
## Noninteractive overlay: authored radius/lifetime, no collider or timing change.
var radius: float=0
var duration: float=0
var elapsed: float=0
static func install(host: Node,authored_radius: float,authored_duration: float) -> void:
 if not SettingsManager.high_contrast_warnings or not is_finite(authored_radius) or not is_finite(authored_duration) or authored_radius<=0 or authored_duration<=0:return
 var ring: Node2D=load("res://scripts/experience/accessible_hazard.gd").new();ring.radius=authored_radius;ring.duration=authored_duration;ring.z_index=30;host.add_child(ring)
func _process(delta: float) -> void:
 elapsed+=delta
 if elapsed>=duration:queue_free()
 else:queue_redraw()
func _draw() -> void:
 draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(.01,.03,.03,.95),7,true)
 draw_arc(Vector2.ZERO,radius,0,TAU,64,Color("fff0b0"),3,true)
 draw_string(ThemeDB.fallback_font,Vector2(-6,7),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("fff0b0"))
