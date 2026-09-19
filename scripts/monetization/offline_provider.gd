extends Node

## Safe production default. No advertising or billing network connections.
signal reward_confirmed(request_id: int)
signal request_finished(request_id: int, status: String)
signal entitlements_received(product_ids: Array[String])


func _emit_reward_confirmed(request_id: int) -> void:
	reward_confirmed.emit(request_id)


func rewarded_available(_placement: String) -> bool:
	return false


func show_rewarded(request_id: int, _placement: String) -> void:
	request_finished.emit(request_id, "unavailable")


func privacy_options_required() -> bool:
	return false


func show_privacy_options() -> bool:
	return false


func get_runtime_status() -> Dictionary:
	return {
		"provider": "offline",
		"state": "ready",
		"rewarded_ready": false,
		"privacy_options_required": false
	}


func purchase(request_id: int, _product_id: String) -> void:
	request_finished.emit(request_id, "unavailable")


func restore_entitlements() -> void:
	var empty: Array[String] = []
	entitlements_received.emit(empty)
