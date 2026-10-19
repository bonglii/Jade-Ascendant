extends RefCounted
## One resident atlas; AtlasTexture regions avoid CPU image extraction per card.
const ATLAS=preload("res://assets/ui/liveops/odyssey/flow/flow_atlas.png")
const FONT=preload("res://assets/ui/library/fonts/archive_serif.ttf")
const INK=Color("263d32")
const MUTED=Color("647160")
const GOLD=Color("ead09b")
static var regions: Dictionary={}
static func texture(index: int)->Texture2D:
 if regions.has(index): return regions[index]
 var cell:=Vector2(float(ATLAS.get_width())/3.0,float(ATLAS.get_height())/2.0)
 var tile:=AtlasTexture.new();tile.atlas=ATLAS;tile.filter_clip=true
 tile.region=Rect2(Vector2(float(index%3)*cell.x,floorf(float(index)/3.0)*cell.y)+Vector2(12,12),cell-Vector2(24,24))
 regions[index]=tile;return tile
static func style(index: int=3)->StyleBoxTexture:
 var box:=StyleBoxTexture.new();box.texture=texture(index)
 box.texture_margin_left=48;box.texture_margin_right=48;box.texture_margin_top=40;box.texture_margin_bottom=40
 box.content_margin_left=26;box.content_margin_right=26;box.content_margin_top=18;box.content_margin_bottom=18
 return box
static func card()->PanelContainer:
 var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",style(3));return panel
static func button(title: String,callback: Callable)->Button:
 var action:=Button.new();action.text=title;action.custom_minimum_size=Vector2(0,62)
 action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 action.add_theme_stylebox_override("normal",style(4));action.add_theme_stylebox_override("hover",style(4));action.add_theme_stylebox_override("pressed",style(4));action.add_theme_stylebox_override("disabled",style(5))
 action.add_theme_color_override("font_color",Color("fff0c4"));action.add_theme_color_override("font_hover_color",Color("ffffff"));action.add_theme_color_override("font_pressed_color",GOLD);action.add_theme_color_override("font_disabled_color",Color("e3dfcc"));action.add_theme_font_size_override("font_size",16)
 action.keep_pressed_outside=false;action.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE;action.pressed.connect(callback);return action
static func text(copy: String,points: int=17,heading: bool=false)->Label:
 var node:=Label.new();node.text=copy;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
 node.add_theme_color_override("font_color",INK);node.add_theme_font_size_override("font_size",points)
 if heading: node.add_theme_font_override("font",FONT)
 return node
