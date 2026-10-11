extends RefCounted
## RC3 read-only projection of signed server-held trusted progression.
## Never writes progression.save, grants an unlock, or enables paid summon.
const MAX_JSON_CHARS: int = 2048
const MAX_SAFE: int = 9007199254740990

static func empty(status: String = "not_connected") -> Dictionary:
	return {"status": status, "canonical_revision": -1, "cleared_stage_keys": [],
		"server_unlock_preview": false, "display_only": true,
		"runtime_cutover": false, "can_provision": false, "can_spend": false}

static func _whole(value: Variant, lo: int, hi: int) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= lo and value <= hi
	if typeof(value) == TYPE_FLOAT:
		var n: float = value
		return is_finite(n) and n >= float(lo) and n <= float(hi) and floorf(n) == n
	return false

static func from_native_result(success: bool, native_status: String, payload: String) -> Dictionary:
	if not success:
		return empty("unavailable")
	if native_status != "TRUSTED_PROGRESSION_READ_ONLY" or payload.is_empty() or payload.length() > MAX_JSON_CHARS:
		return empty("invalid_response")
	var decoded: Variant = JSON.parse_string(payload)
	if not decoded is Dictionary:
		return empty("invalid_response")
	var value: Dictionary = decoded
	if value.size() != 7:
		return empty("invalid_response")
	for k: String in ["trusted_progression_contract_version", "state", "canonical_revision", "cleared_stage_keys", "paid_summon_unlocked", "authority", "display_only"]:
		if not value.has(k):
			return empty("invalid_response")
	if not _whole(value["trusted_progression_contract_version"], 1, 1) or value["state"] != "verified":
		return empty("invalid_response")
	if value["authority"] != "server_verified_only" or value["display_only"] != true:
		return empty("invalid_response")
	if not _whole(value["canonical_revision"], 0, MAX_SAFE):
		return empty("invalid_response")
	if value["paid_summon_unlocked"] != true or not value["cleared_stage_keys"] is Array:
		return empty("invalid_response")
	var stages: Array = value["cleared_stage_keys"]
	if stages.size() < 1 or stages.size() > 15:
		return empty("invalid_response")
	var rx := RegEx.new()
	if rx.compile("^[1-3]-[1-5]$") != OK:
		return empty("invalid_response")
	var normalized: Array[String] = []
	var previous: String = ""
	for raw: Variant in stages:
		if not raw is String:
			return empty("invalid_response")
		var key: String = raw
		if rx.search(key) == null or (not previous.is_empty() and key <= previous):
			return empty("invalid_response")
		normalized.append(key)
		previous = key
	if not normalized.has("1-5"):
		return empty("invalid_response")
	return {"status": "ready", "canonical_revision": int(value["canonical_revision"]),
		"cleared_stage_keys": normalized, "server_unlock_preview": true,
		"display_only": true, "runtime_cutover": false,
		"can_provision": false, "can_spend": false}
