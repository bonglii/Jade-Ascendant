extends Control

const PUBLISHER_INFO_PATH: String = "res://release/publisher_info.cfg"
const MonetizationLocalization = preload(
	"res://scripts/monetization/monetization_localization.gd"
)

var privacy_url: String = ""
var support_email: String = ""
const TRUST_POLICY_URL: String = "https://jade-ascendant-player.jade-ascendant-studio.workers.dev/privacy-policy.html"
const ACCOUNT_DELETION_URL: String = "https://jade-ascendant-player.jade-ascendant-studio.workers.dev/account-deletion.html"
var _ad_privacy_button: Button
var _link_feedback: Label


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
	privacy_url = TRUST_POLICY_URL
	var publisher: String = str(config.get_value("publisher", "name", ""))

	var hero: VBoxContainer = _card(content, Color(0.32, 0.90, 0.78), true)
	_label(hero, tr("PLAYER TRUST"), 12, Color(0.34, 0.92, 0.80))
	_label(hero, tr("Privacy & Support"), 27, Color(0.98, 0.83, 0.43))
	_label(
		hero,
		_local("Your data. Your account. Your choices.", "Data Anda. Akun Anda. Pilihan Anda."),
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

	_add_section(content, _local("PROGRESS & BACKUP", "PROGRESS & BACKUP"), _local("Local play, optional cloud backup", "Bermain lokal, backup cloud opsional"), _local("Progress is saved on this device. After Google sign-in, choose Save in Cloud backup to enable nine-domain server backups and automatic menu updates. Restore is always your choice; Google sign-in alone does not upload progress.", "Progress tersimpan di perangkat. Setelah login Google, pilih Simpan pada Cloud backup untuk mengaktifkan backup sembilan bagian progress ke server serta pembaruan otomatis saat di menu. Pemulihan selalu pilihan Anda; login saja tidak mengunggah progress."))
	_add_section(content, _local("OPTIONAL GOOGLE SIGN-IN", "LOGIN GOOGLE OPSIONAL"), _local("Identity, profile and server mail", "Identitas, profil, dan surat server"), _local("Guest play is available. Google/Firebase identify your account. Our profile service stores an account binding, a separate public UID, mail/read/claim records and recent activity to provide your connected features. Signing out does not delete server data.", "Mode tamu tersedia. Google/Firebase memverifikasi akun Anda. Layanan profil menyimpan pengikat akun, UID publik terpisah, catatan surat/baca/klaim serta aktivitas terbaru untuk fitur online. Logout tidak menghapus data server."))
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
	_add_section(content, tr("GOOGLE PLAY PURCHASES"), _local("Verified by the purchase server", "Diverifikasi server pembelian"), _local("Google Play processes payments. Our server verifies purchase state, delivers paid Jade/items, prevents duplicate credits and reconciles refunds. Paid state reloads from that service, independently of offline progress backup. We do not receive full card details.", "Google Play memproses pembayaran. Server kami memverifikasi status, mengirim Jade/item berbayar, mencegah kredit ganda, dan merekonsiliasi refund. Status berbayar dimuat dari layanan itu, terpisah dari backup progress offline. Kami tidak menerima rincian lengkap kartu."))
	_add_section(content, _local("ACCOUNT & DATA CONTROL", "KONTROL AKUN & DATA"), _local("Request account deletion", "Minta penghapusan akun"), _local("Use the request button below or our public deletion page, even after uninstalling. Support verifies ownership and aims to complete verified requests within 30 days. This is a request, not instant deletion. Profile, cloud backups, account mail and server gameplay are removed; limited financial/security evidence may be retained for fraud, disputes or legal obligations. Deletion does not delete your Google account or request a refund. Android app storage controls local files.", "Gunakan tombol permintaan di bawah atau halaman publik penghapusan, termasuk setelah game dicopot. Bantuan memverifikasi kepemilikan dan menargetkan penyelesaian dalam 30 hari. Ini permintaan, bukan penghapusan instan. Profil, backup cloud, surat akun, dan gameplay server dihapus; bukti keuangan/keamanan terbatas dapat dipertahankan untuk penipuan, sengketa, atau kewajiban hukum. Penghapusan tidak menghapus akun Google atau meminta refund. Penyimpanan aplikasi Android mengatur file lokal."))
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

	_button(actions, _local("REQUEST ACCOUNT DELETION", "MINTA PENGHAPUSAN AKUN"), _open_deletion_request, false)
	_button(actions, _local("EMAIL A DELETION REQUEST", "EMAIL PERMINTAAN PENGHAPUSAN"), _email_deletion_request, false)
	_button(actions, tr("AD PRIVACY OPTIONS"), _open_ad_privacy_options, false)
	_ad_privacy_button = actions.get_child(actions.get_child_count() - 1) as Button
	_refresh_privacy_access()
	var privacy_timer := Timer.new()
	privacy_timer.wait_time = 1.0
	privacy_timer.timeout.connect(_refresh_privacy_access)
	add_child(privacy_timer)
	privacy_timer.start()
	_link_feedback = Label.new()
	_link_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_link_feedback.add_theme_font_size_override("font_size", 13)
	_link_feedback.visible = false
	actions.add_child(_link_feedback)

	if privacy_url.begins_with("https://"):
		_button(
			actions,
			tr("OPEN PRIVACY POLICY"),
			func() -> void: _open_external(privacy_url),
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
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
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

func _local(english: String, indonesian: String) -> String:
	return indonesian if SettingsManager.language == "id" else english

func _refresh_privacy_access() -> void:
	if _ad_privacy_button != null:
		_ad_privacy_button.visible = MonetizationManager.privacy_options_required()
		_ad_privacy_button.disabled = MonetizationManager.active_request >= 0 or bool(MonetizationManager.get_provider_runtime_status().get("privacy_form_open", false))

func _open_external(url: String) -> void:
	if OS.shell_open(url) != OK and _link_feedback != null:
		_link_feedback.text = _local("Unable to open an external app. Contact ", "Aplikasi eksternal belum bisa dibuka. Hubungi ") + support_email + " — " + ACCOUNT_DELETION_URL
		_link_feedback.visible = true

func _open_deletion_request() -> void:
	_open_external(ACCOUNT_DELETION_URL)

func deletion_request_email_url() -> String:
	# User reviews/sends their own draft. Never append private UID, token or save data.
	var subject: String = "Jade Ascendant - Account deletion request"
	var body: String = "Please delete my Jade Ascendant game account and associated data.\n\nI am sending from the Google email used for the game.\nPublic UID (optional, if known):\n\nPlease explain any financial/security data that must be retained."
	return "mailto:" + support_email + "?subject=" + subject.uri_encode() + "&body=" + body.uri_encode()

func _email_deletion_request() -> void:
	_open_external(deletion_request_email_url())
	if _link_feedback != null:
		_link_feedback.text = _local("Send the draft from your Google game email to ", "Kirim draf dari email Google game Anda ke ") + support_email + _local(". Nothing is submitted until you send it. Never send passwords or tokens.", ". Permintaan belum dikirim sampai Anda mengirimnya. Jangan kirim password atau token.")
		_link_feedback.visible = true
