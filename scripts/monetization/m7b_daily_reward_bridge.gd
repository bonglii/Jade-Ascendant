extends Node

## M7B: persistent owner-side route for TWO opted-in rewarded placements.
## AdMob SDK earned callback is a CLIENT confirmation, NOT signed server SSV.
## DailyQuestManager owns claim flags; RewardManager commits payout + flags in
## ONE save batch. Never grant from UI or from ad-dismissal alone.

const REWARDS: Dictionary = {
	"daily_completion_cache": {"stones": 50, "shards": 0},
	"refinement_supply": {"stones": 0, "shards": 2},
}
const NON_REVIVE_DAILY_TARGET: int = 5

var _pending_placement: String = ""
var _pending_day: String = ""
var _pending_grant_id: String = ""


func _ready() -> void:
	if not MonetizationManager.verified_rewarded_completed.is_connected(_on_sdk_reward):
		MonetizationManager.verified_rewarded_completed.connect(_on_sdk_reward)
	if not MonetizationManager.rewarded_request_finished.is_connected(_on_ad_finished):
		MonetizationManager.rewarded_request_finished.connect(_on_ad_finished)


func get_offer_status(placement: String) -> Dictionary:
	if not REWARDS.has(placement):
		return {"available": false, "reason": "UNAVAILABLE"}
	DailyQuestManager.refresh_daily_date()
	if SaveManager.is_progress_read_only():
		return {"available": false, "reason": "SAVE LOCKED"}
	if DailyQuestManager.m7b_claimed_placement_ids.has(placement):
		return {"available": false, "reason": "CLAIMED TODAY"}
	if placement == "daily_completion_cache":
		var active_ids: Array[String] = DailyQuestManager.get_daily_quest_ids()
		if active_ids.is_empty():
			return {"available": false, "reason": "QUESTS LOCKED"}
		for quest_id: String in active_ids:
			if not DailyQuestManager.is_claimed(quest_id):
				return {"available": false, "reason": "CLAIM DAILY QUESTS"}
	elif placement == "refinement_supply":
		if not JourneyManager.is_stage_cleared(1, 3):
			return {"available": false, "reason": "CLEAR 1-3 FIRST"}
		if not InventoryManager.is_known_item(InventoryManager.REFINEMENT_SHARD):
			return {"available": false, "reason": "ITEM UNAVAILABLE"}
	if not _pending_placement.is_empty():
		return {"available": false, "reason": "AD PENDING"}
	# Existing call sites are historically locked. Enforce the proposed global
	# five-per-day cap at THESE NEW entry points; do not claim it is global yet.
	var successful_non_revive: int = 0
	for key: Variant in MonetizationManager.placement_counts.keys():
		if str(key) == "game_over_revive":
			continue
		successful_non_revive += maxi(int(MonetizationManager.placement_counts[key]), 0)
	if successful_non_revive >= NON_REVIVE_DAILY_TARGET:
		return {"available": false, "reason": "DAILY AD LIMIT"}
	var policy: Dictionary = MonetizationManager.get_rewarded_policy_status(placement)
	if int(policy.get("placement_claims", 0)) > 0:
		return {"available": false, "reason": "CLAIMED TODAY"}
	if int(policy.get("cooldown_remaining_seconds", 0)) > 0:
		return {
			"available": false,
			"reason": "WAIT %ds" % int(policy.get("cooldown_remaining_seconds", 0))
		}
	if not bool(policy.get("available", false)):
		return {"available": false, "reason": "AD PREPARING"}
	return {"available": true, "reason": "READY"}


func request_rewarded(placement: String) -> bool:
	if not REWARDS.has(placement) or not _pending_placement.is_empty():
		return false
	if not bool(get_offer_status(placement).get("available", false)):
		return false
	var snapshot_day: String = DailyQuestManager.active_date_key
	if not MonetizationManager.show_rewarded(placement):
		return false
	_pending_placement = placement
	_pending_day = snapshot_day
	_pending_grant_id = str(MonetizationManager.active_grant_id)
	if _pending_grant_id.is_empty():
		_clear_pending()
		return false
	return true


func _on_sdk_reward(placement: String, grant_id: String) -> void:
	if not REWARDS.has(placement):
		return
	var valid_pending: bool = (
		placement == _pending_placement
		and grant_id == _pending_grant_id
		and not grant_id.is_empty()
	)
	if not valid_pending:
		MonetizationManager.publish_reward_delivery_result(
			placement, false, 0, "Reward request no longer matches."
		)
		return
	# Check the local policy COMMIT, not just a transient in-memory callback.
	# This can fail closed when local storage is unavailable.
	var durable: Dictionary = MonetizationManager.policy_store.call("load_state")
	var persisted_counts: Dictionary = durable.get("placement_counts", {})
	var policy_is_durable: bool = (
		int(persisted_counts.get(placement, 0))
		== int(MonetizationManager.placement_counts.get(placement, 0))
		and int(durable.get("last_reward_unix", -1))
		== int(MonetizationManager.last_reward_unix)
	)
	var result: Dictionary = {"success": false, "error": "Ad policy save did not persist."}
	if policy_is_durable:
		result = DailyQuestManager.m7b_commit_sdk_reward(
			placement, _pending_day, grant_id
		)
	var succeeded: bool = bool(result.get("success", false))
	var amount: int = 0
	if succeeded:
		var reward: Dictionary = REWARDS[placement]
		amount = int(reward.get("stones", 0)) + int(reward.get("shards", 0))
	var message: String = (
		"+50 Spirit Stones" if placement == "daily_completion_cache" else "+2 Refinement Shards"
	) if succeeded else str(result.get("error", "Reward save failed."))
	MonetizationManager.publish_reward_delivery_result(
		placement, succeeded, amount, message
	)
	DailyQuestManager.m7b_offer_finished.emit(placement, succeeded, message)
	_clear_pending()


func _on_ad_finished(placement: String, status: String) -> void:
	if placement != _pending_placement:
		return
	if status != "completed":
		DailyQuestManager.m7b_offer_finished.emit(
			placement, false, "No reward granted: " + status
		)
	elif not _pending_placement.is_empty():
		DailyQuestManager.m7b_offer_finished.emit(
			placement, false, "Reward confirmation unavailable."
		)
	_clear_pending()


func _clear_pending() -> void:
	_pending_placement = ""
	_pending_day = ""
	_pending_grant_id = ""
