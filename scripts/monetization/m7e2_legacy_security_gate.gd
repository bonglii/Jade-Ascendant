extends RefCounted

## M7E2: legacy UI-route cap and durable SDK-callback guard.
## Additive; DOES NOT replace MonetizationManager or AdMob SDK verification.
## No server-side AdMob SSV is present. This guards only in-game routes.
const Catalog = preload("res://scripts/monetization/m7_rewarded_offer_catalog.gd")
const DAILY_NON_REVIVE_CAP: int = 5
const REVIVE_PLACEMENT: String = "game_over_revive"


static func get_policy_status(placement: String) -> Dictionary:
	var policy: Dictionary = MonetizationManager.get_rewarded_policy_status(placement)
	if not Catalog.is_shipping_placement(placement):
		policy["available"] = false
		policy["m7e2_reason"] = "UNKNOWN PLACEMENT"
		return policy
	if SaveManager.is_progress_read_only():
		policy["available"] = false
		policy["m7e2_reason"] = "SAVE LOCKED"
		return policy
	if placement != REVIVE_PLACEMENT and _non_revive_confirmed() >= DAILY_NON_REVIVE_CAP:
		policy["available"] = false
		policy["m7e2_reason"] = "DAILY AD LIMIT"
	return policy


static func can_request(placement: String) -> bool:
	return bool(get_policy_status(placement).get("available", false)) and MonetizationManager.rewarded_available(placement)


static func request(placement: String) -> bool:
	if not can_request(placement):
		return false
	return MonetizationManager.show_rewarded(placement)


static func earned_is_durable(placement: String, grant_id: String) -> bool:
	# A client callback is not an authenticated SSV receipt. We only verify that
	# this exact active request had a durable local policy commit before payout.
	if not Catalog.is_shipping_placement(placement) or grant_id.is_empty():
		return false
	if not MonetizationManager.reward_consumed:
		return false
	if str(MonetizationManager.active_placement) != placement:
		return false
	if str(MonetizationManager.active_grant_id) != grant_id:
		return false
	if SaveManager.is_progress_read_only():
		return false
	var store: Variant = MonetizationManager.policy_store
	if store == null:
		return false
	var persistent: Dictionary = store.call("load_state")
	if int(persistent.get("day_bucket", -1)) != int(MonetizationManager.policy_day_bucket):
		return false
	if int(persistent.get("last_reward_unix", -1)) != int(MonetizationManager.last_reward_unix):
		return false
	var persisted_counts: Dictionary = persistent.get("placement_counts", {})
	if int(persisted_counts.get(placement, 0)) != int(MonetizationManager.placement_counts.get(placement, 0)):
		return false
	return true


static func _non_revive_confirmed() -> int:
	var count: int = 0
	for key: Variant in MonetizationManager.placement_counts.keys():
		if str(key) == REVIVE_PLACEMENT:
			continue
		count += maxi(int(MonetizationManager.placement_counts[key]), 0)
	return count
