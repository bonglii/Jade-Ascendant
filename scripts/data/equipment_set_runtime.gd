extends RefCounted

## Stateless bridge between the permanent/set catalog and the runtime-aware
## EquipmentManager loadout resolver. No gameplay state is stored here.
const EquipmentSetCatalog = preload("res://scripts/data/equipment_set_catalog.gd")

static var _batch_depth: int = 0
static var _batch_ids: Array[String] = []
static var _batch_bonuses: Dictionary = {}
static func begin_combat_batch() -> void:
	if _batch_depth == 0:
		_batch_ids = get_equipped_item_ids()
		_batch_bonuses.clear()
	_batch_depth += 1

static func end_combat_batch() -> void:
	_batch_depth = maxi(0, _batch_depth - 1)
	if _batch_depth == 0:
		_batch_ids.clear(); _batch_bonuses.clear()

static func _manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("EquipmentManager") if tree != null else null

static func get_equipped_item_ids() -> Array[String]:
	if _batch_depth > 0: return _batch_ids
	var item_ids: Array[String] = []
	var manager: Node = _manager()
	if manager == null: return item_ids
	for slot_id: String in manager.get_slot_ids():
		var item_id: String = manager.get_equipped_item_id(slot_id)
		if not item_id.is_empty():
			item_ids.append(item_id)
	return item_ids

static func get_bonus(stat_id: String) -> float:
	if _batch_depth > 0:
		if not _batch_bonuses.has(stat_id): _batch_bonuses[stat_id] = EquipmentSetCatalog.get_gameplay_bonus(stat_id, _batch_ids)
		return float(_batch_bonuses[stat_id])
	return EquipmentSetCatalog.get_gameplay_bonus(
		stat_id,
		get_equipped_item_ids()
	)

static func get_capped_combined_secondary_bonus(
	stat_id: String,
	cap: float
) -> float:
	return clampf(
		(_manager().get_secondary_bonus(stat_id, cap) if _manager() != null else 0.0)
		+ get_bonus(stat_id),
		0.0,
		cap
	)
