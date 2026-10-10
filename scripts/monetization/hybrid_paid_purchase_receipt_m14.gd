extends RefCounted
## M14 confirmed SERVER wallet receipt. Volatile display ONLY.
## Never add Jade, modify inventory, spend, or persist in pavilion.save.
const MAX_JSON_CHARS: int = 2048
const MAX_SAFE: int = 9007199254740991

static func empty(status: String = "not_connected") -> Dictionary:
    return {"status":status,"balance":-1,"revision":-1,"display_only":true,
        "authority":"server_only","can_grant":false,"can_spend":false,"runtime_cutover":false}

static func _keys(value: Dictionary, keys: Array) -> bool:
    if value.size() != keys.size():
        return false
    for key in keys:
        if not value.has(key):
            return false
    return true

static func _int(value: Variant, lower: int, upper: int) -> bool:
    if typeof(value) == TYPE_INT:
        return value >= lower and value <= upper
    if typeof(value) == TYPE_FLOAT:
        var v: float = value
        return is_finite(v) and v >= float(lower) and v <= float(upper) and floorf(v) == v
    return false

static func from_native_result(success: bool, native_status: String, payload: String) -> Dictionary:
    if not success:
        return empty("unavailable")
    if native_status != "PAID_WALLET_SERVER_CREDITED" or payload.is_empty() or payload.length() > MAX_JSON_CHARS:
        return empty("invalid_response")
    var decoded: Variant = JSON.parse_string(payload)
    if not (decoded is Dictionary):
        return empty("invalid_response")
    var outer: Dictionary = decoded
    if not _keys(outer, ["purchase_receipt_version", "state", "wallet"]):
        return empty("invalid_response")
    if not _int(outer["purchase_receipt_version"],1,1) or outer["state"] != "server_wallet_credited":
        return empty("invalid_response")
    if not (outer["wallet"] is Dictionary):
        return empty("invalid_response")
    var wallet: Dictionary = outer["wallet"]
    if not _keys(wallet, ["wallet_contract_version", "balance", "revision"]):
        return empty("invalid_response")
    if not _int(wallet["wallet_contract_version"],1,1):
        return empty("invalid_response")
    if not _int(wallet["balance"],0,MAX_SAFE) or not _int(wallet["revision"],1,MAX_SAFE):
        return empty("invalid_response")
    return {"status":"credited","balance":int(wallet["balance"]),"revision":int(wallet["revision"]),
        "display_only":true,"authority":"server_only","can_grant":false,"can_spend":false,"runtime_cutover":false}
