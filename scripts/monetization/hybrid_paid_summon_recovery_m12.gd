extends RefCounted
## M12 display-only validated envelope for an already COMMITTED paid summon.
## Never writes inventory, grants currency, spends Jade, or mutates saves.
const MAX_JSON_CHARS: int = 20000
const SAFE_MAX: int = 9007199254740991
const RESULTS_KEYS: Array[String] = [
    "item_id", "rarity", "duplicate", "duplicate_shards",
    "hard_legendary_pity", "wish_hit", "wish_fate_activated", "wish_fate_consumed"
]
const ALLOWED_RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]

static func empty(reason: String = "not_connected") -> Dictionary:
    return {
        "status": reason, "request_id": "", "spend_id": "",
        "outcome": {}, "display_only": true, "can_grant": false,
        "can_spend": false, "runtime_cutover": false,
    }

static func _keys_exact(v: Dictionary, expected: Array) -> bool:
    if v.size() != expected.size():
        return false
    for key in expected:
        if not v.has(key):
            return false
    return true

static func _int_exact(value: Variant, minimum: int, maximum: int) -> bool:
    if typeof(value) == TYPE_INT:
        return value >= minimum and value <= maximum
    if typeof(value) == TYPE_FLOAT:
        var n: float = value
        return is_finite(n) and n >= float(minimum) and n <= float(maximum) and floorf(n) == n
    return false

static func _match(value: String, expression: String) -> bool:
    var regex := RegEx.new()
    if regex.compile(expression) != OK:
        return false
    return regex.search(value) != null

static func valid_request_id(value: String) -> bool:
    return _match(value, "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")

static func from_native_result(success: bool, status: String, payload: String, expected_request_id: String) -> Dictionary:
    if not success:
        return empty("unavailable")
    if status != "PAID_SUMMON_RECOVERY_READ_ONLY":
        return empty("invalid_response")
    if not valid_request_id(expected_request_id) or payload.is_empty() or payload.length() > MAX_JSON_CHARS:
        return empty("invalid_response")
    var parsed: Variant = JSON.parse_string(payload)
    if not (parsed is Dictionary):
        return empty("invalid_response")
    var data: Dictionary = parsed
    if not _keys_exact(data, ["recovery_contract_version", "request_id", "state", "spend_id", "outcome"]):
        return empty("invalid_response")
    if not _int_exact(data["recovery_contract_version"], 1, 1):
        return empty("invalid_response")
    if data["request_id"] != expected_request_id.to_lower() or data["state"] != "committed":
        return empty("invalid_response")
    if not (data["spend_id"] is String) or not _match(data["spend_id"], "^spendv1:[0-9a-f]{64}$"):
        return empty("invalid_response")
    if not (data["outcome"] is Dictionary):
        return empty("invalid_response")
    var outcome: Dictionary = data["outcome"]
    if not _keys_exact(outcome, ["outcome_contract_version", "pull_count", "results", "next_pity"]):
        return empty("invalid_response")
    if not _int_exact(outcome["outcome_contract_version"], 1, 1):
        return empty("invalid_response")
    if not _int_exact(outcome["pull_count"], 1, 10):
        return empty("invalid_response")
    var count: int = int(outcome["pull_count"])
    if count != 1 and count != 10:
        return empty("invalid_response")
    if not (outcome["results"] is Array) or outcome["results"].size() != count:
        return empty("invalid_response")
    if not (outcome["next_pity"] is Dictionary):
        return empty("invalid_response")
    var pity: Dictionary = outcome["next_pity"]
    if not _keys_exact(pity, ["rare_plus", "epic_plus", "legendary"]):
        return empty("invalid_response")
    for key in ["rare_plus", "epic_plus", "legendary"]:
        var cap: int = 9 if key == "rare_plus" else (29 if key == "epic_plus" else 49)
        if not _int_exact(pity[key], 0, cap):
            return empty("invalid_response")
    for entry in outcome["results"]:
        if not (entry is Dictionary):
            return empty("invalid_response")
        var result: Dictionary = entry
        if not _keys_exact(result, RESULTS_KEYS):
            return empty("invalid_response")
        if not (result["item_id"] is String) or not _match(result["item_id"], "^[a-z][a-z0-9_]{0,95}$"):
            return empty("invalid_response")
        if not (result["rarity"] is String) or result["rarity"] not in ALLOWED_RARITIES:
            return empty("invalid_response")
        if not _int_exact(result["duplicate_shards"], 0, 75):
            return empty("invalid_response")
        for bool_key in ["duplicate", "hard_legendary_pity", "wish_hit", "wish_fate_activated", "wish_fate_consumed"]:
            if typeof(result[bool_key]) != TYPE_BOOL:
                return empty("invalid_response")
    return {
        "status": "ready", "request_id": data["request_id"], "spend_id": data["spend_id"],
        "outcome": outcome.duplicate(true), "display_only": true,
        "can_grant": false, "can_spend": false, "runtime_cutover": false,
    }
