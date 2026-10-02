extends Node

## Android destructive restore QA only. The disposable QA build redirects the
## MonetizationManager, GoogleAccountManager and Firebase autoload names to this
## offline stub so no network/native service can start in the isolated package.

signal account_state_changed(snapshot: Dictionary)
signal operation_finished(status: String)
signal rewarded_completed(placement: String)
signal verified_rewarded_completed(placement: String, grant_id: String)
signal rewarded_request_finished(placement: String, status: String)
signal reward_delivery_finished(placement: String, success: bool, amount: int, message: String)
signal entitlements_changed(product_ids: Array[String])
signal analytics_event(event_id: String, properties: Dictionary)

var auth: Variant = null


func refresh_provider() -> void:
	pass


func get_account_snapshot() -> Dictionary:
	return {
		"native_ready": false,
		"signed_in": false,
		"busy": false,
		"operation": "",
		"display_name": "",
		"status": "Android restore QA is offline-only.",
		"cloud_save_active": false,
	}


func get_authenticated_uid() -> String:
	return ""


func get_cloud_save_probe() -> Node:
	return null


func rewarded_available(_placement: String) -> bool:
	return false


func is_rewarded_request_active(_placement: String) -> bool:
	return false


func get_rewarded_policy_status(_placement: String) -> Dictionary:
	return {
		"available": false,
		"placement_claims": 0,
		"daily_limit": 0,
		"cooldown_remaining_seconds": 0,
		"provider_ready": false,
	}


func show_rewarded(_placement: String) -> bool:
	return false


func use_test_provider(_test_provider: Node) -> bool:
	return false
