extends PanelContainer

## Small, additive Account card for the already-approved Settings screen.
## Injected by GoogleAccountManager when Settings becomes the active scene.
## No Google credentials, tokens or gameplay save fields are stored here.

const GOLD: Color = Color(0.99, 0.80, 0.42, 1.0)
const JADE: Color = Color(0.23, 0.89, 0.76, 1.0)
const IVORY: Color = Color(0.95, 0.97, 0.92, 1.0)
const MUTED: Color = Color(0.76, 0.85, 0.81, 1.0)

var _status: Label
var _action: Button
var _footer: Label


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

	GoogleAccountManager.account_state_changed.connect(_refresh)
	_refresh(GoogleAccountManager.get_account_snapshot())


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
		_status.text = _local(
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
