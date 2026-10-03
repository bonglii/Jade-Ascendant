extends RefCounted

## Eight-domain full permanent snapshot contract used by the controlled-transfer
## staging QA. This mirrors the reviewed backend Gate 6 v2 shape, adds local
## catalogue compatibility checks, performs no networking and never writes saves.

const DRAFT_SNAPSHOT_VERSION: int = 2
const DOMAIN_COUNT: int = 8
const MAX_SNAPSHOT_BYTES: int = 524288
const MAX_NESTING_DEPTH: int = 12
const MAX_CONTAINER_ENTRIES: int = 2048
const MAX_SAFE_INTEGER: int = 9007199254740991

const PERMANENT_DOMAIN_IDS = [
	"achievements",
	"daily_quests",
	"equipment",
	"idle_cultivation",
	"inventory",
	"journey",
	"pavilion",
	"progression",
]
const ROOT_KEYS = [
	"draft_snapshot_version", "owner_uid", "captured_at_unix",
	"domain_schema_versions", "domains",
]
const EQUIPMENT_SLOTS = ["armament", "robe", "bracer", "boots", "pendant"]
const ALLOWED_FIELDS = {
	"achievements": ["version", "progress", "unlocked", "claimed"],
	"daily_quests": ["version", "date_key", "active_quest_ids", "progress", "completed", "claimed"],
	"equipment": ["version", "equipped_item_ids", "ascension_stars"],
	"idle_cultivation": [
		"version", "last_claim_unix", "last_observed_unix",
		"lifetime_claim_seconds", "shard_progress_units",
		"processed_rewarded_grant_ids",
	],
	"inventory": ["version", "item_counts"],
	"journey": [
		"version", "selected_chapter_id", "selected_stage_id",
		"active_run_chapter_id", "active_run_stage_id",
		"unlocked_stage_keys", "cleared_stage_keys",
	],
	"pavilion": [
		"version", "meditation_date", "cosmetic_id", "owned_cosmetics",
		"celestial_jade", "pavilion_seals", "starter_seals_claimed",
		"wish_item_id", "wish_fate_guaranteed", "pity_rare_plus",
		"pity_epic_plus", "pity_legendary", "lifetime_pulls",
		"cadence_last_daily_bonus_date", "cadence_active_days",
		"cadence_cycles_completed", "rewarded_ads_claimed_in_cycle",
		"claimed_milestone_ids", "claimed_one_time_product_ids",
		"monthly_blessing_expires_unix", "monthly_blessing_last_claim_date",
		"monthly_blessing_daily_claims_remaining",
		"monthly_blessing_purchase_count", "processed_grant_ids",
	],
	"progression": [
		"version", "spirit_stone", "vitality_level", "sword_power_level",
		"swift_qi_level", "hero_experience_total", "hero_milestones_claimed",
	],
}
const REQUIRED_FIELDS = {
	"achievements": ["progress", "unlocked", "claimed"],
	"daily_quests": ["date_key", "progress", "completed", "claimed"],
	"equipment": ["equipped_item_ids"],
	"idle_cultivation": [
		"last_claim_unix", "last_observed_unix", "lifetime_claim_seconds",
		"shard_progress_units",
	],
	"inventory": ["item_counts"],
	"journey": [
		"selected_chapter_id", "selected_stage_id", "active_run_chapter_id",
		"active_run_stage_id", "unlocked_stage_keys", "cleared_stage_keys",
	],
	"pavilion": ["meditation_date", "cosmetic_id", "owned_cosmetics"],
	"progression": [
		"spirit_stone", "vitality_level", "sword_power_level", "swift_qi_level",
	],
}


func get_domain_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in PERMANENT_DOMAIN_IDS:
		ids.append(str(raw_id))
	return ids


func inspect_draft(draft: Dictionary, expected_uid: String) -> Dictionary:
	if not _safe_uid(expected_uid):
		return _reject("INVALID_IDENTITY")
	if not _has_exact_keys(draft, ROOT_KEYS):
		return _reject("INVALID_ENVELOPE")
	if typeof(draft.get("draft_snapshot_version")) != TYPE_INT:
		return _reject("INVALID_DRAFT_VERSION")
	if int(draft["draft_snapshot_version"]) != DRAFT_SNAPSHOT_VERSION:
		return _reject("INVALID_DRAFT_VERSION")
	if not (draft.get("owner_uid") is String) or str(draft["owner_uid"]) != expected_uid:
		return _reject("OWNER_MISMATCH")
	if not _positive_int(draft.get("captured_at_unix")):
		return _reject("UNTRUSTED_TIMESTAMP_SHAPE")
	if not (draft.get("domain_schema_versions") is Dictionary):
		return _reject("INVALID_DOMAIN_VERSIONS")
	if not (draft.get("domains") is Dictionary):
		return _reject("INVALID_DOMAIN_SET")
	if not _json_tree_safe(draft, 0):
		return _reject("UNSAFE_JSON_STRUCTURE")
	if JSON.stringify(draft).to_utf8_buffer().size() > MAX_SNAPSHOT_BYTES:
		return _reject("DRAFT_TOO_LARGE")

	var registered_ids: Array[String] = SaveManager.get_save_domain_ids_for_scope(
		SaveManager.SCOPE_PERMANENT
	)
	registered_ids.sort()
	if registered_ids != get_domain_ids():
		return _reject("PERMANENT_DOMAIN_REGISTRY_CHANGED")

	var versions: Dictionary = draft["domain_schema_versions"]
	var domains: Dictionary = draft["domains"]
	if not _has_exact_keys(versions, PERMANENT_DOMAIN_IDS):
		return _reject("INCOMPLETE_PERMANENT_DOMAINS")
	if not _has_exact_keys(domains, PERMANENT_DOMAIN_IDS):
		return _reject("INCOMPLETE_PERMANENT_DOMAINS")

	for raw_id in PERMANENT_DOMAIN_IDS:
		var domain_id: String = str(raw_id)
		if not SaveManager.has_save_domain(domain_id):
			return _reject("UNREGISTERED_DOMAIN")
		if SaveManager.get_save_scope(domain_id) != SaveManager.SCOPE_PERMANENT:
			return _reject("NON_PERMANENT_DOMAIN")
		var schema: int = SaveManager.get_save_schema_version(domain_id)
		if typeof(versions.get(domain_id)) != TYPE_INT or int(versions[domain_id]) != schema:
			return _reject("SCHEMA_VERSION_MISMATCH")
		if not (domains.get(domain_id) is Dictionary):
			return _reject("DOMAIN_PAYLOAD_INVALID")
		var payload: Dictionary = domains[domain_id]
		if not _allowed_keys_only(payload, ALLOWED_FIELDS[domain_id]):
			return _reject("UNEXPECTED_DOMAIN_FIELD")
		if typeof(payload.get("version")) != TYPE_INT or int(payload["version"]) != schema:
			return _reject("DOMAIN_VERSION_MISMATCH")
		for required_key in REQUIRED_FIELDS[domain_id]:
			if not payload.has(required_key):
				return _reject("MISSING_DOMAIN_FIELD")
		for required_key in SaveManager.get_save_required_keys(domain_id):
			if not payload.has(required_key):
				return _reject("MISSING_DOMAIN_FIELD")
		if not _validate_domain_fields(domain_id, payload):
			return _reject("INVALID_DOMAIN_FIELDS")

	if not _equipment_inventory_consistent(domains["equipment"], domains["inventory"]):
		return _reject("EQUIPMENT_INVENTORY_MISMATCH")
	if not _local_catalog_compatible(domains["equipment"], domains["inventory"]):
		return _reject("LOCAL_CATALOG_INCOMPATIBLE")

	return {
		"valid": true,
		"reason": "FULL_PERMANENT_SNAPSHOT_VALID",
		"domain_count": DOMAIN_COUNT,
		"draft_snapshot_version": DRAFT_SNAPSHOT_VERSION,
		"upload_allowed": false,
		"restore_allowed": false,
		"server_verified": false,
		"server_freshness_verified": false,
	}


func hash_draft(draft: Dictionary) -> String:
	if not _json_tree_safe(draft, 0):
		return ""
	var canonical: String = _canonical_json(draft)
	if canonical.is_empty():
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(canonical.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()


func _validate_domain_fields(domain_id: String, payload: Dictionary) -> bool:
	match domain_id:
		"progression":
			if not _nonnegative_int(payload.get("spirit_stone")):
				return false
			for key in ["vitality_level", "sword_power_level", "swift_qi_level"]:
				if not _bounded_int(payload.get(key), 10):
					return false
			if payload.has("hero_experience_total") and not _nonnegative_int(payload["hero_experience_total"]):
				return false
			if payload.has("hero_milestones_claimed") and not _int_array(payload["hero_milestones_claimed"], false):
				return false
			return true
		"journey":
			if not _positive_int(payload.get("selected_chapter_id")):
				return false
			if not _positive_int(payload.get("selected_stage_id")):
				return false
			if typeof(payload.get("active_run_chapter_id")) != TYPE_INT or int(payload["active_run_chapter_id"]) != 0:
				return false
			if typeof(payload.get("active_run_stage_id")) != TYPE_INT or int(payload["active_run_stage_id"]) != 0:
				return false
			if not _string_array(payload.get("unlocked_stage_keys"), 2048):
				return false
			if not _string_array(payload.get("cleared_stage_keys"), 2048):
				return false
			return true
		"achievements":
			return (
				_count_map(payload.get("progress"))
				and _string_array(payload.get("unlocked"), 2048)
				and _string_array(payload.get("claimed"), 2048)
			)
		"daily_quests":
			if not (payload.get("date_key") is String) or str(payload["date_key"]).length() > 32:
				return false
			if payload.has("active_quest_ids") and not _string_array(payload["active_quest_ids"], 2048):
				return false
			return (
				_count_map(payload.get("progress"))
				and _string_array(payload.get("completed"), 2048)
				and _string_array(payload.get("claimed"), 2048)
			)
		"inventory":
			return _count_map(payload.get("item_counts"))
		"equipment":
			if not (payload.get("equipped_item_ids") is Dictionary):
				return false
			var slots: Dictionary = payload["equipped_item_ids"]
			if not _has_exact_keys(slots, EQUIPMENT_SLOTS):
				return false
			for slot_id in EQUIPMENT_SLOTS:
				if not (slots[slot_id] is String) or str(slots[slot_id]).length() > 256:
					return false
			if payload.has("ascension_stars"):
				if not (payload["ascension_stars"] is Dictionary):
					return false
				for raw_id in payload["ascension_stars"]:
					if not (raw_id is String) or not _bounded_positive_int(payload["ascension_stars"][raw_id], 5):
						return false
			return true
		"pavilion":
			return _validate_pavilion(payload)
		"idle_cultivation":
			return _validate_idle(payload)
	return false


func _validate_pavilion(payload: Dictionary) -> bool:
	if not (payload.get("meditation_date") is String) or str(payload["meditation_date"]).length() > 32:
		return false
	if not (payload.get("cosmetic_id") is String) or str(payload["cosmetic_id"]).length() > 128:
		return false
	if not _string_array(payload.get("owned_cosmetics"), 2048):
		return false
	var owned: Array = payload["owned_cosmetics"]
	if "plain" not in owned or str(payload["cosmetic_id"]) not in owned:
		return false
	for key in [
		"celestial_jade", "pavilion_seals", "lifetime_pulls",
		"cadence_cycles_completed", "monthly_blessing_expires_unix",
		"monthly_blessing_daily_claims_remaining", "monthly_blessing_purchase_count",
	]:
		if payload.has(key) and not _nonnegative_int(payload[key]):
			return false
	var bounded_fields: Dictionary = {
		"pity_rare_plus": 9,
		"pity_epic_plus": 29,
		"pity_legendary": 49,
		"cadence_active_days": 6,
		"rewarded_ads_claimed_in_cycle": 3,
	}
	for key in bounded_fields:
		if payload.has(key) and not _bounded_int(payload[key], int(bounded_fields[key])):
			return false
	for key in ["starter_seals_claimed", "wish_fate_guaranteed"]:
		if payload.has(key) and typeof(payload[key]) != TYPE_BOOL:
			return false
	for key in ["wish_item_id", "cadence_last_daily_bonus_date", "monthly_blessing_last_claim_date"]:
		if payload.has(key):
			if not (payload[key] is String) or str(payload[key]).length() > 256:
				return false
	var array_limits: Dictionary = {
		"claimed_milestone_ids": 2048,
		"claimed_one_time_product_ids": 1024,
		"processed_grant_ids": 1024,
	}
	for key in array_limits:
		if payload.has(key) and not _string_array(payload[key], int(array_limits[key])):
			return false
	if payload.has("processed_grant_ids"):
		for raw_id in payload["processed_grant_ids"]:
			if str(raw_id).begins_with("iap:"):
				return false
	return true


func _validate_idle(payload: Dictionary) -> bool:
	for key in ["last_claim_unix", "last_observed_unix", "lifetime_claim_seconds", "shard_progress_units"]:
		if not _nonnegative_int(payload.get(key)):
			return false
	if int(payload["last_observed_unix"]) < int(payload["last_claim_unix"]):
		return false
	if payload.has("processed_rewarded_grant_ids") and not _string_array(payload["processed_rewarded_grant_ids"], 32):
		return false
	return true


func _equipment_inventory_consistent(equipment: Dictionary, inventory: Dictionary) -> bool:
	var counts: Dictionary = inventory["item_counts"]
	var slots: Dictionary = equipment["equipped_item_ids"]
	var equipped_once: Dictionary = {}
	for slot_id in EQUIPMENT_SLOTS:
		var item_id: String = str(slots[slot_id])
		if item_id.is_empty():
			continue
		if equipped_once.has(item_id) or not _positive_int(counts.get(item_id)):
			return false
		equipped_once[item_id] = true
	if equipment.has("ascension_stars"):
		for raw_id in equipment["ascension_stars"]:
			if not _positive_int(counts.get(str(raw_id))):
				return false
	return true


func _local_catalog_compatible(equipment: Dictionary, inventory: Dictionary) -> bool:
	for raw_id in inventory["item_counts"]:
		if not InventoryManager.is_known_item(str(raw_id)):
			return false
	var slots: Dictionary = equipment["equipped_item_ids"]
	for slot_id in EQUIPMENT_SLOTS:
		var item_id: String = str(slots[slot_id])
		if item_id.is_empty():
			continue
		if not EquipmentManager.has_item_definition(item_id):
			return false
		if str(EquipmentManager.get_item_data(item_id).get("slot", "")) != str(slot_id):
			return false
	if equipment.has("ascension_stars"):
		for raw_id in equipment["ascension_stars"]:
			if not EquipmentManager.has_item_definition(str(raw_id)):
				return false
	return true


func _has_exact_keys(data: Dictionary, expected: Array) -> bool:
	if data.size() != expected.size():
		return false
	return _allowed_keys_only(data, expected)


func _allowed_keys_only(data: Dictionary, expected: Array) -> bool:
	for raw_key in data.keys():
		if not (raw_key is String) or raw_key not in expected:
			return false
	return true


func _safe_uid(uid: String) -> bool:
	if uid.is_empty() or uid.length() > 128:
		return false
	for character in uid:
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-".contains(character):
			return false
	return true


func _positive_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) > 0 and int(value) <= MAX_SAFE_INTEGER


func _nonnegative_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0 and int(value) <= MAX_SAFE_INTEGER


func _bounded_int(value: Variant, maximum: int) -> bool:
	return _nonnegative_int(value) and int(value) <= maximum


func _bounded_positive_int(value: Variant, maximum: int) -> bool:
	return _positive_int(value) and int(value) <= maximum


func _count_map(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for raw_key in value:
		if not (raw_key is String) or str(raw_key).is_empty() or str(raw_key).length() > 256:
			return false
		if not _nonnegative_int(value[raw_key]):
			return false
	return true


func _string_array(value: Variant, maximum_entries: int) -> bool:
	if not (value is Array) or value.size() > maximum_entries:
		return false
	var seen: Dictionary = {}
	for element in value:
		if not (element is String):
			return false
		var text: String = str(element)
		if text.is_empty() or text.length() > 256 or seen.has(text):
			return false
		seen[text] = true
	return true


func _int_array(value: Variant, require_positive: bool) -> bool:
	if not (value is Array) or value.size() > MAX_CONTAINER_ENTRIES:
		return false
	var seen: Dictionary = {}
	for element in value:
		var valid: bool = _positive_int(element) if require_positive else _nonnegative_int(element)
		if not valid or seen.has(int(element)):
			return false
		seen[int(element)] = true
	return true


func _json_tree_safe(value: Variant, depth: int) -> bool:
	if depth > MAX_NESTING_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL:
			return true
		TYPE_INT:
			return int(value) >= -MAX_SAFE_INTEGER and int(value) <= MAX_SAFE_INTEGER
		TYPE_STRING:
			return str(value).length() <= 4096
		TYPE_ARRAY:
			if value.size() > MAX_CONTAINER_ENTRIES:
				return false
			for entry in value:
				if not _json_tree_safe(entry, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > MAX_CONTAINER_ENTRIES:
				return false
			for raw_key in value:
				if not (raw_key is String):
					return false
				var key: String = str(raw_key)
				if key.is_empty() or key.length() > 256 or key in ["__proto__", "prototype", "constructor"]:
					return false
				if not _json_tree_safe(value[raw_key], depth + 1):
					return false
			return true
		_:
			return false


func _canonical_json(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return JSON.stringify(value)
		TYPE_ARRAY:
			var array_parts: Array[String] = []
			for entry in value:
				array_parts.append(_canonical_json(entry))
			return "[" + ",".join(array_parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort()
			var object_parts: Array[String] = []
			for raw_key in keys:
				var key: String = str(raw_key)
				object_parts.append(JSON.stringify(key) + ":" + _canonical_json(value[raw_key]))
			return "{" + ",".join(object_parts) + "}"
	return ""


func _reject(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"domain_count": 0,
		"draft_snapshot_version": DRAFT_SNAPSHOT_VERSION,
		"upload_allowed": false,
		"restore_allowed": false,
		"server_verified": false,
		"server_freshness_verified": false,
	}
