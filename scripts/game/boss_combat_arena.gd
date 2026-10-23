extends Node2D
## A visible, physical enclosure. No damage/stat buffs; attacks retain their own collisions.
const RADIUS: float=430.0
const FLOOR=preload("res://assets/world/boss_arena/jade_ritual_dais.png")
var accent: Color=Color(.35,.92,.72)
var _floor: Sprite2D
var player_actor: Node2D
var boss_actor: Node2D
var _time: float=0.0
var _redraw: float=0.0
func _ready() -> void:
 name="BossCombatArena";z_index=-1;process_physics_priority=100
 _floor=Sprite2D.new();_floor.name="RitualDais";_floor.texture=FLOOR
 _floor.scale=Vector2.ONE*(RADIUS*2.02)/FLOOR.get_width()
 _floor.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 _floor.modulate=Color(.92,.96,.92,0);add_child(_floor)
 var walls:=StaticBody2D.new();walls.name="JadeBoundary";walls.collision_layer=16;walls.collision_mask=0;add_child(walls)
 for index: int in range(48):
  var segment:=SegmentShape2D.new();segment.a=Vector2.from_angle(TAU*index/48.0)*RADIUS;segment.b=Vector2.from_angle(TAU*(index+1)/48.0)*RADIUS
  var collision:=CollisionShape2D.new();collision.shape=segment;walls.add_child(collision)
 if is_instance_valid(boss_actor):
  boss_actor.tree_exiting.connect(queue_free,CONNECT_ONE_SHOT)
  if boss_actor.has_signal("boss_defeated"):boss_actor.connect("boss_defeated",queue_free,CONNECT_ONE_SHOT)
func _physics_process(delta: float) -> void:
 if not is_instance_valid(boss_actor):queue_free();return
 for actor: Node2D in [player_actor,boss_actor]:
  if not is_instance_valid(actor):continue
  var offset: Vector2=actor.global_position-global_position
  if offset.length()>RADIUS-22.0:actor.global_position=global_position+offset.limit_length(RADIUS-22.0)
 _time+=delta;_redraw+=delta
 _floor.modulate.a=smoothstep(0.0,.75,_time)*.92
 if _redraw>=.08:_redraw=0;queue_redraw()
func _draw() -> void:
 var opacity: float=smoothstep(0.0,.75,_time)
 var pulse: float=.75+sin(_time*1.7)*.12
 # The bright physical boundary is exactly430px; carvings never imply extra room.
 draw_arc(Vector2.ZERO,RADIUS,0,TAU,128,Color(accent,.18*opacity),9,true)
 draw_arc(Vector2.ZERO,RADIUS,0,TAU,128,Color(.96,.81,.46,.8*opacity),1.6,true)
 for index: int in range(8):
  var angle: float=TAU*index/8.0
  var at: Vector2=Vector2.from_angle(angle)*(RADIUS-19)
  draw_circle(at,7.5,Color(accent,.12*opacity*pulse))
  draw_circle(at,3,Color(.8,1,.87,.65*opacity*pulse))
