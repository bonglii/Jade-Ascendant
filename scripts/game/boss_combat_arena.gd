extends Node2D
## A visible, physical enclosure. No damage/stat buffs; attacks retain their own collisions.
const RADIUS: float=430.0
var player_actor: Node2D
var boss_actor: Node2D
var _time: float=0.0
var _redraw: float=0.0
func _ready() -> void:
 name="BossCombatArena";z_index=-1;process_physics_priority=100
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
 if _redraw>=.08:_redraw=0;queue_redraw()
func _draw() -> void:
 var opacity: float=minf(_time/.6,1.0)
 draw_circle(Vector2.ZERO,RADIUS,Color(.04,.16,.12,.035*opacity))
 draw_arc(Vector2.ZERO,RADIUS,0,TAU,128,Color(.11,.56,.43,.26*opacity),16,true)
 draw_arc(Vector2.ZERO,RADIUS-3,0,TAU,128,Color(.96,.79,.39,.85*opacity),2.2,true)
 draw_arc(Vector2.ZERO,RADIUS-12,0,TAU,128,Color(.34,.86,.67,.4*opacity),1,true)
 for index: int in range(12):
  var angle: float=TAU*index/12.0;var at: Vector2=Vector2.from_angle(angle)*(RADIUS-5)
  draw_circle(at,10,Color(.04,.25,.19,.95*opacity));draw_arc(at,10,0,TAU,20,Color(.94,.77,.4,.9*opacity),2,true)
  var axis:=Vector2.from_angle(angle);draw_line(at-axis*5,at+axis*5,Color(.78,.95,.75,opacity),2,true)
