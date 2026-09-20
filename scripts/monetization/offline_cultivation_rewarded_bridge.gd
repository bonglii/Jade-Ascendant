extends Node

## Verified rewarded-ad boundary for Spirit Meditation.
## The UI may request an ad, but only this bridge can convert a verified
## provider callback into the snapshotted 2x offline-cultivation grant.
const PLACEMENT_ID: String = "offline_cultivation_double"


func _ready() -> void:
	var manager: Variant = get_parent()
	if not manager.verified_rewarded_completed.is_connected(
		_on_verified_rewarded_completed
	):
		manager.verified_rewarded_completed.connect(
			_on_verified_rewarded_completed
		)
	if not manager.rewarded_request_finished.is_connected(
		_on_rewarded_request_finished
	):
		manager.rewarded_request_finished.connect(
			_on_rewarded_request_finished
		)


func _on_verified_rewarded_completed(
	placement: String,
	grant_id: String
) -> void:
	if placement != PLACEMENT_ID:
		return

	var monetization: Variant = get_parent()
	var result: Dictionary = (
		IdleCultivationManager.apply_verified_rewarded_double_claim(
			grant_id
		)
	)
	var success: bool = bool(result.get("success", false))
	var message: String = str(result.get("error", ""))
	if success:
		var applied_reward: Dictionary = result.get(
			"applied_reward_data",
			{}
		)
		message = RewardManager.get_reward_summary(
			applied_reward,
			"Reward claimed."
		)

	monetization.call(
		"publish_reward_delivery_result",
		placement,
		success,
		IdleCultivationManager.get_rewarded_double_multiplier()
			if success
			else 0,
		message
	)

	if not success:
		push_error(
			"Offline Cultivation rewarded 2x grant gagal: "
			+ message
		)


func _on_rewarded_request_finished(
	placement: String,
	status: String
) -> void:
	if placement != PLACEMENT_ID:
		return
	if status != "completed":
		IdleCultivationManager.cancel_pending_rewarded_double_claim()
