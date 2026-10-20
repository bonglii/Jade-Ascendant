extends RefCounted
## One coordinate space for all combat notices: the actual HUD safe area.
static func fit(panel: Control, safe_area: Control) -> void:
 if not is_instance_valid(panel) or not is_instance_valid(safe_area): return
 var width: float = maxf(220,minf(560,safe_area.size.x-28))
 panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 panel.custom_minimum_size = Vector2.ZERO
 panel.clip_contents = true
 for label: Label in panel.find_children("*","Label",true,false):
  label.custom_minimum_size.x = 0
  label.max_lines_visible = 2
  label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 var top: float = clampf(safe_area.size.y*0.28,150,320)
 for node_name: String in ["TopHUD","BossPanel"]:
  var strip: Control = safe_area.get_node_or_null(node_name)
  if strip != null and strip != panel and strip.visible: top = maxf(top,strip.get_rect().end.y+14)
 var height: float = 176 if panel.name == "BossPreWarning" else 156
 panel.size = Vector2(width,height)
 panel.position = Vector2((safe_area.size.x-width)*0.5,minf(top,maxf(0,safe_area.size.y-height-24)))
 panel.pivot_offset = panel.size*0.5
static func settle(panel: Control, safe_area: Control) -> void:
 # All geometry is established before visibility; no multi-frame resize coroutine
 # may resurrect an old notice after spawn/defeat or paint a full-height dark box.
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
 panel.add_theme_stylebox_override("panel",preload("res://scripts/ui/combat_chrome.gd").skin("crimson" if panel.name == "BossPreWarning" else "gold"))
 var frame: Frame=panel.get_node_or_null("CeremonialFrame") as Frame
 if frame==null:
  frame=Frame.new();frame.name="CeremonialFrame";panel.add_child(frame)
 frame.accent=accent;frame.queue_redraw()
