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
 if enemy.has_node("EquipmentSetStatus"): return
 if enemy.get_tree().get_first_node_in_group("player")==null: return
 var passive: Dictionary=Catalog.get_active_passive(Runtime.get_equipped_item_ids())
 if str(passive.get("kind","")) not in ["poison","bleed","burn"]: return
 if enemy.get_tree().get_nodes_in_group("equipment_set_status").size()>=MAX_STATUSES: return
 var status: Node2D=load("res://scripts/effects/equipment_set_status.gd").new()
 status.name="EquipmentSetStatus"
 status.kind=str(passive.kind);status.tint=passive.color
 status.tick_damage=amount*float(passive.ratio)*(0.5 if enemy.is_in_group("boss") else 1.0)
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
  enemy.take_damage(tick_damage)
  enemy.remove_meta(DOT_META)
  if ticks_left<=0:queue_free()
 queue_redraw()

func _draw() -> void:
 if SettingsManager.reduced_effects: return
 var pulse: float=0.65+0.15*sin(age*4.0)
 var color: Color=Color(tint,pulse)
 draw_arc(Vector2(0,-12),15,age,age+4.8,24,color,1.4,true)
 for i: int in range(3):
  var point: Vector2=Vector2(sin(age*1.5+i*2.0)*11,-20-i*4-fmod(age*10.0,8.0))
  if kind=="bleed":draw_line(point,point+Vector2(1,4),color,1.5,true)
  else:draw_circle(point,1.8,color)
