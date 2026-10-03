extends Control

## Optional first-entry identity screen. GoogleAccountManager owns auth state.
## Signed-in Firebase sessions bypass this screen; signed-out players may choose
## Google or Guest on each fresh launch. No gameplay SaveManager or currency API
## is touched.
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const GOLD: Color = Color(0.99, 0.80, 0.42, 1.0)
const JADE: Color = Color(0.30, 0.90, 0.75, 1.0)
const IVORY: Color = Color(0.94, 0.97, 0.94, 1.0)
const MUTED: Color = Color(0.72, 0.81, 0.78, 1.0)

@onready var eyebrow_label: Label = %EyebrowLabel
@onready var brand_label: Label = %BrandLabel
@onready var panel_eyebrow: Label = %PanelEyebrow
@onready var panel_title: Label = %PanelTitle
@onready var panel_description: Label = %PanelDescription
@onready var account_status: Label = %AccountStatus
@onready var google_button: Button = %GoogleButton
@onready var guest_button: Button = %GuestButton
@onready var privacy_note: Label = %PrivacyNote
@onready var login_panel: PanelContainer = %LoginPanel

var _moving_to_home: bool = false


func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)
	google_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	guest_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	google_button.pressed.connect(_on_google_pressed)
	guest_button.pressed.connect(_on_guest_pressed)
	GoogleAccountManager.account_state_changed.connect(_on_account_state_changed)
	_apply_copy()
	_apply_presentation()
	GoogleAccountManager.refresh_provider()
	_on_account_state_changed(GoogleAccountManager.get_account_snapshot())
	# An existing restored session bypasses this screen without requiring a tap.
	if not SettingsManager.reduced_effects:
		_play_intro()


func _exit_tree() -> void:
	if GoogleAccountManager.account_state_changed.is_connected(
		_on_account_state_changed
	):
		GoogleAccountManager.account_state_changed.disconnect(
			_on_account_state_changed
		)


func _local(en: String, id: String) -> String:
	return id if SettingsManager.language == "id" else en


func _apply_copy() -> void:
	eyebrow_label.text = "YUNG DEV STUDIO  ·  CELESTIAL REALMS"
	brand_label.text = "JADE ASCENDANT"
	panel_eyebrow.text = _local("THE CELESTIAL GATE", "GERBANG LANGIT")
	panel_title.text = _local("Begin Your Ascension", "Awali Perjalananmu")
	panel_description.text = _local(
		"Choose how you enter the realm. Your cultivation journey awaits.",
		"Pilih cara masuk ke dunia kultivasi. Perjalananmu menanti."
	)
	privacy_note.text = _local(
		"Google Login does not back up your progress. Cloud Save is not available yet.",
		"Login Google belum mencadangkan progres. Cloud Save belum tersedia."
	)


func _apply_presentation() -> void:
	login_panel.add_theme_stylebox_override(
		"panel", _panel_style()
	)
	_apply_button_style(google_button, true)
	_apply_button_style(guest_button, false)


func _panel_style() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.004, 0.027, 0.041, 0.965)
	panel.set_border_width_all(2)
	panel.border_width_bottom = 3
	panel.border_color = Color(0.91, 0.75, 0.40, 0.87)
	panel.set_corner_radius_all(18)
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	panel.shadow_size = 13
	return panel


func _apply_button_style(button: Button, is_google: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(11)
	normal.set_border_width_all(2)
	normal.content_margin_left = 13.0
	normal.content_margin_right = 13.0
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0
	normal.bg_color = (
		Color(0.95, 0.95, 0.92, 1.0)
		if is_google else Color(0.008, 0.105, 0.110, 1.0)
	)
	normal.border_color = GOLD if is_google else JADE
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	hover.bg_color = (
		Color(1.0, 0.97, 0.87, 1.0)
		if is_google else Color(0.017, 0.15, 0.14, 1.0)
	)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.14)
	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.080, 0.13, 0.14, 0.98)
	disabled.border_color = Color(0.33, 0.45, 0.43, 0.70)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	var foreground: Color = Color(0.08, 0.13, 0.13, 1.0) if is_google else IVORY
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground if is_google else GOLD)
	button.add_theme_color_override("font_pressed_color", foreground)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_font_size_override("font_size", 18)


func _on_account_state_changed(snapshot: Dictionary) -> void:
	if _moving_to_home or not is_inside_tree():
		return
	if bool(snapshot.get("signed_in", false)):
		_continue_home.call_deferred()
		return

	var native_available: bool = bool(snapshot.get("native_ready", false))
	var operation_busy: bool = bool(snapshot.get("busy", false))
	google_button.disabled = operation_busy or not native_available
	guest_button.disabled = operation_busy
	google_button.text = (
		_local("CONNECTING...", "MENGHUBUNGKAN...")
		if operation_busy
		else _local("CONTINUE WITH GOOGLE", "MASUK DENGAN GOOGLE")
	)
	guest_button.text = _local("PLAY AS GUEST", "MAIN SEBAGAI TAMU")
	if operation_busy:
		account_status.text = _local(
			"Connecting to your Google account...",
			"Sedang menghubungkan akun Google..."
		)
	elif not native_available:
		account_status.text = _local(
			"Google Login is unavailable in this build. Guest mode remains available.",
			"Login Google belum tersedia di build ini. Mode tamu tetap bisa dimainkan."
		)
	else:
		var current_status: String = str(snapshot.get("status", ""))
		if current_status.begins_with("Google sign-in failed") or current_status.begins_with("Google did not respond"):
			account_status.text = _local(
				"Google Login was not completed. Retry or play as Guest.",
				"Login Google belum selesai. Coba lagi atau main sebagai Tamu."
			)
		else:
			account_status.text = _local(
				"Google account or Guest • no forced sign-in.",
				"Akun Google atau Tamu • login tidak diwajibkan."
			)
	account_status.add_theme_color_override(
		"font_color", GOLD if operation_busy else MUTED
	)


func _on_google_pressed() -> void:
	if _moving_to_home:
		return
	var snapshot: Dictionary = GoogleAccountManager.get_account_snapshot()
	if bool(snapshot.get("busy", false)) or not bool(snapshot.get("native_ready", false)):
		return
	GoogleAccountManager.request_google_sign_in()


func _on_guest_pressed() -> void:
	if _moving_to_home:
		return
	var snapshot: Dictionary = GoogleAccountManager.get_account_snapshot()
	if bool(snapshot.get("busy", false)):
		return
	_continue_home()


func _continue_home() -> void:
	if _moving_to_home or not is_inside_tree():
		return
	_moving_to_home = true
	google_button.disabled = true
	guest_button.disabled = true
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		MAIN_MENU_SCENE, 1
	)
	if change_error == OK:
		return
	_moving_to_home = false
	push_warning(
		"Account entry: Home transition failed (error %d)." % int(change_error)
	)
	# The existing Main Menu stays reachable even when the cosmetic transition
	# fails. Never lock a Guest out of their device-local save.
	if change_error == ERR_BUSY:
		var snapshot: Dictionary = GoogleAccountManager.get_account_snapshot()
		google_button.disabled = (
			bool(snapshot.get("busy", false))
			or not bool(snapshot.get("native_ready", false))
		)
		guest_button.disabled = bool(snapshot.get("busy", false))
		account_status.text = _local(
			"Finishing another transition. Please try again.",
			"Transisi lain masih berlangsung. Silakan coba lagi."
		)
		return
	var fallback_error: Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if fallback_error != OK:
		google_button.disabled = false
		guest_button.disabled = false
		account_status.text = _local(
			"Unable to open Home. Please try again.",
			"Gagal membuka Beranda. Silakan coba lagi."
		)


func handle_system_back() -> void:
	if _moving_to_home or SceneTransitionManager.is_transitioning:
		return
	# Back exits this optional welcome screen; it never silently links or
	# replaces the current device-local save.
	get_tree().quit()


func _play_intro() -> void:
	var panel_alpha: float = login_panel.modulate.a
	login_panel.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(login_panel, "modulate:a", panel_alpha, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
