extends Node

## Firebase Authentication / Google Sign-In boundary for Jade Ascendant.
## Phase 1 deliberately does NOT read, upload, merge, or switch gameplay saves.
## Depends on the optional tracked GodotFirebaseAndroid native addon; fails closed.

signal account_state_changed(snapshot: Dictionary)
signal monetization_identity_changed(ready: bool)

const SETTINGS_SCENE: String = "res://scenes/ui/settings_screen.tscn"
const ACCOUNT_CARD_PATH: String = "res://scripts/ui/google_account_card.gd"
const NATIVE_SINGLETON: String = "GodotFirebaseAndroid"
const OPERATION_TIMEOUT_SECONDS: float = 35.0

var _auth: Object = null
var _native_ready: bool = false
var _signed_in: bool = false
var _busy: bool = false
var _operation: String = ""
var _operation_nonce: int = 0
var _display_name: String = ""
var _account_uid: String = ""
var _firebase_uid: String = ""
var _link_source_uid: String = ""
var _status: String = "Guest progress stays on this device."


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_initialize_after_autoloads")


func _initialize_after_autoloads() -> void:
	refresh_provider()
	_on_scene_changed()


func _on_scene_changed() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path != SETTINGS_SCENE:
		return
	# The Firebase addon registers a second autoload. Resolve it again when
	# Settings opens instead of relying solely on startup ordering.
	if not _native_ready:
		refresh_provider()
	var content: VBoxContainer = scene.get_node_or_null(
		"SafeArea/Scroll/Content"
	) as VBoxContainer
	if content == null or content.has_node("GoogleAccountCard"):
		return
	var card_script: Script = load(ACCOUNT_CARD_PATH) as Script
	if card_script == null:
		push_warning("Google Account: Settings card script was not found.")
		return
	var card: PanelContainer = card_script.new() as PanelContainer
	if card == null:
		push_warning("Google Account: Settings card did not construct.")
		return
	card.name = "GoogleAccountCard"
	content.add_child(card)
	var audio_card: Node = content.get_node_or_null("AudioCard")
	if audio_card != null:
		content.move_child(card, audio_card.get_index())
	# The Settings scene is deliberately left untouched. The Account card is
	# appended only in Settings; all existing controls remain intact.


func get_account_snapshot() -> Dictionary:
	return {
		"native_ready": _native_ready,
		"signed_in": _signed_in,
		"busy": _busy,
		"operation": _operation,
		"display_name": _display_name,
		"status": _status,
		"monetization_identity_ready": not get_monetization_account_binding().is_empty(),
		"cloud_save_active": false
	}


## UID is a private identity boundary for account-owned cloud metadata.
## Never include it in UI snapshots, debug logs, or local gameplay saves.
## Recheck the native session on every access: a cached sign-in flag is not proof.
func get_authenticated_uid() -> String:
	if not _native_ready or not _signed_in or _busy or _auth == null:
		return ""
	if not OS.has_feature("android") or not bool(_auth.call("is_signed_in")):
		return ""
	var current_user: Variant = _auth.call("get_current_user_data")
	if not (current_user is Dictionary):
		return ""
	var user_data: Dictionary = current_user as Dictionary
	if bool(user_data.get("isAnonymous", false)):
		return ""
	var live_uid: String = str(user_data.get("uid", "")).strip_edges()
	return _account_uid if live_uid == _account_uid else ""


## Purchase identity is intentionally separate from the visible Google-account
## state. Firebase anonymous auth remains Guest in UI but gives secure backend
## requests a stable UID. Only a SHA-256 binding leaves this manager for Play.
func get_monetization_account_binding() -> String:
	if not _native_ready or _auth == null:
		return ""
	if not OS.has_feature("android") or not bool(_auth.call("is_signed_in")):
		return ""
	var current_user: Variant = _auth.call("get_current_user_data")
	if not (current_user is Dictionary):
		return ""
	var user_data: Dictionary = current_user as Dictionary
	var live_uid: String = str(user_data.get("uid", "")).strip_edges()
	if live_uid.is_empty() or live_uid != _firebase_uid:
		return ""
	return _sha256_hex(live_uid)


func ensure_monetization_identity() -> bool:
	if not OS.has_feature("android"):
		return false
	if not _native_ready:
		refresh_provider()
	if not _native_ready or _auth == null:
		return false
	if bool(_auth.call("is_signed_in")):
		var current_user: Variant = _auth.call("get_current_user_data")
		if current_user is Dictionary:
			_apply_user(current_user as Dictionary)
			return not get_monetization_account_binding().is_empty()
	if _busy:
		return false
	_busy = true
	_operation = "anonymous_identity"
	_operation_nonce += 1
	_publish()
	_start_timeout(_operation_nonce, _operation)
	_auth.call("sign_in_anonymously")
	return false


func _sha256_hex(value: String) -> String:
	if value.is_empty():
		return ""
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(value.to_utf8_buffer()) != OK:
		return ""
	return hashing.finish().hex_encode()


func refresh_provider() -> void:
	if _busy:
		return
	if not OS.has_feature("android"):
		_native_ready = false
		_signed_in = false
		_display_name = ""
		_status = "Google Sign-In is available in the Android build."
		_publish()
		return
	if not Engine.has_singleton(NATIVE_SINGLETON):
		_native_ready = false
		_signed_in = false
		_display_name = ""
		_status = "Google Login plugin is not installed in this Android build."
		_publish()
		return
	var firebase_root: Node = get_node_or_null("/root/Firebase")
	if firebase_root == null:
		_native_ready = false
		_status = "Firebase plugin is not enabled in Project Settings."
		_publish()
		return
	var candidate: Variant = firebase_root.get("auth")
	if not (candidate is Object):
		_native_ready = false
		_status = "Firebase authentication module is unavailable."
		_publish()
		return
	var next_auth: Object = candidate as Object
	if _auth != next_auth:
		_auth = next_auth
		_connect_once(&"auth_success", Callable(self, "_on_auth_success"))
		_connect_once(&"auth_failure", Callable(self, "_on_auth_failure"))
		_connect_once(&"auth_state_changed", Callable(self, "_on_auth_state_changed"))
		_connect_once(&"sign_out_success", Callable(self, "_on_sign_out_success"))
		_connect_once(
			&"link_with_google_success",
			Callable(self, "_on_link_with_google_success")
		)
		_connect_once(
			&"link_with_google_failure",
			Callable(self, "_on_link_with_google_failure")
		)
		_auth.call("add_auth_state_listener")
	_native_ready = true
	_sync_native_session()


func _connect_once(signal_name: StringName, callback: Callable) -> void:
	if _auth != null and _auth.has_signal(signal_name):
		if not _auth.is_connected(signal_name, callback):
			_auth.connect(signal_name, callback)


func _sync_native_session() -> void:
	if not _native_ready or _auth == null or _busy:
		return
	if not bool(_auth.call("is_signed_in")):
		_set_guest()
		call_deferred("ensure_monetization_identity")
		return
	var data: Variant = _auth.call("get_current_user_data")
	if not (data is Dictionary):
		_set_guest()
		call_deferred("ensure_monetization_identity")
		return
	_apply_user(data as Dictionary)


func request_google_sign_in() -> void:
	if _busy:
		return
	if not _native_ready:
		refresh_provider()
	if not _native_ready or _auth == null:
		return
	if _signed_in:
		return

	var should_link_anonymous: bool = false
	_link_source_uid = ""
	if bool(_auth.call("is_signed_in")):
		var current_user: Variant = _auth.call("get_current_user_data")
		if current_user is Dictionary:
			var user_data: Dictionary = current_user as Dictionary
			var live_uid: String = str(user_data.get("uid", "")).strip_edges()
			if bool(user_data.get("isAnonymous", false)) and not live_uid.is_empty():
				should_link_anonymous = true
				_link_source_uid = live_uid

	_busy = true
	_operation = "link_google" if should_link_anonymous else "sign_in"
	_status = "Opening Google sign-in..."
	_operation_nonce += 1
	_publish()
	_start_timeout(_operation_nonce, _operation)
	if should_link_anonymous:
		_auth.call("link_anonymous_with_google")
	else:
		_auth.call("sign_in_with_google")


func request_sign_out() -> void:
	if _busy or not _signed_in:
		return
	if not _native_ready or _auth == null:
		refresh_provider()
		return
	_busy = true
	_operation = "sign_out"
	_status = "Signing out..."
	_operation_nonce += 1
	_publish()
	_start_timeout(_operation_nonce, _operation)
	_auth.call("sign_out")


func _start_timeout(nonce: int, operation: String) -> void:
	get_tree().create_timer(OPERATION_TIMEOUT_SECONDS).timeout.connect(
		_on_operation_timeout.bind(nonce, operation), CONNECT_ONE_SHOT
	)


func _on_operation_timeout(nonce: int, operation: String) -> void:
	if not _busy or nonce != _operation_nonce or _operation != operation:
		return
	_busy = false
	_operation = ""
	_status = "Google did not respond. Check your connection and try again."
	_publish()


func _on_auth_success(data: Dictionary) -> void:
	if _operation not in ["sign_in", "anonymous_identity"]:
		return
	var completed_operation: String = _operation
	_finish_operation()
	_apply_user(data)
	if completed_operation == "anonymous_identity" and _firebase_uid.is_empty():
		monetization_identity_changed.emit(false)


func _on_auth_failure(_message: String) -> void:
	if not _busy:
		return
	var failed_operation: String = _operation
	_finish_operation()
	if failed_operation == "anonymous_identity":
		_set_guest()
		return
	_status = (
		"Google sign-in failed. Check your connection or Google configuration."
		if failed_operation == "sign_in"
		else "Sign out failed. Please try again."
	)
	_publish()


func _on_link_with_google_success(data: Dictionary) -> void:
	if _operation != "link_google":
		return
	var expected_uid: String = _link_source_uid
	var linked_uid: String = str(data.get("uid", "")).strip_edges()
	_finish_operation()
	if expected_uid.is_empty() or linked_uid != expected_uid:
		_set_guest()
		_status = "Google account link changed the secure purchase identity."
		_publish()
		return
	_apply_user(data)


func _on_link_with_google_failure(_message: String) -> void:
	if _operation != "link_google":
		return
	_finish_operation()
	_sync_native_session()
	_status = "Google sign-in failed. Guest progress is unchanged."
	_publish()


func _on_auth_state_changed(signed_in: bool, user_data: Dictionary) -> void:
	# Interactive Google operations finish only through their explicit result
	# signals. This prevents an intermediate anonymous auth callback from
	# changing the visible account state or purchase owner.
	if _operation in ["sign_in", "link_google"]:
		return
	if _operation == "sign_out":
		return
	if _operation == "anonymous_identity":
		if not signed_in:
			return
		_finish_operation()
		_apply_user(user_data)
		return
	if not signed_in:
		_finish_operation()
		_set_guest()
		call_deferred("ensure_monetization_identity")
		return
	_finish_operation()
	_apply_user(user_data)


func _on_sign_out_success(succeeded: bool) -> void:
	if _operation != "sign_out":
		return
	_finish_operation()
	if succeeded:
		_set_guest()
		call_deferred("ensure_monetization_identity")
	else:
		_status = "Sign out failed. Your local progress is unchanged."
		_publish()


func _finish_operation() -> void:
	_busy = false
	_operation = ""
	_link_source_uid = ""
	_operation_nonce += 1


func _apply_user(data: Dictionary) -> void:
	var uid: String = str(data.get("uid", "")).strip_edges()
	if uid.is_empty():
		_set_guest()
		return

	# Anonymous Firebase identity is intentionally invisible to account UI.
	# It exists only so secure purchase verification has a stable server owner.
	_firebase_uid = uid
	if bool(data.get("isAnonymous", false)):
		_account_uid = ""
		_signed_in = false
		_display_name = ""
		_status = "Guest progress stays on this device."
		_publish()
		monetization_identity_changed.emit(true)
		return

	_account_uid = uid
	_signed_in = true
	var account_name: Variant = data.get("name", "")
	_display_name = account_name.strip_edges() if account_name is String else ""
	if _display_name.is_empty():
		_display_name = "Google account"
	_status = "Google account connected on this device."
	_publish()
	monetization_identity_changed.emit(true)


func _set_guest() -> void:
	_firebase_uid = ""
	_account_uid = ""
	_signed_in = false
	_display_name = ""
	_status = "Guest progress stays on this device."
	_publish()
	monetization_identity_changed.emit(false)


func _publish() -> void:
	account_state_changed.emit(get_account_snapshot())
