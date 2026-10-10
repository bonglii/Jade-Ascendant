extends SceneTree
const Receipt = preload("res://scripts/monetization/hybrid_paid_purchase_receipt_m14.gd")
var checks: int = 0
var errors: int = 0
func check(ok: bool, reason: String) -> void:
    checks += 1
    if not ok:
        errors += 1
        printerr("M14_FAILURE=" + reason)
func valid() -> Dictionary:
    return {"purchase_receipt_version":1,"state":"server_wallet_credited", "wallet":{"wallet_contract_version":1,"balance":550,"revision":2}}
func parse(v: Dictionary) -> Dictionary:
    return Receipt.from_native_result(true,"PAID_WALLET_SERVER_CREDITED",JSON.stringify(v))
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var a := parse(valid())
    check(a.get("status") == "credited", "valid")
    check(a.get("balance") == 550 and a.get("revision") == 2, "numbers")
    check(a.get("can_grant") == false and a.get("can_spend") == false, "no_local_authority")
    check(a.get("runtime_cutover") == false and a.get("display_only") == true, "read_only")
    check(not a.has("celestial_jade") and not a.has("grant_id"), "no_client_grant")
    check(Receipt.empty().get("balance") == -1, "empty")
    check(Receipt.from_native_result(false,"ERR","{}").get("status") == "unavailable", "failure")
    check(Receipt.from_native_result(true,"BAD",JSON.stringify(valid())).get("status") == "invalid_response", "status")
    var b := valid()
    b["grant_id"] = "bad"
    check(parse(b).get("status") == "invalid_response", "extra_root")
    b = valid()
    b["wallet"]["celestial_jade"] = 500
    check(parse(b).get("status") == "invalid_response", "extra_wallet")
    b = valid()
    b["wallet"]["balance"] = -1
    check(parse(b).get("status") == "invalid_response", "negative")
    b = valid()
    b["wallet"]["revision"] = 0
    check(parse(b).get("status") == "invalid_response", "revision")
    b = valid()
    b["wallet"]["balance"] = "550"
    check(parse(b).get("status") == "invalid_response", "string_number")
    b = valid()
    b["state"] = "grant_ready"
    check(parse(b).get("status") == "invalid_response", "wrong_state")
    b = valid()
    b["purchase_receipt_version"] = 2
    check(parse(b).get("status") == "invalid_response", "wrong_contract")
    b = valid()
    b["wallet"]["balance"] = 1.5
    check(parse(b).get("status") == "invalid_response", "decimal")
    check(Receipt.from_native_result(true,"PAID_WALLET_SERVER_CREDITED","no-json").get("status") == "invalid_response", "bad_json")
    if errors == 0:
        print("M14_GODOT_ISOLATED_SMOKE=PASS_" + str(checks))
        quit(0)
    else:
        printerr("M14_GODOT_ISOLATED_SMOKE=FAIL_" + str(errors))
        quit(1)
