extends RefCounted
const Catalog=preload("res://scripts/data/equipment_set_catalog.gd")
static var _cached_key: String="__unset__"
static var _cached_passive: Dictionary={}
static func active_passive() -> Dictionary:
 var ids: Array[String]=equipped_ids()
 var key: String=",".join(ids)
 if key!=_cached_key:
  _cached_key=key;_cached_passive=Catalog.get_active_passive(ids)
 return _cached_passive
static func equipped_ids() -> Array[String]:
 var result: Array[String]=[]
 var tree: SceneTree=Engine.get_main_loop() as SceneTree
 var manager: Node=tree.root.get_node_or_null("EquipmentManager") if tree!=null else null
 if manager!=null:
  for slot: String in manager.get_slot_ids():
   var id: String=manager.get_equipped_item_id(slot)
   if not id.is_empty():result.append(id)
 return result
static func modify_hit(target: Node,amount: float,source: String) -> float:
 if source.begins_with("set_"):return amount
 var passive: Dictionary=active_passive()
 if passive.get("kind","")!="verdict":return amount
 var maximum: Variant=target.get("max_hp")
 var current: Variant=target.get("current_hp")
 if maximum!=null and current!=null and float(maximum)>0 and float(current)<=float(maximum)*.35:
  return amount*(1.06 if target.is_in_group("boss") else 1.12)
 return amount
static func on_applied_hit(target: Node,source: String) -> void:
 if source.begins_with("set_") or bool(target.get("is_dead")):return
 var passive: Dictionary=active_passive()
 if passive.get("kind","")=="frost":preload("res://scripts/weapon/jade_binding_slow.gd").apply(target,.6,.8,.94)
