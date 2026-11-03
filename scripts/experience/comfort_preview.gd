extends Control
## Illustrative preferences only, no combat actor or input capture.
func _ready() -> void:mouse_filter=MOUSE_FILTER_IGNORE;SettingsManager.settings_changed.connect(queue_redraw);resized.connect(queue_redraw)
func _draw() -> void:
 var center: Vector2=size*.5;var radius: float=minf(size.y*.35,size.x*.25)
 draw_circle(center,radius,Color(.8,.25,.1,.12));draw_arc(center,radius,0,TAU,48,Color("ffad73"),2,true)
 if SettingsManager.high_contrast_warnings:
  draw_arc(center,radius,0,TAU,48,Color("fff0b0"),4,true);draw_string(ThemeDB.fallback_font,center+Vector2(-6,7),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("fff0b0"))
 if not SettingsManager.quiet_player_vfx:
  for i: int in range(4):draw_arc(center,radius+12+i*5,.2,1.1,12,Color(.35,.85,.65,.15),2,true)
 draw_circle(center+Vector2(-radius-32,0),10,Color("77dfbb"))
