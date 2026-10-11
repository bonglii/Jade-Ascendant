extends RefCounted
## RC2.1 pure read-only paid loadout envelope.
## Server ownership only; NEVER writes user://, equips gameplay stats,
## performs a local grant, or merges paid items into InventoryManager.

const MAX_JSON_CHARS: int = 2048
const MAX_REV: int = 9007199254740990
const SLOTS: Array[String] = ["armament", "robe", "bracer", "boots", "pendant"]
const PER_SLOT: Dictionary = {
	"armament": ["wanderer_jade_jian", "mistveil_jian", "spirit_seal_fan", "cinnabar_moon_saber", "nine_heavens_star_sword", "mountain_ward_jian", "stillwater_mirror_blade", "sunfire_dragon_jian"],
	"robe": ["verdant_qi_robe", "bamboo_weave_robe", "moonthread_robe", "ward_keeper_robe", "sovereign_mantle", "stone_meridian_robe", "glassmoon_robe", "dawn_meridian_robe"],
	"bracer": ["jade_guard_bracer", "jade_edge_bracer", "mirror_edge_bracer", "stormcall_bracer", "tribulation_bracer", "earthseal_bracer", "reflection_bracer", "solar_edict_bracer"],
	"boots": ["cloudstep_boots", "miststride_boots", "shadowstep_boots", "starstep_boots", "cloudtreader_boots", "rootstep_boots", "silent_ripple_boots", "sunstride_boots"],
	"pendant": ["spirit_jade_pendant", "qi_reservoir_pendant", "shrine_seal_pendant", "sword_heart_pendant", "ascendant_heart", "guardian_jade_pendant", "mirror_heart_pendant", "golden_core_pendant"]
}

static func empty(status: String = "not_connected") -> Dictionary:
	return {
		"status": status, "revision": -1, "entitlement_revision": -1,
		"paid_slots": {}, "authority": "server_only", "display_only": true,
		"can_grant": false, "can_spend": false, "can_equip": false,
		"runtime_cutover": false
	}

static func _exact(value: Dictionary, names: Array) -> bool:
	if value.size() != names.size():
		return false
	for name in names:
		if not value.has(name):
			return false
	return true

static func _whole(x: Variant) -> bool:
	if typeof(x) == TYPE_INT:
		return x >= 0 and x <= MAX_REV
	if typeof(x) == TYPE_FLOAT:
		var v: float = x
		return is_finite(v) and v >= 0.0 and v <= float(MAX_REV) and floorf(v) == v
	return false

static func from_native_result(
	success: bool, native_status: String, payload: String,
	fresh_entitlements: Dictionary
) -> Dictionary:
	if not success:
		return empty("unavailable")
	if native_status != "PAID_LOADOUT_READ_ONLY" or payload.is_empty() or payload.length() > MAX_JSON_CHARS:
		return empty("invalid_response")
	# The client must already have freshly authenticated entitlements from the
	# SAME live Firebase session. Account-switch invalidates BOTH snapshots.
	if str(fresh_entitlements.get("status", "")) != "ready" or not _whole(fresh_entitlements.get("revision", null)):
		return empty("entitlements_unavailable")
	if str(fresh_entitlements.get("authority", "")) != "server_read_only":
		return empty("entitlements_unavailable")
	var item_ids: Variant = fresh_entitlements.get("item_ids", null)
	if not (item_ids is Array):
		return empty("entitlements_unavailable")
	var decoded: Variant = JSON.parse_string(payload)
	if not (decoded is Dictionary):
		return empty("invalid_response")
	var d: Dictionary = decoded
	if not _exact(d, ["paid_loadout_contract_version", "state", "revision", "entitlement_revision", "paid_slots", "authority"]):
		return empty("invalid_response")
	if not _whole(d["paid_loadout_contract_version"]) or int(d["paid_loadout_contract_version"]) != 1:
		return empty("invalid_response")
	if d["state"] != "verified" or d["authority"] != "server_only":
		return empty("invalid_response")
	if not _whole(d["revision"]) or not _whole(d["entitlement_revision"]):
		return empty("invalid_response")
	if int(d["entitlement_revision"]) != int(fresh_entitlements["revision"]):
		return empty("stale_entitlements")
	if not (d["paid_slots"] is Dictionary):
		return empty("invalid_response")
	var raw_slots: Dictionary = d["paid_slots"]
	if not _exact(raw_slots, SLOTS):
		return empty("invalid_response")
	var result_slots: Dictionary = {}
	for slot_id in SLOTS:
		var item: Variant = raw_slots[slot_id]
		if not (item is String):
			return empty("invalid_response")
		if not item.is_empty():
			if item not in PER_SLOT[slot_id] or item not in item_ids:
				return empty("invalid_response")
		result_slots[slot_id] = item
	return {
		"status": "ready", "revision": int(d["revision"]),
		"entitlement_revision": int(d["entitlement_revision"]),
		"paid_slots": result_slots, "authority": "server_only", "display_only": true,
		"can_grant": false, "can_spend": false, "can_equip": false,
		"runtime_cutover": false
	}
