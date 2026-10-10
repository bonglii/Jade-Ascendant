extends RefCounted
## Read-only mirror of the authenticated server's paid item ownership.
## Never persists, grants, consumes, equips or mutates local inventory.

const MAX_JSON_CHARS: int = 16384
const MAX_SAFE: int = 9007199254740991
const MAX_SHARDS: int = 1000000000

static func empty(status: String = "not_connected") -> Dictionary:
	return {
		"status": status, "revision": -1, "item_ids": [], "refinement_shards": -1,
		"authority": "server_read_only", "display_only": true,
		"can_grant": false, "can_spend": false, "runtime_cutover": false
	}

static func _exact(d: Dictionary, fields: Array) -> bool:
	if d.size() != fields.size():
		return false
	for field: String in fields:
		if not d.has(field):
			return false
	return true

static func _whole(x: Variant, low: int, high: int) -> bool:
	if typeof(x) == TYPE_INT:
		return x >= low and x <= high
	if typeof(x) == TYPE_FLOAT:
		var v: float = x
		return is_finite(v) and v >= float(low) and v <= float(high) and floorf(v) == v
	return false

static func from_native_result(success: bool, native_status: String, payload: String) -> Dictionary:
	if not success:
		return empty("unavailable")
	if native_status != "PAID_ENTITLEMENTS_READ_ONLY" or payload.is_empty() or payload.length() > MAX_JSON_CHARS:
		return empty("invalid_response")
	var decoded: Variant = JSON.parse_string(payload)
	if not (decoded is Dictionary):
		return empty("invalid_response")
	var d: Dictionary = decoded
	if not _exact(d, ["paid_entitlements_contract_version", "state", "revision", "item_ids", "refinement_shards", "authority"]):
		return empty("invalid_response")
	if not _whole(d["paid_entitlements_contract_version"], 1, 1) or d["state"] != "verified" or d["authority"] != "server_read_only":
		return empty("invalid_response")
	if not _whole(d["revision"], 0, MAX_SAFE - 1) or not _whole(d["refinement_shards"], 0, MAX_SHARDS):
		return empty("invalid_response")
	if not (d["item_ids"] is Array):
		return empty("invalid_response")
	var items: Array = d["item_ids"]
	if items.size() > 300:
		return empty("invalid_response")
	var regex := RegEx.new()
	if regex.compile("^[a-z][a-z0-9_]{0,95}$") != OK:
		return empty("invalid_response")
	var previous: String = ""
	var result_items: Array[String] = []
	for raw_item: Variant in items:
		if not (raw_item is String):
			return empty("invalid_response")
		var item_id: String = raw_item
		if regex.search(item_id) == null or (not previous.is_empty() and item_id <= previous):
			return empty("invalid_response")
		result_items.append(item_id)
		previous = item_id
	return {
		"status": "ready", "revision": int(d["revision"]),
		"item_ids": result_items, "refinement_shards": int(d["refinement_shards"]),
		"authority": "server_read_only", "display_only": true,
		"can_grant": false, "can_spend": false, "runtime_cutover": false
	}
