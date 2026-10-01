extends PanelContainer

## Small, additive Account card for the already-approved Settings screen.
## Injected by GoogleAccountManager when Settings becomes the active scene.
## No Google credentials, tokens or gameplay save fields are stored here.

const GOLD: Color = Color(0.99, 0.80, 0.42, 1.0)
const JADE: Color = Color(0.23, 0.89, 0.76, 1.0)
const IVORY: Color = Color(0.95, 0.97, 0.92, 1.0)
const MUTED: Color = Color(0.76, 0.85, 0.81, 1.0)
const SnapshotCaptureScript = preload(
	"res://scripts/managers/cloud_save_snapshot_capture.gd"
)

var _status: Label
var _action: Button
var _footer: Label
var _cloud_qa_button: Button = null
var _cloud_qa_status: Label = null
var _cloud_qa_probe: Node = null
var _cloud_qa_last_signed_in: bool = false
var _capture_qa_button: Button = null
var _capture_qa_status: Label = null
var _capture_qa_last_signed_in: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", _card_style())
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	add_child(content)

	var eyebrow: Label = _make_label(
		_local("ACCOUNT  •  GOOGLE", "AKUN  •  GOOGLE"), 12, JADE
	)
	content.add_child(eyebrow)

	var heading: Label = _make_label(
		_local("Your Jade Account", "Akun Jade Lu"), 22, GOLD
	)
	content.add_child(heading)

	var description: Label = _make_label(
		_local(
			"Connect a Google account to establish your player identity.",
			"Hubungkan akun Google untuk membuat identitas pemain."
		), 14, MUTED
	)
	content.add_child(description)

	var rule := ColorRect.new()
	rule.color = Color(0.30, 0.79, 0.67, 0.46)
	rule.custom_minimum_size.y = 2.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rule)

	_status = _make_label("", 15, IVORY)
	content.add_child(_status)

	_action = Button.new()
	_action.custom_minimum_size.y = 57.0
	_action.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_action.mouse_filter = Control.MOUSE_FILTER_PASS
	_action.add_theme_font_size_override("font_size", 16)
	_action.pressed.connect(_on_action_pressed)
	content.add_child(_action)

	_footer = _make_label(
		_local(
			"Cloud Save is not active. Gameplay progress and purchases remain in this device's local save.",
			"Cloud Save belum aktif. Progres game dan riwayat pembelian masih tersimpan lokal di perangkat ini."
		), 13, MUTED
	)
	content.add_child(_footer)

	# Gate 1 manual, READ-ONLY connectivity test. Debug Android builds only;
	# this control is not present in production release APKs.
	if OS.has_feature("android") and OS.is_debug_build():
		_add_cloud_qa_controls(content)

	GoogleAccountManager.account_state_changed.connect(_refresh)
	_refresh(GoogleAccountManager.get_account_snapshot())


func _add_cloud_qa_controls(content: VBoxContainer) -> void:
	var separator := ColorRect.new()
	separator.color = Color(0.30, 0.79, 0.67, 0.34)
	separator.custom_minimum_size.y = 1.0
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(separator)

	var debug_label: Label = _make_label(
		_local("FIRESTORE CONNECTION TEST  •  DEBUG ONLY", "UJI KONEKSI FIRESTORE  •  KHUSUS DEBUG"),
		12, JADE
	)
	content.add_child(debug_label)

	_cloud_qa_button = Button.new()
	_cloud_qa_button.custom_minimum_size.y = 48.0
	_cloud_qa_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_cloud_qa_button.mouse_filter = Control.MOUSE_FILTER_PASS
	_cloud_qa_button.add_theme_font_size_override("font_size", 14)
	_cloud_qa_button.text = _local("CHECK FIRESTORE  •  READ ONLY", "PERIKSA FIRESTORE  •  BACA SAJA")
	_cloud_qa_button.add_theme_stylebox_override("normal", _button_style(false, true))
	_cloud_qa_button.add_theme_stylebox_override("hover", _button_style(false, true))
	_cloud_qa_button.add_theme_stylebox_override("pressed", _button_style(false, true))
	_cloud_qa_button.add_theme_stylebox_override("disabled", _button_style(true, true))
	_cloud_qa_button.add_theme_color_override("font_color", IVORY)
	_cloud_qa_button.add_theme_color_override("font_disabled_color", MUTED)
	_cloud_qa_button.pressed.connect(_on_cloud_qa_pressed)
	content.add_child(_cloud_qa_button)

	_cloud_qa_status = _make_label(
		_local("Sign in with Google to check Firestore access. No progress is uploaded.",
			"Masuk dengan Google untuk menguji akses Firestore. Tidak ada progres yang diunggah."),
		13, MUTED
	)
	content.add_child(_cloud_qa_status)

	# LOCAL MEMORY ONLY: no disk, Firestore, upload, restore or logging.
	# Kept in this same Android-debug-only section as the existing probe.
	var capture_separator := ColorRect.new()
	capture_separator.color = Color(0.30, 0.79, 0.67, 0.34)
	capture_separator.custom_minimum_size.y = 1.0
	capture_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(capture_separator)

	content.add_child(_make_label(
		_local("LOCAL SNAPSHOT CHECK  •  DEBUG ONLY", "UJI SNAPSHOT LOKAL  •  KHUSUS DEBUG"),
		12, JADE
	))
	_capture_qa_button = Button.new()
	_capture_qa_button.custom_minimum_size.y = 48.0
	_capture_qa_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_capture_qa_button.mouse_filter = Control.MOUSE_FILTER_PASS
	_capture_qa_button.add_theme_font_size_override("font_size", 14)
	_capture_qa_button.text = _local(
		"CHECK LOCAL SNAPSHOT  •  NO UPLOAD", "PERIKSA SNAPSHOT LOKAL  •  TANPA UPLOAD"
	)
	_capture_qa_button.add_theme_stylebox_override("normal", _button_style(false, true))
	_capture_qa_button.add_theme_stylebox_override("hover", _button_style(false, true))
	_capture_qa_button.add_theme_stylebox_override("pressed", _button_style(false, true))
	_capture_qa_button.add_theme_stylebox_override("disabled", _button_style(true, true))
	_capture_qa_button.add_theme_color_override("font_color", IVORY)
	_capture_qa_button.add_theme_color_override("font_disabled_color", MUTED)
	_capture_qa_button.pressed.connect(_on_capture_qa_pressed)
	content.add_child(_capture_qa_button)

	_capture_qa_status = _make_label(
		_local(
			"Sign in with Google to inspect local memory. This is NOT a backup.",
			"Masuk dengan Google untuk memeriksa memori lokal. Ini BUKAN backup."
		), 13, MUTED
	)
	content.add_child(_capture_qa_status)


func _exit_tree() -> void:
	if _cloud_qa_probe != null and is_instance_valid(_cloud_qa_probe):
		var callback: Callable = Callable(self, "_on_cloud_qa_state_changed")
		if _cloud_qa_probe.is_connected(&"preview_state_changed", callback):
			_cloud_qa_probe.disconnect(&"preview_state_changed", callback)


func _local(en: String, id: String) -> String:
	return id if SettingsManager.language == "id" else en


func _make_label(message: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _card_style() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.004, 0.029, 0.042, 0.977)
	panel.set_border_width_all(2)
	panel.border_width_bottom = 3
	panel.border_color = Color(0.96, 0.79, 0.44, 0.73)
	panel.set_corner_radius_all(16)
	panel.content_margin_left = 20.0
	panel.content_margin_right = 20.0
	panel.content_margin_top = 18.0
	panel.content_margin_bottom = 19.0
	panel.shadow_color = Color(0.60, 0.44, 0.13, 0.15)
	panel.shadow_size = 8
	return panel


func _button_style(disabled: bool, signed_in: bool) -> StyleBoxFlat:
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(9)
	normal.set_border_width_all(2)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 11.0
	normal.content_margin_bottom = 11.0
	if disabled:
		normal.bg_color = Color(0.08, 0.14, 0.16, 1.0)
		normal.border_color = Color(0.38, 0.49, 0.48, 0.50)
	elif signed_in:
		normal.bg_color = Color(0.012, 0.10, 0.11, 1.0)
		normal.border_color = JADE
	else:
		normal.bg_color = Color(0.93, 0.94, 0.90, 1.0)
		normal.border_color = Color(0.85, 0.72, 0.42, 1.0)
	return normal


func _refresh(snapshot: Dictionary) -> void:
	if not is_inside_tree():
		return
	var native_ready: bool = bool(snapshot.get("native_ready", false))
	var signed_in: bool = bool(snapshot.get("signed_in", false))
	var busy: bool = bool(snapshot.get("busy", false))
	var current_operation: String = str(snapshot.get("operation", ""))
	var status_message: String = str(snapshot.get("status", ""))
	var display_name: String = str(snapshot.get("display_name", ""))

	if _cloud_qa_button != null:
		var cloud_busy: bool = false
		if _cloud_qa_probe != null and is_instance_valid(_cloud_qa_probe):
			var cloud_status: Dictionary = _cloud_qa_probe.call("get_preview_status")
			cloud_busy = bool(cloud_status.get("busy", false))
		_cloud_qa_button.disabled = not native_ready or not signed_in or busy or cloud_busy
		if signed_in != _cloud_qa_last_signed_in:
			_cloud_qa_status.text = (
				_local("Ready for a read-only Firestore check. No progress will be uploaded.",
					"Siap memeriksa Firestore tanpa menulis. Tidak ada progres yang diunggah.")
				if signed_in else _local("Sign in with Google to check Firestore access.",
					"Masuk dengan Google untuk menguji akses Firestore.")
			)
			_cloud_qa_last_signed_in = signed_in

	if _capture_qa_button != null:
		_capture_qa_button.disabled = not native_ready or not signed_in or busy
		if signed_in != _capture_qa_last_signed_in:
			_capture_qa_status.text = (
				_local(
					"Ready to check six local domains. No cloud backup will be created.",
					"Siap memeriksa enam domain lokal. Tidak membuat backup cloud."
				)
				if signed_in else _local(
					"Sign in with Google to inspect local memory. This is NOT a backup.",
					"Masuk dengan Google untuk memeriksa memori lokal. Ini BUKAN backup."
				)
			)
			_capture_qa_last_signed_in = signed_in

	_action.disabled = busy or not native_ready
	if busy:
		_status.text = _local(
			"Connecting with Google..." if current_operation == "sign_in" else "Signing out...",
			"Menghubungkan Google..." if current_operation == "sign_in" else "Keluar dari akun..."
		)
		_status.add_theme_color_override("font_color", GOLD)
		_action.text = _local("PLEASE WAIT", "MOHON TUNGGU")
	elif signed_in:
		_status.text = _local("CONNECTED  •  ", "TERHUBUNG  •  ") + display_name
		_status.add_theme_color_override("font_color", JADE)
		_action.text = _local("SIGN OUT OF GOOGLE", "KELUAR DARI GOOGLE")
	elif native_ready:
		_status.text = _local("GUEST  •  ", "TAMU  •  ") + status_message
		_status.add_theme_color_override("font_color", MUTED)
		_action.text = _local("CONTINUE WITH GOOGLE", "MASUK DENGAN GOOGLE")
	else:
		# Keep the provider's specific, non-sensitive failure reason visible.
		# This separates Desktop-only mode, missing native AAR, and missing
		# Firebase autoload without requiring Android logcat or console access.
		_status.text = status_message if not status_message.is_empty() else _local(
			"Google Login requires a configured Android build.",
			"Login Google memerlukan build Android yang telah dikonfigurasi."
		)
		_status.add_theme_color_override("font_color", MUTED)
		_action.text = _local("GOOGLE SIGN-IN UNAVAILABLE", "LOGIN GOOGLE BELUM TERSEDIA")

	var normal: StyleBoxFlat = _button_style(_action.disabled, signed_in)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.10)
	_action.add_theme_stylebox_override("normal", normal)
	_action.add_theme_stylebox_override("hover", hover)
	_action.add_theme_stylebox_override("focus", hover)
	_action.add_theme_stylebox_override("pressed", pressed)
	_action.add_theme_stylebox_override("disabled", _button_style(true, signed_in))
	var foreground: Color = IVORY if signed_in or _action.disabled else Color(0.08, 0.13, 0.14, 1.0)
	_action.add_theme_color_override("font_color", foreground)
	_action.add_theme_color_override("font_hover_color", GOLD if signed_in else foreground)
	_action.add_theme_color_override("font_pressed_color", foreground)
	_action.add_theme_color_override("font_disabled_color", MUTED)


func _on_action_pressed() -> void:
	var screen: Node = get_tree().current_scene
	if screen != null and bool(screen.get("_scroll_gesture_active")):
		return
	var snapshot: Dictionary = GoogleAccountManager.get_account_snapshot()
	if bool(snapshot.get("busy", false)) or not bool(snapshot.get("native_ready", false)):
		return
	if bool(snapshot.get("signed_in", false)):
		GoogleAccountManager.request_sign_out()
	else:
		GoogleAccountManager.request_google_sign_in()


func _on_cloud_qa_pressed() -> void:
	# Same scroll-gesture guard as the Google Sign-In / Sign-Out button.
	var screen: Node = get_tree().current_scene
	if screen != null and bool(screen.get("_scroll_gesture_active")):
		return
	var snapshot: Dictionary = GoogleAccountManager.get_account_snapshot()
	if not bool(snapshot.get("signed_in", false)) or bool(snapshot.get("busy", false)):
		return
	if _cloud_qa_probe == null or not is_instance_valid(_cloud_qa_probe):
		_cloud_qa_probe = GoogleAccountManager.get_cloud_save_probe()
		if _cloud_qa_probe == null:
			_cloud_qa_status.text = _local(
				"Cloud probe is unavailable; local progress is unchanged.",
				"Pemeriksaan cloud tidak tersedia; progres lokal tidak berubah."
			)
			return
		var callback: Callable = Callable(self, "_on_cloud_qa_state_changed")
		if not _cloud_qa_probe.is_connected(&"preview_state_changed", callback):
			_cloud_qa_probe.connect(&"preview_state_changed", callback)
	if not bool(_cloud_qa_probe.call("request_preview")):
		_on_cloud_qa_state_changed(_cloud_qa_probe.call("get_preview_status"))


func _on_cloud_qa_state_changed(preview: Dictionary) -> void:
	if _cloud_qa_button == null or not is_inside_tree():
		return
	var state: String = str(preview.get("state", ""))
	match state:
		"checking":
			_cloud_qa_status.text = _local(
				"Reading this account's Firestore metadata… No upload or restore.",
				"Membaca metadata Firestore akun ini… Tanpa unggah atau pemulihan."
			)
		"no_manifest":
			_cloud_qa_status.text = _local(
				"Firestore responded: no manifest found. Cloud backup is NOT active; server freshness is unverified.",
				"Firestore merespons: manifest tidak ditemukan. Backup cloud BELUM aktif; data belum diverifikasi dari server."
			)
		"manifest_found":
			_cloud_qa_status.text = _local(
				"Manifest metadata read. Backup/restore and server freshness are NOT verified.",
				"Metadata manifest terbaca. Backup/pemulihan dan data terbaru dari server BELUM terverifikasi."
			)
		"unavailable":
			_cloud_qa_status.text = _local(
				"Firestore read unavailable. Check Android network and Firestore access rules. Local saves are safe.",
				"Pembacaan Firestore gagal. Periksa jaringan dan izin Firestore. Save lokal aman."
			)
		"timeout":
			_cloud_qa_status.text = _local(
				"Read timed out. Restart the app before another probe. No saves were changed.",
				"Pembacaan terlalu lama. Buka ulang game sebelum mencoba lagi. Save tidak berubah."
			)
		"invalid":
			_cloud_qa_status.text = _local(
				"Unsupported cloud metadata; no restore performed.",
				"Metadata cloud tidak kompatibel; tidak ada pemulihan yang dilakukan."
			)
		"account_changed", "guest":
			_cloud_qa_status.text = _local(
				"Signed out or account changed; prior cloud result discarded.",
				"Akun keluar atau berubah; hasil pembacaan sebelumnya dibatalkan."
			)
		_:
			_cloud_qa_status.text = _local(
				"No cloud backup is active. Check status again if necessary.",
				"Belum ada backup cloud yang aktif. Periksa lagi jika diperlukan."
			)
	var snapshot: Dictionary = GoogleAccountManager.get_account_snapshot()
	_cloud_qa_button.disabled = (
		bool(snapshot.get("busy", false))
		or not bool(snapshot.get("signed_in", false))
		or not bool(snapshot.get("native_ready", false))
		or bool(preview.get("busy", false))
	)


func _on_capture_qa_pressed() -> void:
	# Avoid accidental capture on swipe; this is NEVER available in release.
	if not OS.has_feature("android") or not OS.is_debug_build():
		return
	if _capture_qa_button == null or _capture_qa_status == null:
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
		_capture_qa_status.text = _local(
			"A connected Google account is required. No data was captured.",
			"Akun Google harus terhubung. Tidak ada data yang diambil."
		)
		return

	# The helper reads six manager dictionaries synchronously in memory. The
	# returned draft contains player data: NEVER log/store/render/transfer it.
	var capture_helper: RefCounted = SnapshotCaptureScript.new() as RefCounted
	if capture_helper == null:
		_capture_qa_status.text = _local(
			"Capture helper unavailable. Local data was not changed.",
			"Modul capture tidak tersedia. Data lokal tidak diubah."
		)
		return
	var result: Dictionary = capture_helper.call("capture_current_account_preview")
	var valid: bool = bool(result.get("valid", false))
	var reason: String = str(result.get("reason", "invalid_snapshot"))
	# Drop the raw UID/gameplay draft before updating anything on the UI.
	result.clear()
	if valid:
		_capture_qa_status.text = _local(
			"Six-domain structural check passed in memory. NOT uploaded, saved, or backed up.",
			"Struktur enam domain lolos pemeriksaan memori. TIDAK diunggah, disimpan, atau dicadangkan."
		)
	elif reason in ["active_run", "active_checkpoint", "active_run_loadout", "gameplay_scene"]:
		_capture_qa_status.text = _local(
			"Capture safely blocked: a run/checkpoint is active. Finish the run normally; do not delete saves.",
			"Capture ditolak dengan aman: run/checkpoint masih aktif. Selesaikan run seperti biasa; jangan hapus save."
		)
	elif reason in ["pending_transaction", "save_write_blocked", "scene_transition"]:
		_capture_qa_status.text = _local(
			"Capture safely blocked: save or scene transition is busy. Try again from Home.",
			"Capture ditolak dengan aman: save atau perpindahan scene masih sibuk. Coba lagi dari Home."
		)
	elif reason in ["not_authenticated", "invalid_identity", "account_changed"]:
		_capture_qa_status.text = _local(
			"Capture safely blocked: account identity changed. Reconnect Google before retrying.",
			"Capture ditolak dengan aman: identitas akun berubah. Hubungkan ulang Google sebelum mencoba."
		)
	else:
		# A structural rejection is actionable QA, not a reason to edit saves.
		# The diagnostic code is allowlisted from the local validator, not raw data.
		_capture_qa_status.text = _local(
			"Capture rejected by snapshot validation (" + reason + "). No data was changed.",
			"Capture ditolak validasi snapshot (" + reason + "). Tidak ada data yang diubah."
		)
