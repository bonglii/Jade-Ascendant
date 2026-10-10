extends RefCounted
## M9 read-only snapshot model. It cannot authorize a spend, credit local Jade,
## migrate old save balances, or persist server data to the device.
## Only the verified M8 native signal should feed this parser in production.
const MAX_SAFE_INTEGER: int = 9007199254740991
const MAX_SNAPSHOT_JSON_CHARS: int = 2048

static func empty(status: String = "not_connected") -> Dictionary:
	return {
		"status": status,
		"balance": -1,
		"revision": -1,
		"is_fresh": false,
		"authority": "server_only",
		"display_only": true,
		"can_grant": false,
		"can_spend": false,
		"runtime_cutover": false,
	}


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true


## Godot JSON.parse_string may decode JSON integers as floats. Accept only
## exact, finite whole numbers within JS-safe range; never round/truncate.
static func _safe_whole_number(value: Variant, minimum: int) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= minimum and int(value) <= MAX_SAFE_INTEGER
	if typeof(value) == TYPE_FLOAT:
		var n: float = float(value)
		return is_finite(n) and n >= float(minimum) and n <= float(MAX_SAFE_INTEGER) and floorf(n) == n
	return false


static func from_native_result(success: bool, status: String, payload: String) -> Dictionary:
	if not success:
		return empty("unavailable")
	if status != "WALLET_SNAPSHOT_READ_ONLY":
		return empty("invalid_response")
	if payload.is_empty() or payload.length() > MAX_SNAPSHOT_JSON_CHARS:
		return empty("invalid_response")
	var decoded: Variant = JSON.parse_string(payload)
	if not (decoded is Dictionary):
		return empty("invalid_response")
	var outer: Dictionary = decoded
	var outer_keys: Array[String] = [
		"hybrid_policy_version", "paid_wallet",
		"local_wallet_authority", "legacy_wallet_migration",
	]
	if not _has_exact_keys(outer, outer_keys):
		return empty("invalid_response")
	if not _safe_whole_number(outer["hybrid_policy_version"], 1) or int(outer["hybrid_policy_version"]) != 1:
		return empty("invalid_response")
	if outer["local_wallet_authority"] != "device_only_untrusted":
		return empty("invalid_response")
	if outer["legacy_wallet_migration"] != "requires_explicit_reconciliation":
		return empty("invalid_response")
	if not (outer["paid_wallet"] is Dictionary):
		return empty("invalid_response")
	var paid: Dictionary = outer["paid_wallet"]
	if not _has_exact_keys(paid, ["currency", "authority", "balance", "revision"]):
		return empty("invalid_response")
	if paid["currency"] != "celestial_jade" or paid["authority"] != "server":
		return empty("invalid_response")
	if not _safe_whole_number(paid["balance"], 0) or not _safe_whole_number(paid["revision"], 0):
		return empty("invalid_response")
	var balance: int = int(paid["balance"])
	var revision: int = int(paid["revision"])
	if balance < 0 or balance > MAX_SAFE_INTEGER or revision < 0 or revision > MAX_SAFE_INTEGER:
		return empty("invalid_response")
	return {
		"status": "ready",
		"balance": balance,
		"revision": revision,
		"is_fresh": true,
		"authority": "server_only",
		"display_only": true,
		"can_grant": false,
		"can_spend": false,
		"runtime_cutover": false,
	}
