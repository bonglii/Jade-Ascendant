extends RefCounted

## Stateless bridge between the permanent/set catalog and the runtime-aware
## EquipmentManager loadout resolver. No gameplay state is stored here.
const EquipmentSetCatalog = preload("res://scripts/data/equipment_set_catalog.gd")

static func get_equipped_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	for slot_id: String in EquipmentManager.get_slot_ids():
		var item_id: String = EquipmentManager.get_equipped_item_id(slot_id)
		if not item_id.is_empty():
			item_ids.append(item_id)
	return item_ids

static func get_bonus(stat_id: String) -> float:
	return EquipmentSetCatalog.get_gameplay_bonus(
		stat_id,
		get_equipped_item_ids()
	)

static func get_capped_combined_secondary_bonus(
	stat_id: String,
	cap: float
) -> float:
	return clampf(
		EquipmentManager.get_secondary_bonus(stat_id, cap)
		+ get_bonus(stat_id),
		0.0,
		cap
	)
