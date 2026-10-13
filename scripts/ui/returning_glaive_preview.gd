extends Control
const Art = preload("res://scripts/weapon/returning_glaive_art.gd")
const Imperial = preload("res://scripts/ui/pavilion_imperial_style.gd")
var age: float = 0.0
var sample: float = 0.0
var phase_label: Label
var stage: Control
var player_offset: float = 0.0
var level: int = 1
var level_button: Button
func _ready() -> void:
 name="ReturningGlaivePreview"
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);z_index=100
 var shade:=ColorRect.new();shade.color=Color(0,.015,.025,.94);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
 var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(center)
 var panel:=PanelContainer.new();panel.custom_minimum_size.x=minf(get_viewport_rect().size.x-32,480);panel.add_theme_stylebox_override("panel",Imperial.new());center.add_child(panel)
 var compact: bool=get_viewport_rect().size.y<700
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",6 if compact else 12);panel.add_child(box)
 var title:=Label.new();title.text="CELESTIAL RETURNING GLAIVE";title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",18 if compact else 22);title.add_theme_color_override("font_color",Art.GOLD);box.add_child(title)
 var rarity:=Label.new();rarity.text="LEGENDARY • ★1 → ★5";rarity.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;rarity.add_theme_color_override("font_color",Art.GOLD);box.add_child(rarity)
 stage=Control.new();stage.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;stage.custom_minimum_size.y=150 if compact else 240;stage.draw.connect(_draw_demo);box.add_child(stage)
 phase_label=Label.new();phase_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;phase_label.add_theme_color_override("font_color",Art.CYAN);box.add_child(phase_label)
 var desc:=Label.new();desc.text="Lempar → putar → kembali.\nTurquoise: pergi • Emas: pulang\nLv.3: sabit • Lv.5: dua cakram\nLv.7: cincin pada tangkapan\nGeser posisi untuk arah pulang.";desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.add_theme_font_size_override("font_size",13 if compact else 15);box.add_child(desc)
 var slider:=HSlider.new();slider.min_value=-60;slider.max_value=60;slider.custom_minimum_size.y=36;slider.value_changed.connect(func(value: float) -> void: player_offset=value;stage.queue_redraw());box.add_child(slider)
 level_button=Button.new();level_button.text="PREVIEW LV.1";level_button.custom_minimum_size.y=44;level_button.pressed.connect(_cycle_level);level_button.add_theme_stylebox_override("normal",Imperial.new());box.add_child(level_button)
 var close:=Button.new();close.text="TUTUP PREVIEW";close.custom_minimum_size.y=44;close.add_theme_stylebox_override("normal",Imperial.new());close.pressed.connect(queue_free);box.add_child(close);close.grab_focus()
func _cycle_level() -> void:
 level=3 if level==1 else (5 if level==3 else (7 if level==5 else 1));age=0.0;level_button.text="PREVIEW LV.%d"%level
func _process(delta: float) -> void:
 age=fmod(age+delta,2.3);sample-=delta
 if sample>0: return
 sample=.05
 phase_label.text="PRATINJAU STATIS" if SettingsManager.reduced_effects else ("01 • LEMPAR" if age<.46 else ("02 • PUTAR" if age<.70 else "03 • KEMBALI"))
 stage.queue_redraw()
func _unhandled_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"): get_viewport().set_input_as_handled();queue_free()
func _draw_demo() -> void:
 var origin: Vector2=stage.size*Vector2(.5,.83)+Vector2(player_offset,0)
 var start: Vector2=stage.size*Vector2(.5,.83)
 var end: Vector2=stage.size*Vector2(.5,.19)
 var reduced: bool=SettingsManager.reduced_effects
 stage.draw_circle(origin,8,Color(.19,.66,.65));stage.draw_arc(origin,11,0,TAU,16,Color(Art.GOLD,.7),1.2,true)
 stage.draw_line(start,end,Color(Art.CYAN,.16),1,true)
 stage.draw_line(end,origin,Color(Art.GOLD,.25),1,true)
 for i: int in range(2 if level>=5 else 1):
  var t: float=.82 if reduced else age-i*.16
  if t<0 or t>1.8: continue
  var returning: bool=t>=.70
  var pos: Vector2=end
  var curve: float=40 if level>=3 else 0
  if t<.46: pos=start.lerp(end,t/.46)+Vector2(sin(t/.46*PI)*curve*(1 if i==0 else -1),0)
  elif returning: pos=end.lerp(origin,minf((t-.70)/.65,1))
  var caught: bool=t>=1.35
  if not caught: Art.disc(stage,pos,t*15*(1 if i==0 else -1),returning,reduced,48 if stage.size.y<200 else 64)
  elif level>=7: Art.closure(stage,origin,t-1.35,reduced,42)
