extends Node

## Gate 1 — explicit, READ-ONLY Firebase manifest inspection.
## Created on demand by GoogleAccountManager (not a separate Autoload).
## No local SaveManager calls, no Firestore write calls, and no restore API.

signal preview_state_changed(status: Dictionary)

const ManifestInspectorScript = preload(
	"res://scripts/managers/cloud_save_manifest_inspector.gd"
)
const COLLECTION: String = "jade_cloud_manifests_v1"
const READ_TIMEOUT_SECONDS: float = 20.0

var _validator: RefCounted = ManifestInspectorScript.new()
var _firestore: Object = null
var _pending_uid: String = ""
var _pending_serial: int = 0
var _pending_session_valid: bool = false
var _pending_expired: bool = false
var _last_owner_uid: String = ""
var _status: Dictionary = {
	"state": "not_checked",
	"message": "Cloud Save is not active. Local progress is unchanged.",
	"busy": false,
	"manifest_present": false,
	"domain_ids": [],
	"domain_count": 0,
	"revision": 0,
	"saved_at_unix": 0,
	"cloud_write_enabled": false,
	"cloud_restore_enabled": false,
	"server_freshness_verified": false
}


func _ready() -> void:
	var account: Node = get_parent()
	if account != null and account.has_signal(&"account_state_changed"):
		account.connect(
			&"account_state_changed", Callable(self, "_on_account_state_changed")
		)
	_last_owner_uid = _authenticated_uid()


func get_preview_status() -> Dictionary:
	return _status.duplicate(true)


## Future UI may explicitly invoke this when the player requests cloud status.
## It is never called from Boot / Google Sign-In / gameplay save callbacks.
func request_preview() -> bool:
	# A timed-out native request remains reserved until its callback arrives.
	# Native plugin v1.1.0 lacks per-operation request IDs; this avoids
	# confusing a late callback with a new read for the same account.
	if not _pending_uid.is_empty():
		return false
	var uid: String = _authenticated_uid()
	if not bool(_validator.call("is_safe_uid", uid)):
		_publish("guest", "Sign in with Google to inspect cloud metadata.")
		return false
	var firebase: Node = get_node_or_null("/root/Firebase")
	if firebase == null:
		_publish("unavailable", "Firebase provider is not available in this build.")
		return false
	var provider: Variant = firebase.get("firestore")
	if not (provider is Object):
		_publish("unavailable", "Firestore provider is not available.")
		return false
	var firestore: Object = provider as Object
	if not firestore.has_method("get_document") or not firestore.has_signal(&"get_task_completed"):
		_publish("unavailable", "Firestore does not support safe metadata reads.")
		return false
	if not (firestore.get("_plugin_singleton") is Object):
		_publish("unavailable", "Native Firestore is not initialized.")
		return false
	if _firestore != firestore:
		if _firestore != null and is_instance_valid(_firestore):
			var previous: Callable = Callable(self, "_on_get_completed")
			if _firestore.is_connected(&"get_task_completed", previous):
				_firestore.disconnect(&"get_task_completed", previous)
		_firestore = firestore
	var callback: Callable = Callable(self, "_on_get_completed")
	if not _firestore.is_connected(&"get_task_completed", callback):
		_firestore.connect(&"get_task_completed", callback)
	_pending_uid = uid
	_pending_serial += 1
	_pending_session_valid = true
	_pending_expired = false
	_last_owner_uid = uid
	_publish("checking", "Checking cloud manifest (read-only)...")
	get_tree().create_timer(READ_TIMEOUT_SECONDS).timeout.connect(
		_on_read_timeout.bind(_pending_serial), CONNECT_ONE_SHOT
	)
	_firestore.call("get_document", COLLECTION, uid)
	return true


func _on_account_state_changed(_snapshot: Dictionary) -> void:
	var uid: String = _authenticated_uid()
	if not _pending_uid.is_empty() and uid != _pending_uid:
		_pending_session_valid = false
		_publish("account_changed", "Account changed during cloud inspection. Results discarded.")
		_last_owner_uid = uid
		return
	if uid != _last_owner_uid:
		_last_owner_uid = uid
		if uid.is_empty():
			_publish("guest", "Guest progress stays on this device.")
		else:
			_publish("not_checked", "Cloud metadata has not been checked for this account.")


func _on_read_timeout(serial: int) -> void:
	if serial != _pending_serial or _pending_uid.is_empty():
		return
	_pending_expired = true
	_publish("timeout", "Cloud read timed out; local progress is unchanged.")
	# Keep _pending_uid reserved until the native callback or app restart.


func _on_get_completed(result: Dictionary) -> void:
	if _pending_uid.is_empty():
		return
	# The installed native plugin returns docID, not the full collection path.
	# Ignore unrelated Firestore result signals; never accept an anonymous one.
	if str(result.get("docID", "")) != _pending_uid:
		return
	var original_uid: String = _pending_uid
	var accept: bool = (
		_pending_session_valid
		and not _pending_expired
		and _authenticated_uid() == original_uid
	)
	_pending_uid = ""
	_pending_session_valid = false
	_pending_expired = false
	if not accept:
		_publish("not_checked", "Previous cloud result was discarded. Retry if needed.")
		return
	if not bool(result.get("status", false)):
		if str(result.get("error", "")) == "Document does not exist":
			_publish("no_manifest", "No cloud manifest exists for this account yet.")
		else:
			_publish("unavailable", "Cloud read unavailable. Local progress is unchanged.")
		return
	var incoming: Variant = result.get("data", null)
	if not (incoming is Dictionary):
		_publish("invalid", "Cloud metadata has an unsupported format.")
		return
	var inspected: Dictionary = _validator.call(
		"inspect_document", incoming as Dictionary, original_uid
	)
	if not bool(inspected.get("valid", false)):
		_publish("invalid", "Cloud metadata is incompatible; no restore performed.")
		return
	_publish("manifest_found", "Cloud manifest found; save content is NOT verified.", inspected)


func _authenticated_uid() -> String:
	var account_manager: Node = get_parent()
	if account_manager == null or not account_manager.has_method("get_authenticated_uid"):
		return ""
	return str(account_manager.call("get_authenticated_uid"))


func _publish(state: String, message: String, inspected: Dictionary = {}) -> void:
	_status = {
		"state": state,
		"message": message,
		"busy": not _pending_uid.is_empty() and not _pending_expired,
		"manifest_present": state == "manifest_found",
		"domain_ids": inspected.get("domain_ids", []),
		"domain_count": int(inspected.get("domain_count", 0)),
		"revision": int(inspected.get("revision", 0)),
		"saved_at_unix": int(inspected.get("saved_at_unix", 0)),
		"cloud_write_enabled": false,
		"cloud_restore_enabled": false,
		"server_freshness_verified": false
	}
	preview_state_changed.emit(get_preview_status())
