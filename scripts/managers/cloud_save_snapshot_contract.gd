extends RefCounted

## Cloud Save Gate 1 — STRUCTURAL SNAPSHOT CONTRACT ONLY.
## No disk I/O, Firebase I/O, server trust, cloud upload or save restoration.
## This validates proposed in-memory data, not ownership of earned rewards.
## Never feed this result directly to SaveManager.write_save_batch().

const ManifestInspectorScript = preload(
	"res://scripts/managers/cloud_save_manifest_inspector.gd"
)
const SNAPSHOT_FORMAT_VERSION: int = 1
const MAX_SNAPSHOT_BYTES: int = 262144
const MAX_NESTING_DEPTH: int = 10
const MAX_CONTAINER_ENTRIES: int = 512
const MAX_SAFE_INTEGER: int = 9007199254740991

# Keep exactly aligned with the *current* read-only manifest allowlist.
# Pavilion, idle_cultivation and checkpoint MUST NOT enter a draft snapshot.
const DOMAIN_IDS = [
	"achievements", "daily_quests", "equipment", "inventory", "journey", "progression"
]
const SNAPSHOT_KEYS = [
	"snapshot_format_version", "owner_uid", "revision", "saved_at_unix",
	"domain_schema_versions", "domains"
]
const ALLOWED_DOMAIN_FIELDS = {
	"achievements": ["version", "progress", "unlocked", "claimed"],
	"daily_quests": ["version", "date_key", "active_quest_ids", "progress", "completed", "claimed"],
	"equipment": ["version", "equipped_item_ids", "ascension_stars"],
	"inventory": ["version", "item_counts"],
	"journey": ["version", "selected_chapter_id", "selected_stage_id", "active_run_chapter_id", "active_run_stage_id", "unlocked_stage_keys", "cleared_stage_keys"],
	"progression": ["version", "spirit_stone", "vitality_level", "sword_power_level", "swift_qi_level", "hero_experience_total", "hero_milestones_claimed"]
}
const EQUIPMENT_SLOTS = ["armament", "robe", "bracer", "boots", "pendant"]


func get_domain_ids() -> Array[String]:
	var result: Array[String] = []
	for domain_id in DOMAIN_IDS:
		result.append(str(domain_id))
	return result


func inspect_draft(snapshot: Dictionary, expected_uid: String) -> Dictionary:
	# Inspect the shape only. A structurally valid snapshot is NOT approved for
	# upload, restoration, account merge, premium grants or cross-device use.
	var uid_validator: RefCounted = ManifestInspectorScript.new() as RefCounted
	if not bool(uid_validator.call("is_safe_uid", expected_uid)):
		return _reject("invalid_identity")
	if not _has_exact_keys(snapshot, SNAPSHOT_KEYS):
		return _reject("snapshot_shape")
	if typeof(snapshot.get("snapshot_format_version")) != TYPE_INT:
		return _reject("snapshot_version")
	if int(snapshot["snapshot_format_version"]) != SNAPSHOT_FORMAT_VERSION:
		return _reject("snapshot_version")
	if not (snapshot.get("owner_uid") is String):
		return _reject("invalid_identity")
	if str(snapshot["owner_uid"]) != expected_uid:
		return _reject("owner_mismatch")
	if not _positive_int(snapshot.get("revision")):
		return _reject("revision")
	if not _positive_int(snapshot.get("saved_at_unix")):
		return _reject("timestamp")
	if not (snapshot.get("domain_schema_versions") is Dictionary):
		return _reject("domain_versions")
	if not (snapshot.get("domains") is Dictionary):
		return _reject("domain_set")
	var versions: Dictionary = snapshot["domain_schema_versions"]
	var domains: Dictionary = snapshot["domains"]
	if not _has_exact_keys(versions, DOMAIN_IDS):
		return _reject("domain_versions")
	if not _has_exact_keys(domains, DOMAIN_IDS):
		return _reject("domain_set")

	var json_issue: String = _json_structure_issue(snapshot, 0)
	if not json_issue.is_empty():
		return _reject("non_json_data")
	if JSON.stringify(snapshot).to_utf8_buffer().size() > MAX_SNAPSHOT_BYTES:
		return _reject("snapshot_too_large")

	for domain_id in DOMAIN_IDS:
		# The manager registry is the authority for permanent scope, schema,
		# and required keys. Looking up metadata does NOT read user:// files.
		if not SaveManager.has_save_domain(domain_id):
			return _reject("unregistered_domain")
		if SaveManager.get_save_scope(domain_id) != SaveManager.SCOPE_PERMANENT:
			return _reject("unsafe_scope")
		var schema: int = SaveManager.get_save_schema_version(domain_id)
		if typeof(versions[domain_id]) != TYPE_INT or int(versions[domain_id]) != schema:
			return _reject("domain_schema_mismatch")
		if not (domains[domain_id] is Dictionary):
			return _reject("domain_payload")
		var payload: Dictionary = domains[domain_id]
		if not _allowed_keys_only(payload, ALLOWED_DOMAIN_FIELDS[domain_id]):
			return _reject("unexpected_domain_field")
		if typeof(payload.get("version")) != TYPE_INT or int(payload["version"]) != schema:
			return _reject("domain_schema_mismatch")
		for required_key in SaveManager.get_save_required_keys(domain_id):
			if not payload.has(required_key):
				return _reject("missing_domain_field")
		if not _validate_domain_fields(domain_id, payload):
			return _reject("invalid_domain_fields")

	if not _equipment_inventory_consistent(
		domains["equipment"], domains["inventory"]
	):
		return _reject("equipment_inventory_mismatch")

	return {
		"valid": true,
		"reason": "structural_preview_only",
		"domain_count": DOMAIN_IDS.size(),
		"snapshot_format_version": SNAPSHOT_FORMAT_VERSION,
		"upload_allowed": false,
		"restore_allowed": false,
		"server_verified": false,
		"economy_verified": false
	}


func _validate_domain_fields(domain_id: String, payload: Dictionary) -> bool:
	match domain_id:
		"progression":
			if not _nonnegative_int(payload.get("spirit_stone")):
				return false
			for key in ["vitality_level", "sword_power_level", "swift_qi_level"]:
				if not _nonnegative_int(payload.get(key)) or int(payload[key]) > 10:
					return false
			if payload.has("hero_experience_total") and not _nonnegative_int(payload["hero_experience_total"]):
				return false
			if payload.has("hero_milestones_claimed") and not _int_array(payload["hero_milestones_claimed"]):
				return false
		"journey":
			for key in ["selected_chapter_id", "selected_stage_id"]:
				if not _positive_int(payload.get(key)):
					return false
			# Journey.NO_ACTIVE_ID is 0. An active run is local-only.
			for key in ["active_run_chapter_id", "active_run_stage_id"]:
				if typeof(payload.get(key)) != TYPE_INT or int(payload[key]) != 0:
					return false
			if not _string_array(payload.get("unlocked_stage_keys")):
				return false
			if not _string_array(payload.get("cleared_stage_keys")):
				return false
		"achievements":
			return (
				_count_map(payload.get("progress"))
				and _string_array(payload.get("unlocked"))
				and _string_array(payload.get("claimed"))
			)
		"daily_quests":
			if not (payload.get("date_key") is String):
				return false
			if str(payload["date_key"]).length() > 32:
				return false
			if payload.has("active_quest_ids") and not _string_array(payload["active_quest_ids"]):
				return false
			return (
				_count_map(payload.get("progress"))
				and _string_array(payload.get("completed"))
				and _string_array(payload.get("claimed"))
			)
		"inventory":
			if not _count_map(payload.get("item_counts")):
				return false
		"equipment":
			if not (payload.get("equipped_item_ids") is Dictionary):
				return false
			var slots: Dictionary = payload["equipped_item_ids"]
			if not _has_exact_keys(slots, EQUIPMENT_SLOTS):
				return false
			for slot_id in EQUIPMENT_SLOTS:
				if not (slots[slot_id] is String):
					return false
			if payload.has("ascension_stars"):
				if not (payload["ascension_stars"] is Dictionary):
					return false
				var stars: Dictionary = payload["ascension_stars"]
				for raw_id in stars:
					if not (raw_id is String) or not _positive_int(stars[raw_id]):
						return false
					if int(stars[raw_id]) > 5:
						return false
		_:
			return false
	return true


func _equipment_inventory_consistent(equipment: Dictionary, inventory: Dictionary) -> bool:
	var counts: Dictionary = inventory["item_counts"]
	var slots: Dictionary = equipment["equipped_item_ids"]
	var equipped_once: Dictionary = {}
	for raw_id in counts:
		if not InventoryManager.is_known_item(str(raw_id)):
			return false
	for slot_id in EQUIPMENT_SLOTS:
		var item_id: String = str(slots[slot_id])
		if item_id.is_empty():
			continue
		if equipped_once.has(item_id):
			return false
		if not EquipmentManager.has_item_definition(item_id):
			return false
		if str(EquipmentManager.get_item_data(item_id).get("slot", "")) != slot_id:
			return false
		if not _positive_int(counts.get(item_id)):
			return false
		equipped_once[item_id] = true
	if equipment.has("ascension_stars"):
		for raw_id in equipment["ascension_stars"]:
			if not EquipmentManager.has_item_definition(str(raw_id)):
				return false
			if not _positive_int(counts.get(str(raw_id))):
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


func _positive_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value > 0 and value <= MAX_SAFE_INTEGER


func _nonnegative_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= MAX_SAFE_INTEGER


func _count_map(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for raw_key in value:
		if not (raw_key is String) or str(raw_key).is_empty():
			return false
		if not _nonnegative_int(value[raw_key]):
			return false
	return true


func _string_array(value: Variant) -> bool:
	if not (value is Array):
		return false
	var seen: Dictionary = {}
	for element in value:
		if not (element is String) or str(element).is_empty():
			return false
		if seen.has(element):
			return false
		seen[element] = true
	return true


func _int_array(value: Variant) -> bool:
	if not (value is Array):
		return false
	var seen: Dictionary = {}
	for element in value:
		if not _positive_int(element) or seen.has(element):
			return false
		seen[element] = true
	return true


func _json_structure_issue(value: Variant, depth: int) -> String:
	if depth > MAX_NESTING_DEPTH:
		return "nested"
	match typeof(value):
		TYPE_BOOL:
			return ""
		TYPE_INT:
			return "" if value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER else "integer"
		TYPE_FLOAT:
			return "" if is_finite(float(value)) else "float"
		TYPE_STRING:
			return "" if str(value).length() <= 2048 else "string"
		TYPE_ARRAY:
			if value.size() > MAX_CONTAINER_ENTRIES:
				return "array"
			for entry in value:
				if not _json_structure_issue(entry, depth + 1).is_empty():
					return "array_value"
			return ""
		TYPE_DICTIONARY:
			if value.size() > MAX_CONTAINER_ENTRIES:
				return "dictionary"
			for key in value:
				if not (key is String) or str(key).is_empty() or str(key).length() > 128:
					return "key"
				if not _json_structure_issue(value[key], depth + 1).is_empty():
					return "dictionary_value"
			return ""
		_:
			return "variant"


func _reject(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"domain_count": 0,
		"snapshot_format_version": SNAPSHOT_FORMAT_VERSION,
		"upload_allowed": false,
		"restore_allowed": false,
		"server_verified": false,
		"economy_verified": false
	}
