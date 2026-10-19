extends PanelContainer
const Flow=preload("res://scripts/ui/liveops/odyssey_flow_skin.gd")
const Art=preload("res://scripts/ui/liveops/odyssey_art.gd")
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_theme_stylebox_override("panel",Flow.style(4,true))
 var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_theme_constant_override("separation",12);add_child(row)
 var icon:=TextureRect.new();icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.set_script(preload("res://scripts/ui/liveops/odyssey_die_badge.gd"));icon.texture=Art.DIE;icon.custom_minimum_size=Vector2(58,58);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(icon)
 var copy:=VBoxContainer.new();copy.mouse_filter=Control.MOUSE_FILTER_IGNORE;copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(copy)
 for item: Array in [["REWARD GRANTED",18],["+1 DADU",26],["Perjalanan · terkonfirmasi server",15]]:
  var text: Label=Flow.text(str(item[0]),int(item[1]),true);text.add_theme_color_override("font_color",Color("fff0c4"));copy.add_child(text)
 call_deferred("_fit_height")
 modulate.a=0.0
 var motion:=create_tween();motion.tween_property(self,"modulate:a",1.0,0.18);motion.tween_interval(4.0);motion.tween_property(self,"modulate:a",0.0,0.3);motion.tween_callback(queue_free)

func _fit_height()->void:
 size.y=get_combined_minimum_size().y
