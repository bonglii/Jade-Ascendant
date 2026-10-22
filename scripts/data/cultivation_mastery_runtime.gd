extends RefCounted
const Catalog=preload("res://scripts/data/cultivation_mastery_catalog.gd")
static func manager() -> Node:
 var tree: SceneTree=Engine.get_main_loop() as SceneTree
 return tree.root.get_node_or_null("CultivationMasteryManager") if tree!=null else null
static func bonus(key: String,read_only: bool=false) -> float:
 var owner: Node=manager()
 if owner==null:return 0.0
 var equipment: Node=owner.get_node_or_null("/root/EquipmentManager")
 var practice: bool=equipment!=null and bool(equipment.call("is_practice"))
 var choices: Dictionary=owner.get_run_choices(read_only or practice)
 var value: float=0
 for id: String in choices.values():value+=float(Catalog.NODES.get(id,{}).get("bonus",{}).get(key,0.0))
 return value
