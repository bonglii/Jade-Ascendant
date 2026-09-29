extends Control

## CELESTIAL EVENTS — ISOLATED REDESIGN LAB V1.
## Read-only LiveOps status; no reward grants, purchases, save mutations or
## production navigation. All art references use existing tracked project assets.

const HOME_ART: Texture2D = preload(
	"res://assets/ui/main_menu/main_menu_key_art_lin_yue.png"
)
const SEVEN_DAY_ART: Texture2D = preload(
	"res://assets/ui/liveops/seven_day/seven_day_ascension_hero_portrait_bg.png"
)
const DAILY_ICON: Texture2D = preload(
	"res://assets/ui/icons/actions/daily.png"
)
const PAVILION_ICON: Texture2D = preload(
	"res://assets/ui/pavilion/icons/pavilion_crest.png"
)
# Exact existing approved Treasury frame, copied unchanged into this isolated LAB.
const FRAME_ART: Texture2D = preload(
	"res://assets/ui/liveops/event_center_lab/treasury_frame_approved.png"
)
# Dark background is clipped to the alpha silhouette of the same frame.
const INTERIOR_ART: Texture2D = preload(
	"res://assets/ui/liveops/event_center_lab/frame_interior_silhouette.png"
)

const GOLD: Color = Color(0.93, 0.74, 0.35, 1.0)
const GOLD_LIGHT: Color = Color(1.0, 0.91, 0.67, 1.0)
const JADE: Color = Color(0.44, 0.91, 0.79, 1.0)
const IVORY: Color = Color(0.97, 0.97, 0.92, 1.0)
const MUTED: Color = Color(0.73, 0.84, 0.82, 1.0)
const INK: Color = Color(0.006, 0.029, 0.038, 0.97)
const SCROLL_GUARD_MS: int = 190
const SCROLL_DEADZONE: int = 7

var _live_ops: Node = null
var _popup: PanelContainer = null
var _chrome_mask: TextureRect = null
var _chrome_frame: TextureRect = null
var _close_button: Button = null
var _body_margin: MarginContainer = null
var _scroll: ScrollContainer = null
var _header: Control = null
var _header_title: Label = null
var _hero_art: TextureRect = null
var _hero_stage: Control = null
var _event_status: Label = null
var _event_progress: Label = null
var _featured_tag: Label = null
var _featured_action_row: GridContainer = null
var _grid: GridContainer = null
var _modal: Control = null
var _modal_title: Label = null
var _modal_body: RichTextLabel = null
var _dragging: bool = false
var _tap_guard_until: int = 0
var _press_scroll_y: Dictionary = {}
var _layout_generation: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_live_ops = get_node_or_null("/root/LiveOpsManager")
	_build_lab()
	# Hold only the initial layout until responsive container measurements settle.
	# This prevents the blank tall popup from appearing for one frame.
	_popup.visible = false
	_refresh_readonly_status()
	_fit_layout()
	resized.connect(_fit_layout)
	if _live_ops != null and _live_ops.has_signal("live_ops_changed"):
		var refresh_callback: Callable = Callable(self, "_refresh_readonly_status")
		if not _live_ops.is_connected("live_ops_changed", refresh_callback):
			_live_ops.connect("live_ops_changed", refresh_callback)


func _build_lab() -> void:
	var backdrop := TextureRect.new()
	backdrop.name = "ApprovedHomeBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = HOME_ART
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var shade := ColorRect.new()
	shade.name = "PopupSafeScrim"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.009, 0.020, 0.79)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_chrome_mask = _texture(INTERIOR_ART)
	_chrome_mask.name = "FrameConformantInteriorMask"
	_chrome_mask.stretch_mode = TextureRect.STRETCH_SCALE
	_chrome_mask.visible = false
	add_child(_chrome_mask)

	_popup = PanelContainer.new()
	_popup.name = "CelestialEventsLabPopup"
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	# No old flat rectangle or shadow behind the irregular approved frame.
	_popup.add_theme_stylebox_override(
		"panel", _panel(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 0)
	)
	add_child(_popup)

	_body_margin = MarginContainer.new()
	_popup.add_child(_body_margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 9)
	_body_margin.add_child(outer)

	_header = Control.new()
	_header.custom_minimum_size.y = 78.0
	outer.add_child(_header)

	# The Treasury frame already has a large central jewel; a second crest would
	# overlap it, so the old small emblem is omitted rather than regenerated.
	var eyebrow := _label("JADE ASCENDANT  /  LIVE EVENTS", 12, JADE)
	eyebrow.name = "EventEyebrow"
	eyebrow.position = Vector2(0.0, 43.0)
	eyebrow.size = Vector2(280.0, 22.0)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_child(eyebrow)

	_header_title = _label("CELESTIAL EVENTS", 30, GOLD_LIGHT)
	_header_title.name = "EventCenterHeadline"
	_header_title.position = Vector2(0.0, 2.0)
	_header_title.size = Vector2(280.0, 41.0)
	_header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_header_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header_title.add_theme_color_override(
		"font_shadow_color", Color(0.0, 0.0, 0.0, 0.8)
	)
	_header_title.add_theme_constant_override("shadow_offset_y", 2)
	_header.add_child(_header_title)

	var divider := HSeparator.new()
	divider.name = "HeaderSeparator"
	divider.position = Vector2(0.0, 70.0)
	divider.size = Vector2(280.0, 2.0)
	divider.add_theme_stylebox_override(
		"separator", _panel(Color(0.95, 0.73, 0.30, 0.62), Color.TRANSPARENT, 0, 0)
	)
	_header.add_child(divider)

	_scroll = ScrollContainer.new()
	_scroll.name = "EventCenterVerticalScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = SCROLL_DEADZONE
	_scroll.follow_focus = false
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	outer.add_child(_scroll)

	var body := VBoxContainer.new()
	body.name = "EventCenterBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	_scroll.add_child(body)

	_build_featured(body)
	_build_secondary(body)

	var footer := _label(
		"VISUAL LAB  ·  EVENTS AND REWARDS REMAIN MANAGED BY THE EXISTING GAME SYSTEM",
		12, MUTED
	)
	footer.name = "ReadOnlyLabNotice"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.custom_minimum_size.y = 26.0
	body.add_child(footer)

	_scroll.scroll_started.connect(_on_scroll_started)
	_scroll.scroll_ended.connect(_on_scroll_ended)

	_build_modal()

	# Frame is drawn over only the noninteractive outer edge. Preview overlay
	# has higher z_index so its close button never ends up behind the ornament.
	_chrome_frame = _texture(FRAME_ART)
	_chrome_frame.name = "ExactTreasuryApprovedOrnamentalFrame"
	_chrome_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_chrome_frame.visible = false
	_chrome_frame.z_index = 2
	add_child(_chrome_frame)

	_close_button = _button("×", false)
	_close_button.name = "CloseVisualLab"
	_close_button.custom_minimum_size = Vector2(44.0, 44.0)
	_close_button.size = Vector2(44.0, 44.0)
	_close_button.add_theme_font_size_override("font_size", 29)
	_close_button.add_theme_color_override("font_color", IVORY)
	_close_button.add_theme_color_override("font_hover_color", GOLD_LIGHT)
	_close_button.add_theme_color_override("font_pressed_color", GOLD_LIGHT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		_close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_close_button.z_index = 3
	_close_button.visible = false
	_close_button.pressed.connect(_close_lab)
	add_child(_close_button)


func _build_featured(parent: VBoxContainer) -> void:
	var main := _panel_container(
		"FeaturedSevenDays", Color(0.005, 0.050, 0.062, 0.98), GOLD, 16, 2
	)
	parent.add_child(main)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_add_panel_margin(main, content, 11, 11, 11, 12)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	content.add_child(row)

	_featured_tag = _badge("FEATURED EVENT", GOLD_LIGHT, Color(0.34, 0.18, 0.055, 0.96))
	_featured_tag.custom_minimum_size = Vector2(139.0, 29.0)
	row.add_child(_featured_tag)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_event_status = _badge("EVENT ACTIVE", JADE, Color(0.018, 0.11, 0.11, 0.98))
	_event_status.custom_minimum_size = Vector2(126.0, 29.0)
	row.add_child(_event_status)

	# Approved LAB V1.4: fill the complete banner with the original Seven Days
	# image. Direct STRETCH_SCALE is intentional: the user prefers a slight
	# aspect-ratio change over cropping, letterboxing, or panoramic edge artifacts.
	_hero_stage = Control.new()
	_hero_stage.name = "FullArtworkSafeBanner"
	_hero_stage.custom_minimum_size.y = 220.0
	_hero_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_stage.clip_contents = true
	content.add_child(_hero_stage)
	_hero_art = _texture(SEVEN_DAY_ART)
	_hero_art.name = "ExistingSevenDayArtwork_StretchToFrame"
	_hero_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero_art.stretch_mode = TextureRect.STRETCH_SCALE
	_hero_stage.add_child(_hero_art)
	var hero_outline := Panel.new()
	hero_outline.name = "FeaturedArtworkInsetGoldEdge"
	hero_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero_outline.add_theme_stylebox_override(
		"panel", _panel(Color.TRANSPARENT, GOLD, 8, 1)
	)
	hero_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_stage.add_child(hero_outline)

	var title := _label("SEVEN DAYS OF ASCENSION", 23, GOLD_LIGHT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)

	var description := _label(
		"Continue your cultivation journey and collect the rewards you have earned.",
		15, IVORY
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)

	_featured_action_row = GridContainer.new()
	_featured_action_row.columns = 2
	_featured_action_row.add_theme_constant_override("h_separation", 9)
	_featured_action_row.add_theme_constant_override("v_separation", 8)
	content.add_child(_featured_action_row)
	_event_progress = _badge("CHECKING EVENT", IVORY, Color(0.008, 0.078, 0.083, 0.97))
	_event_progress.custom_minimum_size = Vector2(158.0, 48.0)
	_event_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_featured_action_row.add_child(_event_progress)

	var open := _button("OPEN EVENT  ›", true)
	open.name = "PreviewSevenDayNavigation"
	open.custom_minimum_size = Vector2(153.0, 48.0)
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wire_preview_button(open, "seven_day")
	_featured_action_row.add_child(open)


func _build_secondary(parent: VBoxContainer) -> void:
	var heading := _label("YOUR CULTIVATION ACTIVITIES", 16, GOLD_LIGHT)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.y = 25.0
	parent.add_child(heading)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 11)
	_grid.add_theme_constant_override("v_separation", 11)
	parent.add_child(_grid)

	_add_activity_card(
		"Daily Trials", "DAILY CULTIVATION", "Complete daily disciplines and collect available rewards.",
		DAILY_ICON, JADE, "OPEN DAILY  ›", "daily"
	)
	_add_activity_card(
		"Celestial Pavilion", "OPTIONAL ACTIVITIES", "Discover Pavilion services and optional rewarded activities.",
		PAVILION_ICON, Color(0.58, 0.79, 1.0, 1.0), "OPEN PAVILION  ›", "pavilion"
	)


func _add_activity_card(
	card_name: String,
	eyebrow_text: String,
	description_text: String,
	icon_art: Texture2D,
	accent: Color,
	cta_text: String,
	preview_id: String
) -> void:
	var panel := _panel_container(card_name, Color(0.006, 0.045, 0.057, 0.98), accent, 14, 2)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(panel)

	var card_content := VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 8)
	_add_panel_margin(panel, card_content, 13, 13, 12, 13)

	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 9)
	card_content.add_child(icon_row)
	var icon := _texture(icon_art)
	icon.custom_minimum_size = Vector2(62.0, 62.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon_row.add_child(icon)
	var eyebrow := _label(eyebrow_text, 13, accent)
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eyebrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	icon_row.add_child(eyebrow)

	var title := _label(card_name.to_upper(), 21, GOLD_LIGHT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_content.add_child(title)

	var description := _label(description_text, 15, IVORY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 58.0
	card_content.add_child(description)

	var cta := _button(cta_text, false)
	cta.custom_minimum_size.y = 48.0
	cta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wire_preview_button(cta, preview_id)
	card_content.add_child(cta)


func _refresh_readonly_status() -> void:
	if _event_status == null or _event_progress == null:
		return
	if _live_ops == null:
		# F6 may launch the scene without the production LiveOps autoload.
		# Do not imply the real feature is unavailable in a visual-only LAB.
		_event_status.text = "LAB PREVIEW"
		_event_progress.text = "READ ONLY"
		return
	var day_count: int = int(_live_ops.get_active_login_day_count())
	var total: int = int(_live_ops.LOGIN_DAY_COUNT)
	var claimable: int = int(_live_ops.get_login_claimable_count())
	_event_progress.text = "DAY %d / %d" % [day_count, total]
	if bool(_live_ops.is_new_player_event_complete()):
		_event_status.text = "COMPLETED"
	elif claimable > 0:
		_event_status.text = "%d READY" % claimable
	else:
		_event_status.text = "IN PROGRESS"


func _build_modal() -> void:
	_modal = Control.new()
	_modal.name = "PreviewNavigationOnly"
	_modal.z_index = 4
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	_popup.add_child(_modal)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.005, 0.015, 0.81)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(dim)

	var box := PanelContainer.new()
	box.name = "NonInteractiveDestinationPreview"
	box.anchor_left = 0.075
	box.anchor_right = 0.925
	box.anchor_top = 0.33
	box.anchor_bottom = 0.67
	box.add_theme_stylebox_override("panel", _panel(INK, GOLD, 16, 2, 14))
	_modal.add_child(box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	box.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	_modal_title = _label("", 23, GOLD_LIGHT)
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_modal_title)
	# Keep long preview/translated copy in its own bounded reading zone.
	# The footer action must not move when the description grows.
	_modal_body = RichTextLabel.new()
	_modal_body.name = "ScrollablePreviewDescription"
	_modal_body.bbcode_enabled = false
	_modal_body.fit_content = false
	_modal_body.scroll_active = true
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_body.add_theme_font_size_override("normal_font_size", 16)
	_modal_body.add_theme_color_override("default_color", IVORY)
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.add_child(_modal_body)
	var close := _button("RETURN TO EVENTS", true)
	close.custom_minimum_size.y = 46.0
	close.pressed.connect(func() -> void: _modal.visible = false)
	stack.add_child(close)


func _wire_preview_button(button: Button, id: String) -> void:
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.keep_pressed_outside = false
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.button_down.connect(_record_button_down.bind(id))
	button.pressed.connect(_open_preview.bind(id))


func _record_button_down(id: String) -> void:
	if is_instance_valid(_scroll):
		_press_scroll_y[id] = _scroll.scroll_vertical


func _open_preview(id: String) -> void:
	var before: int = int(_press_scroll_y.get(id, -1))
	_press_scroll_y.erase(id)
	if _dragging or Time.get_ticks_msec() < _tap_guard_until:
		return
	if before >= 0 and absi(_scroll.scroll_vertical - before) >= SCROLL_DEADZONE:
		return
	match id:
		"seven_day":
			_modal_title.text = "SEVEN DAYS OF ASCENSION"
			_modal_body.text = "Production will open the existing Seven-Day event. No reward is granted from this visual LAB."
		"daily":
			_modal_title.text = "DAILY TRIALS"
			_modal_body.text = "Production will open the existing Daily Trials screen. This LAB does not claim or change quests."
		"pavilion":
			_modal_title.text = "CELESTIAL PAVILION"
			_modal_body.text = "Production will open the existing Pavilion screen. This LAB never opens ads or purchases."
		_:
			return
	_modal.visible = true


func _on_scroll_started() -> void:
	_dragging = true
	_tap_guard_until = Time.get_ticks_msec() + SCROLL_GUARD_MS


func _on_scroll_ended() -> void:
	_dragging = false
	_tap_guard_until = Time.get_ticks_msec() + SCROLL_GUARD_MS


func _fit_layout() -> void:
	if not is_instance_valid(_popup) or size.x < 1.0 or size.y < 1.0:
		return
	_popup.visible = false
	_chrome_mask.visible = false
	_chrome_frame.visible = false
	_close_button.visible = false

	var compact: bool = size.x < 500.0
	var popup_w: float = minf(size.x - 14.0, 640.0)
	var popup_h: float = minf(size.y - 40.0, 1020.0)
	_popup.position = Vector2((size.x - popup_w) * 0.5, (size.y - popup_h) * 0.5)
	_popup.size = Vector2(popup_w, popup_h)

	# The approved frame has a narrow closed interior. Keep EVERY interactive
	# child within it; the custom background is masked to that same silhouette.
	var safe_x: int = ceili(maxf(27.0, popup_w * 0.087))
	var safe_top: int = ceili(maxf(74.0, popup_h * 0.132))
	var safe_bottom: int = ceili(maxf(76.0, popup_h * 0.107))
	_body_margin.add_theme_constant_override("margin_left", safe_x)
	_body_margin.add_theme_constant_override("margin_right", safe_x)
	_body_margin.add_theme_constant_override("margin_top", safe_top)
	_body_margin.add_theme_constant_override("margin_bottom", safe_bottom)

	_grid.columns = 1 if compact else 2
	_featured_action_row.columns = 1 if compact else 2
	# Production readability raises 13px badges to 15px. Author at that
	# final size in the LAB and reserve real widths for every status value.
	_featured_tag.text = "FEATURED" if compact else "FEATURED EVENT"
	_featured_tag.custom_minimum_size.x = 94.0 if compact else 155.0
	_event_status.custom_minimum_size.x = 124.0 if compact else 126.0

	var inner_w: float = popup_w - float(safe_x) * 2.0
	var target_title_font: int = 22 if compact else 28
	if _header_title.get_theme_font_size("font_size") != target_title_font:
		_header_title.add_theme_font_size_override("font_size", target_title_font)
	_header_title.size = Vector2(inner_w, 40.0)
	var eye := _header.get_node_or_null("EventEyebrow") as Label
	if eye != null:
		eye.text = (
			"JADE ASCENDANT  /  EVENTS"
			if compact else "JADE ASCENDANT  /  LIVE EVENTS"
		)
		eye.size.x = inner_w
	var divider := _header.get_node_or_null("HeaderSeparator") as HSeparator
	if divider != null:
		divider.size.x = inner_w

	# Keep the approved banner height, layout and scroll behavior unchanged.
	# Only the picture-fitting policy above changes in V1.4.
	var source_size: Vector2i = SEVEN_DAY_ART.get_size()
	var source_ratio: float = float(source_size.y) / maxf(float(source_size.x), 1.0)
	var hero_available_w: float = maxf(inner_w - 26.0, 1.0)
	var hero_h: float = clampf(
		hero_available_w * source_ratio,
		196.0 if compact else 240.0,
		260.0 if compact else 355.0
	)
	_hero_stage.custom_minimum_size.y = hero_h

	var modal_box := _modal.get_node_or_null("NonInteractiveDestinationPreview") as PanelContainer
	if modal_box != null:
		if compact and popup_h < 650.0:
			modal_box.anchor_top = 0.18
			modal_box.anchor_bottom = 0.82
		else:
			modal_box.anchor_top = 0.25 if compact else 0.33
			modal_box.anchor_bottom = 0.75 if compact else 0.67

	_layout_generation += 1
	call_deferred("_settle_popup_height", _layout_generation)


func _settle_popup_height(expected_generation: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_inside_tree() or expected_generation != _layout_generation:
		return
	if not is_instance_valid(_popup) or not is_instance_valid(_scroll):
		return
	var body: Control = _scroll.get_child(0) as Control
	if body == null:
		return
	var desired_body_height: float = body.get_combined_minimum_size().y
	var safe_top: float = float(_body_margin.get_theme_constant("margin_top"))
	var safe_bottom: float = float(_body_margin.get_theme_constant("margin_bottom"))
	var required_height: float = (
		_header.custom_minimum_size.y + 9.0 + safe_top
		+ safe_bottom + desired_body_height + 6.0
	)
	var viewport_cap: float = minf(maxf(size.y - 40.0, 1.0), 1020.0)
	var target_height: float = minf(viewport_cap, maxf(required_height, 340.0))
	_popup.size.y = target_height
	_popup.position.y = (size.y - target_height) * 0.5

	# Frame AND background use the exact same rect/stretch. Never leave the
	# old rectangular shadow sticking outside the ornamental alpha silhouette.
	_chrome_mask.position = _popup.position
	_chrome_mask.size = _popup.size
	_chrome_frame.position = _popup.position
	_chrome_frame.size = _popup.size
	_close_button.position = (
		_popup.position
		+ Vector2(_popup.size.x * 0.908 - 22.0, _popup.size.y * 0.084 - 22.0)
	)

	_popup.visible = true
	_chrome_mask.visible = true
	_chrome_frame.visible = true
	_close_button.visible = true


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if is_instance_valid(_modal) and _modal.visible:
		_modal.visible = false
	else:
		_close_lab()


func _close_lab() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _add_panel_margin(
	parent: PanelContainer,
	child: Control,
	left: int,
	top: int,
	right: int,
	bottom: int
) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(m)
	m.add_child(child)


func _panel_container(
	ui_name: String,
	fill: Color,
	border: Color,
	radius: int,
	width_value: int
) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = ui_name
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _panel(fill, border, radius, width_value, 3))
	return p


func _panel(
	fill: Color,
	edge: Color,
	radius: int,
	width_value: int,
	shadow_size: int = 0
) -> StyleBoxFlat:
	var p := StyleBoxFlat.new()
	p.bg_color = fill
	p.border_color = edge
	p.set_border_width_all(width_value)
	p.set_corner_radius_all(radius)
	p.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	p.shadow_size = shadow_size
	return p


func _texture(tex: Texture2D) -> TextureRect:
	var v := TextureRect.new()
	v.texture = tex
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _badge(value: String, ink: Color, fill: Color) -> Label:
	var l := _label(value, 13, ink)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_stylebox_override("normal", _panel(fill, GOLD, 7, 1))
	return l


func _label(value: String, size_value: int, ink: Color) -> Label:
	var l := Label.new()
	l.text = value
	# The production MenuReadabilityManager excludes /lab/, but on promotion
	# it raises 12/13px -> 15px and 15px -> 16px. Set the FINAL size
	# before first paint so there is no delayed label reflow in production.
	var final_size: int = size_value
	if size_value <= 7:
		final_size = 12
	elif size_value <= 9:
		final_size = 13
	elif size_value <= 11:
		final_size = 14
	elif size_value <= 13:
		final_size = 15
	elif size_value <= 15:
		final_size = 16
	l.add_theme_font_size_override("font_size", final_size)
	l.add_theme_color_override("font_color", ink)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(value: String, main: bool) -> Button:
	var b := Button.new()
	b.text = value
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.keep_pressed_outside = false
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override(
		"font_color", Color(0.12, 0.07, 0.01, 1.0) if main else IVORY
	)
	b.add_theme_stylebox_override(
		"normal",
		_panel(
			Color(0.99, 0.78, 0.34, 1.0) if main else Color(0.0, 0.08, 0.09, 0.98),
			GOLD if main else JADE, 9, 2
		)
	)
	b.add_theme_stylebox_override(
		"hover",
		_panel(
			Color(1.0, 0.89, 0.53, 1.0) if main else Color(0.03, 0.14, 0.15, 1.0),
			GOLD_LIGHT, 9, 2
		)
	)
	b.add_theme_stylebox_override(
		"pressed",
		_panel(
			Color(0.88, 0.63, 0.25, 1.0) if main else Color(0.0, 0.05, 0.06, 1.0),
			GOLD, 9, 2
		)
	)
	return b
