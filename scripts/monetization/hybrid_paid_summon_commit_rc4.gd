extends RefCounted
## Validates native committed server paid-summon result. Volatile and display-only.
const MAX_CHARS: int = 16384
const MAX_SAFE: int = 9007199254740990
const RESULT_KEYS: Array = ["item_id", "rarity", "duplicate", "duplicate_shards", "hard_legendary_pity", "wish_hit", "wish_fate_activated", "wish_fate_consumed"]

static func empty(status: String = "not_connected") -> Dictionary:
	return {"status": status, "request_id": "", "outcome": {}, "wallet": {}, "display_only": true, "can_grant": false, "can_spend": false, "runtime_cutover": false}

static func _exact(data: Dictionary, keys: Array) -> bool:
	if data.size() != keys.size():
		return false
	for key: String in keys:
		if not data.has(key):
			return false
	return true

static func _int(value: Variant, min_v: int, max_v: int) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= min_v and value <= max_v
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and floorf(value) == value and value >= float(min_v) and value <= float(max_v)
	return false

static func _pattern(s: String, expression: String) -> bool:
	var re := RegEx.new()
	return re.compile(expression) == OK and re.search(s) != null

static func from_native_result(success: bool, status: String, json: String, expected_request_id: String) -> Dictionary:
	if not success:
		return empty("unavailable")
	if status != "PAID_SUMMON_SERVER_COMMITTED" or json.is_empty() or json.length() > MAX_CHARS:
		return empty("invalid_response")
	var parsed: Variant = JSON.parse_string(json)
	if not (parsed is Dictionary):
		return empty("invalid_response")
	var d: Dictionary = parsed
	if not _exact(d, ["paid_summon_contract_version", "state", "request_id", "spend_id", "outcome", "wallet"]):
		return empty("invalid_response")
	if not _int(d["paid_summon_contract_version"], 1, 1) or d["state"] != "committed":
		return empty("invalid_response")
	if not _pattern(expected_request_id, "^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$"):
		return empty("invalid_response")
	if d["request_id"] != expected_request_id or not (d["spend_id"] is String) or not _pattern(d["spend_id"], "^spendv1:[a-f0-9]{64}$"):
		return empty("invalid_response")
	if not (d["outcome"] is Dictionary) or not (d["wallet"] is Dictionary):
		return empty("invalid_response")
	var o: Dictionary = d["outcome"]
	var w: Dictionary = d["wallet"]
	if not _exact(o, ["outcome_contract_version", "pull_count", "results", "next_pity"]):
		return empty("invalid_response")
	if not _int(o["outcome_contract_version"], 1, 1) or not _int(o["pull_count"], 1, 10):
		return empty("invalid_response")
	if int(o["pull_count"]) not in [1, 10] or not (o["results"] is Array) or o["results"].size() != int(o["pull_count"]):
		return empty("invalid_response")
	if not (o["next_pity"] is Dictionary) or not _exact(o["next_pity"], ["rare_plus", "epic_plus", "legendary"]):
		return empty("invalid_response")
	var pity: Dictionary = o["next_pity"]
	for key: String in ["rare_plus", "epic_plus", "legendary"]:
		var cap: int = 9 if key == "rare_plus" else (29 if key == "epic_plus" else 49)
		if not _int(pity[key], 0, cap):
			return empty("invalid_response")
	for entry: Variant in o["results"]:
		if not (entry is Dictionary):
			return empty("invalid_response")
		var result: Dictionary = entry
		if not _exact(result, RESULT_KEYS):
			return empty("invalid_response")
		if not (result["item_id"] is String) or not _pattern(result["item_id"], "^[a-z][a-z0-9_]{0,95}$"):
			return empty("invalid_response")
		if result["rarity"] not in ["common", "rare", "epic", "legendary"] or not _int(result["duplicate_shards"], 0, 75):
			return empty("invalid_response")
		for key: String in ["duplicate", "hard_legendary_pity", "wish_hit", "wish_fate_activated", "wish_fate_consumed"]:
			if typeof(result[key]) != TYPE_BOOL:
				return empty("invalid_response")
	if not _exact(w, ["wallet_contract_version", "balance", "revision"]):
		return empty("invalid_response")
	if not _int(w["wallet_contract_version"], 1, 1) or not _int(w["balance"], 0, MAX_SAFE) or not _int(w["revision"], 0, MAX_SAFE):
		return empty("invalid_response")
	return {"status": "committed", "request_id": expected_request_id, "outcome": o.duplicate(true), "wallet": w.duplicate(true), "display_only": true, "can_grant": false, "can_spend": false, "runtime_cutover": false}
