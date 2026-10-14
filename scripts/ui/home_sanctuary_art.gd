extends RefCounted

const BACKGROUND: Texture2D = preload("res://assets/ui/home/sanctuary/background.png")
const FRAME_PANEL: Texture2D = preload("res://assets/ui/home/sanctuary/frame_panel.png")
const FRAME_COMPACT: Texture2D = preload("res://assets/ui/home/sanctuary/frame_compact.png")
const SERIF: Font = preload("res://assets/ui/library/fonts/archive_serif.ttf")

static func frame(parent: Control, compact: bool = true) -> NinePatchRect:
 var node := NinePatchRect.new()
 node.name = "SanctuaryFrame"
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 node.texture = FRAME_COMPACT if compact else FRAME_PANEL
 node.draw_center = false
 node.show_behind_parent = parent is BaseButton
 node.patch_margin_left = 38 if compact else 76
 node.patch_margin_right = node.patch_margin_left
 node.patch_margin_top = 20 if compact else 40
 node.patch_margin_bottom = node.patch_margin_top
 parent.add_child(node)
 var callback: Callable=func():_fit_frame(node,parent)
 parent.resized.connect(callback)
 var viewport: Viewport=parent.get_viewport()
 if viewport!=null:
  viewport.size_changed.connect(callback)
  parent.tree_exiting.connect(func():
   if is_instance_valid(viewport) and viewport.size_changed.is_connected(callback):viewport.size_changed.disconnect(callback)
  ,CONNECT_ONE_SHOT)
 _fit_frame(node,parent)
 return node

static func _fit_frame(node: NinePatchRect, parent: Control) -> void:
 # NinePatchRect's patch margins impose a minimum size. Scale its canvas,
 # rather than changing source cut lines, so small header buttons retain corners.
 var minimum := Vector2(node.patch_margin_left+node.patch_margin_right,node.patch_margin_top+node.patch_margin_bottom)
 var unit: float=clampf(parent.get_viewport_rect().size.x/648.0,.49,1.8)
 var factor := minf(unit,minf(parent.size.x/minimum.x,parent.size.y/minimum.y))
 factor=maxf(.01,factor)
 node.scale=Vector2.ONE*factor
 node.position=Vector2.ZERO
 node.size=parent.size/factor

static func fill(parent: Control, color: Color = Color(.008,.045,.048,.92)) -> Panel:
 var node := Panel.new()
 node.name = "SanctuaryGlass"
 node.show_behind_parent = parent is BaseButton
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var style := StyleBoxFlat.new()
 style.bg_color = color
 style.set_corner_radius_all(12)
 style.shadow_color = Color(.0,.015,.02,.24)
 style.shadow_size = 6
 node.add_theme_stylebox_override("panel", style)
 parent.add_child(node)
 node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 node.offset_left=4;node.offset_top=4;node.offset_right=-4;node.offset_bottom=-4
 return node
