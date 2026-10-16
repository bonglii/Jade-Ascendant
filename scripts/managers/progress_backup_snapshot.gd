extends RefCounted
## Offline progress only. Server-paid state, identities and active runs never enter archives.
const DOMAINS: Array[String] = ["achievements", "cultivation_mastery", "daily_quests", "equipment", "idle_cultivation", "inventory", "journey", "pavilion", "progression"]
const MAX_BYTES: int = 196608
const FORBIDDEN: Array[String] = ["__proto__", "constructor", "prototype", "purchase_token", "purchaseToken", "id_token", "access_token", "auth", "email", "paid_wallet", "paid_entitlements"]

static func _service(id: String) -> Variant:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null(NodePath(id))

static func safe_tree(value: Variant, depth: int = 0) -> bool:
	if depth > 14: return false
	if value == null or value is bool: return true
	if value is int: return value >= 0 and value <= 9007199254740991
	if value is float: return is_finite(value) and value >= 0 and value <= 9007199254740991 and floor(value) == value
	if value is String: return value.to_utf8_buffer().size() <= 4096
	if value is Array:
		if value.size() > 4096: return false
		for entry: Variant in value:
			if not safe_tree(entry, depth + 1): return false
		return true
	if not value is Dictionary or value.size() > 2048: return false
	for key: Variant in value:
		if not key is String or key.length() > 128 or key in FORBIDDEN or not safe_tree(value[key], depth + 1): return false
	return true

static func integer_tree(value: Variant) -> Variant:
	if value is float and is_finite(value) and floor(value) == value and abs(value) <= 9007199254740991: return int(value)
	if value is Array:
		var array: Array = []
		for entry: Variant in value: array.append(integer_tree(entry))
		return array
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key: Variant in value: dictionary[key] = integer_tree(value[key])
		return dictionary
	return value

static func valid(value: Variant) -> bool:
	var saves: Variant = _service("SaveManager")
	var inventory_manager: Variant = _service("InventoryManager")
	if not value is Dictionary or value.size() != 2 or value.get("format") != 1 or not value.get("domains") is Dictionary or not safe_tree(value): return false
	if JSON.stringify(value).to_utf8_buffer().size() > MAX_BYTES - 256: return false
	var domains: Dictionary = value.domains
	var ids: Array = domains.keys(); ids.sort()
	if ids != DOMAINS or saves.get_save_domain_ids_for_scope("permanent") != DOMAINS: return false
	if not saves._validate_batch_targets(domains): return false
	var journey: Dictionary = domains.journey
	if journey.get("active_run_chapter_id") != 0 or journey.get("active_run_stage_id") != 0 or journey.get("m7d_run_id") != "": return false
	var equipment: Dictionary = domains.equipment
	if equipment.has("active_run_loadout_snapshot") or not equipment.get("weapon_levels") is Dictionary or not equipment.get("ascension_stars") is Dictionary: return false
	var inventory: Dictionary = domains.inventory.item_counts
	for id: Variant in inventory:
		if not inventory_manager.is_known_item(str(id)): return false
	var catalog = preload("res://scripts/data/equipment_catalog.gd")
	for slot: Variant in equipment.equipped_item_ids:
		if slot not in ["armament", "robe", "bracer", "boots", "pendant"]: return false
		var id: String = str(equipment.equipped_item_ids[slot])
		if id != "" and (not catalog.ITEMS.has(id) or catalog.ITEMS[id].slot != slot or int(inventory.get(id, 0)) <= 0): return false
	for id: Variant in equipment.weapon_levels:
		if not catalog.ITEMS.has(id) or catalog.ITEMS[id].slot != "armament" or int(equipment.weapon_levels[id]) > int(equipment.ascension_stars.get(id, 1)) * 10: return false
	var mastery: Dictionary = domains.cultivation_mastery
	if not mastery.get("run") is Dictionary or not mastery.run.is_empty() or not mastery.get("trial") is Dictionary or not mastery.trial.is_empty(): return false
	var manager: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("CultivationMasteryManager")
	if manager == null or not bool(manager.call("_valid", mastery)): return false
	return true

static func capture() -> Dictionary:
	var services: Dictionary = {}
	for id: String in ["AchievementManager", "DailyQuestManager", "EquipmentManager", "IdleCultivationManager", "InventoryManager", "JourneyManager", "PavilionManager", "ProgressionManager"]:
		services[id] = _service(id)
		if services[id] == null: return {}
	var mastery: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("CultivationMasteryManager")
	if mastery == null or not bool(mastery.get("ready_state")): return {}
	var domains: Dictionary = {
		"achievements": services["AchievementManager"].build_save_data(),
		"cultivation_mastery": mastery.get("state").duplicate(true),
		"daily_quests": services["DailyQuestManager"].build_save_data(),
		"equipment": services["EquipmentManager"].build_equipment_save_data(),
		"idle_cultivation": services["IdleCultivationManager"].state.duplicate(true),
		"inventory": {"version": 1, "item_counts": services["InventoryManager"].item_counts.duplicate(true)},
		"journey": services["JourneyManager"].build_save_data(),
		"pavilion": services["PavilionManager"].state.duplicate(true),
		"progression": services["ProgressionManager"].build_progression_save_data(),
	}
	domains.journey.active_run_chapter_id = 0; domains.journey.active_run_stage_id = 0; domains.journey.m7d_run_id = ""
	domains.cultivation_mastery.run = {}; domains.cultivation_mastery.trial = {}
	domains.equipment.erase("active_run_loadout_snapshot")
	var snapshot: Dictionary = {"format": 1, "domains": domains}
	return snapshot if valid(snapshot) else {}
