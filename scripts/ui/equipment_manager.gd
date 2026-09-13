extends Node

## Equipment Manager
## Mengelola definisi equipment permanen dan slot yang sedang dipakai.
## Ownership item dikelola oleh InventoryManager.
## EquipmentManager hanya mengelola equipped slot dan stat contribution.

signal equipment_changed(slot_id: String, item_id: String)
signal equipment_ascended(item_id: String, old_star: int, new_star: int)

const SAVE_PATH: String = "user://equipment.save"
const SAVE_VERSION: int = 1
const CHECKPOINT_PATH: String = "user://checkpoint.save"

const SLOT_ARMAMENT: String = "armament"
const SLOT_ROBE: String = "robe"
const SLOT_BRACER: String = "bracer"
const SLOT_BOOTS: String = "boots"
const SLOT_PENDANT: String = "pendant"

const RARITY_COMMON: String = "common"
const RARITY_RARE: String = "rare"
const RARITY_EPIC: String = "epic"
const RARITY_LEGENDARY: String = "legendary"

# Gate 1.5: every permanent equipment item begins at 1★ and can ascend to 5★.
# Ascension deliberately scales only core passives; Signature Effects stay at their
# locked Gate 1.4 values so stars do not silently rewrite item identities.
const MAX_ASCENSION_STAR: int = 5
const ASCENSION_CORE_MULTIPLIERS: Dictionary = {
	1: 1.00,
	2: 1.05,
	3: 1.10,
	4: 1.15,
	5: 1.20
}
const ASCENSION_COST_MULTIPLIERS: Dictionary = {
	2: 1,
	3: 2,
	4: 3,
	5: 5
}
const ASCENSION_SCALABLE_STATS = [
	"max_health_flat",
	"damage_bonus",
	"movement_speed_bonus",
	"experience_bonus",
	"critical_chance_bonus"
]

const EquipmentCatalog = preload("res://scripts/data/equipment_catalog.gd")
const EQUIPMENT_CATALOG: Dictionary = EquipmentCatalog.ITEMS

var equipped_item_ids: Dictionary = {
	SLOT_ARMAMENT: "",
	SLOT_ROBE: "",
	SLOT_BRACER: "",
	SLOT_BOOTS: "",
	SLOT_PENDANT: ""
}
var ascension_stars: Dictionary = {}

func _ready() -> void:
	load_equipment()
	_validate_loaded_state()
	save_equipment()
	print_equipment_status()

func get_slot_ids() -> Array[String]:
	return [
		SLOT_ARMAMENT,
		SLOT_ROBE,
		SLOT_BRACER,
		SLOT_BOOTS,
		SLOT_PENDANT
	]

func get_rarity_ids() -> Array[String]:
	return [
		RARITY_COMMON,
		RARITY_RARE,
		RARITY_EPIC,
		RARITY_LEGENDARY
	]

func is_valid_slot(slot_id: String) -> bool:
	return slot_id in get_slot_ids()

func is_valid_rarity(rarity_id: String) -> bool:
	return rarity_id in get_rarity_ids()

func has_item_definition(item_id: String) -> bool:
	return EQUIPMENT_CATALOG.has(item_id)

func get_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	for raw_item_id in EQUIPMENT_CATALOG.keys():
		item_ids.append(str(raw_item_id))
	item_ids.sort()
	return item_ids

func get_item_ids_for_slot(slot_id: String) -> Array[String]:
	var item_ids: Array[String] = []
	if not is_valid_slot(slot_id):
		return item_ids
	for item_id in get_item_ids():
		var item_data := get_item_data(item_id)
		if str(item_data.get("slot", "")) == slot_id:
			item_ids.append(item_id)
	return item_ids

func can_modify_equipment() -> bool:
	if SaveManager.is_progress_read_only():
		return false
	if JourneyManager.has_active_run():
		return false
	return not FileAccess.file_exists(CHECKPOINT_PATH)

func get_item_data(item_id: String) -> Dictionary:
	if not has_item_definition(item_id):
		return {}
	var item_data: Dictionary = EQUIPMENT_CATALOG[item_id]
	return item_data.duplicate(true)

func get_equipped_item_id(slot_id: String) -> String:
	if not is_valid_slot(slot_id):
		return ""
	return str(equipped_item_ids.get(slot_id, ""))

func get_equipped_item_data(slot_id: String) -> Dictionary:
	var item_id := get_equipped_item_id(slot_id)
	if item_id.is_empty():
		return {}
	return get_effective_item_data(item_id)

func get_item_star(item_id: String) -> int:
	if not has_item_definition(item_id):
		return 0
	return clampi(int(ascension_stars.get(item_id, 1)), 1, MAX_ASCENSION_STAR)

func get_item_ascension_multiplier(item_id: String) -> float:
	var star: int = get_item_star(item_id)
	if star <= 0:
		return 1.0
	return float(ASCENSION_CORE_MULTIPLIERS.get(star, 1.0))

func get_effective_item_data(item_id: String) -> Dictionary:
	var item_data: Dictionary = get_item_data(item_id)
	if item_data.is_empty():
		return {}
	var star: int = get_item_star(item_id)
	var multiplier: float = get_item_ascension_multiplier(item_id)
	for stat_id: String in ASCENSION_SCALABLE_STATS:
		if item_data.has(stat_id):
			item_data[stat_id] = float(item_data[stat_id]) * multiplier
	item_data["ascension_star"] = star
	item_data["ascension_multiplier"] = multiplier
	return item_data

func get_ascension_cost_for_star(item_id: String, target_star: int) -> int:
	if not has_item_definition(item_id):
		return 0
	if target_star < 2 or target_star > MAX_ASCENSION_STAR:
		return 0
	var rarity: String = str(get_item_data(item_id).get("rarity", RARITY_COMMON))
	var duplicate_value: int = int(InventoryManager.DUPLICATE_SHARDS.get(rarity, 0))
	var cost_multiplier: int = int(ASCENSION_COST_MULTIPLIERS.get(target_star, 0))
	return maxi(duplicate_value * cost_multiplier, 0)

func get_ascension_cost(item_id: String) -> int:
	var current_star: int = get_item_star(item_id)
	if current_star <= 0 or current_star >= MAX_ASCENSION_STAR:
		return 0
	return get_ascension_cost_for_star(item_id, current_star + 1)

func can_ascend_item(item_id: String) -> bool:
	if not has_item_definition(item_id):
		return false
	if not can_modify_equipment():
		return false
	if not InventoryManager.owns_item(item_id):
		return false
	var cost: int = get_ascension_cost(item_id)
	if cost <= 0:
		return false
	return InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD) >= cost

func ascend_item(item_id: String) -> bool:
	if not can_ascend_item(item_id):
		return false
	var old_star: int = get_item_star(item_id)
	var new_star: int = old_star + 1
	var shard_cost: int = get_ascension_cost_for_star(item_id, new_star)
	var shard_balance: int = InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD)

	var next_stars: Dictionary = ascension_stars.duplicate(true)
	next_stars[item_id] = new_star
	var next_counts: Dictionary = InventoryManager.item_counts.duplicate(true)
	var next_shards: int = shard_balance - shard_cost
	if next_shards > 0:
		next_counts[InventoryManager.REFINEMENT_SHARD] = next_shards
	else:
		next_counts.erase(InventoryManager.REFINEMENT_SHARD)

	var equipment_target: Dictionary = build_equipment_save_data(next_stars)
	var inventory_target: Dictionary = {
		"version": InventoryManager.SAVE_VERSION,
		"item_counts": next_counts
	}
	if not SaveManager.write_save_batch({
		"equipment": equipment_target,
		"inventory": inventory_target
	}):
		return false

	ascension_stars = next_stars
	InventoryManager.item_counts = next_counts
	InventoryManager.inventory_changed.emit(InventoryManager.REFINEMENT_SHARD, next_shards)
	InventoryManager.item_removed.emit(InventoryManager.REFINEMENT_SHARD, shard_cost, next_shards)
	equipment_ascended.emit(item_id, old_star, new_star)
	var slot_id: String = str(get_item_data(item_id).get("slot", ""))
	if get_equipped_item_id(slot_id) == item_id:
		equipment_changed.emit(slot_id, item_id)
	AudioManager.play_sfx("equip")
	DebugLogger.system(str(
		"Equipment ascended: ", item_id, " | ", old_star, "★ -> ", new_star,
		"★ | Refinement Shards -", shard_cost
	))
	return true

func equip_item(item_id: String) -> bool:
	if not can_modify_equipment():
		push_warning(
			"EquipmentManager: equipment tidak dapat diubah "
			+ "selama run aktif."
		)
		return false
	if not has_item_definition(item_id):
		push_warning(
			"EquipmentManager: equipment tidak ditemukan: "
			+ item_id
		)
		return false
	if not InventoryManager.owns_item(item_id):
		push_warning(
			"EquipmentManager: equipment belum dimiliki: "
			+ item_id
		)
		return false
	var item_data := get_item_data(item_id)
	var slot_id := str(item_data.get("slot", ""))
	if not is_valid_slot(slot_id):
		push_warning(
			"EquipmentManager: slot equipment tidak valid: "
			+ item_id
		)
		return false
	var previous_item_id := get_equipped_item_id(slot_id)
	if previous_item_id == item_id:
		return false
	equipped_item_ids[slot_id] = item_id
	save_equipment()
	equipment_changed.emit(slot_id, item_id)
	DebugLogger.system(str(
		"Equipment dipasang: ",
		item_id,
		" | Slot: ",
		slot_id
	))
	return true

func unequip_slot(slot_id: String) -> bool:
	if not can_modify_equipment():
		push_warning(
			"EquipmentManager: equipment tidak dapat diubah "
			+ "selama run aktif."
		)
		return false
	if not is_valid_slot(slot_id):
		return false
	var previous_item_id := get_equipped_item_id(slot_id)
	if previous_item_id.is_empty():
		return false
	equipped_item_ids[slot_id] = ""
	save_equipment()
	equipment_changed.emit(slot_id, "")
	DebugLogger.system(str(
		"Equipment dilepas: ",
		previous_item_id,
		" | Slot: ",
		slot_id
	))
	return true

func get_total_max_health_bonus() -> float:
	var total_bonus: float = 0.0
	for slot_id in get_slot_ids():
		var item_data := get_equipped_item_data(slot_id)
		total_bonus += float(
			item_data.get("max_health_flat", 0.0)
		)
	return total_bonus

func get_damage_multiplier() -> float:
	var total_bonus: float = 0.0
	for slot_id in get_slot_ids():
		var item_data := get_equipped_item_data(slot_id)
		total_bonus += float(
			item_data.get("damage_bonus", 0.0)
		)
	return maxf(1.0 + total_bonus, 0.0)

func get_movement_speed_multiplier() -> float:
	var total_bonus: float = 0.0
	for slot_id in get_slot_ids():
		var item_data := get_equipped_item_data(slot_id)
		total_bonus += float(
			item_data.get("movement_speed_bonus", 0.0)
		)
	return maxf(1.0 + total_bonus, 0.0)

func get_experience_multiplier() -> float:
	var total_bonus: float = 0.0
	for slot_id in get_slot_ids():
		var item_data := get_equipped_item_data(slot_id)
		total_bonus += float(
			item_data.get("experience_bonus", 0.0)
		)
	return maxf(1.0 + total_bonus, 0.0)

func get_critical_chance_bonus() -> float:
	var total_bonus: float = 0.0
	for slot_id in get_slot_ids():
		var item_data := get_equipped_item_data(slot_id)
		total_bonus += float(
			item_data.get("critical_chance_bonus", 0.0)
		)
	return maxf(total_bonus, 0.0)

func _validate_loaded_state() -> void:
	var validated: Dictionary = {}
	for slot_id in get_slot_ids():
		var item_id := str(
			equipped_item_ids.get(slot_id, "")
		)
		if item_id.is_empty():
			validated[slot_id] = ""
			continue
		if not has_item_definition(item_id):
			validated[slot_id] = ""
			continue
		var item_data := get_item_data(item_id)
		if str(item_data.get("slot", "")) != slot_id:
			validated[slot_id] = ""
			continue
		validated[slot_id] = item_id
	equipped_item_ids = validated
	var validated_stars: Dictionary = {}
	for raw_item_id in ascension_stars.keys():
		var item_id: String = str(raw_item_id)
		if not has_item_definition(item_id):
			continue
		validated_stars[item_id] = clampi(
			int(ascension_stars.get(raw_item_id, 1)),
			1,
			MAX_ASCENSION_STAR
		)
	ascension_stars = validated_stars

func build_equipment_save_data(stars_override: Dictionary = {}) -> Dictionary:
	var stars: Dictionary = ascension_stars if stars_override.is_empty() else stars_override
	return {
		"version": SAVE_VERSION,
		"equipped_item_ids": equipped_item_ids.duplicate(true),
		"ascension_stars": stars.duplicate(true)
	}

func save_equipment() -> void:
	var save_data: Dictionary = build_equipment_save_data()
	var io_result: Dictionary = SaveManager.write_save_data(
		"equipment",
		save_data
	)
	if not bool(io_result.get("success", false)):
		push_error(
			"EquipmentManager: gagal menyimpan equipment.save."
		)

func load_equipment() -> void:
	var io_result: Dictionary = SaveManager.read_save_data("equipment")
	if not bool(io_result.get("exists", false)):
		DebugLogger.system(str("Belum ada equipment save."))
		return
	if not bool(io_result.get("success", false)):
		push_warning(
			"EquipmentManager: equipment.save tidak dapat dibuka."
		)
		return
	var save_data: Dictionary = io_result.get("data", {})
	var loaded_equipped = save_data.get(
		"equipped_item_ids",
		{}
	)
	if not loaded_equipped is Dictionary:
		return
	for slot_id in get_slot_ids():
		equipped_item_ids[slot_id] = str(
			loaded_equipped.get(slot_id, "")
		)
	var loaded_stars = save_data.get("ascension_stars", {})
	if loaded_stars is Dictionary:
		ascension_stars = loaded_stars.duplicate(true)

func print_equipment_status() -> void:
	DebugLogger.system(str("EquipmentManager aktif!"))
	DebugLogger.system(str("Equipment Item Count: ", EQUIPMENT_CATALOG.size()))
	for slot_id in get_slot_ids():
		var item_id := get_equipped_item_id(slot_id)
		if item_id.is_empty():
			DebugLogger.system(str("Equipment Slot ", slot_id, ": Empty"))
		else:
			DebugLogger.system(str(
				"Equipment Slot ",
				slot_id,
				": ",
				item_id,
				" | ",
				get_item_star(item_id),
				"★"
			))

func get_secondary_bonus(stat_id: String, cap: float) -> float:
	var total: float = 0.0
	for slot_id in get_slot_ids():
		total += float(get_equipped_item_data(slot_id).get(stat_id, 0.0))
	return clampf(total, 0.0, cap)
