extends RefCounted
const JadeMaterial=preload("res://scripts/ui/liveops/event_jade_material.gd")
const GOLD: Color=Color("d6b56f")
const CREAM: Color=Color("ffedbc")
const JADE: Color=Color("8ed7bc")
const TEXT: Color=Color("e2ece5")
const MUTED: Color=Color("a1b7ac")
const DISPLAY: Font=preload("res://assets/ui/library/fonts/archive_serif.ttf")
static func panel(fill: Color=Color("092820"),edge: Color=Color("5b6540"),radius: int=12) -> StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=fill;box.border_color=edge;box.set_border_width_all(1);box.set_corner_radius_all(radius)
 return box
static func button(button_node: Button,featured: bool=false) -> void:
 button_node.mouse_filter=Control.MOUSE_FILTER_PASS;button_node.focus_mode=Control.FOCUS_NONE
 button_node.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE;button_node.keep_pressed_outside=false
 button_node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 button_node.add_theme_color_override("font_color",CREAM);button_node.add_theme_color_override("font_hover_color",CREAM)
 button_node.add_theme_color_override("font_pressed_color",CREAM)
 if featured:
  var skin:=StyleBoxTexture.new();skin.texture=preload("res://assets/ui/liveops/event_center_v2/journey_button.svg")
  skin.texture_margin_left=24;skin.texture_margin_right=24;skin.texture_margin_top=14;skin.texture_margin_bottom=14
  skin.content_margin_left=24;skin.content_margin_right=24;skin.content_margin_top=10;skin.content_margin_bottom=10
  button_node.add_theme_stylebox_override("normal",skin);button_node.add_theme_stylebox_override("hover",skin)
  var pressed: StyleBoxTexture=skin.duplicate();pressed.modulate_color=Color(.8,.9,.82);button_node.add_theme_stylebox_override("pressed",pressed)
 else:
  button_node.add_theme_stylebox_override("normal",JadeMaterial.button())
  button_node.add_theme_stylebox_override("hover",JadeMaterial.button())
  button_node.add_theme_stylebox_override("pressed",JadeMaterial.button(false,true))
 button_node.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
 button_node.add_theme_stylebox_override("disabled",JadeMaterial.button(true))

static func meter() -> ProgressBar:
 var bar:=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size.y=5;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 bar.add_theme_stylebox_override("background",panel(Color("041914"),Color("314d3c"),2))
 bar.add_theme_stylebox_override("fill",panel(Color("bba768"),Color("d1c490"),2))
 return bar
