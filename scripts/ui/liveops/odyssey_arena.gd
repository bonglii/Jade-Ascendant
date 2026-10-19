extends Control
signal completed(trace: String,abandon: bool)
const Sim=preload("res://scripts/ui/liveops/odyssey_arena_sim.gd")
const Flow=preload("res://scripts/ui/liveops/odyssey_flow_skin.gd")
const FLOOR=preload("res://assets/ui/liveops/odyssey/flow/arena_floor.png")
const PLAYER=preload("res://assets/character/player/player_lin_yue_idle_walk_spriteframes.tres")
const BOSS=preload("res://assets/enemy/boss_2d/atlas_1_5.png")
const SLASH=preload("res://assets/ui/liveops/odyssey/flow/qi_slash.svg")
const WARNING=preload("res://assets/ui/liveops/odyssey/flow/arena_warning.svg")
var client: Node
var battle: Dictionary={}
var state: Dictionary={}
var trace: String=""
var _owner: String=""
var _accumulator: float=0.0
var _stick: Vector2=Vector2.ZERO
var _finger: int=-1
var _mouse: bool=false
var _suspended: bool=false
var _finished: bool=false
var _abandoned: bool=false
var _player: AnimatedSprite2D
var _boss: AnimatedSprite2D
var _title: Label
var _health: ProgressBar
var _hint: Label
var _retreat: Button
var _retry: Button
var _health_old: int=5
var _hit_glow: float=0.0
static var _boss_frames: SpriteFrames
func _path()->String: return "user://odyssey_arena_"+_owner+".json" if _owner.length()==64 else ""
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_STOP;texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 _owner=str(client.snapshot.get("owner_binding","")) if client!=null else "";state=Sim.initial(int(battle.get("seed",0)));_load_trace()
 _player=AnimatedSprite2D.new();_player.sprite_frames=PLAYER;_player.play("idle_down");add_child(_player)
 if _boss_frames==null:
  _boss_frames=SpriteFrames.new();_boss_frames.remove_animation(&"default");var cell:=Vector2(float(BOSS.get_width())/6.0,float(BOSS.get_height())/6.0)
  for family: String in ["walk","melee","projectile","radial","lightning","shockwave"]:
   _boss_frames.add_animation(family);_boss_frames.set_animation_speed(family,8);_boss_frames.set_animation_loop(family,true)
   var row: int=["walk","melee","projectile","radial","lightning","shockwave"].find(family)
   for column: int in range(6):
    var tile:=AtlasTexture.new();tile.atlas=BOSS;tile.region=Rect2(Vector2(float(column)*cell.x,float(row)*cell.y),cell);tile.filter_clip=true;_boss_frames.add_frame(family,tile)
 _boss=AnimatedSprite2D.new();_boss.sprite_frames=_boss_frames;_boss.play("walk");add_child(_boss)
 var top:=VBoxContainer.new();top.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(top);top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);top.offset_left=20;top.offset_right=-20;top.offset_top=12
 _title=Flow.text("DRAGON GATE GUARDIAN",22,true);_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;top.add_child(_title)
 _health=ProgressBar.new();_health.max_value=16;_health.show_percentage=false;_health.custom_minimum_size.y=12;top.add_child(_health)
 _hint=Flow.text("",17);_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;top.add_child(_hint)
 _retreat=Flow.button("KELUAR · HADIAH DASAR",func()->void: _finish(true));add_child(_retreat);_retreat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);_retreat.offset_left=-clampf(size.x*0.43,150,240)-16;_retreat.offset_right=-16;_retreat.offset_top=-84;_retreat.offset_bottom=-18
 _retry=Flow.button("COBA SAMBUNG",func()->void:
  if client!=null and not client.busy:
   if _finished and client.status=="connected": completed.emit(trace,_abandoned)
   else: client.refresh())
 add_child(_retry);_retry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);_retry.offset_left=-clampf(size.x*0.43,150,240)-16;_retry.offset_right=-16;_retry.offset_top=-154;_retry.offset_bottom=-90;_retry.visible=false
 resized.connect(_layout);_layout();_paint_state()
 if bool(state.done): call_deferred("_finish",false)
func _world()->Rect2: return Rect2(Vector2(size.x*0.10,104),Vector2(size.x*0.80,maxf(110,size.y-220)))
func _point(x: float,y: float)->Vector2:
 var rect: Rect2=_world();return rect.position+Vector2(x,y)*rect.size/1024.0
func _pad()->Vector2: return Vector2(minf(size.x*0.21,116),size.y-106)
func _radius()->float: return clampf(size.x*0.14,52,80)
func _layout()->void:
 if _player==null: return
 if _retreat!=null: _retreat.offset_left=-clampf(size.x*0.43,150,240)-16
 if _retry!=null: _retry.offset_left=-clampf(size.x*0.43,150,240)-16
 _player.scale=Vector2.ONE*clampf(size.x/648.0,0.62,1.0)*0.85
 var frame: Texture2D=_boss_frames.get_frame_texture("walk",0);var box: Rect2=frame.get_image().get_used_rect();_boss.scale=Vector2.ONE*(clampf(size.x*0.20,72,125)/maxf(box.size.y,1))
 _paint_state()
func _direction()->int:
 var direction: Vector2=_stick
 if direction.length()<0.2:
  direction=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 if direction.length()<0.2: return 0
 return 1+posmod(roundi((direction.angle()+PI*0.5)/(PI*0.25)),8)
func _gui_input(event: InputEvent)->void:
 if event is InputEventScreenTouch:
  if event.pressed and _finger<0 and event.position.distance_to(_pad())<_radius()+20: _finger=event.index;_stick=(event.position-_pad()).limit_length(_radius())/_radius();accept_event()
  elif not event.pressed and event.index==_finger: _finger=-1;_stick=Vector2.ZERO;accept_event()
 elif event is InputEventScreenDrag and event.index==_finger: _stick=(event.position-_pad()).limit_length(_radius())/_radius();accept_event()
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed and event.position.distance_to(_pad())<_radius()+20: _mouse=true;_stick=(event.position-_pad()).limit_length(_radius())/_radius();accept_event()
  elif not event.pressed: _mouse=false;_stick=Vector2.ZERO
 elif event is InputEventMouseMotion and _mouse: _stick=(event.position-_pad()).limit_length(_radius())/_radius();accept_event()
func _process(delta: float)->void:
 _hit_glow=maxf(0,_hit_glow-delta)
 if _suspended: return
 if not bool(state.done) and not _finished:
  _accumulator+=minf(delta,0.25)
  while _accumulator>=0.05 and not bool(state.done):
   _accumulator-=0.05;var direction: int=_direction();trace+=str(direction);Sim.step(state,direction)
   if int(state.t)%60==0: _save_trace()
  if bool(state.done): _finish(false)
 _paint_state();queue_redraw()
func _paint_state()->void:
 if _player==null or _boss==null: return
 _player.position=_point(float(state.x),float(state.y))-Vector2(0,30*_player.scale.y)
 _boss.position=_point(float(state.bx),float(state.by))-Vector2(0,36);_boss.flip_h=int(state.x)<int(state.bx)
 var direction: int=_direction();var facing: String="up" if direction in [1,2,8] else "right" if direction in [3,4] else "left" if direction in [6,7] else "down"
 var animation: String=("walk_" if direction>0 and not bool(state.done) else "idle_")+facing
 if _player.animation!=animation: _player.play(animation)
 var phase: int=maxi(0,(int(state.t)-1)%60);var round_value: int=maxi(0,floori(float(int(state.t)-1)/60.0));var pattern: int=(int(state.seed)+round_value)%3
 var family: String="walk" if phase<20 else "projectile" if pattern==0 else "lightning" if pattern==1 else "shockwave"
 if _boss.animation!=family: _boss.play(family)
 if _health!=null: _health.value=maxi(0,int(state.boss_hp))
 if int(state.hp)<_health_old: _hit_glow=0.3;_health_old=int(state.hp)
 _player.modulate=Color("ffb080") if _hit_glow>0 else Color.WHITE
 if _hint!=null: _hint.text="%d/5 HP · %ds · %s" % [maxi(0,int(state.hp)),maxi(0,30-floori(float(state.t)/20.0)),"JAGA JARAK DARI TANDA SERANGAN" if phase<30 else "HINDARI SERANGAN"]
 if _finished and _hint!=null:
  _hint.text="HASIL DIKIRIM · MENUNGGU VERIFIKASI" if client==null or client.busy else "PROGRES TERSIMPAN · TEKAN COBA SAMBUNG"
  _retry.visible=client!=null and not client.busy
func _finish(abandon: bool)->void:
 if _finished: return
 _finished=true;_abandoned=abandon;_stick=Vector2.ZERO;_save_trace();_retreat.disabled=true;completed.emit(trace,abandon)
func _load_trace()->void:
 if _path().is_empty() or not FileAccess.file_exists(_path()): return
 var file:=FileAccess.open(_path(),FileAccess.READ)
 if file==null or file.get_length()>4096: return
 var value: Variant=JSON.parse_string(file.get_as_text())
 if not value is Dictionary or int(value.get("seed",-1))!=int(battle.seed) or int(value.get("started_at",0))!=int(battle.started_at) or value.get("owner","")!=_owner: return
 var saved: String=str(value.get("trace",""))
 if saved.length()>600: return
 var candidate: Dictionary=Sim.initial(int(battle.seed))
 for digit: String in saved:
  if not "012345678".contains(digit) or bool(candidate.done): return
  Sim.step(candidate,int(digit))
 state=candidate;trace=saved
func _save_trace()->void:
 if _path().is_empty(): return
 if client!=null:
  var live: Variant=client.snapshot.get("state",{}).get("battle")
  if not live is Dictionary or int(live.get("seed",-1))!=int(battle.seed) or int(live.get("started_at",0))!=int(battle.started_at): return
 var file:=FileAccess.open(_path()+".tmp",FileAccess.WRITE)
 if file==null: return
 file.store_string(JSON.stringify({"owner":_owner,"seed":int(battle.seed),"started_at":int(battle.started_at),"trace":trace}));file.flush();var error: Error=file.get_error();file.close()
 if error==OK: DirAccess.rename_absolute(_path()+".tmp",_path())
func _notification(what: int)->void:
 if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]: _suspended=true;_stick=Vector2.ZERO;_finger=-1;_mouse=false;_save_trace()
 elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]: _suspended=false
func _exit_tree()->void: _save_trace()
func _draw()->void:
 draw_texture_rect(FLOOR,Rect2(Vector2.ZERO,size),false)
 if state.is_empty(): return
 var rect: Rect2=_world();
 var phase: int=maxi(0,(int(state.t)-1)%60);var round_value: int=maxi(0,floori(float(int(state.t)-1)/60.0));var pattern: int=(int(state.seed)+round_value)%3
 var aim: Vector2=_point(float(state.aim_x),float(state.aim_y));var alpha: float=0.35+float(phase)/60.0 if phase<30 else maxf(0,1.0-float(phase-30)/18.0)
 if pattern==0 and phase<=45:
  var span:=Vector2(230*rect.size.x/1024.0,230*rect.size.y/1024.0);draw_texture_rect(WARNING,Rect2(aim-span*0.5,span),false,Color(1,0.75,0.45,alpha))
 elif pattern==1 and phase<=45:
  var span:=Vector2(rect.size.x,144*rect.size.y/1024.0);var band:=Rect2(Vector2(rect.position.x,aim.y-span.y*0.5),span)
  draw_rect(band,Color(1,0.45,0.10,alpha*0.26));draw_line(band.position,band.position+Vector2(span.x,0),Color(1,0.76,0.38,alpha),2,true);draw_line(band.position+Vector2(0,span.y),band.end,Color(1,0.76,0.38,alpha),2,true);draw_texture_rect(SLASH,band,false,Color(1,0.65,0.22,alpha))
 elif pattern==2:
  var radius: float=clampf(float(phase-29)*32,30,672);var span:=Vector2(radius*2*rect.size.x/1024.0,radius*2*rect.size.y/1024.0)
  draw_texture_rect(WARNING,Rect2(_point(float(state.bx),float(state.by))-span*0.5,span),false,Color(1,0.8,0.4,0.75 if phase>=30 and phase<=50 else 0.15))
 if int(state.t)%15<6 and int(state.t)>0 and not bool(state.done):
  var a: Vector2=_point(float(state.x),float(state.y));var b: Vector2=_point(float(state.bx),float(state.by));var delta: Vector2=b-a
  if delta.length()<420*maxf(rect.size.x,rect.size.y)/1024.0:
   draw_set_transform(a,delta.angle(),Vector2.ONE);draw_texture_rect(SLASH,Rect2(Vector2(0,-18),Vector2(delta.length(),36)),false,Color(0.8,1,0.9,1.0-float(int(state.t)%15)/6.0));draw_set_transform(Vector2.ZERO)
 var center: Vector2=_pad();draw_circle(center,_radius(),Color(0.02,0.11,0.10,0.48));draw_arc(center,_radius(),0,TAU,48,Color(0.91,0.77,0.45,0.7),2,true);draw_circle(center+_stick*(_radius()*0.65),_radius()*0.35,Color(0.12,0.50,0.38,0.85));draw_arc(center+_stick*(_radius()*0.65),_radius()*0.35,0,TAU,32,Flow.GOLD,2,true)
