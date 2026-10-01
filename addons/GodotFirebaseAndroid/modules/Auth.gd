extends Node

signal auth_success(current_user_data: Dictionary)
signal auth_failure(error_message: String)
signal link_with_google_success(current_user_data: Dictionary)
signal link_with_google_failure(error_message: String)
signal sign_out_success(success: bool)
signal password_reset_sent(success: bool)
signal email_verification_sent(success: bool)
signal user_deleted(success: bool)
signal auth_state_changed(signed_in: bool, current_user_data: Dictionary)
signal id_token_result(token: String)
signal id_token_error(error_message: String)
signal profile_updated(success: bool)
signal profile_update_failure(error_message: String)

var _plugin_singleton: Object

func _connect_signals():
	if not _plugin_singleton:
		return
	_plugin_singleton.connect("auth_success", auth_success.emit)
	_plugin_singleton.connect("auth_failure", auth_failure.emit)
	_plugin_singleton.connect("link_with_google_success", link_with_google_success.emit)
	_plugin_singleton.connect("link_with_google_failure", link_with_google_failure.emit)
	_plugin_singleton.connect("sign_out_success", sign_out_success.emit)
	_plugin_singleton.connect("password_reset_sent", password_reset_sent.emit)
	_plugin_singleton.connect("email_verification_sent", email_verification_sent.emit)
	_plugin_singleton.connect("user_deleted", user_deleted.emit)
	_plugin_singleton.connect("auth_state_changed", auth_state_changed.emit)
	_plugin_singleton.connect("id_token_result", id_token_result.emit)
	_plugin_singleton.connect("id_token_error", id_token_error.emit)
	_plugin_singleton.connect("profile_updated", profile_updated.emit)
	_plugin_singleton.connect("profile_update_failure", profile_update_failure.emit)

func sign_in_anonymously() -> void:
	if _plugin_singleton:
		_plugin_singleton.signInAnonymously()

func create_user_with_email_password(email: String, password: String) -> void:
		if _plugin_singleton:
			_plugin_singleton.createUserWithEmailPassword(email, password)

func sign_in_with_email_password(email: String, password: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.signInWithEmailPassword(email, password)

func send_password_reset_email(email: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.sendPasswordResetEmail(email)

func send_email_verification() -> void:
	if _plugin_singleton:
		_plugin_singleton.sendEmailVerification()

func sign_in_with_google() -> void:
	if _plugin_singleton:
		_plugin_singleton.signInWithGoogle()

func link_anonymous_with_google() -> void:
	if _plugin_singleton:
		_plugin_singleton.linkAnonymousWithGoogle()

func get_current_user_data() -> Dictionary:
	var user_data: Dictionary
	if _plugin_singleton:
		user_data = _plugin_singleton.getCurrentUser()
	return user_data

func delete_current_user() -> void:
	if _plugin_singleton:
		_plugin_singleton.deleteUser()

func is_signed_in() -> bool:
	var status := false
	if _plugin_singleton:
		status = _plugin_singleton.isSignedIn()
	return status

func sign_out() -> void:
	if _plugin_singleton:
		_plugin_singleton.signOut()

func use_emulator(host: String, port: int) -> void:
	if _plugin_singleton:
		_plugin_singleton.useAuthEmulator(host, port)

func reauthenticate_with_email(email: String, password: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.reauthenticateWithEmail(email, password)

func add_auth_state_listener() -> void:
	if _plugin_singleton:
		_plugin_singleton.addAuthStateListener()

func remove_auth_state_listener() -> void:
	if _plugin_singleton:
		_plugin_singleton.removeAuthStateListener()

func get_id_token(force_refresh: bool = false) -> void:
	if _plugin_singleton:
		_plugin_singleton.getIdToken(force_refresh)

func update_profile(display_name: String, photo_url: String = "") -> void:
	if _plugin_singleton:
		_plugin_singleton.updateProfile(display_name, photo_url)

func update_password(new_password: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.updatePassword(new_password)

func reload_user() -> void:
	if _plugin_singleton:
		_plugin_singleton.reloadUser()

func unlink_provider(provider_id: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.unlinkProvider(provider_id)
