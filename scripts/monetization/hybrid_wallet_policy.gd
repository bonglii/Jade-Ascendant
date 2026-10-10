extends RefCounted
## M6 hybrid policy preview ONLY. Deliberately not wired to PavilionManager.
## Paid currency is NEVER debited here; paid summon requires server authority.
## Historical pavilion.save celestial_jade remains unclassified and unchanged.

const POLICY_VERSION: int = 1
const COST_SINGLE: int = 100
const COST_TEN: int = 900

static func classify_legacy_save(save: Dictionary) -> Dictionary:
    var amount: Variant = save.get("celestial_jade", null)
    var grants: Variant = save.get("processed_iap_grant_ids", [])
    if typeof(amount) != TYPE_INT or int(amount) < 0 or int(amount) > 9007199254740991:
        return {"error": "invalid_legacy_save"}
    if not (grants is Array) or grants.size() > 100000:
        return {"error": "invalid_legacy_grants"}
    for grant_id in grants:
        if not (grant_id is String):
            return {"error": "invalid_legacy_grants"}
    return {
        "hybrid_policy_version": POLICY_VERSION,
        "legacy_unclassified_jade": int(amount),
        "needs_reconciliation": int(amount) > 0 or grants.size() > 0,
        "auto_paid_credit": 0,
        "legacy_balance_mutated": false,
    }

static func _intent(source: String, cost: int, operation: String, local_debit: int = 0) -> Dictionary:
    return {
        "hybrid_policy_version": POLICY_VERSION,
        "source": source,
        "cost": cost,
        "operation": operation,
        "local_debit": local_debit,
        "requires_server_authorization": source == "paid",
    }

static func plan_summon(source: String, pull_count: int, earned_jade: int, legacy_jade: int, online: bool) -> Dictionary:
    if pull_count != 1 and pull_count != 10:
        return {"error": "invalid_pull_count"}
    if earned_jade < 0 or legacy_jade < 0 or earned_jade > 9007199254740991 or legacy_jade > 9007199254740991:
        return {"error": "invalid_local_balance"}
    if source not in ["earned", "legacy", "paid", "auto"]:
        return {"error": "invalid_source"}
    var cost: int = COST_SINGLE if pull_count == 1 else COST_TEN
    var selected: String = source
    if source == "auto":
        if earned_jade >= cost:
            selected = "earned"
        elif legacy_jade >= cost:
            selected = "legacy"
        elif online:
            selected = "paid"
        else:
            selected = "none"
    if selected == "earned":
        if earned_jade >= cost:
            return _intent("earned", cost, "local_only_pending_game_atomic_commit", -cost)
        return _intent("none", cost, "insufficient_earned")
    if selected == "legacy":
        if legacy_jade >= cost:
            return _intent("legacy", cost, "legacy_local_only_pending_game_atomic_commit", -cost)
        return _intent("none", cost, "insufficient_legacy")
    if selected == "paid":
        if online:
            return _intent("paid", cost, "server_authorization_required")
        return _intent("none", cost, "paid_requires_network")
    return _intent("none", cost, "insufficient_single_lane")
