extends Node

## M7C2: voluntary +10% EXP for the next NEW Journey run.
## Reward originates exclusively from the SDK earned callback (client-side,
## not server-side AdMob SSV). The durable owner is DailyQuestManager.
## Does not mutate EXP, equipment, paid Jade or the provider.
signal offer_finished(success: bool, message: String)

const PLACEMENT_ID: String = "qi_focus"
const NON_REVIVE_DAILY_CAP_TARGET: int = 5

var _pending_grant_id: String = ""
var _pending_day: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not MonetizationManager.verified_rewarded_completed.is_connected(_on_sdk_reward):
		MonetizationManager.verified_rewarded_completed.connect(_on_sdk_reward)
	if not MonetizationManager.rewarded_request_finished.is_connected(_on_ad_finished):
		MonetizationManager.rewarded_request_finished.connect(_on_ad_finished)


func get_offer_status() -> Dictionary:
	DailyQuestManager.refresh_daily_date()
	if SaveManager.is_progress_read_only():
		return {"available": false, "reason": "SAVE LOCKED"}
	if not JourneyManager.is_stage_cleared(1, 1):
		return {"available": false, "reason": "CLEAR STAGE 1-1"}
	if DailyQuestManager.m7c2_pending_focus:
		return {"available": false, "reason": "READY FOR NEXT RUN"}
	if PLACEMENT_ID in DailyQuestManager.m7b_claimed_placement_ids:
		return {"available": false, "reason": "CLAIMED TODAY"}
	if not _pending_grant_id.is_empty():
		return {"available": false, "reason": "AD IN PROGRESS"}
	var non_revive_claims: int = 0
	for raw_id: Variant in MonetizationManager.placement_counts:
		if str(raw_id) != "game_over_revive":
			non_revive_claims += maxi(int(MonetizationManager.placement_counts[raw_id]), 0)
	if non_revive_claims >= NON_REVIVE_DAILY_CAP_TARGET:
		return {"available": false, "reason": "DAILY AD LIMIT"}
	var policy: Dictionary = MonetizationManager.get_rewarded_policy_status(PLACEMENT_ID)
	if int(policy.get("placement_claims", 0)) > 0:
		return {"available": false, "reason": "CLAIMED TODAY"}
	var wait_seconds: int = int(policy.get("cooldown_remaining_seconds", 0))
	if wait_seconds > 0:
		return {"available": false, "reason": "WAIT %ds" % wait_seconds}
	if not bool(policy.get("available", false)):
		return {"available": false, "reason": "AD PREPARING"}
	return {"available": true, "reason": "READY"}


func request_rewarded() -> bool:
	if not _pending_grant_id.is_empty():
		return false
	if not bool(get_offer_status().get("available", false)):
		return false
	var claim_day: String = DailyQuestManager.active_date_key
	if not MonetizationManager.show_rewarded(PLACEMENT_ID):
		return false
	_pending_grant_id = str(MonetizationManager.active_grant_id)
	_pending_day = claim_day
	return not _pending_grant_id.is_empty()


func _on_sdk_reward(placement: String, grant_id: String) -> void:
	if placement != PLACEMENT_ID:
		return
	if grant_id.is_empty() or grant_id != _pending_grant_id or _pending_day.is_empty():
		_publish(false, "Reward request no longer matches.")
		_clear_pending()
		return
	var durable: Dictionary = MonetizationManager.policy_store.call("load_state")
	var counts: Dictionary = durable.get("placement_counts", {})
	var policy_is_durable: bool = (
		int(counts.get(PLACEMENT_ID, 0))
		== int(MonetizationManager.placement_counts.get(PLACEMENT_ID, 0))
		and int(durable.get("last_reward_unix", -1))
		== int(MonetizationManager.last_reward_unix)
	)
	if not policy_is_durable:
		_publish(false, "Ad policy save did not persist. Restart before retrying.")
		_clear_pending()
		return
	var result: Dictionary = DailyQuestManager.m7c2_commit_sdk_reward(
		_pending_day, grant_id
	)
	var success: bool = bool(result.get("success", false))
	_publish(
		success,
		"QI FOCUS READY • +10% EXP ON NEXT NEW RUN"
		if success else str(result.get("error", "Reward could not be saved."))
	)
	_clear_pending()


func _on_ad_finished(placement: String, status: String) -> void:
	if placement != PLACEMENT_ID or _pending_grant_id.is_empty():
		return
	_publish(false, "No bonus granted: " + status)
	_clear_pending()


func _publish(success: bool, message: String) -> void:
	MonetizationManager.publish_reward_delivery_result(
		PLACEMENT_ID, success, 10 if success else 0, message
	)
	offer_finished.emit(success, message)


func _clear_pending() -> void:
	_pending_grant_id = ""
	_pending_day = ""
