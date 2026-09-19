extends Control

const PUBLISHER_INFO_PATH: String = "res://release/publisher_info.cfg"
const MonetizationLocalization = preload(
	"res://scripts/monetization/monetization_localization.gd"
)

var privacy_url: String = ""
var support_email: String = ""


func _ready() -> void:
	MonetizationLocalization.install()
	SceneTransitionManager.set_back_handler(_back)
	_configure_backdrop()
	var scroll: ScrollContainer = $SafeArea/Scroll
	var content: VBoxContainer = $SafeArea/Scroll/Content
	_configure_scroll_surface(scroll, content)
	var config: ConfigFile = ConfigFile.new()
	if config.load(PUBLISHER_INFO_PATH) == OK:
		privacy_url = str(config.get_value("publisher", "privacy_url", ""))
		support_email = str(config.get_value("publisher", "support_email", ""))
	var publisher: String = str(config.get_value("publisher", "name", ""))

	var hero: VBoxContainer = _card(content, Color(0.32, 0.90, 0.78), true)
	_label(hero, tr("PLAYER TRUST"), 12, Color(0.34, 0.92, 0.80))
	_label(hero, tr("Privacy & Support"), 27, Color(0.98, 0.83, 0.43))
	_label(
		hero,
		tr("Your progress stays on your device."),
		15,
		Color(0.82, 0.90, 0.87)
	)
	_label(
		hero,
		"Jade Ascendant"
		+ ("  •  " + publisher if not publisher.is_empty() else ""),
		12,
		Color(0.64, 0.75, 0.72)
	)

	_add_section(
		content,
		tr("LOCAL GAME SAVE"),
		tr("What stays on device"),
		tr(
			"Progress, equipment, achievements, daily trials, run checkpoints, "
			+ "and preferences are stored locally. Jade Ascendant has no player "
			+ "account or cloud save."
		)
	)
	_add_section(
		content,
		tr("OPTIONAL REWARDED ADS"),
		tr("Google Mobile Ads & privacy"),
		tr(
			"On Android, optional rewarded ads use Google Mobile Ads. Google "
			+ "may process IP address, ad or device identifiers, ad interactions, "
			+ "and diagnostic information for advertising, analytics, and fraud "
			+ "prevention. UMP may present privacy choices where required."
		)
	)
	_add_section(
		content,
		tr("PLAYER-FIRST ECONOMY"),
		tr("Optional means optional"),
		tr(
			"Rewarded ads are optional. No gameplay progress is removed for "
			+ "declining or not completing an ad, and a reward is granted only "
			+ "after the ad confirms completion."
		)
	)
	_add_section(
		content,
		tr("DATA CONTROL"),
		tr("Deleting your data"),
		tr(
			"Local progress can be removed from Android app storage or by "
			+ "uninstalling the game. Advertising and consent data handled by "
			+ "Google is governed separately by Google's services and your "
			+ "applicable privacy choices."
		)
	)
	_add_section(
		content,
		tr("OPTIONAL FEEDBACK"),
		tr("Vibration"),
		tr(
			"Vibration can be enabled in Settings. It only provides feedback "
			+ "during combat and does not collect data."
		)
	)
	_add_section(
		content,
		tr("EXTERNAL APPS"),
		tr("Links & support"),
		tr(
			"Opening the policy or support link uses an external browser or "
			+ "email app. Information you choose to send for support is handled "
			+ "by the publisher under the published privacy policy."
		)
	)

	var actions: VBoxContainer = _card(
		content,
		Color(0.96, 0.78, 0.34),
		false
	)
	_label(actions, tr("SUPPORT"), 12, Color(0.96, 0.78, 0.34))

	if MonetizationManager.privacy_options_required():
		_label(
			actions,
			tr(
				"Privacy choices are provided by Google UMP when required for "
				+ "this device or region."
			),
			13,
			Color(0.72, 0.84, 0.80)
		)
		_button(
			actions,
			tr("AD PRIVACY OPTIONS"),
			_open_ad_privacy_options,
			false
		)

	if privacy_url.begins_with("https://"):
		_button(
			actions,
			tr("OPEN PRIVACY POLICY"),
			func() -> void: OS.shell_open(privacy_url),
			false
		)
	if support_email.contains("@") and not support_email.contains("\n"):
		_button(
			actions,
			tr("CONTACT SUPPORT"),
			func() -> void:
				OS.shell_open(
					"mailto:"
					+ support_email
					+ "?subject=Jade%20Ascendant%20Support"
				),
			false
		)
	_button(actions, tr("CREDITS & LICENSES"), _open_credits, false)
	_button(actions, tr("BACK TO SETTINGS"), _back, true)


func _configure_scroll_surface(
	scroll: ScrollContainer,
	content: VBoxContainer
) -> void:
	# The outer ScrollContainer owns swipe gestures on both Android and desktop.
	# Runtime-built cards must never form an input wall in front of it.
	scroll.scroll_deadzone = 6
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	content.mouse_filter = Control.MOUSE_FILTER_PASS

func _configure_backdrop() -> void:
	var backdrop: Control = $Backdrop
	if backdrop != null and backdrop.has_method("apply_profile"):
		backdrop.call("apply_profile", {
			"sky_top": Color(0.003, 0.015, 0.028, 1.0),
			"sky_bottom": Color(0.010, 0.050, 0.064, 1.0),
			"mountain_far": Color(0.025, 0.095, 0.110, 0.78),
			"mountain_near": Color(0.008, 0.042, 0.052, 0.94),
			"mist": Color(0.30, 0.82, 0.82, 0.08),
			"moon": Color(0.90, 0.92, 0.90, 0.06),
			"accent": Color(0.34, 0.90, 0.80, 1.0),
			"gold": Color(0.96, 0.78, 0.34, 1.0)
		})


func _add_section(
	parent_node: Node,
	eyebrow: String,
	title: String,
	body: String
) -> void:
	var box: VBoxContainer = _card(
		parent_node,
		Color(0.28, 0.78, 0.72),
		false
	)
	_label(box, eyebrow, 12, Color(0.34, 0.88, 0.78))
	_label(box, title, 21, Color(0.96, 0.82, 0.45))
	_label(box, body, 14, Color(0.76, 0.85, 0.82))


func _card(
	parent_node: Node,
	accent: Color,
	hero: bool
) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(
		0.002,
		0.024,
		0.036,
		0.94 if hero else 0.90
	)
	style.border_width_left = 2 if hero else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.62 if hero else 0.34
	)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	parent_node.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _label(
	parent_node: Node,
	message: String,
	font_size: int = 13,
	tint: Color = Color(0.82, 0.88, 0.84)
) -> Label:
	var label: Label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent_node.add_child(label)
	return label


func _button(
	parent_node: Node,
	message: String,
	callback: Callable,
	primary: bool
) -> void:
	var button: Button = Button.new()
	button.text = message
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.custom_minimum_size.y = 48.0
	button.add_theme_font_size_override("font_size", 14)
	button.theme_type_variation = (
		&"JadePrimaryButton"
		if primary
		else &"JadeSecondaryButton"
	)
	button.pressed.connect(callback)
	parent_node.add_child(button)


func _open_ad_privacy_options() -> void:
	if not MonetizationManager.show_privacy_options():
		push_warning(
			"PrivacyScreen: Ad privacy options belum tersedia."
		)


func _open_credits() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		"res://scenes/ui/credits_screen.tscn",
		1
	)
	if change_error != OK:
		push_error(
			"PrivacyScreen: gagal membuka Credits. Error code: "
			+ str(change_error)
		)


func _back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		"res://scenes/ui/settings_screen.tscn",
		-1
	)
	if change_error != OK:
		push_error(
			"PrivacyScreen: gagal kembali ke Settings. Error code: "
			+ str(change_error)
		)
