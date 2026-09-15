extends Node

## Equipment Manager
## Mengelola definisi equipment permanen dan slot yang sedang dipakai.
## Ownership item dikelola oleh InventoryManager.
## EquipmentManager hanya mengelola equipped slot dan stat contribution.

signal equipment_changed(slot_id: String, item_id: String)
signal equipment_ascended(item_id: String, old_star: int, new_star: int)

const SAVE_PATH: String = "user://equipment.save"
const SAVE_VERSION: int = 1
const CHECKPOINT_DOMAIN_ID: String = "checkpoint"
const RUN_LOADOUT_SNAPSHOT_VERSION: int = 1
const ACTIVE_RUN_SNAPSHOT_SAVE_KEY: String = "active_run_loadout_snapshot"

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

# `equipped_item_ids` and `ascension_stars` are the permanent NEXT RUN loadout.
# Once a checkpoint exists, this snapshot freezes the loadout that belongs to
# that active run. It is persisted additively inside equipment.save so hub edits
# never rewrite checkpoint primary/backup history.
var active_run_loadout_snapshot: Dictionary = {}
var _snapshot_save_deferred: bool = false

func _ready() -> void:
	load_equipment()
	_validate_loaded_state()
	_connect_checkpoint_lifecycle()
	_reconcile_active_run_loadout_snapshot()
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
	# A checkpoint no longer seals the hub. Hub edits are permanent NEXT RUN
	# choices, while gameplay continues to read the frozen run snapshot. Direct
	# mid-combat mutation remains blocked.
	if SaveManager.is_progress_read_only():
		return false
	return not _has_gameplay_player()

func has_active_run_checkpoint() -> bool:
	return SaveManager.has_save_file(CHECKPOINT_DOMAIN_ID)

func has_preserved_active_run_loadout() -> bool:
	return (
		has_active_run_checkpoint()
		and not active_run_loadout_snapshot.is_empty()
	)

func get_item_data(item_id: String) -> Dictionary:
	if not has_item_definition(item_id):
		return {}
	var item_data: Dictionary = EQUIPMENT_CATALOG[item_id]
	return item_data.duplicate(true)

func get_loadout_equipped_item_id(slot_id: String) -> String:
	if not is_valid_slot(slot_id):
		return ""
	return str(equipped_item_ids.get(slot_id, ""))

func get_runtime_equipped_item_id(slot_id: String) -> String:
	if not is_valid_slot(slot_id):
		return ""
	if active_run_loadout_snapshot.is_empty():
		return get_loadout_equipped_item_id(slot_id)
	var runtime_equipped: Dictionary = active_run_loadout_snapshot.get(
		"equipped_item_ids",
		{}
	)
	return str(runtime_equipped.get(slot_id, ""))

func get_equipped_item_id(slot_id: String) -> String:
	# Keep the established API safe for gameplay callers without changing hub
	# semantics. Menu scenes have no real player node and therefore see NEXT RUN.
	if _should_use_active_run_loadout():
		return get_runtime_equipped_item_id(slot_id)
	return get_loadout_equipped_item_id(slot_id)

func get_loadout_equipped_item_data(slot_id: String) -> Dictionary:
	var item_id: String = get_loadout_equipped_item_id(slot_id)
	if item_id.is_empty():
		return {}
	return _build_effective_item_data(
		item_id,
		get_loadout_item_star(item_id)
	)

func get_runtime_equipped_item_data(slot_id: String) -> Dictionary:
	var item_id: String = get_runtime_equipped_item_id(slot_id)
	if item_id.is_empty():
		return {}
	return _build_effective_item_data(
		item_id,
		get_runtime_item_star(item_id)
	)

func get_equipped_item_data(slot_id: String) -> Dictionary:
	if _should_use_active_run_loadout():
		return get_runtime_equipped_item_data(slot_id)
	return get_loadout_equipped_item_data(slot_id)

func get_loadout_item_star(item_id: String) -> int:
	if not has_item_definition(item_id):
		return 0
	return clampi(
		int(ascension_stars.get(item_id, 1)),
		1,
		MAX_ASCENSION_STAR
	)

func get_runtime_item_star(item_id: String) -> int:
	if not has_item_definition(item_id):
		return 0
	if active_run_loadout_snapshot.is_empty():
		return get_loadout_item_star(item_id)
	var runtime_stars: Dictionary = active_run_loadout_snapshot.get(
		"ascension_stars",
		{}
	)
	return clampi(
		int(runtime_stars.get(item_id, 1)),
		1,
		MAX_ASCENSION_STAR
	)

func get_item_star(item_id: String) -> int:
	if _should_use_active_run_loadout():
		return get_runtime_item_star(item_id)
	return get_loadout_item_star(item_id)

func get_item_ascension_multiplier(item_id: String) -> float:
	var star: int = get_item_star(item_id)
	if star <= 0:
		return 1.0
	return float(ASCENSION_CORE_MULTIPLIERS.get(star, 1.0))

func get_effective_item_data(item_id: String) -> Dictionary:
	return _build_effective_item_data(item_id, get_item_star(item_id))

func _build_effective_item_data(item_id: String, star: int) -> Dictionary:
	var item_data: Dictionary = get_item_data(item_id)
	if item_data.is_empty():
		return {}
	var clamped_star: int = clampi(star, 1, MAX_ASCENSION_STAR)
	var multiplier: float = float(
		ASCENSION_CORE_MULTIPLIERS.get(clamped_star, 1.0)
	)
	for stat_id: String in ASCENSION_SCALABLE_STATS:
		if item_data.has(stat_id):
			item_data[stat_id] = float(item_data[stat_id]) * multiplier
	item_data["ascension_star"] = clamped_star
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
	if get_loadout_equipped_item_id(slot_id) == item_id:
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
			"EquipmentManager: equipment tidak dapat diubah saat gameplay "
			+ "aktif atau save sedang recovery/read-only."
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
	var previous_item_id := get_loadout_equipped_item_id(slot_id)
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
			"EquipmentManager: equipment tidak dapat diubah saat gameplay "
			+ "aktif atau save sedang recovery/read-only."
		)
		return false
	if not is_valid_slot(slot_id):
		return false
	var previous_item_id := get_loadout_equipped_item_id(slot_id)
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

func _get_stat_total(stat_id: String, use_runtime: bool) -> float:
	var total_bonus: float = 0.0
	for slot_id in get_slot_ids():
		var item_data: Dictionary = (
			get_runtime_equipped_item_data(slot_id)
			if use_runtime
			else get_loadout_equipped_item_data(slot_id)
		)
		total_bonus += float(item_data.get(stat_id, 0.0))
	return total_bonus

func get_loadout_total_max_health_bonus() -> float:
	return _get_stat_total("max_health_flat", false)

func get_loadout_damage_multiplier() -> float:
	return maxf(1.0 + _get_stat_total("damage_bonus", false), 0.0)

func get_loadout_movement_speed_multiplier() -> float:
	return maxf(
		1.0 + _get_stat_total("movement_speed_bonus", false),
		0.0
	)

func get_loadout_experience_multiplier() -> float:
	return maxf(1.0 + _get_stat_total("experience_bonus", false), 0.0)

func get_loadout_critical_chance_bonus() -> float:
	return maxf(_get_stat_total("critical_chance_bonus", false), 0.0)

func get_total_max_health_bonus() -> float:
	return _get_stat_total(
		"max_health_flat",
		_should_use_active_run_loadout()
	)

func get_damage_multiplier() -> float:
	return maxf(
		1.0 + _get_stat_total(
			"damage_bonus",
			_should_use_active_run_loadout()
		),
		0.0
	)

func get_movement_speed_multiplier() -> float:
	return maxf(
		1.0 + _get_stat_total(
			"movement_speed_bonus",
			_should_use_active_run_loadout()
		),
		0.0
	)

func get_experience_multiplier() -> float:
	return maxf(
		1.0 + _get_stat_total(
			"experience_bonus",
			_should_use_active_run_loadout()
		),
		0.0
	)

func get_critical_chance_bonus() -> float:
	return maxf(
		_get_stat_total(
			"critical_chance_bonus",
			_should_use_active_run_loadout()
		),
		0.0
	)

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
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"equipped_item_ids": equipped_item_ids.duplicate(true),
		"ascension_stars": stars.duplicate(true)
	}
	if not active_run_loadout_snapshot.is_empty():
		save_data[ACTIVE_RUN_SNAPSHOT_SAVE_KEY] = (
			active_run_loadout_snapshot.duplicate(true)
		)
	return save_data

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
	var loaded_snapshot: Variant = save_data.get(
		ACTIVE_RUN_SNAPSHOT_SAVE_KEY,
		{}
	)
	if loaded_snapshot is Dictionary:
		active_run_loadout_snapshot = loaded_snapshot.duplicate(true)

func print_equipment_status() -> void:
	DebugLogger.system(str("EquipmentManager aktif!"))
	DebugLogger.system(str("Equipment Item Count: ", EQUIPMENT_CATALOG.size()))
	for slot_id in get_slot_ids():
		var item_id := get_loadout_equipped_item_id(slot_id)
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
	if has_preserved_active_run_loadout():
		DebugLogger.system(str(
			"Active Run Loadout Snapshot: preserved | ",
			active_run_loadout_snapshot.get("equipped_item_ids", {})
		))

func get_loadout_secondary_bonus(stat_id: String, cap: float) -> float:
	return clampf(_get_stat_total(stat_id, false), 0.0, cap)

func get_secondary_bonus(stat_id: String, cap: float) -> float:
	return clampf(
		_get_stat_total(
			stat_id,
			_should_use_active_run_loadout()
		),
		0.0,
		cap
	)

func build_active_run_loadout_snapshot() -> Dictionary:
	var snapshot_equipped: Dictionary = {}
	var snapshot_stars: Dictionary = {}
	for slot_id in get_slot_ids():
		var item_id: String = get_loadout_equipped_item_id(slot_id)
		snapshot_equipped[slot_id] = item_id
		if not item_id.is_empty():
			snapshot_stars[item_id] = get_loadout_item_star(item_id)
	return {
		"version": RUN_LOADOUT_SNAPSHOT_VERSION,
		"equipped_item_ids": snapshot_equipped,
		"ascension_stars": snapshot_stars,
		"signature": _build_active_run_snapshot_signature(
			snapshot_equipped,
			snapshot_stars
		)
	}

func get_active_run_loadout_snapshot() -> Dictionary:
	return active_run_loadout_snapshot.duplicate(true)

func _normalize_active_run_loadout_snapshot(raw_snapshot: Variant) -> Dictionary:
	if not raw_snapshot is Dictionary:
		return {}
	var snapshot: Dictionary = raw_snapshot
	var raw_version: Variant = snapshot.get("version", -1)
	if not raw_version is int:
		return {}
	if int(raw_version) != RUN_LOADOUT_SNAPSHOT_VERSION:
		return {}
	var raw_equipped: Variant = snapshot.get("equipped_item_ids", {})
	var raw_stars: Variant = snapshot.get("ascension_stars", {})
	var raw_signature: Variant = snapshot.get("signature", "")
	if not raw_equipped is Dictionary or not raw_stars is Dictionary:
		return {}
	if not raw_signature is String or str(raw_signature).is_empty():
		return {}

	for raw_item_id: Variant in raw_stars.keys():
		if not raw_item_id is String:
			return {}
		var star_value: Variant = raw_stars[raw_item_id]
		if not star_value is int:
			return {}
		if int(star_value) < 1 or int(star_value) > MAX_ASCENSION_STAR:
			return {}

	var normalized_equipped: Dictionary = {}
	var normalized_stars: Dictionary = {}
	for slot_id in get_slot_ids():
		if not raw_equipped.has(slot_id):
			return {}
		var raw_item_id: Variant = raw_equipped[slot_id]
		if not raw_item_id is String:
			return {}
		var item_id: String = raw_item_id
		if item_id.is_empty():
			normalized_equipped[slot_id] = ""
			continue
		if not has_item_definition(item_id):
			return {}
		if str(get_item_data(item_id).get("slot", "")) != slot_id:
			return {}
		if not raw_stars.has(item_id):
			return {}
		normalized_equipped[slot_id] = item_id
		normalized_stars[item_id] = int(raw_stars[item_id])

	var expected_signature: String = _build_active_run_snapshot_signature(
		normalized_equipped,
		normalized_stars
	)
	if str(raw_signature) != expected_signature:
		return {}

	return {
		"version": RUN_LOADOUT_SNAPSHOT_VERSION,
		"equipped_item_ids": normalized_equipped,
		"ascension_stars": normalized_stars,
		"signature": expected_signature
	}

func _build_active_run_snapshot_signature(
	equipped: Dictionary,
	stars: Dictionary
) -> String:
	var parts: Array[String] = []
	for slot_id in get_slot_ids():
		var item_id: String = str(equipped.get(slot_id, ""))
		var star: int = 0 if item_id.is_empty() else int(stars.get(item_id, 1))
		parts.append("%s:%s:%d" % [slot_id, item_id, star])
	return "|".join(parts)

func _get_backup_active_run_loadout_snapshot() -> Dictionary:
	var backup_result: Dictionary = SaveManager.read_save_backup("equipment")
	if not bool(backup_result.get("success", false)):
		return {}
	var backup_data: Dictionary = backup_result.get("data", {})
	return _normalize_active_run_loadout_snapshot(
		backup_data.get(ACTIVE_RUN_SNAPSHOT_SAVE_KEY, {})
	)

func _reconcile_active_run_loadout_snapshot() -> void:
	if not has_active_run_checkpoint():
		if not active_run_loadout_snapshot.is_empty():
			active_run_loadout_snapshot.clear()
		return

	var normalized: Dictionary = _normalize_active_run_loadout_snapshot(
		active_run_loadout_snapshot
	)
	if not normalized.is_empty():
		active_run_loadout_snapshot = normalized
		DebugLogger.system(
			"Active Run Loadout Snapshot: restored from equipment.save"
		)
		return

	var backup_snapshot: Dictionary = _get_backup_active_run_loadout_snapshot()
	if not backup_snapshot.is_empty():
		active_run_loadout_snapshot = backup_snapshot
		DebugLogger.system(
			"Active Run Loadout Snapshot: recovered from equipment backup"
		)
		return

	# Backward compatibility: before this feature the hub sealed equipment while
	# a checkpoint existed, so the current permanent loadout is the only valid
	# historical source for a legacy checkpoint. Freeze it once before hub edits.
	active_run_loadout_snapshot = build_active_run_loadout_snapshot()
	DebugLogger.system(
		"Active Run Loadout Snapshot: legacy checkpoint frozen safely"
	)

func _connect_checkpoint_lifecycle() -> void:
	if not SaveManager.save_write_completed.is_connected(
		_on_checkpoint_save_write_completed
	):
		SaveManager.save_write_completed.connect(
			_on_checkpoint_save_write_completed
		)
	if not SaveManager.save_delete_completed.is_connected(
		_on_checkpoint_save_delete_completed
	):
		SaveManager.save_delete_completed.connect(
			_on_checkpoint_save_delete_completed
		)

func _on_checkpoint_save_write_completed(
	domain_id: String,
	io_result: Dictionary
) -> void:
	if domain_id != CHECKPOINT_DOMAIN_ID:
		return
	if not bool(io_result.get("success", false)):
		return
	if active_run_loadout_snapshot.is_empty():
		active_run_loadout_snapshot = build_active_run_loadout_snapshot()
		DebugLogger.system(
			"Active Run Loadout Snapshot: frozen at first checkpoint"
		)
	_queue_snapshot_save()

func _on_checkpoint_save_delete_completed(
	domain_id: String,
	io_result: Dictionary
) -> void:
	if domain_id != CHECKPOINT_DOMAIN_ID:
		return
	if not bool(io_result.get("success", false)):
		return
	if active_run_loadout_snapshot.is_empty():
		return
	active_run_loadout_snapshot.clear()
	DebugLogger.system("Active Run Loadout Snapshot: cleared with checkpoint")
	_queue_snapshot_save()

func _queue_snapshot_save() -> void:
	if _snapshot_save_deferred:
		return
	_snapshot_save_deferred = true
	call_deferred("_persist_snapshot_state")

func _persist_snapshot_state() -> void:
	_snapshot_save_deferred = false
	if SaveManager.has_pending_transaction():
		return
	if SaveManager.is_progress_read_only():
		return
	save_equipment()

func _has_gameplay_player() -> bool:
	return get_tree().get_first_node_in_group("player") != null

func _should_use_active_run_loadout() -> bool:
	return (
		not active_run_loadout_snapshot.is_empty()
		and _has_gameplay_player()
	)
