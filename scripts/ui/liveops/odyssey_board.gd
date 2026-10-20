extends Control
const PRESENTATION_REVISION: int=4
signal travel_finished
const Art=preload("res://scripts/ui/liveops/odyssey_art.gd")
const ActorMaterial=preload("res://scripts/effects/premium_actor_material.gd")
const TILE=preload("res://assets/ui/liveops/odyssey/imperial_v2/tile_mobile.png")
const TEMPLE=preload("res://assets/ui/liveops/odyssey/temple.png")
const DRAGON=preload("res://assets/ui/liveops/odyssey/dragon.png")
const HALO=preload("res://assets/ui/pavilion/vfx/shared/soft_halo_premium.png")
const FRAMES=preload("res://assets/ui/liveops/odyssey/pawn_v2/lin_yue_board.tres")
const STONE=preload("res://assets/ui/shared/resources/spirit_stone_premium.png")
const JADE=preload("res://assets/ui/shared/resources/celestial_jade_premium.png")
const SEAL=preload("res://assets/ui/shared/resources/pavilion_seal_premium.png")
const TYPES: Array[String]=["LOTUS","STONE","SCROLL","CHEST","STONE","GATE","JADE","STONE","LOTUS","CHEST","SCROLL","STONE","GATE","JADE","STONE","CHEST","LOTUS","SCROLL","STONE","GATE"]
const STEP_SECONDS: float=0.28
const LAST_STEP_SECONDS: float=0.34
const ARRIVAL_SECONDS: float=0.22
const TOP: float=110.0
const CELL: float=192.0
const FEET: float=68.0
var token: AnimatedSprite2D
var selected: int=0
var coordinates: Array[Vector2i]=[]
var seal_stops: Array[int]=[]
var claimed_seals: Array[int]=[]
var _from: int=0
var _destination: int=0
var _steps: int=0
var _travel: float=0.0
var _age: float=0.0
var _idle_clock: float=0.0
var _last_step: int=-1
var _landing: float=0.0
var _arrival_wait: float=0.0
var _facing: String="down"
var _selection_frame: StyleBoxFlat
var _info_frame: StyleBoxTexture
var _actor_material: ShaderMaterial
static var _cached_frame: Texture2D
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE; texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 for x: int in range(6): coordinates.append(Vector2i(x,0))
 for y: int in range(1,6): coordinates.append(Vector2i(5,y))
 for x: int in range(4,-1,-1): coordinates.append(Vector2i(x,5))
 for y: int in range(4,0,-1): coordinates.append(Vector2i(0,y))
 token=AnimatedSprite2D.new(); token.sprite_frames=FRAMES; token.play("idle_down"); token.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; token.z_index=1; add_child(token)
 _actor_material=ActorMaterial.create(token,Color("8fe9df")); _actor_material.set_shader_parameter("rim_strength",0.26)
 token.frame_changed.connect(_sync_frame); token.animation_changed.connect(_sync_frame); _sync_frame()
 _selection_frame=StyleBoxFlat.new(); _selection_frame.bg_color=Color("197c63"); _selection_frame.border_color=Art.GOLD; _selection_frame.set_border_width_all(2); _selection_frame.set_corner_radius_all(12)
 if _cached_frame==null:
  var image: Image=TILE.get_image(); image.resize(128,128,Image.INTERPOLATE_LANCZOS); _cached_frame=ImageTexture.create_from_image(image)
 _info_frame=StyleBoxTexture.new(); _info_frame.texture=_cached_frame; _info_frame.texture_margin_left=24; _info_frame.texture_margin_right=24; _info_frame.texture_margin_top=24; _info_frame.texture_margin_bottom=24
 resized.connect(_layout); _layout()
func _sync_frame() -> void:
 if token!=null and _actor_material!=null: ActorMaterial.sync_frame(token,_actor_material)
func _width() -> float: return size.x
func tile_size() -> Vector2:
 return Vector2((size.x-8.0)/6.0,minf((size.y-TOP)/6.0,94.0))
func point(index: int) -> Vector2:
 if coordinates.is_empty(): return size*0.5
 var c: Vector2i=coordinates[posmod(index,20)]; var cell: Vector2=tile_size()
 return Vector2((size.x-cell.x*6.0)*0.5+cell.x*(float(c.x)+0.5),TOP+cell.y*(float(c.y)+0.5))
func _place(at: Vector2) -> void:
 token.position=at-Vector2(0,FEET*token.scale.x)
func _layout() -> void:
 if token!=null:
  var display: float=clampf(tile_size().x*1.85,94,190); token.scale=Vector2.ONE*display/CELL
  if _steps==0: _place(point(selected))
 queue_redraw()
func set_reward_stops(definition: Dictionary, claimed: Array) -> void:
 var stops: Array[int]=[]; var collected: Array[int]=[]
 for value: Variant in definition.get("seal_tiles",[]):
  if value is float or value is int:
   if int(value)>=0 and int(value)<20: stops.append(int(value))
 for value: Variant in claimed:
  if (value is float or value is int) and int(value) in stops: collected.append(int(value))
 if stops!=seal_stops or collected!=claimed_seals: seal_stops=stops; claimed_seals=collected; queue_redraw()
func is_travelling() -> bool: return _steps>0 or _arrival_wait>0.0
func show_position(index: int, steps: int=0) -> void:
 index=posmod(index,20)
 if token==null: selected=index; return
 if steps<1:
  _steps=0; _arrival_wait=0; _landing=0; selected=index; _destination=index; token.play("idle_"+_facing); _layout(); return
 if is_travelling(): return
 _from=selected; _destination=index; _steps=clampi(steps,1,6); _travel=0; _last_step=-1
func _duration_for_step(step: int) -> float:
 if Art.reduced(self): return 0.15
 return LAST_STEP_SECONDS if step==_steps-1 else STEP_SECONDS
func _process(delta: float) -> void:
 _age+=delta; _landing=maxf(0,_landing-delta)
 if _steps>0:
  _travel+=delta
  var elapsed: float=_travel; var step: int=0
  while step<_steps-1 and elapsed>=_duration_for_step(step): elapsed-=_duration_for_step(step); step+=1
  var t: float=clampf(elapsed/_duration_for_step(step),0,1)
  var start: Vector2=point(_from+step); var finish: Vector2=point(_from+step+1)
  if step!=_last_step:
   var grid: Vector2i=coordinates[posmod(_from+step+1,20)]-coordinates[posmod(_from+step,20)]
   _facing="right" if grid.x>0 else "left" if grid.x<0 else "down" if grid.y>0 else "up"
   token.play("walk_"+_facing); _last_step=step
  _place(start.lerp(finish,t*t*(3.0-2.0*t)))
  if t>=1.0-0.000001 and step==_steps-1:
   var overshoot: float=maxf(0,elapsed-_duration_for_step(step))
   _steps=0; selected=_destination; _arrival_wait=maxf(0,ARRIVAL_SECONDS-overshoot); _landing=0.65; token.play("idle_"+_facing); _place(point(selected))
   if _arrival_wait==0:travel_finished.emit()
  queue_redraw()
 elif _arrival_wait>0:
  _arrival_wait=maxf(0,_arrival_wait-delta)
  if _arrival_wait==0: travel_finished.emit()
  queue_redraw()
 else:
  _idle_clock+=delta
  if _idle_clock>=1.0/24.0: _idle_clock=0; queue_redraw()
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
 var kind: String=TYPES[index]; var seal_available: bool=index in seal_stops and index not in claimed_seals
 var icon: Texture2D=SEAL if seal_available else JADE if kind=="JADE" else DRAGON if kind=="GATE" else STONE
 var side: float=clampf(minf(span.x,span.y)*0.64,36,54)
 if kind=="GATE":
  var crest: float=minf(span.x*0.83,72)
  if not Art.reduced(self): draw_texture_rect(HALO,Rect2(center-Vector2.ONE*side*.55-Vector2(0,4),Vector2.ONE*side*1.1),false,Color(0.7,1,0.85,0.19+sin(_age*2+index)*0.04))
  draw_texture_rect(DRAGON,Rect2(center-Vector2(crest*.5,crest*.29)-Vector2(0,5),Vector2(crest,crest*.48)),false)
 else:
  if seal_available: draw_texture_rect(HALO,Rect2(center-Vector2.ONE*side*.65-Vector2(0,4),Vector2.ONE*side*1.3),false,Color(1,.9,.6,.23))
  draw_texture_rect(icon,Rect2(center-Vector2.ONE*side*0.5-Vector2(0,5),Vector2.ONE*side),false)
 _ink("%02d" % (index+1),center+Vector2(0,span.y*0.5-9),14)
func _draw() -> void:
 if coordinates.is_empty() or _info_frame==null: return
 var cell: Vector2=tile_size(); var center:=Vector2(size.x*0.5,TOP+cell.y*3)
 for i: int in range(20): _tile(i)
 var temple: float=minf(cell.x*3.75,cell.y*3.75)
 var breathing: float=0 if Art.reduced(self) else sin(_age*1.5)*1.5
 if not Art.reduced(self): draw_texture_rect(HALO,Rect2(center-Vector2.ONE*temple*.49-Vector2(0,temple*.15),Vector2.ONE*temple*.98),false,Color(.65,.95,.8,.13))
 draw_texture_rect(TEMPLE,Rect2(center-Vector2(temple*0.5,temple*0.69+breathing),Vector2.ONE*temple),false)
 var info:=Rect2(Vector2(center.x-cell.x*1.78,center.y+cell.y*1.03),Vector2(cell.x*3.56,cell.y*0.96))
 draw_style_box(_info_frame,info)
 var seal_available: bool=selected in seal_stops and selected not in claimed_seals
 var kind: String="CHOOSE YOUR PATH" if TYPES[selected]=="GATE" else "PAVILION SEAL" if seal_available else "CELESTIAL JADE" if TYPES[selected]=="JADE" else "SPIRIT STONES"
 _ink("TILE %02d" % (selected+1),Vector2(center.x,info.position.y+info.size.y*0.40),16)
 _ink(kind,Vector2(center.x,info.position.y+info.size.y*0.73),mini(21,roundi(cell.x*.29)))
 var at: Vector2=token.position+Vector2(0,FEET*token.scale.x)
 draw_set_transform(at+Vector2(0,3),0,Vector2(1,0.35)); draw_circle(Vector2.ZERO,cell.x*0.34,Color(0.01,0.06,0.05,0.65)); draw_set_transform(Vector2.ZERO)
 var aura: float=cell.x*(0.95 if not Art.reduced(self) else .85)
 draw_texture_rect(HALO,Rect2(at-Vector2(aura*.5,aura*.24),Vector2(aura,aura*.48)),false,Color(.6,1,.85,.48))
 if _landing>0 and not Art.reduced(self):
  var reveal: float=1.0-_landing/0.65; var span:=Vector2(cell.x*1.3,cell.x*.65)*(1+reveal*0.35)
  draw_texture_rect(DRAGON,Rect2(at-span*0.5-Vector2(0,60+reveal*20),span),false,Color(1,1,1,(1-reveal)*0.65))
