extends Node
## Local run report only; never currency/reward authority.
const Catalog=preload("res://scripts/data/skill_catalog.gd")
const SOURCES: Array[String]=["phoenix_war_fan","void_piercer_spear","astral_resonance_bell","spirit_sword","jade_binding_chain","celestial_returning_glaive","fire_orb","thunder_talisman","yin_yang_blades","heavenly_sword_rain","eight_trigrams_formation","heavenly_tribulation","set_bleed","set_poison","set_burn"]
var totals: Dictionary={}
var partial: bool=false
var frozen: bool=false

static func apply_hit(target: Node,amount: float,source: String) -> float:
 if not is_instance_valid(target) or not target.has_method("take_damage"):return 0.0
 # All production enemies expose current_hp. Preview fixtures may not.
 var before: Variant=target.get("current_hp")
 target.take_damage(preload("res://scripts/effects/equipment_set_combat.gd").modify_hit(target,amount,source))
 if before==null or not is_instance_valid(target):return 0.0
 var after: Variant=target.get("current_hp")
 if after==null:return 0.0
 var applied: float=maxf(float(before)-maxf(float(after),0.0),0.0)
 if not is_finite(applied) or applied<=0.0:return 0.0
 preload("res://scripts/effects/equipment_set_combat.gd").on_applied_hit(target,source,float(before))
 if not target.is_inside_tree():return applied
 var tree: SceneTree=target.get_tree()
 if tree==null:return applied
 var player: Node=tree.get_first_node_in_group("player")
 if player==null:return applied

 if target is Node2D and source in SOURCES and not source.begins_with("set_") and source not in ["spirit_sword","fire_orb"]:
  var feedback: Node=tree.root.get_node_or_null("CombatFeedback")
  if feedback!=null:feedback.weapon_impact((target as Node2D).global_position,source)
 var ledger: Node=player.get_node_or_null("WeaponManager/RunCombatLedger")
 if ledger!=null:ledger.record(source,applied)
 return applied

func record(source: String,amount: float) -> void:
 if frozen or source not in SOURCES or not is_finite(amount) or amount<=0.0:return
 totals[source]=float(totals.get(source,0.0))+amount

func snapshot() -> Dictionary:
 return {"version":1,"totals":totals.duplicate(),"partial":partial}

static func valid_snapshot(value: Variant) -> bool:
 if not value is Dictionary or value.get("version")!=1 or not value.get("totals") is Dictionary or not value.get("partial") is bool:return false
 if value.totals.size()>SOURCES.size():return false
 for id: Variant in value.totals:
  var amount: Variant=value.totals[id]
  if str(id) not in SOURCES or typeof(amount) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(amount)) or float(amount)<0.0 or float(amount)>1.0e12:return false
 return true

func restore(value: Variant) -> void:
 totals.clear();frozen=false
 partial=not valid_snapshot(value)
 if partial:return
 totals=value.totals.duplicate();partial=bool(value.partial)

func skills() -> Array[Dictionary]:
 var manager: Node=get_parent()
 var player: Node=manager.get_parent()
 var rows: Array[Dictionary]=[]
 for weapon: Weapon in manager.weapons:
  var id: String={"Spirit Sword":"spirit_sword","Fire Orb":"fire_orb","Thunder Talisman":"thunder_talisman","Yin-Yang Blades":"yin_yang_blades","Heavenly Sword Rain":"heavenly_sword_rain","Eight Trigrams Formation":"eight_trigrams_formation"}.get(weapon.weapon_name,"")
  if id.is_empty():continue
  var title: String=weapon.get_combat_display_name() if id=="spirit_sword" else Catalog.get_upgrade_display_name(id)
  rows.append({"id":id,"name":title,"level":weapon.level,"armament_id":str(weapon.get("armament_id")) if id=="spirit_sword" else ""})
 var stats: Node=player.get_node("PlayerStats")
 var health: Node=player.get_node("PlayerHealth")
 for pair: Array in [["power",stats.power_level],["attack_speed",stats.attack_speed_level],["sword_intent",stats.sword_intent_level],["movement_speed",player.movement_speed_level],["spiritual_insight",player.spiritual_insight_level],["body_refinement",health.body_refinement_level],["qi_shield",health.qi_shield_level],["iron_body",health.iron_body_level],["blood_qi",health.blood_qi_level],["sword_dao_resonance",int(stats.has_sword_dao_resonance())],["yin_yang_reversal",int(stats.has_yin_yang_reversal())],["heavenly_tribulation",int(stats.has_heavenly_tribulation())]]:
  if int(pair[1])>0:
   var starter: Node=manager.get_weapon_by_name("Spirit Sword")
   rows.append({"id":str(pair[0]),"name":Catalog.get_upgrade_display_name(str(pair[0])),"level":int(pair[1]),"armament_id":str(starter.get("armament_id")) if str(pair[0])=="sword_dao_resonance" and starter!=null else ""})
 return rows

func damage_rows() -> Array[Dictionary]:
 var rows: Array[Dictionary]=[]
 var owned: Dictionary={}
 for skill: Dictionary in skills():
  var id: String=str(skill.id)
  if id=="spirit_sword":
   var weapon: Weapon=get_parent().get_weapon_by_name("Spirit Sword")
   var armament: String=str(weapon.get("armament_id"))
   if armament in ["jade_binding_chain","celestial_returning_glaive","phoenix_war_fan","void_piercer_spear","astral_resonance_bell"]:id=armament
  if id in SOURCES:owned[id]=str(skill.name)
 for id: String in totals:
  if not owned.has(id):owned[id]=Catalog.get_upgrade_display_name(id) if not id.begins_with("set_") else ("Efek Set" if get_tree().root.get_node("SettingsManager").language=="id" else "Set Effect")+" · "+id.trim_prefix("set_").capitalize()
 for id: String in owned:rows.append({"id":id,"name":owned[id],"damage":float(totals.get(id,0.0))})
 rows.sort_custom(func(a: Dictionary,b: Dictionary):return a.damage>b.damage if a.damage!=b.damage else str(a.id)<str(b.id))
 return rows
