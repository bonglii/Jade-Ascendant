extends Node2D

## One pause-aware, non-stacking status per real enemy. DOT cannot trigger DOT.
const Catalog=preload("res://scripts/data/equipment_set_catalog.gd")
const Runtime=preload("res://scripts/data/equipment_set_runtime.gd")
const DOT_META: StringName=&"jade_set_dot_inflight"
const MAX_STATUSES: int=64
var kind: String=""
var tint: Color=Color.WHITE
var tick_damage: float=0.0
var ticks_left: int=0
var clock: float=0.0
var age: float=0.0

static func on_hit(enemy: Node2D, amount: float) -> void:
 if amount<=0.0 or not is_finite(amount) or enemy.has_meta(DOT_META): return
 if not enemy.is_in_group("enemy") or enemy.is_queued_for_deletion(): return
 if bool(enemy.get("is_dead")) or float(enemy.get("current_hp"))<=0.0: return
 if enemy.get_tree().get_first_node_in_group("player")==null: return
 var passive: Dictionary=Catalog.get_active_passive(Runtime.get_equipped_item_ids())
 if str(passive.get("kind","")) not in ["poison","bleed","burn"]: return
 var amount_per_tick: float=amount*float(passive.ratio)*(0.5 if enemy.is_in_group("boss") else 1.0)
 var existing: Node=enemy.get_node_or_null("EquipmentSetStatus")
 if existing!=null:
  if not existing.is_queued_for_deletion() and str(existing.kind)==str(passive.kind) and int(existing.ticks_left)>0:
   existing.tick_damage=maxf(float(existing.tick_damage),amount_per_tick)
  return
 if enemy.get_tree().get_nodes_in_group("equipment_set_status").size()>=MAX_STATUSES: return
 var status: Node2D=load("res://scripts/effects/equipment_set_status.gd").new()
 status.name="EquipmentSetStatus"
 status.kind=str(passive.kind);status.tint=passive.color
 status.tick_damage=amount_per_tick
 status.ticks_left=4 if status.kind=="poison" else 3
 enemy.add_child(status)
 status.add_to_group("equipment_set_status")
 status.z_index=9

func _physics_process(delta: float) -> void:
 var enemy: Node2D=get_parent() as Node2D
 if enemy==null or enemy.is_queued_for_deletion() or not enemy.is_in_group("enemy") or bool(enemy.get("is_dead")):
  queue_free();return
 var player: Node=get_tree().get_first_node_in_group("player")
 if player==null:
  queue_free();return
 clock+=delta;age+=delta
 if clock>=1.0:
  if str(Catalog.get_active_passive(Runtime.get_equipped_item_ids()).get("kind",""))!=kind:
   queue_free();return
  clock-=1.0;ticks_left-=1
  enemy.set_meta(DOT_META,true)
  preload("res://scripts/weapon/run_combat_ledger.gd").apply_hit(enemy,tick_damage,"set_"+kind)
  enemy.remove_meta(DOT_META)
  if ticks_left<=0:queue_free()
 queue_redraw()

func _draw() -> void:
 _draw_head_marker()
 if SettingsManager.reduced_effects: return
 var pulse: float=0.65+0.15*sin(age*4.0)
 var color: Color=Color(tint,pulse)
 draw_arc(Vector2(0,-12),15,age,age+4.8,24,color,1.4,true)
 for i: int in range(3):
  var point: Vector2=Vector2(sin(age*1.5+i*2.0)*11,-20-i*4-fmod(age*10.0,8.0))
  if kind=="bleed":draw_line(point,point+Vector2(1,4),color,1.5,true)
  else:draw_circle(point,1.8,color)

func _draw_head_marker() -> void:
 var enemy: Node2D=get_parent() as Node2D
 if enemy==null:return
 if ticks_left<=0 or kind not in ["bleed","poison","burn"]:return
 var y: float=-44.0
 var sprite: AnimatedSprite2D=enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
 if sprite!=null and sprite.sprite_frames!=null:
  var texture: Texture2D=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
  if texture!=null:y=minf(y,sprite.position.y-texture.get_height()*absf(sprite.scale.y)*.5-10)
 var at:=Vector2(0,y)
 draw_circle(at,9,Color(.025,.045,.06,.94))
 draw_arc(at,9,0,TAU,20,Color(tint,.95),1.5,true)
 if kind=="bleed":
  var drop:=PackedVector2Array([at+Vector2(0,-6),at+Vector2(4,0),at+Vector2(3,4),at+Vector2(0,5),at+Vector2(-3,4),at+Vector2(-4,0)])
  draw_colored_polygon(drop,tint)
 elif kind=="poison":
  draw_rect(Rect2(at+Vector2(-2,-6),Vector2(4,3)),tint)
  draw_circle(at+Vector2(0,2),4.5,tint)
  draw_line(at+Vector2(-2,-6),at+Vector2(2,-6),Color(.7,1,.8),1.5)
 else:
  draw_colored_polygon(PackedVector2Array([at+Vector2(0,-6),at+Vector2(4,2),at+Vector2(0,6),at+Vector2(-4,2)]),tint)
 for index: int in range(ticks_left):draw_circle(at+Vector2((index-(ticks_left-1)*.5)*4,13),1.1,tint)
