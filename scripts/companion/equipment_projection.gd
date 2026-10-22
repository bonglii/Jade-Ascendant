extends RefCounted
## Read-only gear contribution, not an invented DPS / unconditional power score.
const Sets = preload("res://scripts/data/equipment_set_catalog.gd")
static func slots() -> Dictionary:
 var result: Dictionary = {}
 for slot: String in EquipmentManager.get_slot_ids(): result[slot] = EquipmentManager.get_loadout_equipped_item_id(slot)
 return result
static func project(loadout: Dictionary) -> Dictionary:
 var totals: Dictionary = {"max_health_flat":0.0,"damage_bonus":0.0,"critical_chance_bonus":0.0,"movement_speed_bonus":0.0,"experience_bonus":0.0}
 var ids: Array[String] = []
 for slot: String in EquipmentManager.get_slot_ids():
  var id: String = str(loadout.get(slot, ""))
  if id.is_empty(): continue
  ids.append(id)
  var item: Dictionary = EquipmentManager._build_effective_item_data(id, EquipmentManager.get_loadout_item_star(id))
  for key: String in totals: totals[key] += float(item.get(key, 0))
 for key: String in totals: totals[key] += Sets.get_gameplay_bonus(key, ids)
 totals.critical_chance_bonus = clampf(totals.critical_chance_bonus,0,1)
 totals.set = Sets.get_dominant_set_state(ids)
 totals.passive = Sets.get_active_passive(ids)
 totals.weapon_level = EquipmentManager.get_item_weapon_level(str(loadout.get("armament", "")))
 return totals
static func compare(id: String) -> Dictionary:
 var data: Dictionary = EquipmentManager.get_item_data(id)
 if data.is_empty(): return {}
 var before: Dictionary = slots()
 var after: Dictionary = before.duplicate()
 after[str(data.slot)] = id
 return {"before":project(before),"after":project(after),"previous":str(before.get(str(data.slot),"")),"candidate":id}
