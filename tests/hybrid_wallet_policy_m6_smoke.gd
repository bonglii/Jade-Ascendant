extends SceneTree

const Policy = preload("res://scripts/monetization/hybrid_wallet_policy.gd")
var checks: int = 0

func _check(condition: bool, label: String) -> bool:
    if not condition:
        push_error("M6_GODOT_FAIL=" + label)
        quit(1)
        return false
    checks += 1
    return true

func _initialize() -> void:
    var old: Dictionary = {"celestial_jade": 1200, "processed_iap_grant_ids": ["iapv1:test"]}
    var original: String = JSON.stringify(old)
    var p: Dictionary = Policy.classify_legacy_save(old)
    if not _check(p.get("legacy_unclassified_jade") == 1200, "preserve_legacy"): return
    if not _check(p.get("auto_paid_credit") == 0, "no_legacy_to_paid"): return
    if not _check(p.get("needs_reconciliation") == true, "reconcile_flag"): return
    if not _check(JSON.stringify(old) == original, "input_not_changed"): return
    var a: Dictionary = Policy.plan_summon("earned", 1, 100, 0, false)
    if not _check(a.get("local_debit") == -100, "earned_preview"): return
    var b: Dictionary = Policy.plan_summon("paid", 10, 0, 0, true)
    if not _check(b.get("requires_server_authorization") == true, "paid_server"): return
    if not _check(b.get("local_debit") == 0, "paid_no_local_debit"): return
    var c: Dictionary = Policy.plan_summon("auto", 10, 500, 500, false)
    if not _check(c.get("source") == "none", "no_mixed_spend"): return
    var d: Dictionary = Policy.plan_summon("paid", 1, 0, 0, false)
    if not _check(d.get("operation") == "paid_requires_network", "offline_paid_lock"): return
    var e: Dictionary = Policy.plan_summon("auto", 1, 200, 300, true)
    if not _check(e.get("source") == "earned", "free_first"): return
    var f: Dictionary = Policy.plan_summon("auto", 1, 0, 300, true)
    if not _check(f.get("source") == "legacy", "legacy_second"): return
    var g: Dictionary = Policy.plan_summon("auto", 1, 0, 0, true)
    if not _check(g.get("source") == "paid", "paid_fallback"): return
    print("GODOT_M6_HYBRID_SMOKE=PASS_" + str(checks))
    quit(0)
