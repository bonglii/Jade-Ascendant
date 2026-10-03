extends Node

## Disposable Android account-bound transport QA stub.
## External services are intentionally unavailable in this package.

func _ready() -> void:
	pass


func get_account_snapshot() -> Dictionary:
	return {
		"native_ready": false,
		"signed_in": false,
		"busy": false,
		"operation": "",
		"display_name": "",
		"status": "Android account-bound transport QA is offline-only.",
		"cloud_save_active": false,
	}


func get_authenticated_uid() -> String:
	return ""
