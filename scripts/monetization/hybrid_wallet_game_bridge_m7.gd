extends RefCounted
## M7: read-only preview bridge for an offline-first Hybrid wallet.
## Intentionally NOT a transaction gateway. No HTTP, Firebase or save writes.
## Never treat legacy pavilion.save Jade as paid or earned currency.
const Policy = preload("res://scripts/monetization/hybrid_wallet_policy.gd")
const BRIDGE_VERSION: int = 1

static func status_from_local(legacy_jade: int, processed_iap: Array, purchase_locked: bool) -> Dictionary:
    var old: Dictionary = {
        "celestial_jade": legacy_jade,
        "processed_iap_grant_ids": processed_iap.duplicate(true),
    }
    var classification: Dictionary = Policy.classify_legacy_save(old)
    if classification.has("error"):
        return {"error": str(classification["error"]), "runtime_cutover": false}
    return {
        "hybrid_bridge_version": BRIDGE_VERSION,
        "hybrid_policy_version": Policy.POLICY_VERSION,
        "legacy_unclassified_jade": int(classification["legacy_unclassified_jade"]),
        "needs_reconciliation": bool(classification["needs_reconciliation"]),
        "local_iap_grant_ids_count": processed_iap.size(),
        "paid_balance_authority": "server_only",
        "paid_balance_status": "not_connected",
        "auto_paid_credit": 0,
        "runtime_cutover": false,
        "purchase_locked": purchase_locked,
    }

static func _blocked(code: String) -> Dictionary:
    return {
        "error": code,
        "preview_only": true,
        "execution_allowed": false,
        "local_committed": false,
        "server_committed": false,
    }

static func preview_summon(legacy_jade: int, pull_count: int, source: String) -> Dictionary:
    # M7 has no earned lane tracking and no paid wallet transport.
    # Never fall back to a fake local paid balance or merge lanes.
    if source == "paid":
        return _blocked("paid_wallet_not_connected")
    if source == "earned":
        return _blocked("earned_lane_not_wired")
    if source not in ["auto", "legacy"]:
        return _blocked("invalid_source")
    var result: Dictionary = Policy.plan_summon(source, pull_count, 0, legacy_jade, false)
    if result.has("error"):
        return _blocked(str(result["error"]))
    var preview: Dictionary = result.duplicate(true)
    preview["preview_only"] = true
    preview["execution_allowed"] = false
    preview["local_committed"] = false
    preview["server_committed"] = false
    preview["paid_balance_status"] = "not_connected"
    return preview
