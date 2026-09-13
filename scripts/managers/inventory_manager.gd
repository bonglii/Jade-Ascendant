extends Node

## Inventory Manager
## Mengelola ownership dan jumlah item permanen milik Player.
## Equipment definition tetap menjadi tanggung jawab EquipmentManager.
## Inventory hanya menyimpan ownership/count dan tidak mengubah stat Player.

signal inventory_changed(item_id: String, new_count: int)
signal item_added(item_id: String, amount: int, new_count: int)
signal item_removed(item_id: String, amount: int, new_count: int)

const SAVE_PATH: String = "user://inventory.save"
const SAVE_VERSION: int = 1

const ITEM_TYPE_EQUIPMENT: String = "equipment"
const ITEM_TYPE_MATERIAL: String = "material"
const ITEM_TYPE_CONSUMABLE: String = "consumable"
const REFINEMENT_SHARD: String = "refinement_shard"
const DUPLICATE_SHARDS: Dictionary = {"common": 5, "rare": 12, "epic": 30, "legendary": 75}

var item_counts: Dictionary = {}

func _ready() -> void:
	load_inventory()
	_validate_loaded_state()
	_migrate_equipped_items_to_inventory()
	save_inventory()
	print_inventory_status()

func is_known_item(item_id: String) -> bool:
	return item_id == REFINEMENT_SHARD or EquipmentManager.has_item_definition(item_id)

func get_item_type(item_id: String) -> String:
	if item_id == REFINEMENT_SHARD:
		return ITEM_TYPE_MATERIAL
	if EquipmentManager.has_item_definition(item_id):
		return ITEM_TYPE_EQUIPMENT
	return ""

func get_item_data(item_id: String) -> Dictionary:
	if item_id == REFINEMENT_SHARD:
		return {"display_name": "Refinement Shard", "rarity": "rare", "item_type": ITEM_TYPE_MATERIAL,
			"description": "Repeat clears and duplicate equipment provide shards. Use them to forge or ascend equipment."}
	if not is_known_item(item_id):
		return {}
	if EquipmentManager.has_item_definition(item_id):
		var item_data := EquipmentManager.get_item_data(item_id)
		item_data["item_type"] = ITEM_TYPE_EQUIPMENT
		return item_data
	return {}

func get_item_count(item_id: String) -> int:
	if not is_known_item(item_id):
		return 0
	return maxi(int(item_counts.get(item_id, 0)), 0)

func owns_item(item_id: String) -> bool:
	return get_item_count(item_id) > 0

func get_owned_item_ids() -> Array[String]:
	var owned_item_ids: Array[String] = []
	for raw_item_id in item_counts.keys():
		var item_id := str(raw_item_id)
		if get_item_count(item_id) <= 0:
			continue
		owned_item_ids.append(item_id)
	owned_item_ids.sort()
	return owned_item_ids

func get_unique_item_count() -> int:
	return get_owned_item_ids().size()

func get_total_item_count() -> int:
	var total_count: int = 0
	for item_id in get_owned_item_ids():
		total_count += get_item_count(item_id)
	return total_count

func add_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if not is_known_item(item_id):
		push_warning(
			"InventoryManager: item tidak dikenal: "
			+ item_id
		)
		return false
	item_counts = preview_add_items({item_id: amount})
	var new_count: int = get_item_count(item_id)
	save_inventory()
	inventory_changed.emit(item_id, new_count)
	item_added.emit(item_id, amount, new_count)
	DebugLogger.system(str(
		"Inventory item ditambahkan: ",
		item_id,
		" +",
		amount,
		" | Total: ",
		new_count
	))
	return true

func can_remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if not is_known_item(item_id):
		return false
	var current_count := get_item_count(item_id)
	if current_count < amount:
		return false
	var remaining_count := current_count - amount
	if remaining_count <= 0 and _is_equipped(item_id):
		return false
	return true

func remove_item(item_id: String, amount: int = 1) -> bool:
	if not can_remove_item(item_id, amount):
		return false
	var new_count := get_item_count(item_id) - amount
	if new_count <= 0:
		item_counts.erase(item_id)
		new_count = 0
	else:
		item_counts[item_id] = new_count
	save_inventory()
	inventory_changed.emit(item_id, new_count)
	item_removed.emit(item_id, amount, new_count)
	DebugLogger.system(str(
		"Inventory item dikurangi: ",
		item_id,
		" -",
		amount,
		" | Total: ",
		new_count
	))
	return true

func _is_equipped(item_id: String) -> bool:
	for slot_id in EquipmentManager.get_slot_ids():
		if EquipmentManager.get_equipped_item_id(slot_id) == item_id:
			return true
	return false

func _migrate_equipped_items_to_inventory() -> void:
	var migrated_count: int = 0
	for slot_id in EquipmentManager.get_slot_ids():
		var item_id := EquipmentManager.get_equipped_item_id(slot_id)
		if item_id.is_empty():
			continue
		if not is_known_item(item_id):
			continue
		if get_item_count(item_id) > 0:
			continue
		item_counts[item_id] = 1
		migrated_count += 1
	if migrated_count > 0:
		DebugLogger.system(str(
			"Inventory migration: ",
			migrated_count,
			" equipped item ditambahkan ke ownership."
		))

func _validate_loaded_state() -> void:
	var validated_counts: Dictionary = {}
	for raw_item_id in item_counts.keys():
		var item_id := str(raw_item_id)
		if not is_known_item(item_id):
			continue
		var item_count := maxi(
			int(item_counts.get(raw_item_id, 0)),
			0
		)
		if item_count <= 0:
			continue
		validated_counts[item_id] = item_count
	item_counts = validated_counts
	# Convert legacy duplicates once; inventory remains a v1 count dictionary.
	item_counts = preview_add_items({})

func preview_add_items(rewards: Dictionary) -> Dictionary:
	var counts: Dictionary = item_counts.duplicate(true)
	for raw_id in rewards:
		var item_id: String = str(raw_id)
		if is_known_item(item_id):
			counts[item_id] = int(counts.get(item_id, 0)) + maxi(int(rewards[raw_id]), 0)
	var shards: int = int(counts.get(REFINEMENT_SHARD, 0))
	for raw_id in counts.keys():
		var item_id: String = str(raw_id)
		if item_id == REFINEMENT_SHARD or not EquipmentManager.has_item_definition(item_id):
			continue
		var count: int = int(counts[item_id])
		if count <= 1:
			continue
		var rarity: String = str(EquipmentManager.get_item_data(item_id).get("rarity", "common"))
		shards += (count - 1) * int(DUPLICATE_SHARDS.get(rarity, 5))
		counts[item_id] = 1
	if shards > 0:
		counts[REFINEMENT_SHARD] = shards
	return counts

func save_inventory() -> void:
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"item_counts": item_counts.duplicate(true)
	}
	var io_result: Dictionary = SaveManager.write_save_data(
		"inventory",
		save_data
	)
	if not bool(io_result.get("success", false)):
		push_error(
			"InventoryManager: gagal menyimpan inventory.save."
		)

func load_inventory() -> void:
	var io_result: Dictionary = SaveManager.read_save_data("inventory")
	if not bool(io_result.get("exists", false)):
		DebugLogger.system(str("Belum ada inventory save."))
		return
	if not bool(io_result.get("success", false)):
		push_warning(
			"InventoryManager: inventory.save tidak dapat dibuka."
		)
		return
	var save_data: Dictionary = io_result.get("data", {})
	var loaded_counts = save_data.get("item_counts", {})
	if not loaded_counts is Dictionary:
		return
	item_counts = loaded_counts.duplicate(true)

func print_inventory_status() -> void:
	DebugLogger.system(str("InventoryManager aktif!"))
	DebugLogger.system(str("Inventory Unique Items: ", get_unique_item_count()))
	DebugLogger.system(str("Inventory Total Items: ", get_total_item_count()))
	for item_id in get_owned_item_ids():
		DebugLogger.system(str(
			"Inventory Item ",
			item_id,
			": ",
			get_item_count(item_id)
		))
