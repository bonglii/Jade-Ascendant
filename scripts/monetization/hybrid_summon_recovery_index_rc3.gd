extends RefCounted
## RC3: account-bound recovery index preview; READ ONLY.
## request_ids must be fetched as committed receipts, never re-spent locally.
const MAX_JSON_CHARS: int = 4096
const MAX_CURSOR: int = 999999999999999

static func empty(status: String = "not_connected") -> Dictionary:
	return {"status": status, "request_ids": [], "next_before": -1,
		"display_only": true, "can_spend": false, "can_grant": false,
		"runtime_cutover": false}

static func _whole(value: Variant, min_value: int, max_value: int) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= min_value and value <= max_value
	if typeof(value) == TYPE_FLOAT:
		var n: float = value
		return is_finite(n) and n >= float(min_value) and n <= float(max_value) and floorf(n) == n
	return false

static func from_native_result(success: bool, native_status: String, payload: String) -> Dictionary:
	if not success:
		return empty("unavailable")
	if native_status != "SUMMON_RECOVERY_INDEX_READ_ONLY" or payload.is_empty() or payload.length() > MAX_JSON_CHARS:
		return empty("invalid_response")
	var decoded: Variant = JSON.parse_string(payload)
	if not decoded is Dictionary:
		return empty("invalid_response")
	var value: Dictionary = decoded
	if value.size() != 6:
		return empty("invalid_response")
	for k: String in ["recovery_index_contract_version", "state", "request_ids", "next_before", "coverage", "authority"]:
		if not value.has(k):
			return empty("invalid_response")
	if not _whole(value["recovery_index_contract_version"], 1, 1) or value["state"] != "read_only":
		return empty("invalid_response")
	if value["coverage"] != "indexed_commits_only" or value["authority"] != "server_only":
		return empty("invalid_response")
	if not value["request_ids"] is Array:
		return empty("invalid_response")
	var raw_ids: Array = value["request_ids"]
	if raw_ids.size() > 20:
		return empty("invalid_response")
	var cursor: Variant = value["next_before"]
	if cursor != null and not _whole(cursor, 1, MAX_CURSOR):
		return empty("invalid_response")
	if cursor != null and raw_ids.size() != 20:
		return empty("invalid_response")
	var rx := RegEx.new()
	if rx.compile("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$") != OK:
		return empty("invalid_response")
	var ids: Array[String] = []
	for raw: Variant in raw_ids:
		if not raw is String:
			return empty("invalid_response")
		var item: String = raw
		if rx.search(item) == null or ids.has(item):
			return empty("invalid_response")
		ids.append(item)
	return {"status": "ready", "request_ids": ids, "next_before": int(cursor) if cursor != null else -1,
		"display_only": true, "can_spend": false, "can_grant": false,
		"runtime_cutover": false}
