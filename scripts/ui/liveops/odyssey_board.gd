extends Control
const PRESENTATION_REVISION: int=3
signal travel_finished
const Art=preload("res://scripts/ui/liveops/odyssey_art.gd")
const TILE=preload("res://assets/ui/liveops/odyssey/imperial_v2/tile_mobile.png")
const TEMPLE=preload("res://assets/ui/liveops/odyssey/temple.png")
const DRAGON=preload("res://assets/ui/liveops/odyssey/dragon.png")
const FRAMES=preload("res://assets/character/player/player_lin_yue_idle_walk_spriteframes.tres")
const STONE=preload("res://assets/ui/shared/resources/spirit_stone_premium.png")
const JADE=preload("res://assets/ui/shared/resources/celestial_jade_premium.png")
const SEAL=preload("res://assets/ui/shared/resources/pavilion_seal_premium.png")
const TYPES: Array[String]=["LOTUS","STONE","SCROLL","CHEST","STONE","GATE","JADE","STONE","LOTUS","CHEST","SCROLL","STONE","GATE","JADE","STONE","CHEST","LOTUS","SCROLL","STONE","GATE"]
var token: AnimatedSprite2D
var selected: int=0
var coordinates: Array[Vector2i]=[]
var _from: int=0
var _steps: int=0
var _travel: float=0.0
var _age: float=0.0
var _idle_clock: float=0.0
var _last_step: int=-1
var _landing: float=0.0
var _selection_frame: StyleBoxFlat
var _info_frame: StyleBoxTexture
static var _cached_frame: Texture2D
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for x: int in range(6): coordinates.append(Vector2i(x,0))
	for y: int in range(1,6): coordinates.append(Vector2i(5,y))
	for x: int in range(4,-1,-1): coordinates.append(Vector2i(x,5))
	for y: int in range(4,0,-1): coordinates.append(Vector2i(0,y))
	token=AnimatedSprite2D.new(); token.sprite_frames=FRAMES; token.play("idle_down"); token.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; token.z_index=0; add_child(token)
	_selection_frame=StyleBoxFlat.new(); _selection_frame.bg_color=Color("197c63"); _selection_frame.border_color=Art.GOLD; _selection_frame.set_border_width_all(2); _selection_frame.set_corner_radius_all(12)
	if _cached_frame==null:
		var image: Image=TILE.get_image(); image.resize(128,128,Image.INTERPOLATE_LANCZOS); _cached_frame=ImageTexture.create_from_image(image)
	_info_frame=StyleBoxTexture.new(); _info_frame.texture=_cached_frame; _info_frame.texture_margin_left=24; _info_frame.texture_margin_right=24; _info_frame.texture_margin_top=24; _info_frame.texture_margin_bottom=24
	resized.connect(_layout); _layout()
func _width() -> float: return size.x
func tile_size() -> Vector2:
	return Vector2((size.x-8.0)/6.0,minf((size.y-66.0)/6.0,94.0))
func point(index: int) -> Vector2:
	if coordinates.is_empty(): return size*0.5
	var c: Vector2i=coordinates[posmod(index,20)]; var cell: Vector2=tile_size()
	return Vector2((size.x-cell.x*6.0)*0.5+cell.x*(float(c.x)+0.5),66.0+cell.y*(float(c.y)+0.5))
func _layout() -> void:
	if token!=null:
		var display: float=clampf(_width()*0.22,118,148); token.scale=Vector2.ONE*display/96.0
		if not is_travelling(): token.position=point(selected)-Vector2(0,display*0.25)
	queue_redraw()
func is_travelling() -> bool: return _steps>0
func show_position(index: int, steps: int=0) -> void:
	if token==null: selected=index; return
	if steps<1: _steps=0; selected=index; _layout(); return
	_from=selected; selected=index; _steps=clampi(steps,1,6); _travel=0; _last_step=-1
func _process(delta: float) -> void:
	_age+=delta; _landing=maxf(0,_landing-delta)
	if is_travelling():
		var duration: float=0.10 if not Art.reduced(self) else 0.04
		_travel+=delta
		var step: int=mini(int(_travel/duration),_steps-1)
		var t: float=clampf((_travel-float(step)*duration)/duration,0,1)
		var start: Vector2=point(_from+step); var finish: Vector2=point(_from+step+1)
		if step!=_last_step:
			var grid: Vector2i=coordinates[posmod(_from+step+1,20)]-coordinates[posmod(_from+step,20)]
			var direction: String="right" if grid.x>0 else "left" if grid.x<0 else "down" if grid.y>0 else "up"
			token.play("walk_"+direction); _last_step=step
		var lift: float=sin(t*PI)*8.0 if not Art.reduced(self) else 0.0
		token.position=start.lerp(finish,t*t*(3.0-2.0*t))-Vector2(0,token.scale.x*96*0.25+lift)
		if _travel>=float(_steps)*duration: _steps=0; _landing=0.65; token.play("idle_down"); _layout(); travel_finished.emit()
		queue_redraw()
	else:
		_idle_clock+=delta
		if _idle_clock>=1.0/20.0: _idle_clock=0; queue_redraw()
func _ink(text: String, at: Vector2, font_size: int, color: Color=Art.GOLD) -> void:
	var font: Font=ThemeDB.fallback_font
	var origin: Vector2=at-Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5,0)
	draw_string_outline(font,origin+Vector2(0,1),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("05201d"))
	draw_string(font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _tile(index: int) -> void:
	var center: Vector2=point(index); var span: Vector2=tile_size()-Vector2(3,3)
	var rect:=Rect2(center-span*0.5,span)
	if index==selected: draw_style_box(_selection_frame,rect.grow(1))
	draw_texture_rect(TILE,rect,false,Color("fff1ba") if index==selected else Color.WHITE)
	var icon: Texture2D=JADE if TYPES[index]=="JADE" else DRAGON if TYPES[index]=="GATE" else STONE
	var side: float=clampf(minf(span.x,span.y)*0.62,38,54)
	draw_texture_rect(icon,Rect2(center-Vector2.ONE*side*0.5-Vector2(0,5),Vector2.ONE*side),false)
	_ink("%02d" % (index+1),center+Vector2(0,span.y*0.5-9),14)
func _draw() -> void:
	if coordinates.is_empty() or _info_frame==null: return
	var cell: Vector2=tile_size(); var center:=Vector2(size.x*0.5,66+cell.y*3)
	for i: int in range(20): _tile(i)
	var temple: float=minf(cell.x*3.75,cell.y*3.75)
	draw_texture_rect(TEMPLE,Rect2(center-Vector2(temple*0.5,temple*0.69),Vector2.ONE*temple),false)
	var info:=Rect2(Vector2(center.x-cell.x*1.78,center.y+cell.y*1.03),Vector2(cell.x*3.56,cell.y*0.96))
	draw_style_box(_info_frame,info)
	var kind: String="CHOOSE YOUR PATH" if TYPES[posmod(selected,20)]=="GATE" else "CELESTIAL JADE" if TYPES[posmod(selected,20)]=="JADE" else "SPIRIT STONES"
	_ink("TILE %02d" % (posmod(selected,20)+1),Vector2(center.x,info.position.y+info.size.y*0.40),16)
	_ink(kind,Vector2(center.x,info.position.y+info.size.y*0.73),21)
	var at: Vector2=token.position+Vector2(0,token.scale.x*96*0.25) if is_travelling() else point(selected)
	draw_set_transform(at+Vector2(0,8),0,Vector2(1,0.35)); draw_circle(Vector2.ZERO,cell.x*0.39,Color(0.01,0.06,0.05,0.65)); draw_set_transform(Vector2.ZERO)
	if not Art.reduced(self):
		var pulse: float=0.5+0.5*sin(_age*2)
		draw_texture_rect(SEAL,Rect2(at-Vector2(35,30),Vector2(70,70)),false,Color(0.6,1,0.85,0.12+pulse*0.08))
		if _landing>0:
			var reveal: float=1.0-_landing/0.65; var span:=Vector2(110,58)*(1+reveal*0.4)
			draw_texture_rect(DRAGON,Rect2(at-span*0.5-Vector2(0,55+reveal*20),span),false,Color(1,1,1,(1-reveal)*0.8))
