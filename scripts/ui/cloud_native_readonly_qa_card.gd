extends PanelContainer

## Gate 4.2C: Android DEBUG ONLY, manual Cloud Functions/App Check QA.
## Never transmits client UID, save, balances, receipts or other payloads.
## No autoload, no automatic requests, no persistent state, no save writes.

const NATIVE_SINGLETON: String = "JadeCloudNativeBridge"
const QA_TIMEOUT_SECONDS: float = 30.0
const GOLD: Color = Color(0.99, 0.80, 0.42, 1.0)
const JADE: Color = Color(0.23, 0.89, 0.76, 1.0)
const IVORY: Color = Color(0.95, 0.97, 0.92, 1.0)
const MUTED: Color = Color(0.76, 0.85, 0.81, 1.0)

var _button: Button = null
var _status: Label = null
var _bridge: Object = null
var _pending: bool = false
var _retry_locked: bool = false
var _expired: bool = false
var _session_valid: bool = false
var _request_uid: String = "" # PRIVATE, memory-only identity boundary.
var _request_epoch: int = 0
var _identity_epoch: int = 0
var _last_signed_in: bool = false
var _request_serial: int = 0


func _ready() -> void:
	# Fail closed even if this scene were accidentally instantiated elsewhere.
	if not OS.has_feature("android") or not OS.is_debug_build():
		queue_free()
		return
	mouse_filter = Control.MOUSE_FILTER_PASS
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.004, 0.029, 0.042, 0.977)
	panel.set_border_width_all(2)
	panel.border_color = Color(0.23, 0.89, 0.76, 0.64)
	panel.set_corner_radius_all(16)
	panel.content_margin_left = 20.0
	panel.content_margin_right = 20.0
	panel.content_margin_top = 18.0
	panel.content_margin_bottom = 18.0
	add_theme_stylebox_override("panel", panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	content.add_child(_label(
		_local("CLOUD FUNCTIONS  •  DEBUG ONLY", "CLOUD FUNCTIONS  •  KHUSUS DEBUG"),
		13, JADE
	))
	content.add_child(_label(
		_local("Verify native read-only connection", "Uji koneksi native baca saja"),
		18, GOLD
	))
	content.add_child(_label(
		_local(
			"Manual QA only. The backend has NOT been deployed. No backup, restore, or purchase verification happens here.",
			"Khusus uji manual. Backend BELUM di-deploy. Tidak ada backup, restore, atau verifikasi pembelian."
		), 13, MUTED
	))

	_button = Button.new()
	_button.custom_minimum_size.y = 48.0
	_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_button.mouse_filter = Control.MOUSE_FILTER_PASS
	_button.text = _local("TEST FUNCTIONS / APP CHECK", "UJI FUNCTIONS / APP CHECK")
	_button.add_theme_font_size_override("font_size", 14)
	_button.pressed.connect(_on_pressed)
	content.add_child(_button)

	_status = _label("", 13, IVORY)
	content.add_child(_status)

	var account_state: Dictionary = GoogleAccountManager.get_account_snapshot()
	_last_signed_in = bool(account_state.get("signed_in", false))
	GoogleAccountManager.account_state_changed.connect(_on_account_state_changed)
	_refresh(account_state)


func _exit_tree() -> void:
	var account_cb: Callable = Callable(self, "_on_account_state_changed")
	if GoogleAccountManager.account_state_changed.is_connected(account_cb):
		GoogleAccountManager.account_state_changed.disconnect(account_cb)
	if _bridge != null and is_instance_valid(_bridge):
		var native_cb: Callable = Callable(self, "_on_native_result")
		if _bridge.is_connected(&"capabilitiesResult", native_cb):
			_bridge.disconnect(&"capabilitiesResult", native_cb)


func _label(message: String, font_size: int, ink: Color) -> Label:
	var result := Label.new()
	result.text = message
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", ink)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _local(en: String, id: String) -> String:
	return id if SettingsManager.language == "id" else en


func _refresh(snapshot: Dictionary) -> void:
	if _button == null or _status == null:
		return
	var account_ready: bool = (
		bool(snapshot.get("native_ready", false))
		and bool(snapshot.get("signed_in", false))
		and not bool(snapshot.get("busy", false))
	)
	_button.disabled = not account_ready or _pending or _retry_locked
	if _pending:
		return
	if not account_ready or GoogleAccountManager.get_authenticated_uid().is_empty():
		_button.disabled = true
		_status.text = _local(
			"Connect Google first. Your local progress stays on this device.",
			"Hubungkan Google dahulu. Progres lokal tetap di perangkat ini."
		)
	elif not Engine.has_singleton(NATIVE_SINGLETON):
		_button.disabled = true
		_status.text = _local(
			"Native bridge missing. Enable JadeCloudNativeBridge in Godot and re-export Debug APK.",
			"Native bridge tidak ditemukan. Aktifkan JadeCloudNativeBridge lalu export APK Debug."
		)
	elif _status.text.is_empty() or _status.text.begins_with("Connect Google") or _status.text.begins_with("Hubungkan Google"):
		_status.text = _local(
			"Ready for manual read-only probe. A missing endpoint is EXPECTED, not a PASS.",
			"Siap uji baca saja. Endpoint yang belum ada adalah kondisi wajar, BUKAN PASS."
		)


func _on_account_state_changed(snapshot: Dictionary) -> void:
	var signed_in: bool = bool(snapshot.get("signed_in", false))
	if signed_in != _last_signed_in:
		_identity_epoch += 1
	_last_signed_in = signed_in
	if _pending and (
		not signed_in
		or bool(snapshot.get("busy", false))
		or GoogleAccountManager.get_authenticated_uid() != _request_uid
	):
		_session_valid = false
		_status.text = _local(
			"Account changed; pending result will be discarded. No save was modified.",
			"Akun berubah; hasil lama akan ditolak. Save tidak diubah."
		)
	_refresh(snapshot)


func _on_pressed() -> void:
	if not OS.has_feature("android") or not OS.is_debug_build() or _pending or _retry_locked:
		return
	var screen: Node = get_tree().current_scene
	if screen != null and bool(screen.get("_scroll_gesture_active")):
		return
	var account_state: Dictionary = GoogleAccountManager.get_account_snapshot()
	if (
		not bool(account_state.get("native_ready", false))
		or not bool(account_state.get("signed_in", false))
		or bool(account_state.get("busy", false))
	):
		_refresh(account_state)
		return
	var uid: String = GoogleAccountManager.get_authenticated_uid()
	if uid.is_empty():
		_refresh(account_state)
		return
	if not Engine.has_singleton(NATIVE_SINGLETON):
		_refresh(account_state)
		return
	var native: Object = Engine.get_singleton(NATIVE_SINGLETON)
	# Godot 4.7's Android JNISingleton exposes annotated Java/Kotlin
	# entrypoints through has_java_method(), not Object.has_method().
	# Guard the built-in introspection method before calling it dynamically.
	if native == null or not native.has_method("has_java_method"):
		_status.text = _local(
			"Android native bridge introspection unavailable.",
			"Pemeriksaan API native Android tidak tersedia."
		)
		return
	if not bool(native.call("has_java_method", "isAppCheckConfigured")):
		_status.text = _local(
			"Native App Check method not registered.",
			"Method native App Check belum terdaftar."
		)
		return
	if not bool(native.call("has_java_method", "requestReadOnlyCapabilities")):
		_status.text = _local(
			"Native read-only callable method not registered.",
			"Method native callable baca saja belum terdaftar."
		)
		return
	if not native.has_signal(&"capabilitiesResult"):
		_status.text = _local(
			"Native read-only result signal not registered.",
			"Signal native hasil baca saja belum terdaftar."
		)
		return
	if not bool(native.call("isAppCheckConfigured")):
		_status.text = _local(
			"App Check provider was not initialized. No request sent.",
			"Provider App Check belum terpasang. Tidak ada request dikirim."
		)
		return
	if _bridge != native:
		if _bridge != null and is_instance_valid(_bridge):
			var old_cb: Callable = Callable(self, "_on_native_result")
			if _bridge.is_connected(&"capabilitiesResult", old_cb):
				_bridge.disconnect(&"capabilitiesResult", old_cb)
		_bridge = native
	var callback: Callable = Callable(self, "_on_native_result")
	if not _bridge.is_connected(&"capabilitiesResult", callback):
		_bridge.connect(&"capabilitiesResult", callback)
	_pending = true
	_expired = false
	_session_valid = true
	_request_uid = uid
	_request_epoch = _identity_epoch
	_request_serial += 1
	_button.disabled = true
	_status.text = _local(
		"Requesting READ-ONLY capabilities… App Check provider ready does NOT prove attestation.",
		"Meminta capabilities BACA SAJA… Provider App Check siap BUKAN bukti attestation."
	)
	get_tree().create_timer(QA_TIMEOUT_SECONDS).timeout.connect(
		_on_timeout.bind(_request_serial), CONNECT_ONE_SHOT
	)
	_bridge.call("requestReadOnlyCapabilities")


func _on_timeout(serial: int) -> void:
	if not _pending or serial != _request_serial:
		return
	_expired = true
	_session_valid = false
	_status.text = _local(
		"Timed out. Wait for the native callback or restart the game before retrying.",
		"Timeout. Tunggu callback native atau restart game sebelum mencoba lagi."
	)
	# Keep the reservation: native API has no request IDs. Avoid a late result
	# being mistaken for the result of a second account's request.


func _on_native_result(success: bool, code: String) -> void:
	if not _pending:
		return
	var accept: bool = (
		_session_valid and not _expired
		and _request_epoch == _identity_epoch
		and not _request_uid.is_empty()
		and GoogleAccountManager.get_authenticated_uid() == _request_uid
	)
	_pending = false
	_session_valid = false
	_request_uid = ""
	if code == "BUSY":
		# Another UI instance may have begun this native request. A late
		# callback has no request ID: disallow re-probing until restart.
		_retry_locked = true
	if not accept:
		_status.text = _local(
			"Stale result ignored (account change/timeout). No save was modified.",
			"Hasil lama diabaikan (akun berubah/timeout). Save tidak diubah."
		)
	else:
		_status.text = _message_for_code(success, code)
	_refresh(GoogleAccountManager.get_account_snapshot())


func _message_for_code(success: bool, code: String) -> String:
	# ONLY recognized, nonsensitive codes may become UI text.
	if success and code == "CLOUD_DISABLED_CONFIRMED":
		return _local(
			"READ-ONLY callable confirmed: all Cloud Save / purchase switches are OFF. No backup exists from this test.",
			"Callable BACA SAJA terkonfirmasi: seluruh switch Cloud Save / pembelian NONAKTIF. Tidak membuat backup."
		)
	match code:
		"CALLABLE_NOT_FOUND":
			return _local(
				"Endpoint not deployed / not found (EXPECTED at this gate). SDK attempt only; NOT a live server PASS.",
				"Endpoint belum di-deploy / tidak ada (WAJAR saat ini). Baru uji SDK, BUKAN PASS server."
			)
		"CALLABLE_UNAVAILABLE", "CALLABLE_DEADLINE_EXCEEDED":
			return _local("Endpoint/network unavailable. No progress changed.", "Endpoint/jaringan tidak tersedia. Progres tidak berubah.")
		"CALLABLE_UNAUTHENTICATED", "CALLABLE_PERMISSION_DENIED":
			return _local("Auth / App Check rejected request. No progress changed.", "Auth / App Check menolak request. Progres tidak berubah.")
		"GOOGLE_SIGN_IN_REQUIRED":
			return _local("Google sign-in is required.", "Login Google diperlukan.")
		"APP_CHECK_NOT_READY":
			return _local("App Check provider not configured.", "Provider App Check belum dikonfigurasi.")
		"ACCOUNT_CHANGED":
			return _local("Account switched; native response discarded.", "Akun berganti; respons native dibuang.")
		"BUSY":
			return _local("Native request already in progress. Restart before retry.", "Request native masih berjalan. Restart sebelum mencoba lagi.")
		"UNSUPPORTED_CAPABILITIES_RESPONSE":
			return _local("Unsafe/unknown server response REJECTED. Cloud Save remains disabled.", "Respons server tak dikenal DITOLAK. Cloud Save tetap nonaktif.")
		"NATIVE_UNAVAILABLE":
			return _local("Native Firebase SDK unavailable.", "Firebase SDK native tidak tersedia.")
		_:
			return _local("Callable failed or returned an unknown status. No save was modified.", "Callable gagal / status tidak dikenal. Save tidak diubah.")
