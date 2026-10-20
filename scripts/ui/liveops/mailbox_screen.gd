extends Control

## SPIRIT MESSAGES — APPROVED MAIL PRODUCTION
## Presentation only. LiveOpsManager owns mail catalog, read/claimed ledger,
## save and authoritative claims. RewardManager owns reward transactions;
## shared Reward Delivery and Unified Claim Result presenters own feedback.
## Visual layout and artwork promoted from user-approved Mail LAB V2.11.

const EquipmentVisualCatalog = preload("res://scripts/ui/equipment_visual_catalog.gd")
const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")

const HOME_ART: Texture2D = preload(
	"res://assets/ui/main_menu/main_menu_key_art_lin_yue.png"
)
const MAIL_BACKGROUND: Texture2D = preload(
	"res://assets/ui/results/quiet/jade.svg"
)
const MAIL_FRAME: Texture2D = preload(
	"res://assets/ui/liveops/mail/spirit_messages_jade_frame.png"
)
const LETTER_PARCHMENT: Texture2D = preload(
	"res://assets/ui/results/quiet/paper.svg"
)
const SPIRIT_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)
const SHARD_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/refinement_shard_premium.png"
)
const HERO_EXP_ICON: Texture2D = preload(
	"res://assets/ui/equipment/polish/ascension_emblem.svg"
)
const GENERIC_REWARD_ICON: Texture2D = preload(
	"res://assets/ui/pavilion/icons/reward_chest.png"
)

const GOLD: Color = Color(0.92, 0.72, 0.32, 1.0)
const GOLD_LIGHT: Color = Color(1.0, 0.89, 0.62, 1.0)
const JADE: Color = Color(0.43, 0.91, 0.79, 1.0)
const IVORY: Color = Color(0.98, 0.98, 0.91, 1.0)
const MUTED: Color = Color(0.76, 0.84, 0.83, 1.0)
const INK: Color = Color(0.20, 0.15, 0.10, 1.0)
const PAPER_MUTED: Color = Color(0.48, 0.35, 0.22, 1.0)
const DEADZONE: int = 6
const TAP_GUARD_MS: int = 190
const INBOX_CARD_MIN_HEIGHT: float = 96.0
const INBOX_TITLE_MAX_LINES: int = 3
const INBOX_SENDER_MAX_LINES: int = 2
# Slightly expand the parchment into the unused visual gap beside the inbox.
const WIDE_READER_THRESHOLD: float = 760.0

var live_ops: Node = null
var _claim_busy: bool = false
var _mail_refresh_queued: bool = false
var _delete_all_button: Button
var _claim_all_button: Button
var _claim_batch: Node
var _inbox_signature: String=""
var _refreshing: bool = false
var _delete_button: Button = null
var _popup: Control = null
var _popup_safe: MarginContainer = null
var _hero: Control = null
var _compact_inbox_button: Button = null
var _compact_inbox_open: bool = true
var _body: Control = null
var _inbox_panel: PanelContainer = null
var _inbox_safe: MarginContainer
var _letter_panel: Control = null
var _inbox_scroll: ScrollContainer = null
var _inbox_list: VBoxContainer = null
var _inbox_count: Label = null
var _letter_subject: Label = null
var _letter_sender: Label = null
var _letter_body: RichTextLabel = null
var _reader_scroll: ScrollContainer = null
var _reader_content: VBoxContainer = null
var _letter_safe: MarginContainer = null
var _letter_footer: VBoxContainer = null
var _attachment_group: VBoxContainer = null
var _displayed_id: String = ""
var _document_signature: String = ""
var _reader_offsets: Dictionary = {}
var _reader_hint: Label = null
var _attachment_caption: Label = null
var _rewards_row: GridContainer = null
var _claim_button: Button = null
var _no_claim_hint: Label = null
var _footer_label: Label = null
var _server_status: Label = null
var _action_grid: GridContainer
var _mail_title: Label
var _mail_tagline: Label
var _selected_id: String = ""
var _scroll_active: bool = false
var _reader_dragging: bool = false
var _reader_tap_guard_until: int = 0
var _tap_guard_until: int = 0
var _pressed_scroll_y: Dictionary = {}
var _mail_card_refs: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	live_ops = get_node_or_null("/root/LiveOpsManager")
	if live_ops == null:
		push_error("MailboxScreen: LiveOpsManager tidak tersedia.")
		return

	# Home supplies its real wallet/nav. No LAB mock UI in production.
	if not bool(get_meta("liveops_popup", false)):
		_full_texture(self, HOME_ART, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_claim_batch=live_ops.get_node_or_null("MailboxClaimBatch")
	if _claim_batch==null:
		_claim_batch=preload("res://scripts/ui/liveops/mailbox_claim_batch.gd").new();_claim_batch.name="MailboxClaimBatch";_claim_batch.authority=live_ops;live_ops.add_child(_claim_batch)
	_claim_batch.changed.connect(_on_live_ops_changed)
	_build_home_scrim()
	_build_popup()
	_refresh_from_authority()

	var callback: Callable = Callable(self, "_on_live_ops_changed")
	if (
		live_ops.has_signal("live_ops_changed")
		and not live_ops.is_connected("live_ops_changed", callback)
	):
		live_ops.connect("live_ops_changed", callback)

	SceneTransitionManager.set_back_handler(_back)
	resized.connect(_fit_popup)
	call_deferred("_fit_popup")
	ServerMailManager.refresh(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		call_deferred("_refresh_from_authority")

func _build_home_scrim() -> void:
	var scrim := ColorRect.new()
	scrim.name = "SpiritMessagesHomeScrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.0, 0.005, 0.012, 0.64)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_background_input)
	add_child(scrim)


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_back()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_back()


func _build_popup() -> void:
	_popup = Control.new()
	_popup.name = "SpiritMessagesProductionPopup"
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_popup)

	var artwork := _full_texture(
		_popup, MAIL_BACKGROUND, TextureRect.STRETCH_SCALE
	)
	artwork.name = "ApprovedSpiritMessagesBackground"

	# Only the information zone is dimmed. Keep the approved illustration bright.
	var reading_scrim := ColorRect.new()
	reading_scrim.anchor_left = 0.0
	reading_scrim.anchor_top = 0.245
	reading_scrim.anchor_right = 1.0
	reading_scrim.anchor_bottom = 0.985
	reading_scrim.color = Color(0.0, 0.013, 0.023, 0.24)
	reading_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(reading_scrim)

	var safe := MarginContainer.new()
	safe.name = "PopupSafeInterior"
	_popup_safe = safe
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		safe.add_theme_constant_override("margin_" + side, 48)
	safe.add_theme_constant_override("margin_top", 54)
	safe.add_theme_constant_override("margin_bottom", 91)
	_popup.add_child(safe)

	var outer := VBoxContainer.new()
	outer.name = "MailPopupLayout"
	outer.add_theme_constant_override("separation", 8)
	safe.add_child(outer)

	_build_hero(outer)
	_build_mail_toolbar(outer)
	_build_two_column_body(outer)

	# Frame must be above all content, but transparent center must never eat input.
	var frame := _full_texture(_popup, MAIL_FRAME, TextureRect.STRETCH_SCALE)
	frame.name = "ApprovedJadeGoldOverlay"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.hide() # Quiet sheet background owns the border; no ornate overlay.
	frame.z_index = 5


func _build_hero(parent: VBoxContainer) -> void:
	_hero = PanelContainer.new()
	_hero.name = "SpiritMessagesArtHeader"
	_hero.add_theme_stylebox_override("panel", _style(Color(0.002,0.025,0.035,.94),Color(GOLD,.6),12,1))
	parent.add_child(_hero)
	var margin := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	_hero.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	margin.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",3)
	row.add_child(words)
	_mail_title = _label("SPIRIT MESSAGES",28,GOLD_LIGHT)
	_mail_title.name = "SpiritMessagesTitle"
	_mail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(_mail_title)
	_mail_tagline = _label("Messages from across the Cultivation World",14,MUTED)
	_mail_tagline.name = "HeaderTagline"
	_mail_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(_mail_tagline)
	var close := _button("×",false)
	close.name = "CloseSpiritMessages"
	close.custom_minimum_size = Vector2(42,42)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(_back)
	_popup.add_child(close)
	close.anchor_left = .92
	close.anchor_right = .92
	close.anchor_top = .083
	close.anchor_bottom = .083
	close.offset_left = -22
	close.offset_right = 22
	close.offset_top = -22
	close.offset_bottom = 22
	close.z_index = 6
	close.tooltip_text = tr("CLOSE")
	close.add_theme_font_size_override("font_size",26)
	for state: String in ["normal","hover","pressed"]: close.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	close.add_theme_color_override("font_color",GOLD_LIGHT)

func _build_mail_toolbar(parent: VBoxContainer) -> void:
	var toolbar := VBoxContainer.new()
	toolbar.name = "MailboxSyncToolbar"
	toolbar.add_theme_constant_override("separation",4)
	parent.add_child(toolbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	toolbar.add_child(row)
	_compact_inbox_button = _button("INBOX",false)
	_compact_inbox_button.name = "NarrowViewportInboxReaderToggle"
	_compact_inbox_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_inbox_button.pressed.connect(_toggle_compact_inbox)
	row.add_child(_compact_inbox_button)
	_claim_all_button=_button("CLAIM ALL",true);_claim_all_button.name="MailboxClaimAll";_claim_all_button.custom_minimum_size.y=48;_claim_all_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_claim_all_button.add_theme_font_size_override("font_size",14);_claim_all_button.pressed.connect(func()->void: _claim_batch.start());row.add_child(_claim_all_button)
	var clear_button: Button = _button("DELETE ALL",false)
	_delete_all_button = clear_button
	clear_button.name = "MailboxDeleteAllCompleted"
	clear_button.custom_minimum_size.y = 44
	clear_button.tooltip_text = tr("Deletes completed and expired mail. Unclaimed rewards are kept.")
	clear_button.pressed.connect(func() -> void:
		if _claim_batch.active: return
		_claim_batch.message = ""
		if bool(live_ops.delete_all_completed_mail()): _on_live_ops_changed()
	)
	toolbar.add_child(clear_button)
	_server_status = _label(ServerMailManager.get_status(),12,MUTED)
	_server_status.name = "MailboxServerStatus"
	_server_status.add_theme_stylebox_override("normal",_style(Color(0.002,0.02,0.028,.95),Color(GOLD,.3),6,1))
	_server_status.max_lines_visible = 2
	_server_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_server_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_server_status.tooltip_text = _server_status.text
	toolbar.add_child(_server_status)


func _build_two_column_body(parent: VBoxContainer) -> void:
	_body = Control.new()
	_body.name = "ResponsiveMailBody"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_body)

	_build_inbox_panel(_body)
	_build_parchment_panel(_body)
	_body.resized.connect(_layout_body)


func _build_inbox_panel(parent: Control) -> void:
	_inbox_panel = PanelContainer.new()
	_inbox_panel.name = "InboxColumn"
	_inbox_panel.clip_contents = true
	var inbox_style := StyleBoxFlat.new()
	inbox_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	inbox_style.border_color = Color(0.91, 0.72, 0.35, 0.24)
	inbox_style.border_width_left = 1
	inbox_style.border_width_top = 1
	inbox_style.border_width_right = 1
	inbox_style.border_width_bottom = 1
	inbox_style.corner_radius_top_left = 10
	inbox_style.corner_radius_top_right = 10
	inbox_style.corner_radius_bottom_left = 10
	inbox_style.corner_radius_bottom_right = 10
	inbox_style.shadow_size = 0
	_inbox_panel.add_theme_stylebox_override("panel", inbox_style)
	parent.add_child(_inbox_panel)

	var safe := MarginContainer.new()
	_inbox_safe = safe
	for side: String in ["left", "right"]:
		safe.add_theme_constant_override("margin_" + side, 9)
	safe.add_theme_constant_override("margin_top", 4)
	safe.add_theme_constant_override("margin_bottom", 13)
	_inbox_panel.add_child(safe)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	safe.add_child(col)

	var heading := _label("SYSTEM MAIL", 18, GOLD_LIGHT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(heading)

	_inbox_count = _label("2 LETTERS", 13, MUTED)
	_inbox_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_inbox_count)

	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 2.0
	rule.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.65)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)

	_inbox_scroll = ScrollContainer.new()
	_inbox_scroll.name = "IndependentInboxVerticalScroll"
	_inbox_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inbox_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inbox_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_inbox_scroll.scroll_deadzone = DEADZONE
	col.add_child(_inbox_scroll)

	_inbox_list = VBoxContainer.new()
	_inbox_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inbox_list.add_theme_constant_override("separation", 8)
	_inbox_scroll.add_child(_inbox_list)
	_inbox_scroll.scroll_started.connect(func() -> void:
		_scroll_active = true
		_tap_guard_until = Time.get_ticks_msec() + TAP_GUARD_MS
	)
	_inbox_scroll.scroll_ended.connect(func() -> void:
		_scroll_active = false
		_tap_guard_until = Time.get_ticks_msec() + TAP_GUARD_MS
	)

	_footer_label = _label("JADE SANCTUARY", 11, MUTED)
	_footer_label.visible = false
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_footer_label)


func _build_parchment_panel(parent: Control) -> void:
	_letter_panel = Control.new()
	_letter_panel.name = "SelectedLetterParchmentColumn"
	_letter_panel.clip_contents = true
	parent.add_child(_letter_panel)
	var paper := _full_texture(
		_letter_panel, LETTER_PARCHMENT, TextureRect.STRETCH_SCALE
	)
	paper.name = "ApprovedImperialLetterParchment"

	_letter_safe = MarginContainer.new()
	_letter_safe.name = "LetterContentSafeArea"
	_letter_safe.clip_contents = true
	_letter_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_letter_panel.add_child(_letter_safe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",8)
	_letter_safe.add_child(col)
	_reader_scroll = ScrollContainer.new()
	_reader_scroll.name = "CompleteLetterReaderScroll"
	_reader_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader_scroll.custom_minimum_size.y = 48
	_reader_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_reader_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_reader_scroll.scroll_deadzone = DEADZONE
	col.add_child(_reader_scroll)
	_reader_scroll.scroll_started.connect(func():
		_reader_dragging = true
		_reader_tap_guard_until = Time.get_ticks_msec()+TAP_GUARD_MS)
	_reader_scroll.scroll_ended.connect(func():
		_reader_dragging = false
		_reader_tap_guard_until = Time.get_ticks_msec()+TAP_GUARD_MS)
	_reader_hint = _label("SCROLL TO READ FULL LETTER",11,PAPER_MUTED)
	_reader_hint.name = "CompleteLetterScrollHint"
	_reader_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reader_hint.visible = false
	col.add_child(_reader_hint)
	_reader_scroll.get_v_scroll_bar().changed.connect(_update_reader_hint)
	_reader_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _update_reader_hint())
	_reader_content = VBoxContainer.new()
	_reader_content.name = "FullLetterDocument"
	_reader_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_content.add_theme_constant_override("separation",10)
	_reader_scroll.add_child(_reader_content)
	_letter_subject = _label("",21,INK)
	_letter_subject.name = "ActualMessageTitleSlot"
	_letter_subject.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter_subject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Full title and sender belong to the document, rather than fixed clipped slots.
	_letter_subject.max_lines_visible = -1
	_reader_content.add_child(_letter_subject)
	_letter_sender = _label("",12,PAPER_MUTED)
	_letter_sender.name = "FullMessageSender"
	_letter_sender.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter_sender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_content.add_child(_letter_sender)
	_letter_body = RichTextLabel.new()
	_letter_body.name = "FullLetterTextNoTruncation"
	_letter_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_letter_body.fit_content = true
	_letter_body.bbcode_enabled = false
	_letter_body.scroll_active = false
	_letter_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_letter_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letter_body.add_theme_font_size_override("normal_font_size",18)
	_letter_body.add_theme_color_override("default_color",INK)
	_letter_body.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	_letter_body.add_theme_color_override("font_outline_color",Color.TRANSPARENT)
	_letter_body.add_theme_constant_override("outline_size",0)
	_reader_content.add_child(_letter_body)
	_letter_footer = VBoxContainer.new()
	_letter_footer.name = "PinnedAttachmentAndClaimFooter"
	_letter_footer.add_theme_constant_override("separation",6)
	col.add_child(_letter_footer)
	_attachment_group = VBoxContainer.new()
	_attachment_group.name = "ResponsiveMailAttachments"
	_attachment_group.add_theme_constant_override("separation",6)
	_letter_footer.add_child(_attachment_group)
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1
	rule.color = Color(0.60,0.43,0.18,0.65)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attachment_group.add_child(rule)
	_attachment_caption = _label("ATTACHMENTS",14,PAPER_MUTED)
	_attachment_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attachment_group.add_child(_attachment_caption)
	_rebuild_reward_slot(_attachment_group)
	_action_grid = GridContainer.new()
	_action_grid.name = "PinnedMailActions"
	_action_grid.add_theme_constant_override("h_separation",8)
	_action_grid.add_theme_constant_override("v_separation",6)
	_letter_footer.add_child(_action_grid)
	_build_claim_slot(_action_grid)
	_delete_button = _button("DELETE MESSAGE",false)
	_delete_button.name = "MailDeleteMessage"
	_delete_button.clip_text = true
	_delete_button.pressed.connect(_on_delete_pressed)
	_delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grid.add_child(_delete_button)
	LiveOpsUi.make_scroll_tree_touch_safe(_reader_content)
	LiveOpsUi.make_scroll_tree_touch_safe(_inbox_list)


func _rebuild_reward_slot(parent: VBoxContainer) -> void:
	var reward_holder := PanelContainer.new()
	reward_holder.custom_minimum_size.y = 72.0
	var reward_holder_style := StyleBoxFlat.new()
	reward_holder_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	reward_holder_style.border_width_left = 0
	reward_holder_style.border_width_top = 0
	reward_holder_style.border_width_right = 0
	reward_holder_style.border_width_bottom = 0
	reward_holder_style.shadow_size = 0
	reward_holder.add_theme_stylebox_override("panel", reward_holder_style)
	parent.add_child(reward_holder)

	_rewards_row = GridContainer.new()
	_rewards_row.name = "StableAttachmentSlots"
	_rewards_row.columns = 2
	_rewards_row.add_theme_constant_override("h_separation",6)
	_rewards_row.add_theme_constant_override("v_separation",6)
	reward_holder.add_child(_rewards_row)


func _build_claim_slot(parent: Container) -> void:
	var action_slot := Control.new()
	action_slot.custom_minimum_size.y = 56.0
	action_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(action_slot)

	_claim_button = _button("CLAIM", true)
	_claim_button.name = "MailClaimAttachment"
	_claim_button.clip_text = true
	_claim_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_claim_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The shared flight presenter reads the focused button as the source position.
	_claim_button.focus_mode = Control.FOCUS_ALL
	_claim_button.add_theme_font_size_override("font_size", 20)
	_claim_button.pressed.connect(_on_claim_pressed)
	action_slot.add_child(_claim_button)

	_no_claim_hint = _label("NOTICE · NO ATTACHMENT", 15, PAPER_MUTED)
	_no_claim_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_no_claim_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_no_claim_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_claim_hint.visible = false
	action_slot.add_child(_no_claim_hint)


func _fit_popup() -> void:
	if not is_instance_valid(_popup):
		return
	var width_value: float = minf(size.x * 0.94, 960.0 if size.x >= 1100 else 685.0)
	var height_value: float = minf(size.y * (.94 if size.y<650 else .88), 1120.0)
	_popup.position = Vector2((size.x-width_value)*.5,(size.y-height_value)*.5)
	_popup.size = Vector2(width_value,height_value)
	var inset: int = 24
	_popup_safe.add_theme_constant_override("margin_left",inset)
	_popup_safe.add_theme_constant_override("margin_right",inset)
	_popup_safe.add_theme_constant_override("margin_top",28)
	_popup_safe.add_theme_constant_override("margin_bottom",24)
	_mail_title.add_theme_font_size_override("font_size",20 if width_value<400 else 28)
	_mail_tagline.visible = height_value >= 650
	_layout_body()


func _layout_body() -> void:
	if not is_instance_valid(_body) or not is_instance_valid(_inbox_panel):
		return
	var w: float = _body.size.x
	var h: float = _body.size.y
	if is_instance_valid(_compact_inbox_button):
		_compact_inbox_button.visible = w < WIDE_READER_THRESHOLD
		_compact_inbox_button.text = tr("READ") if _compact_inbox_open and not _selected_id.is_empty() else tr("INBOX")
		_compact_inbox_button.disabled = _compact_inbox_open and _selected_id.is_empty()
	if w >= WIDE_READER_THRESHOLD:
		_inbox_panel.visible = true
		_letter_panel.visible = true
		var left_w: float = maxf(220.0, w * 0.29)
		_inbox_panel.position = Vector2.ZERO
		# Size the *existing* cards from the rendered font and available width;
		# the third line of a title or second sender line must not push NOTICE out.
		_inbox_panel.size.x = left_w
		_update_inbox_card_heights(left_w)
		var list_height: float = _inbox_required_height()
		_inbox_panel.size = Vector2(left_w, minf(h, list_height))
		var letter_x: float = left_w + 16.0
		_letter_panel.position = Vector2(letter_x, 0.0)
		_letter_panel.size = Vector2(maxf(w - letter_x, 1.0), h)
	else:
		# Do not squeeze an already narrow parchment into half the height.
		# Provide a reader/inbox toggle on truly narrow logical viewports.
		_inbox_panel.position = Vector2.ZERO
		_inbox_panel.size = Vector2(w, h)
		_update_inbox_card_heights(w)
		_letter_panel.position = Vector2.ZERO
		_letter_panel.size = Vector2(w, h)
		_inbox_panel.visible = _compact_inbox_open
		_letter_panel.visible = not _compact_inbox_open
	_layout_letter_reader()


func _layout_letter_reader() -> void:
	if not is_instance_valid(_reader_scroll): return
	# Use the artwork's inner printable region, not the outer texture bounds.
	var inset: int = roundi(_letter_panel.size.x*.12)
	_letter_safe.add_theme_constant_override("margin_left",inset)
	_letter_safe.add_theme_constant_override("margin_right",inset)
	_letter_safe.add_theme_constant_override("margin_top",24)
	_letter_safe.add_theme_constant_override("margin_bottom",24)
	if _attachment_group.get_parent() != _reader_content:
		_attachment_group.reparent(_reader_content,false)
	# Keep claim/delete accessible while shrinking the decorative vertical gap.
	var short_paper: bool=_letter_panel.size.y<280
	_letter_safe.add_theme_constant_override("margin_top",12 if short_paper else 24)
	_letter_safe.add_theme_constant_override("margin_bottom",12 if short_paper else 24)
	LiveOpsUi.make_scroll_tree_touch_safe(_reader_content)
	var printable_width: float = _letter_panel.size.x - inset*2.0
	_action_grid.columns = 1 if printable_width < 240 else 2
	_claim_button.add_theme_font_size_override("font_size",16 if printable_width<280 else 20)
	_delete_button.text = tr("DELETE") if printable_width < 280 else tr("DELETE MESSAGE")
	_no_claim_hint.text = tr("NO MAIL") if _selected_id.is_empty() else tr("NOTICE") if printable_width < 280 else tr("MESSAGE · NO REWARD")
	_rewards_row.columns = 1 if printable_width < 350.0 else 2
	_letter_subject.add_theme_font_size_override("font_size",18 if printable_width<300 else 22)
	_letter_body.add_theme_font_size_override("normal_font_size",16 if printable_width<300 else 18)


func _update_reader_hint() -> void:
	if not is_instance_valid(_reader_hint): return
	if _letter_panel.size.y<280:
		_reader_hint.hide()
		return
	var bar: VScrollBar = _reader_scroll.get_v_scroll_bar()
	_reader_hint.visible = bar.max_value > bar.page + 1.0
	_reader_hint.text = tr("END OF LETTER") if bar.value >= bar.max_value-bar.page-1.0 else ("GULIR UNTUK BACA" if SettingsManager.language=="id" else "SCROLL TO READ") if _letter_panel.size.x*.76<280 else tr("SCROLL TO READ FULL LETTER")


func _restore_reader_scroll(id: String,signature: String,offset: int) -> void:
	# Containers and RichTextLabel need their new text layout before restoring;
	# setting it while the previous short document is active clamps it to zero.
	for frame: int in range(2):
		if not is_inside_tree(): return
		await get_tree().process_frame
	if not is_inside_tree() or _displayed_id != id or _document_signature != signature: return
	_reader_scroll.scroll_vertical = offset
	_update_reader_hint()


func _inbox_label_height(label: Label, text_width: float, max_lines: int) -> float:
	# Measure with the same Godot theme font and SMART word-break behavior as
	# the actual Label; do not guess character counts or mutate displayed text.
	var font: Font = label.get_theme_font("font")
	if font == null:
		return float(max_lines) * float(label.get_line_height())
	var font_size: int = label.get_theme_font_size("font_size")
	var break_flags: int = (
		TextServer.BREAK_MANDATORY
		| TextServer.BREAK_WORD_BOUND
		| TextServer.BREAK_ADAPTIVE
	)
	return font.get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, text_width,
		font_size, max_lines, break_flags
	).y


func _update_inbox_card_heights(inbox_width: float) -> void:
	if inbox_width <= 0.0:
		return
	var inset: int = roundi(clampf(inbox_width*.08,18,42))
	_inbox_safe.add_theme_constant_override("margin_left",inset)
	_inbox_safe.add_theme_constant_override("margin_right",inset)
	var text_width: float = maxf(inbox_width - inset*2.0 - 40.0, 40.0)
	for raw_refs: Variant in _mail_card_refs.values():
		var refs: Dictionary = raw_refs as Dictionary
		var item: Button = refs.get("button") as Button
		var title: Label = refs.get("title") as Label
		var sender: Label = refs.get("sender") as Label
		var badge: Label = refs.get("badge") as Label
		if (
			not is_instance_valid(item)
			or not is_instance_valid(title)
			or not is_instance_valid(sender)
			or not is_instance_valid(badge)
		):
			continue
		var title_h: float = maxf(
			_inbox_label_height(title, text_width, INBOX_TITLE_MAX_LINES),
			float(title.get_line_height())
		)
		var sender_h: float = maxf(
			_inbox_label_height(sender, text_width, INBOX_SENDER_MAX_LINES),
			float(sender.get_line_height())
		)
		var badge_h: float = float(badge.get_line_height())
		# Fix: title and sender need actual vertical bounds inside VBoxContainer.
		# A clipped/zero-height label previously left only the status visible.
		title.custom_minimum_size.y = ceilf(title_h)
		sender.custom_minimum_size.y = ceilf(sender_h)
		# 17px vertical margins + 8px VBox gaps + 6px rendering guard.
		var needed_h: float = ceilf(title_h + sender_h + badge_h + 31.0)
		item.custom_minimum_size.y = maxf(INBOX_CARD_MIN_HEIGHT, needed_h)


func _inbox_required_height() -> float:
	var count: int = _mail_card_refs.size()
	# Keep the existing short-list size; grow only if text requires it.
	var content_h: float = 96.0 + maxf(float(count - 1), 0.0) * 8.0
	for raw_refs: Variant in _mail_card_refs.values():
		var refs: Dictionary = raw_refs as Dictionary
		var item: Button = refs.get("button") as Button
		if is_instance_valid(item):
			content_h += item.custom_minimum_size.y
	return maxf(maxf(265.0, 145.0 + float(count) * 116.0), content_h)


func _toggle_compact_inbox() -> void:
	if _compact_inbox_open and _selected_id.is_empty(): return
	_compact_inbox_open = not _compact_inbox_open
	_layout_body()


func _entries() -> Array[Dictionary]:
	if live_ops == null or not is_instance_valid(live_ops):
		return []
	var entries: Array[Dictionary] = live_ops.get_mail_entries()
	return entries


func _refresh_from_authority() -> void:
	_mail_refresh_queued = false
	if _refreshing or live_ops == null or not is_instance_valid(_inbox_list):
		return
	_refreshing = true
	if is_instance_valid(_server_status):
		_server_status.text = tr(ServerMailManager.get_status())
		_server_status.tooltip_text = _server_status.text
	if is_instance_valid(_claim_all_button) and is_instance_valid(_claim_batch):
		_claim_all_button.disabled=SaveManager.is_progress_read_only() or (_claim_batch.active and not _claim_batch.paused) or (not _claim_batch.active and int(_claim_batch.available())==0)
		_claim_all_button.text="LANJUTKAN" if _claim_batch.paused else "%d/%d" % [int(_claim_batch.claimed),int(_claim_batch.total)] if _claim_batch.active else "CLAIM ALL"
		if not str(_claim_batch.message).is_empty(): _server_status.text=str(_claim_batch.message);_server_status.tooltip_text=_server_status.text
	if is_instance_valid(_delete_all_button):
		var deleting: bool = ServerMailManager.is_deleting_all_completed()
		_delete_all_button.disabled = deleting or SaveManager.is_progress_read_only() or (is_instance_valid(_claim_batch) and _claim_batch.active)
		_delete_all_button.text = tr("DELETING…") if deleting else tr("DELETE ALL")
	var entries: Array[Dictionary] = _entries()
	var selection_found: bool = false
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) == _selected_id:
			selection_found = true
			break
	if not selection_found:
		_selected_id = ""
		_compact_inbox_open = true
	var signature_parts: Array=[]
	for entry: Dictionary in entries: signature_parts.append([entry.get("id"),entry.get("read"),entry.get("claimed"),entry.get("can_claim"),entry.get("pending"),entry.get("expired"),entry.get("title"),entry.get("created_at")])
	var next_signature: String=JSON.stringify([_selected_id,signature_parts])
	if next_signature!=_inbox_signature: _inbox_signature=next_signature;_rebuild_inbox()
	_refresh_letter()
	_layout_body()
	_refreshing = false


func _on_live_ops_changed() -> void:
	if _claim_busy or not is_inside_tree() or _mail_refresh_queued: return
	_mail_refresh_queued = true
	_refresh_from_authority.call_deferred()


func _rebuild_inbox(preserve_scroll: bool = true) -> void:
	if not is_instance_valid(_inbox_list):
		return
	var preserved_y: int = _inbox_scroll.scroll_vertical
	for child: Node in _inbox_list.get_children():
		_inbox_list.remove_child(child)
		child.queue_free()
	_mail_card_refs.clear()

	var entries: Array[Dictionary] = _entries()
	_inbox_count.text = (tr("%d LETTER") if entries.size() == 1 else tr("%d LETTERS")) % entries.size()
	if entries.is_empty():
		var empty := _label("No letters have arrived.\n\nThe Celestial Courier awaits.", 17, MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_inbox_list.add_child(empty)
		return

	for data: Dictionary in entries:
		var id: String = str(data.get("id", ""))
		var selected: bool = id == _selected_id
		var reward: Dictionary = data.get("reward", {})
		var claimed: bool = bool(data.get("claimed", false))
		var has_claimable_attachment: bool = not reward.is_empty() and not claimed
		var unread: bool = not bool(data.get("read", true))

		var item := _button("", selected)
		item.name = "Letter_" + id
		item.custom_minimum_size.y = INBOX_CARD_MIN_HEIGHT
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		item.add_theme_stylebox_override(
			"normal",
			_style(
				Color(0.86, 0.73, 0.49, 0.96) if selected else Color(0.95, 0.92, 0.84, 0.92),
				GOLD_LIGHT if selected else Color(0.73, 0.60, 0.36, 0.82),
				9, 2 if selected else 1
			)
		)
		item.button_down.connect(_remember_press.bind(id))
		item.pressed.connect(_select_mail.bind(id))
		_inbox_list.add_child(item)

		var inside := MarginContainer.new()
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inside.add_theme_constant_override("margin_left", 10)
		inside.add_theme_constant_override("margin_right", 24 if unread else 8)
		inside.add_theme_constant_override("margin_top", 9)
		inside.add_theme_constant_override("margin_bottom", 8)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Even a future extreme-length title cannot escape its parchment card.
		inside.clip_contents = true
		inside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(inside)

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inside.add_child(v)

		var title := _label(tr(str(data.get("title", ""))), 17, INK if selected else INK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.max_lines_visible = INBOX_TITLE_MAX_LINES
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.tooltip_text = str(data.get("title", ""))
		v.add_child(title)

		var sender := _label(tr(str(data.get("sender", ""))), 12, PAPER_MUTED if selected else PAPER_MUTED)
		sender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sender.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sender.max_lines_visible = INBOX_SENDER_MAX_LINES
		sender.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sender.tooltip_text = str(data.get("sender", ""))
		v.add_child(sender)

		var status: String = tr("NEW") if unread else (tr("ATTACHMENT") if has_claimable_attachment else (tr("CLAIMED") if not reward.is_empty() else tr("NOTICE")))
		var badge := _label(status, 12, INK if selected else (Color(0.47, 0.34, 0.18, 1.0) if has_claimable_attachment else PAPER_MUTED))
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		badge.clip_text = true
		badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		badge.tooltip_text = status
		v.add_child(badge)
		var unread_dot := Panel.new()
		unread_dot.name = "UnreadMailDot"
		unread_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unread_dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		unread_dot.offset_left = -21; unread_dot.offset_right = -9
		unread_dot.offset_top = 9; unread_dot.offset_bottom = 21
		unread_dot.add_theme_stylebox_override("panel", _style(Color("e7474d"), GOLD_LIGHT, 6, 1))
		unread_dot.tooltip_text = tr("UNREAD")
		unread_dot.visible = unread
		item.add_child(unread_dot)
		_mail_card_refs[id] = {
			"button": item,
			"unread_dot": unread_dot,
			"title": title,
			"sender": sender,
			"badge": badge,
			"has_claimable_attachment": has_claimable_attachment,
		}

	if preserve_scroll:
		_inbox_scroll.set_deferred("scroll_vertical", preserved_y)


func _remember_press(id: String) -> void:
	if is_instance_valid(_inbox_scroll):
		_pressed_scroll_y[id] = _inbox_scroll.scroll_vertical


func _select_mail(id: String) -> void:
	if not is_instance_valid(_inbox_scroll):
		return
	var start_y: int = int(_pressed_scroll_y.get(id, _inbox_scroll.scroll_vertical))
	_pressed_scroll_y.erase(id)
	if absi(_inbox_scroll.scroll_vertical - start_y) >= DEADZONE:
		return
	if _scroll_active or Time.get_ticks_msec() < _tap_guard_until:
		return
	if not _mail_card_refs.has(id):
		return
	var selection_changed: bool = id != _selected_id
	if not selection_changed and not _compact_inbox_open:
		return
	_selected_id = id
	live_ops.mark_mail_read(id)
	_refresh_from_authority()
	# On narrow viewports, selecting the current letter must still open it.
	if _body.size.x < WIDE_READER_THRESHOLD:
		_compact_inbox_open = false
		_layout_body()


func _update_inbox_selection() -> void:
	# Update only visual selection state; no queue_free or fresh card geometry.
	for raw_id: Variant in _mail_card_refs.keys():
		var card_id: String = str(raw_id)
		var refs: Dictionary = _mail_card_refs[card_id]
		var item: Button = refs.get("button") as Button
		var badge: Label = refs.get("badge") as Label
		if not is_instance_valid(item) or not is_instance_valid(badge):
			continue
		var selected_now: bool = card_id == _selected_id
		var has_attachment: bool = bool(refs.get("has_claimable_attachment", false))
		item.add_theme_stylebox_override(
			"normal",
			_style(
				Color(0.86, 0.73, 0.49, 0.96) if selected_now else Color(0.95, 0.92, 0.84, 0.92),
				GOLD_LIGHT if selected_now else Color(0.73, 0.60, 0.36, 0.82),
				9, 2 if selected_now else 1
			)
		)
		item.add_theme_stylebox_override(
			"hover",
			_style(
				Color(1.0, 0.85, 0.49, 1.0) if selected_now else Color(0.02, 0.11, 0.12, 0.98),
				GOLD_LIGHT, 11, 2
			)
		)
		badge.add_theme_color_override(
			"font_color",
			INK if selected_now else (Color(0.47, 0.34, 0.18, 1.0) if has_attachment else PAPER_MUTED)
		)


func _refresh_letter() -> void:
	if not is_instance_valid(_letter_subject):
		return
	var entry: Dictionary = {}
	for mail: Dictionary in _entries():
		if str(mail.get("id", "")) == _selected_id:
			entry = mail
			break

	_claim_button.tooltip_text = ""
	_delete_button.visible = not entry.is_empty()
	_delete_button.disabled = not bool(live_ops.can_delete_mail(_selected_id)) or _claim_busy
	_delete_button.tooltip_text = tr("CLAIM ATTACHMENT BEFORE DELETING") if not bool(entry.get("claimed", true)) else ""
	if entry.is_empty():
		_displayed_id = ""
		_document_signature = ""
		_reader_scroll.set_deferred("scroll_vertical",0)
		_letter_subject.text = tr("SELECT A LETTER") if not _entries().is_empty() else tr("The Empty Sky")
		_letter_sender.text = tr("JADE SANCTUARY")
		_letter_body.text = tr("Tap a letter in your inbox to read it.") if not _entries().is_empty() else tr("No messages have arrived.\n\nMay the Celestial Courier bring good tidings to your cultivation path.")
		_attachment_group.visible = false
		_attachment_caption.text = tr("NO ATTACHMENTS")
		_fill_attachment_tiles([])
		_claim_button.visible = false
		_no_claim_hint.visible = true
		_no_claim_hint.text = tr("NO MAIL")
		_footer_label.text = tr("JADE SANCTUARY")
		return

	var server_letter: bool = _selected_id.begins_with("server:")
	var subject: String = str(entry.get("title","")) if server_letter else tr(str(entry.get("title","")))
	var sender: String = tr("FROM · ") + (str(entry.get("sender","")) if server_letter else tr(str(entry.get("sender",""))))
	var body_text: String = str(entry.get("body","")) if server_letter else tr(str(entry.get("body","")))
	var signature: String = JSON.stringify([_selected_id,subject,sender,body_text])
	if signature != _document_signature:
		if not _displayed_id.is_empty(): _reader_offsets[_displayed_id] = _reader_scroll.scroll_vertical
		_displayed_id = _selected_id
		_document_signature = signature
		_letter_subject.text = subject
		_letter_sender.text = sender
		_letter_body.bbcode_enabled = not server_letter
		_letter_body.text = body_text
		_restore_reader_scroll.call_deferred(_selected_id,signature,int(_reader_offsets.get(_selected_id,0)))

	var reward: Dictionary = entry.get("reward", {})
	var has_reward: bool = not reward.is_empty()
	_attachment_group.visible = has_reward
	var claimed: bool = bool(entry.get("claimed", false))
	var read_only: bool = SaveManager.is_progress_read_only()
	_attachment_caption.text = tr("ATTACHMENTS") if has_reward else tr("SEALED NOTICE")
	_fill_attachment_tiles(_reward_tiles(reward))
	_claim_button.visible = has_reward
	_no_claim_hint.visible = not has_reward
	_no_claim_hint.text = tr("MESSAGE · NO REWARD")
	var server_busy: bool = _selected_id.begins_with("server:") and ServerMailManager.is_delivery_busy_for(_selected_id)
	var claim_allowed: bool = bool(entry.get("can_claim",true))
	_claim_button.disabled = claimed or read_only or _claim_busy or server_busy or not claim_allowed or (is_instance_valid(_claim_batch) and _claim_batch.active)
	_claim_button.text = (
		tr("CLAIMED") if claimed
		else tr("CLAIMING…") if server_busy
		else tr("EXPIRED") if bool(entry.get("expired",false)) and not bool(entry.get("pending",false))
		else tr("UNAVAILABLE") if not claim_allowed
		else tr("READ ONLY") if read_only
		else tr("RECOVER CLAIM") if bool(entry.get("pending",false))
		else tr("CLAIM")
	)
	_footer_label.text = (
		tr("ATTACHMENT CLAIMED") if has_reward and claimed
		else tr("UNCLAIMED ATTACHMENT") if has_reward
		else tr("OFFICIAL NOTICE")
	)
	# Server status already has a dedicated slot above the inbox list.
	_footer_label.visible = false


func _reward_tiles(reward: Dictionary) -> Array[Dictionary]:
	reward = RewardManager.retire_fragments(reward)
	var tiles: Array[Dictionary] = []
	var stone_amount: int = maxi(int(reward.get(RewardManager.REWARD_KEY_SPIRIT_STONE, 0)), 0)
	if stone_amount > 0:
		tiles.append({"icon": SPIRIT_ICON, "name": "Spirit Stone", "amount": stone_amount})

	for row: Array in [["celestial_jade","Celestial Jade","res://assets/ui/shared/resources/celestial_jade_premium.png"],["pavilion_seal","Pavilion Seal","res://assets/ui/shared/resources/pavilion_seal_premium.png"]]:
		var amount: int = int(reward.get(row[0],0))
		if amount > 0: tiles.append({"icon":load(row[2]),"name":row[1],"amount":amount})
	var hero_exp_amount: int = maxi(int(reward.get(RewardManager.REWARD_KEY_HERO_EXP, 0)), 0)
	if hero_exp_amount > 0:
		tiles.append({"icon": HERO_EXP_ICON, "name": "Hero EXP", "amount": hero_exp_amount})

	var raw_items: Variant = reward.get(RewardManager.REWARD_KEY_ITEMS, {})
	if raw_items is Dictionary:
		var items: Dictionary = raw_items as Dictionary
		var item_ids: Array[String] = []
		for raw_id: Variant in items.keys():
			item_ids.append(str(raw_id))
		item_ids.sort()
		for item_id: String in item_ids:
			var amount: int = maxi(int(items.get(item_id, 0)), 0)
			if amount <= 0:
				continue
			var icon_texture: Texture2D = GENERIC_REWARD_ICON
			var display_name: String = item_id
			if item_id == InventoryManager.REFINEMENT_SHARD:
				icon_texture = SHARD_ICON
			if EquipmentManager.has_item_definition(item_id):
				icon_texture = load(EquipmentVisualCatalog.get_icon_path(item_id)) as Texture2D
			if InventoryManager.is_known_item(item_id):
				var item_data: Dictionary = InventoryManager.get_item_data(item_id)
				display_name = str(item_data.get("display_name", item_id))
			tiles.append({"icon": icon_texture, "name": display_name, "amount": amount})
	return tiles


func _fill_attachment_tiles(rewards: Array) -> void:
	for child: Node in _rewards_row.get_children():
		_rewards_row.remove_child(child)
		child.queue_free()
	if rewards.is_empty():
		# The fixed SEALED NOTICE and MESSAGE · NO REWARD labels already describe
		# this state. Do not insert a wrapping Label into the centered reward row:
		# it shrinks to one glyph and forces the pinned footer to fill the letter.
		return

	_rewards_row.columns = 1 if _letter_panel.size.x*.76 < 350.0 else 2
	for raw: Variant in rewards:
		if not (raw is Dictionary):
			continue
		var reward: Dictionary = raw
		var tile := PanelContainer.new()
		tile.tooltip_text = tr(str(reward.get("name", "")))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tile_style := StyleBoxFlat.new()
		tile_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		tile_style.border_color = GOLD
		tile_style.border_width_left = 1
		tile_style.border_width_top = 1
		tile_style.border_width_right = 1
		tile_style.border_width_bottom = 1
		tile_style.corner_radius_top_left = 8
		tile_style.corner_radius_top_right = 8
		tile_style.corner_radius_bottom_left = 8
		tile_style.corner_radius_bottom_right = 8
		tile_style.shadow_size = 0
		tile.add_theme_stylebox_override("panel", tile_style)
		_rewards_row.add_child(tile)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation",2)
		tile.add_child(stack)
		var content := HBoxContainer.new()
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 4)
		stack.add_child(content)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(42.0, 42.0)
		pic.texture = reward.get("icon", null) as Texture2D
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(pic)
		var quantity := _label("×%d" % int(reward.get("amount", 0)), 17, INK)
		# A numeric reward amount is indivisible: the shared _label() helper
		# enables word-wrap, which splits digits inside the narrow attachment tile.
		quantity.autowrap_mode = TextServer.AUTOWRAP_OFF
		quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(quantity)
		var name_label := _label(str(reward.get("name","")),10,PAPER_MUTED)
		name_label.max_lines_visible = 2
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stack.add_child(name_label)
	LiveOpsUi.make_scroll_tree_touch_safe(_reader_content)


func _on_claim_pressed() -> void:
	if _reader_dragging or Time.get_ticks_msec()<_reader_tap_guard_until: return
	if _claim_busy or live_ops == null or not is_instance_valid(_claim_button):
		return
	if _claim_button.disabled or _selected_id.is_empty():
		return
	var entry: Dictionary = live_ops.get_mail(_selected_id)
	var reward: Dictionary = entry.get("reward", {})
	if reward.is_empty() or bool(entry.get("claimed", false)):
		_refresh_from_authority()
		return
	if SaveManager.is_progress_read_only():
		_refresh_from_authority()
		return

	# Existing authority handles atomic save/ledger and emits reward_granted.
	# Shared presenters automatically show the flight and claim-result overlay.
	_claim_busy = true
	var success: bool = bool(live_ops.claim_mail(_selected_id))
	_claim_busy = false
	_refresh_from_authority()
	if not success and is_instance_valid(_claim_button) and not _claim_button.disabled:
		_claim_button.text = tr("RETRY")
		_claim_button.tooltip_text = tr("CLAIM FAILED · RETRY")


func _on_delete_pressed() -> void:
	if _reader_dragging or Time.get_ticks_msec()<_reader_tap_guard_until: return
	if _claim_busy or _selected_id.is_empty() or _delete_button.disabled:
		return
	_claim_busy = true
	var success: bool = bool(live_ops.delete_mail(_selected_id))
	_claim_busy = false
	_refresh_from_authority()
	if not success:
		_footer_label.visible = true
		_footer_label.text = tr("DELETE FAILED · RETRY")


func _back() -> void:
	LiveOpsUi.return_home(self)


func _full_texture(parent: Control, texture_value: Texture2D, stretch: TextureRect.StretchMode) -> TextureRect:
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = texture_value
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = stretch
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = tr(value)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size",0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = tr(value)
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.keep_pressed_outside = false
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.add_theme_font_size_override("font_size", 16 if primary else 14)
	button.add_theme_color_override(
		"font_color", INK if primary else IVORY
	)
	button.add_theme_color_override(
		"font_disabled_color", Color(0.96, 0.91, 0.74, 1.0)
	)
	button.add_theme_stylebox_override(
		"normal",
		_style(
			Color(0.92, 0.71, 0.33, 0.99) if primary else Color(0.0, 0.042, 0.050, 0.96),
			GOLD_LIGHT if primary else JADE, 11, 2
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_style(
			Color(1.0, 0.85, 0.49, 1.0) if primary else Color(0.02, 0.11, 0.12, 0.98),
			GOLD_LIGHT, 11, 2
		)
	)
	button.add_theme_stylebox_override(
		"pressed", _style(Color(0.50, 0.39, 0.19, 1.0), GOLD, 11, 2)
	)
	button.add_theme_stylebox_override(
		"disabled", _style(Color(0.28, 0.26, 0.21, 0.98), Color(0.78, 0.68, 0.46, 0.72), 11, 1)
	)
	return button


func _style(background: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_size = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.29)
	return style
