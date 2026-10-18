extends Button
const Art=preload("res://scripts/ui/liveops/odyssey_art.gd")
var glyph: String=""
var primary: bool=false
var caption: Label
var _state: String=""
var _motion: Tween
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_PASS; focus_mode=Control.FOCUS_ALL
	custom_minimum_size.y=maxf(custom_minimum_size.y,64)
	for state: String in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for color: String in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color","font_outline_color"]: add_theme_color_override(color,Color.TRANSPARENT)
	add_theme_constant_override("outline_size",0)
	caption=Label.new(); caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); caption.offset_left=24; caption.offset_right=-24
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size",23 if primary else 16)
	caption.add_theme_color_override("font_shadow_color",Color(0,0.02,0.03,0.95)); caption.add_theme_constant_override("shadow_offset_y",2)
	if primary: caption.add_theme_font_override("font",Art.FONT)
	add_child(caption); button_down.connect(_press.bind(true)); button_up.connect(_press.bind(false))
	resized.connect(func() -> void: pivot_offset=size*0.5)
	pivot_offset=size*0.5; _update()
func _process(_delta: float) -> void: _update()
func _update() -> void:
	var state: String=str(disabled)+str(button_pressed)+str(has_focus())+text
	if state==_state: return
	_state=state
	caption.text=text; caption.add_theme_color_override("font_color",Color("aebfb2") if disabled else Art.GOLD if primary else Color("f5ecd2")); queue_redraw()
func _press(down: bool) -> void:
	if _motion!=null: _motion.kill()
	_motion=create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self,"scale",Vector2.ONE*(0.965 if down else 1.0),0.09)
func _draw() -> void:
	var skin: Texture2D=Art.texture("medallion" if not glyph.is_empty() else "button")
	draw_texture_rect(skin,Rect2(Vector2(0,3),size),false,Color(0,0.02,0.02,0.6))
	draw_texture_rect(skin,Rect2(Vector2.ZERO,size),false,Color(0.45,0.53,0.48,0.90) if disabled else Color.WHITE)
	if glyph.is_empty(): return
	var center: Vector2=size*0.5; var r: float=size.x*0.13; var ink:=Color("f4e4b5")
	match glyph:
		"back": draw_polyline(PackedVector2Array([center+Vector2(r,-r),center+Vector2(-r,0),center+Vector2(r,r)]),ink,3,true)
		"close":
			draw_line(center-Vector2(r,r),center+Vector2(r,r),ink,3,true); draw_line(center+Vector2(-r,r),center+Vector2(r,-r),ink,3,true)
		"refresh":
			draw_arc(center,r*1.35,0.4,5.8,24,ink,2.5,true); draw_line(center+Vector2(r*1.2,-r*0.8),center+Vector2(r*0.15,-r*1.2),ink,2.5,true)
		"info":
			draw_circle(center-Vector2(0,r),2,ink); draw_line(center,center+Vector2(0,r),ink,3,true)
