extends SceneTree
const Bridge = preload("res://scripts/monetization/hybrid_wallet_game_bridge_m7.gd")
var assertions: int = 0

func verify(ok: bool, label: String) -> bool:
    if not ok:
        push_error("GODOT_M7_FAIL=" + label)
        quit(1)
        return false
    assertions += 1
    return true

func _initialize() -> void:
    var grants: Array = ["iapv1:historic"]
    var before: String = JSON.stringify(grants)
    var status: Dictionary = Bridge.status_from_local(1200, grants, true)
    if not verify(status.get("legacy_unclassified_jade") == 1200, "legacy_amount"): return
    if not verify(status.get("needs_reconciliation") == true, "reconciliation_required"): return
    if not verify(status.get("local_iap_grant_ids_count") == 1, "grant_count"): return
    if not verify(status.get("paid_balance_authority") == "server_only", "paid_server_authority"): return
    if not verify(status.get("paid_balance_status") == "not_connected", "no_fake_paid_sync"): return
    if not verify(status.get("auto_paid_credit") == 0, "no_auto_credit"): return
    if not verify(status.get("runtime_cutover") == false, "cutover_locked"): return
    if not verify(status.get("purchase_locked") == true, "iap_locked"): return
    if not verify(JSON.stringify(grants) == before, "grants_not_mutated"): return
    var empty: Dictionary = Bridge.status_from_local(0, [], true)
    if not verify(empty.get("needs_reconciliation") == false, "empty_legacy"): return
    var bad: Dictionary = Bridge.status_from_local(-1, [], true)
    if not verify(bad.get("error") == "invalid_legacy_save", "reject_negative"): return
    var preview: Dictionary = Bridge.preview_summon(1200, 10, "auto")
    if not verify(preview.get("source") == "legacy", "legacy_preview"): return
    if not verify(preview.get("local_debit") == -900, "preview_not_charge"): return
    if not verify(preview.get("preview_only") == true, "preview_marker"): return
    if not verify(preview.get("execution_allowed") == false, "no_execution"): return
    if not verify(preview.get("local_committed") == false, "no_local_commit"): return
    if not verify(preview.get("server_committed") == false, "no_server_commit"): return
    var low: Dictionary = Bridge.preview_summon(500, 10, "auto")
    if not verify(low.get("source") == "none", "insufficient_legacy"): return
    if not verify(Bridge.preview_summon(100, 1, "paid").get("error") == "paid_wallet_not_connected", "paid_fail_closed"): return
    if not verify(Bridge.preview_summon(100, 1, "earned").get("error") == "earned_lane_not_wired", "earned_fail_closed"): return
    if not verify(Bridge.preview_summon(100, 1, "gift").get("error") == "invalid_source", "invalid_source"): return
    if not verify(Bridge.preview_summon(100, 4, "auto").get("error") == "invalid_pull_count", "invalid_pulls"): return
    if not verify(Bridge.preview_summon(-1, 1, "auto").get("error") == "invalid_local_balance", "invalid_balance"): return
    print("GODOT_M7_BRIDGE_SMOKE=PASS_" + str(assertions))
    quit(0)
