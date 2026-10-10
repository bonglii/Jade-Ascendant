extends Node

## M7C1 repeat-stage Victory Encore. Fail-closed presentation bridge.
## Only RewardManager's committed repeat stage reward can arm the offer.
## SDK callback is local, NOT signed server-side AdMob verification (SSV).
## Claim ledger and currency commit atomically in existing daily_quests domain.
signal offer_finished(success: bool, message: String)

const PLACEMENT_ID: String = "victory_encore"
const MAX_BONUS_STONES: int = 100
const NON_REVIVE_DAILY_CAP_TARGET: int = 5
const RECEIPT_HISTORY_LIMIT: int = 64

var _repeat_source_id: String = ""
var _repeat_bonus: int = 0
var _repeat_day: String = ""
var _pending_grant_id: String = ""
var _pending_day: String = ""
var _pending_source_id: String = ""
var _pending_bonus: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not RewardManager.reward_granted.is_connected(_on_reward_granted):
		RewardManager.reward_granted.connect(_on_reward_granted)
	if not MonetizationManager.verified_rewarded_completed.is_connected(_on_sdk_reward):
		MonetizationManager.verified_rewarded_completed.connect(_on_sdk_reward)
	if not MonetizationManager.rewarded_request_finished.is_connected(_on_ad_finished):
		MonetizationManager.rewarded_request_finished.connect(_on_ad_finished)


func _on_reward_granted(source_type: String, source_id: String, reward: Dictionary) -> void:
	if source_type != RewardManager.SOURCE_STAGE_CLEAR:
		return
	if not source_id.begins_with("chapter_") or not source_id.ends_with("_repeat_clear"):
		return
	var parts: PackedStringArray = source_id.split("_")
	if parts.size() != 6 or parts[0] != "chapter" or parts[2] != "stage":
		return
	if not parts[1].is_valid_int() or not parts[3].is_valid_int():
		return
	var chapter: int = int(parts[1])
	var stage: int = int(parts[3])
	if not JourneyManager.has_stage(chapter, stage):
		return
	if not JourneyManager.is_stage_cleared(chapter, stage):
		return
	var catalog_reward: Dictionary = RewardManager.get_stage_clear_reward(chapter, stage, false)
	var stones: int = int(reward.get(RewardManager.REWARD_KEY_SPIRIT_STONE, 0))
	if stones <= 0 or stones != int(catalog_reward.get(RewardManager.REWARD_KEY_SPIRIT_STONE, 0)):
		return
	DailyQuestManager.refresh_daily_date()
	_repeat_bonus = mini(floori(float(stones) * 0.5), MAX_BONUS_STONES)
	_repeat_source_id = source_id if _repeat_bonus > 0 else ""
	_repeat_day = DailyQuestManager.active_date_key


func get_offer_status() -> Dictionary:
	if _repeat_source_id.is_empty() or _repeat_bonus <= 0:
		return {"visible": false, "available": false, "reason": "NOT REPEAT CLEAR", "bonus": 0}
	var ui_layer: CanvasLayer = get_parent() as CanvasLayer
	if ui_layer == null or not ui_layer.visible:
		return {"visible": false, "available": false, "reason": "RESULT HIDDEN", "bonus": 0}
	DailyQuestManager.refresh_daily_date()
	if DailyQuestManager.active_date_key != _repeat_day:
		return {"visible": true, "available": false, "reason": "DAILY CYCLE ENDED", "bonus": _repeat_bonus}
	if SaveManager.is_progress_read_only():
		return {"visible": true, "available": false, "reason": "SAVE LOCKED", "bonus": _repeat_bonus}
	if PLACEMENT_ID in DailyQuestManager.m7b_claimed_placement_ids:
		return {"visible": true, "available": false, "reason": "CLAIMED TODAY", "bonus": _repeat_bonus}
	if not _pending_grant_id.is_empty():
		return {"visible": true, "available": false, "reason": "AD IN PROGRESS", "bonus": _repeat_bonus}
	var non_revive_claims: int = 0
	for raw_placement: Variant in MonetizationManager.placement_counts:
		if str(raw_placement) != "game_over_revive":
			non_revive_claims += maxi(int(MonetizationManager.placement_counts[raw_placement]), 0)
	if non_revive_claims >= NON_REVIVE_DAILY_CAP_TARGET:
		return {"visible": true, "available": false, "reason": "DAILY AD LIMIT", "bonus": _repeat_bonus}
	var policy: Dictionary = MonetizationManager.get_rewarded_policy_status(PLACEMENT_ID)
	if int(policy.get("placement_claims", 0)) >= 1:
		return {"visible": true, "available": false, "reason": "CLAIMED TODAY", "bonus": _repeat_bonus}
	var remaining: int = int(policy.get("cooldown_remaining_seconds", 0))
	if remaining > 0:
		return {"visible": true, "available": false, "reason": "WAIT %ds" % remaining, "bonus": _repeat_bonus}
	if not bool(policy.get("available", false)):
		return {"visible": true, "available": false, "reason": "AD PREPARING", "bonus": _repeat_bonus}
	return {"visible": true, "available": true, "reason": "READY", "bonus": _repeat_bonus}


func request_rewarded() -> bool:
	if not _pending_grant_id.is_empty() or not bool(get_offer_status().get("available", false)):
		return false
	if not MonetizationManager.show_rewarded(PLACEMENT_ID):
		return false
	_pending_grant_id = str(MonetizationManager.active_grant_id)
	_pending_day = _repeat_day
	_pending_source_id = _repeat_source_id
	_pending_bonus = _repeat_bonus
	return not _pending_grant_id.is_empty()


func _on_sdk_reward(placement: String, grant_id: String) -> void:
	if placement != PLACEMENT_ID:
		return
	if grant_id.is_empty() or _pending_grant_id.is_empty() or grant_id != _pending_grant_id:
		_publish(false, 0, "Reward receipt did not match the request.")
		return
	# Do not deliver a payout if the local ad counter was not durably saved.
	var persisted: Dictionary = MonetizationManager.policy_store.call("load_state")
	var persisted_counts: Dictionary = persisted.get("placement_counts", {})
	if int(persisted_counts.get(PLACEMENT_ID, 0)) != int(MonetizationManager.placement_counts.get(PLACEMENT_ID, 0)) or int(persisted.get("last_reward_unix", -1)) != int(MonetizationManager.last_reward_unix):
		_publish(false, 0, "Ad policy save did not persist. Restart before retrying.")
		_clear_pending()
		return
	var result: Dictionary = _commit_reward(_pending_day, _pending_source_id, _pending_bonus, grant_id)
	var success: bool = bool(result.get("success", false))
	_publish(success, _pending_bonus if success else 0, "+%d Spirit Stones" % _pending_bonus if success else str(result.get("error", "Reward save failed.")))
	_clear_pending()


func _commit_reward(day: String, source_id: String, bonus: int, grant_id: String) -> Dictionary:
	DailyQuestManager.refresh_daily_date()
	if SaveManager.is_progress_read_only() or day != DailyQuestManager.active_date_key or day != _repeat_day:
		return {"success": false, "error": "Save locked or daily cycle changed."}
	if source_id != _repeat_source_id or bonus != _repeat_bonus or bonus <= 0 or bonus > MAX_BONUS_STONES:
		return {"success": false, "error": "Victory snapshot mismatch."}
	if grant_id.is_empty() or grant_id in DailyQuestManager.m7b_processed_grant_ids:
		return {"success": false, "error": "Reward receipt already used."}
	if PLACEMENT_ID in DailyQuestManager.m7b_claimed_placement_ids:
		return {"success": false, "error": "Victory Encore already claimed today."}
	var claims: Array[String] = DailyQuestManager.m7b_claimed_placement_ids.duplicate()
	claims.append(PLACEMENT_ID)
	var receipts: Array[String] = DailyQuestManager.m7b_processed_grant_ids.duplicate()
	receipts.append(grant_id)
	if receipts.size() > RECEIPT_HISTORY_LIMIT:
		receipts = receipts.slice(receipts.size() - RECEIPT_HISTORY_LIMIT)
	var next_daily: Dictionary = DailyQuestManager.build_save_data()
	next_daily["m7b_claimed_placement_ids"] = claims
	next_daily["m7b_processed_grant_ids"] = receipts
	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_DAILY_QUEST,
		"m7c_" + day + "_" + source_id,
		RewardManager.create_reward_data(bonus),
		{"daily_quests": next_daily}
	)
	if bool(result.get("success", false)):
		DailyQuestManager.m7b_claimed_placement_ids = claims
		DailyQuestManager.m7b_processed_grant_ids = receipts
	return result


func _on_ad_finished(placement: String, status: String) -> void:
	if placement != PLACEMENT_ID or _pending_grant_id.is_empty():
		return
	_publish(false, 0, "No bonus granted: " + status)
	_clear_pending()


func _publish(success: bool, amount: int, message: String) -> void:
	MonetizationManager.publish_reward_delivery_result(PLACEMENT_ID, success, amount, message)
	offer_finished.emit(success, message)


func _clear_pending() -> void:
	_pending_grant_id = ""
	_pending_day = ""
	_pending_source_id = ""
	_pending_bonus = 0
