extends Node

## Firebase Authentication / Google Sign-In boundary for Jade Ascendant.
## Phase 1 deliberately does NOT read, upload, merge, or switch gameplay saves.
## Depends on optional GodotFirebaseAndroid 1.1.0 native addon; fails closed.

signal account_state_changed(snapshot: Dictionary)

const SETTINGS_SCENE: String = "res://scenes/ui/settings_screen.tscn"
const ACCOUNT_CARD_PATH: String = "res://scripts/ui/google_account_card.gd"
const NATIVE_QA_CARD_PATH: String = "res://scripts/ui/cloud_native_readonly_qa_card.gd"
const NATIVE_SINGLETON: String = "GodotFirebaseAndroid"
const CloudSaveProbeScript = preload(
	"res://scripts/managers/cloud_save_readonly_manager.gd"
)
const OPERATION_TIMEOUT_SECONDS: float = 35.0

var _auth: Object = null
var _native_ready: bool = false
var _signed_in: bool = false
var _busy: bool = false
var _operation: String = ""
var _operation_nonce: int = 0
var _display_name: String = ""
var _account_uid: String = ""
var _cloud_save_probe: Node = null
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
	# Only a manual, read-only native probe is exposed in Android DEBUG builds.
	# This is a sibling of the Account card; there is no autoload, boot probe,
	# persistent state, server write, or production UI addition.
	if OS.has_feature("android") and OS.is_debug_build():
		var qa_script: Script = load(NATIVE_QA_CARD_PATH) as Script
		if qa_script != null:
			var qa_card: PanelContainer = qa_script.new() as PanelContainer
			if qa_card != null:
				qa_card.name = "CloudNativeReadOnlyQACard"
				content.add_child(qa_card)
				content.move_child(qa_card, card.get_index() + 1)
	# The Settings scene is deliberately left untouched. These cards are
	# appended only in Settings; all existing controls remain intact.


func get_account_snapshot() -> Dictionary:
	return {
		"native_ready": _native_ready,
		"signed_in": _signed_in,
		"busy": _busy,
		"operation": _operation,
		"display_name": _display_name,
		"status": _status,
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


## Created lazily; no Firestore network operation occurs during startup.
## This is deliberately NOT a new Autoload, so Phase0's 19-autoload contract
## and the established startup ordering remain unchanged.
func get_cloud_save_probe() -> Node:
	if is_instance_valid(_cloud_save_probe):
		return _cloud_save_probe
	var candidate: Node = CloudSaveProbeScript.new() as Node
	if candidate == null:
		return null
	candidate.name = "CloudSaveReadOnlyManager"
	add_child(candidate)
	_cloud_save_probe = candidate
	return candidate


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
		return
	var data: Variant = _auth.call("get_current_user_data")
	if not (data is Dictionary):
		_set_guest()
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
	_busy = true
	_operation = "sign_in"
	_status = "Opening Google sign-in..."
	_operation_nonce += 1
	_publish()
	_start_timeout(_operation_nonce, _operation)
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
	if _operation != "sign_in":
		return
	_finish_operation()
	_apply_user(data)


func _on_auth_failure(_message: String) -> void:
	if not _busy:
		return
	var failed_operation: String = _operation
	_finish_operation()
	_status = (
		"Google sign-in failed. Check your connection or Google configuration."
		if failed_operation == "sign_in"
		else "Sign out failed. Please try again."
	)
	_publish()


func _on_auth_state_changed(signed_in: bool, user_data: Dictionary) -> void:
	# A sign-out failure must not masquerade as success. For a sign-in attempt,
	# wait for auth_success/auth_failure so the initial 'false' callback does
	# not accidentally cancel an in-flight Google account picker.
	if _operation == "sign_in" and not signed_in:
		return
	if not signed_in:
		_finish_operation()
		_set_guest()
		return
	if _operation == "sign_out":
		return
	_finish_operation()
	_apply_user(user_data)


func _on_sign_out_success(succeeded: bool) -> void:
	if _operation != "sign_out":
		return
	_finish_operation()
	if succeeded:
		_set_guest()
	else:
		_status = "Sign out failed. Your local progress is unchanged."
		_publish()


func _finish_operation() -> void:
	_busy = false
	_operation = ""
	_operation_nonce += 1


func _apply_user(data: Dictionary) -> void:
	# Firebase can also hold an anonymous session. Never label one Google.
	var uid: String = str(data.get("uid", "")).strip_edges()
	if uid.is_empty() or bool(data.get("isAnonymous", false)):
		_set_guest()
		return
	_account_uid = uid
	_signed_in = true
	var account_name: Variant = data.get("name", "")
	_display_name = account_name.strip_edges() if account_name is String else ""
	if _display_name.is_empty():
		_display_name = "Google account"
	_status = "Google account connected on this device."
	_publish()


func _set_guest() -> void:
	_account_uid = ""
	_signed_in = false
	_display_name = ""
	_status = "Guest progress stays on this device."
	_publish()


func _publish() -> void:
	account_state_changed.emit(get_account_snapshot())
