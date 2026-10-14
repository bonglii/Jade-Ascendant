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

const GATE_ART: String="res://assets/ui/account_gate/imperial_v1/"
var _moving_to_home: bool = false
var _layout_pending: bool=false
@onready var _safe: Control=$SafeArea
@onready var _brand: VBoxContainer=$SafeArea/Brand
@onready var _logo: TextureRect=$SafeArea/Brand/Wordmark
@onready var _panel_content: VBoxContainer=%PanelContent



func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)
	google_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	guest_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	google_button.pressed.connect(_on_google_pressed)
	guest_button.pressed.connect(_on_guest_pressed)
	GoogleAccountManager.account_state_changed.connect(_on_account_state_changed)
	resized.connect(_queue_layout)
	_safe.resized.connect(_queue_layout)
	login_panel.minimum_size_changed.connect(_queue_layout)
	_apply_copy()
	_apply_presentation()
	_layout_gate()
	_queue_layout()
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
	eyebrow_label.text = _local("Walk the path to immortality", "Menapaki jalan keabadian")
	brand_label.hide()
	panel_eyebrow.hide()
	panel_title.text = _local("Your journey begins", "Perjalananmu dimulai")
	panel_description.text = _local("Enter the realm and begin your cultivation.", "Masuki dunia dan awali kultivasimu.")
	privacy_note.text = _local("Progress is saved on this device.", "Progres tersimpan di perangkat ini.")
	privacy_note.tooltip_text = _local("Google login links your identity. Cloud Save is not available yet.", "Login Google menghubungkan identitas. Cloud Save belum tersedia.")

func _skin(file: String, panel: bool=false) -> StyleBoxTexture:
	var style:=StyleBoxTexture.new()
	style.texture=load(GATE_ART+"panel.svg") if panel else load(GATE_ART+"jade_button.png")
	if not panel:
		if file=="disabled":style.modulate_color=Color(.37,.49,.51,.94)
		elif file.begins_with("secondary"):style.modulate_color=Color(.50,.70,.76)
		elif file.ends_with("hover"):style.modulate_color=Color(1.13,1.13,1.06)
		elif file.ends_with("pressed"):style.modulate_color=Color(.66,.79,.76)
	if file=="secondary_pressed":style.modulate_color=Color(.35,.52,.58)
	for edge: String in ["left","right","top","bottom"]:
		style.set("texture_margin_"+edge,42 if panel else (16 if edge in ["left","right"] else 12))
		style.set("content_margin_"+edge,18 if panel else (24 if edge in ["left","right"] else 8))
	return style

func _apply_presentation() -> void:
	var serif:=SystemFont.new()
	serif.font_names=PackedStringArray(["Noto Serif","DejaVu Serif"])
	panel_title.add_theme_font_override("font",serif)
	eyebrow_label.add_theme_font_override("font",serif)
	login_panel.add_theme_stylebox_override("panel",_skin("panel",true))
	_style_button(guest_button,true)
	_style_button(google_button,false)

func _style_button(button: Button, primary: bool) -> void:
	var prefix: String="primary" if primary else "secondary"
	for state: String in ["normal","hover","pressed"]:
		button.add_theme_stylebox_override(state,_skin(prefix+"_"+state))
	button.add_theme_stylebox_override("focus",_skin(prefix+"_hover"))
	button.add_theme_stylebox_override("disabled",_skin("disabled"))
	button.add_theme_color_override("font_color",GOLD if primary else IVORY)
	button.add_theme_color_override("font_hover_color",Color(1,.95,.75))
	button.add_theme_color_override("font_pressed_color",GOLD)
	button.add_theme_color_override("font_disabled_color",Color(.60,.70,.69))

func _queue_layout() -> void:
	if _layout_pending:return
	_layout_pending=true
	_layout_gate.call_deferred()

func _layout_gate() -> void:
	_layout_pending=false
	if not is_node_ready():return
	var available: Vector2=_safe.size
	var landscape: bool=available.x>available.y*1.25
	var unit: float=clampf(minf(available.x/390.0,available.y/844.0),.83,1.24)
	var margin: float=clampf(available.x*.04,12,28)
	var panel_width: float=minf(available.x-margin*2,580)
	if landscape:panel_width=minf(available.x*.48,540)
	_panel_content.add_theme_constant_override("separation",roundi(9*unit))
	for pair: Array in [[panel_title,25],[panel_description,15],[account_status,13],[privacy_note,12],[eyebrow_label,17]]:
		var font_size: int=roundi(float(pair[1])*unit)
		if pair[0].get_theme_font_size("font_size")!=font_size:pair[0].add_theme_font_size_override("font_size",font_size)
	for button: Button in [google_button,guest_button]:
		button.custom_minimum_size=Vector2(0,maxf(48,58*unit))
		button.add_theme_font_size_override("font_size",maxi(14,roundi((15 if button==google_button else 17)*unit)))
	account_status.custom_minimum_size=Vector2.ZERO
	login_panel.size.x=panel_width
	# Stable width before measuring wrapped copy. No scale/font entrance tween.
	var natural: float=login_panel.get_combined_minimum_size().y
	login_panel.size=Vector2(panel_width,natural)
	var footer_height: float=36*unit
	var panel_x: float=(available.x-panel_width)*.5 if not landscape else available.x-panel_width-margin
	var panel_y: float=available.y-natural-footer_height-margin if not landscape else (available.y-natural-footer_height)*.5
	login_panel.position=Vector2(panel_x,maxf(margin,panel_y))
	privacy_note.position=Vector2(panel_x,login_panel.position.y+natural+8*unit)
	privacy_note.size=Vector2(panel_width,footer_height-8*unit)
	_brand.position=Vector2(margin,margin)
	_brand.size.x=available.x-margin*2 if not landscape else panel_x-margin*2
	var logo_height: float=clampf(available.y*.24,95,280) if not landscape else minf(available.y*.46,230)
	_logo.custom_minimum_size=Vector2(0,logo_height)
	_brand.add_theme_constant_override("separation",4*unit)
	_brand.size.y=logo_height+30*unit
	if landscape:_brand.position.y=maxf(margin,(available.y-_brand.size.y)*.28)

func _on_account_state_changed(snapshot: Dictionary) -> void:
	if _moving_to_home or not is_inside_tree():
		return
	if bool(snapshot.get("signed_in", false)):
		_continue_home.call_deferred()
		return

	var native_available: bool = bool(snapshot.get("native_ready", false))
	var operation_busy: bool = bool(snapshot.get("busy", false))
	google_button.disabled = operation_busy or not native_available
	_style_button(google_button,native_available)
	_style_button(guest_button,not native_available)
	_panel_content.move_child(google_button if native_available else guest_button,3)
	_panel_content.move_child(guest_button if native_available else google_button,4)
	var preparing_guest: bool = operation_busy and str(snapshot.get("operation", "")) == "anonymous_identity"
	guest_button.disabled = operation_busy and not preparing_guest
	google_button.text = (
		_local("CONNECTING...", "MENGHUBUNGKAN...")
		if operation_busy
		else _local("CONTINUE WITH GOOGLE", "MASUK DENGAN GOOGLE")
	)
	guest_button.text = _local("PLAY AS GUEST", "MAIN SEBAGAI TAMU")
	if preparing_guest:
		account_status.text = _local("Preparing player identity. You can play as Guest now.", "Menyiapkan identitas pemain. Lu sudah bisa main sebagai Tamu.")
	elif operation_busy:
		account_status.text = _local(
			"Connecting to your Google account...",
			"Sedang menghubungkan akun Google..."
		)
	elif not native_available:
		account_status.text = _local(
			"Google login is unavailable in this build.",
			"Login Google belum tersedia di build ini."
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
				"Choose Google or play as Guest.",
				"Pilih Google atau main sebagai Tamu."
			)
	_queue_layout()
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
	if bool(snapshot.get("busy", false)) and str(snapshot.get("operation", "")) != "anonymous_identity":
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
