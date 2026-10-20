extends RefCounted
## One resident atlas; AtlasTexture regions avoid CPU image extraction per card.
const ATLAS=preload("res://assets/ui/liveops/odyssey/flow/flow_atlas.png")
const FONT=preload("res://assets/ui/library/fonts/archive_serif.ttf")
const INK=Color("263d32")
const MUTED=Color("647160")
const GOLD=Color("ead09b")
static var regions: Dictionary={}
static var frames: Dictionary={}
static func texture(index: int)->Texture2D:
 if regions.has(index): return regions[index]
 var cell:=Vector2(float(ATLAS.get_width())/3.0,float(ATLAS.get_height())/2.0)
 var tile:=AtlasTexture.new();tile.atlas=ATLAS;tile.filter_clip=true
 tile.region=Rect2(Vector2(float(index%3)*cell.x,floorf(float(index)/3.0)*cell.y)+Vector2(12,12),Vector2(cell.x-24,cell.y-56 if index==3 else cell.y-68 if index in [4,5] else cell.y-24))
 regions[index]=tile;return tile
static func style(index: int=3,compact: bool=false)->StyleBoxTexture:
 # StyleBoxTexture nine-patch uses an independent image, never a nested atlas
 # region. Resolve each of the three frame textures once, not once per card.
 var key: String=str(index)+("_compact" if compact else "_panel")
 if not frames.has(key):
  var image: Image=texture(index).get_image()
  if compact: image.resize(roundi(float(image.get_width())*0.40),roundi(float(image.get_height())*0.40),Image.INTERPOLATE_LANCZOS)
  frames[key]=ImageTexture.create_from_image(image)
 var box:=StyleBoxTexture.new();box.texture=frames[key]
 box.texture_margin_left=40 if compact else 48;box.texture_margin_right=40 if compact else 48;box.texture_margin_top=40;box.texture_margin_bottom=40
 box.content_margin_left=40 if index==3 else 24;box.content_margin_right=40 if index==3 else 24;box.content_margin_top=44 if index==3 else 14;box.content_margin_bottom=48 if index==3 else 14
 return box
static func card()->PanelContainer:
 var panel:=PanelContainer.new();panel.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;panel.add_theme_stylebox_override("panel",style(3));return panel
static func button(title: String,callback: Callable)->Button:
 var action:=Button.new();action.text=title;action.custom_minimum_size=Vector2(0,58)
 action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 action.add_theme_stylebox_override("normal",style(4,true));action.add_theme_stylebox_override("hover",style(4,true));action.add_theme_stylebox_override("pressed",style(4,true));action.add_theme_stylebox_override("disabled",style(4,true))
 action.add_theme_color_override("font_color",Color("fff0c4"));action.add_theme_color_override("font_hover_color",Color("ffffff"));action.add_theme_color_override("font_pressed_color",GOLD);action.add_theme_color_override("font_disabled_color",Color("c2c9b0"));action.add_theme_font_size_override("font_size",18)
 action.keep_pressed_outside=false;action.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE;action.pressed.connect(callback);return action
static func text(copy: String,points: int=17,heading: bool=false)->Label:
 var node:=Label.new();node.text=copy;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
 node.add_theme_color_override("font_color",INK);node.add_theme_font_size_override("font_size",points)
 node.add_theme_color_override("font_shadow_color",Color.TRANSPARENT);node.add_theme_color_override("font_outline_color",Color.TRANSPARENT);node.add_theme_constant_override("outline_size",0);node.add_theme_constant_override("shadow_offset_x",0);node.add_theme_constant_override("shadow_offset_y",0)
 node.set_meta("jade_mobile_readability_v2",true)
 if heading: node.add_theme_font_override("font",FONT)
 return node

static func progress(meter: ProgressBar) -> void:
 var back:=StyleBoxFlat.new();back.bg_color=Color("d1ccb9");back.set_corner_radius_all(5)
 var fill:=StyleBoxFlat.new();fill.bg_color=Color("17896b");fill.set_corner_radius_all(5)
 meter.add_theme_stylebox_override("background",back);meter.add_theme_stylebox_override("fill",fill)
