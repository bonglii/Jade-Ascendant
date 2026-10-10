extends SceneTree
const Recovery = preload("res://scripts/monetization/hybrid_paid_summon_recovery_m12.gd")
const ID = "9cc242ed-56cc-46bc-8f8d-fb2b83388d7a"
const SPEND = "spendv1:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
var checks: int = 0
var errors: int = 0

func _initialize() -> void:
    call_deferred("_go")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        errors += 1
        printerr("M12_FAILED=" + label)

func valid_data() -> Dictionary:
    return {"recovery_contract_version":1,"request_id":ID,"state":"committed","spend_id":SPEND,
        "outcome":{"outcome_contract_version":1,"pull_count":1,
            "results":[{"item_id":"mistveil_jian","rarity":"rare","duplicate":false,"duplicate_shards":0,
                "hard_legendary_pity":false,"wish_hit":false,"wish_fate_activated":false,"wish_fate_consumed":false}],
            "next_pity":{"rare_plus":0,"epic_plus":1,"legendary":1}}}

func parse(d: Dictionary, id: String = ID) -> Dictionary:
    return Recovery.from_native_result(true, "PAID_SUMMON_RECOVERY_READ_ONLY", JSON.stringify(d), id)

func _go() -> void:
    var d: Dictionary = valid_data()
    var good: Dictionary = parse(d)
    check(good["status"] == "ready", "valid")
    check(not good["can_grant"] and not good["can_spend"], "display_only")
    check(not good["runtime_cutover"], "no_cutover")
    check(Recovery.empty()["status"] == "not_connected", "empty")
    check(Recovery.valid_request_id(ID), "uuid4")
    check(not Recovery.valid_request_id("../bad"), "reject_invalid_uuid")
    check(Recovery.from_native_result(false,"ERR", "", ID)["status"] == "unavailable", "network_failure")
    check(Recovery.from_native_result(true,"WRONG",JSON.stringify(d),ID)["status"] == "invalid_response", "status_check")
    var bad: Dictionary = d.duplicate(true)
    bad["request_id"] = "362ef4da-bc86-43e6-86dc-dad77241cbde"
    check(parse(bad)["status"] == "invalid_response", "other_operation")
    bad = d.duplicate(true)
    bad["unexpected"] = 10
    check(parse(bad)["status"] == "invalid_response", "extra_root")
    bad = d.duplicate(true)
    bad["outcome"]["pull_count"] = 10
    check(parse(bad)["status"] == "invalid_response", "count_mismatch")
    bad = d.duplicate(true)
    bad["outcome"]["results"][0]["item_id"] = "../fake"
    check(parse(bad)["status"] == "invalid_response", "unsafe_item")
    bad = d.duplicate(true)
    bad["outcome"]["results"][0]["duplicate"] = "false"
    check(parse(bad)["status"] == "invalid_response", "bool_string")
    bad = d.duplicate(true)
    bad["outcome"]["next_pity"]["legendary"] = 100
    check(parse(bad)["status"] == "invalid_response", "invalid_pity")
    bad = d.duplicate(true)
    bad["outcome"]["results"][0]["extra"] = 20
    check(parse(bad)["status"] == "invalid_response", "extra_result")
    check(Recovery.from_native_result(true,"PAID_SUMMON_RECOVERY_READ_ONLY","hello",ID)["status"] == "invalid_response", "malformed_json")
    check(parse(d,"362ef4da-bc86-43e6-86dc-dad77241cbde")["status"] == "invalid_response", "request_binding")
    check(good["outcome"]["results"].size() == 1, "recovered_payload")
    check(not good.has("owner_uid"), "no_uid")
    check(not good.has("celestial_jade"), "no_forged_money")
    if errors == 0:
        print("M12_GODOT_ISOLATED_SMOKE=PASS_" + str(checks))
        quit(0)
    else:
        printerr("M12_GODOT_ISOLATED_SMOKE=FAIL_" + str(errors))
        quit(1)
