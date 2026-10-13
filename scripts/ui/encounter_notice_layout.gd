extends RefCounted
## One coordinate space for all combat notices: the actual HUD safe area.
static func fit(panel: Control, safe_area: Control) -> void:
 if not is_instance_valid(panel) or not is_instance_valid(safe_area):return
 var width: float=minf(560.0,safe_area.size.x*.9)
 panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 panel.size.x=width
 var top: float=12.0
 for name: String in ["TopHUD","BossPanel"]:
  var strip: Control=safe_area.get_node_or_null(name)
  if strip!=null and strip.visible:top=maxf(top,strip.get_rect().end.y+16.0)
 var height: float=maxf(110.0,panel.get_combined_minimum_size().y)
 panel.size=Vector2(width,height)
 panel.position=Vector2((safe_area.size.x-panel.size.x)*.5,top)
 panel.pivot_offset=panel.size*.5
static func settle(panel: Control,safe_area: Control) -> void:
 fit(panel,safe_area)
 for i: int in range(3):
  if not is_instance_valid(panel) or not is_instance_valid(safe_area):return
  await safe_area.get_tree().process_frame
  fit(panel,safe_area)

class Frame extends Control:
 var accent: Color=Color.GOLD
 func _ready() -> void:
  mouse_filter=Control.MOUSE_FILTER_IGNORE
  resized.connect(queue_redraw)
 func _draw() -> void:
  var ink:=Color(accent, .65)
  for corner: Vector2 in [Vector2(8,8),Vector2(size.x-8,8),Vector2(8,size.y-8),Vector2(size.x-8,size.y-8)]:
   var x: float=1 if corner.x<size.x*.5 else -1
   var y: float=1 if corner.y<size.y*.5 else -1
   draw_polyline(PackedVector2Array([corner+Vector2(0,22*y),corner+Vector2(0,8*y),corner+Vector2(8*x,0),corner+Vector2(30*x,0)]),ink,1.2,true)
  for y: float in [5.0,size.y-5.0]:
   var c:=Vector2(size.x*.5,y)
   draw_colored_polygon(PackedVector2Array([c+Vector2(-4,0),c+Vector2(0,-2),c+Vector2(4,0),c+Vector2(0,2)]),accent)
   draw_line(c+Vector2(-38,0),c+Vector2(-8,0),ink,1,true)
   draw_line(c+Vector2(8,0),c+Vector2(38,0),ink,1,true)
static func decorate(panel: Control,accent: Color) -> void:
 var frame: Frame=panel.get_node_or_null("CeremonialFrame") as Frame
 if frame==null:
  frame=Frame.new();frame.name="CeremonialFrame";panel.add_child(frame)
 frame.accent=accent;frame.queue_redraw()
