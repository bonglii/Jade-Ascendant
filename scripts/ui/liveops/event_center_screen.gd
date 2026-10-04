extends Control

## CELESTIAL EVENTS — USER-APPROVED PRODUCTION UI (LAB V1.5).
## Presentation and navigation only. LiveOpsManager remains the exclusive
## authority for seven-day progress, rewards, claims and persistent state.
## Daily Trials and Pavilion continue to own their own gameplay and economy.

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")
const NEW_PLAYER_SCENE: String = "res://scenes/ui/new_player_event_screen.tscn"
const DAILY_SCENE: String = "res://scenes/ui/daily_quest_screen.tscn"
const PAVILION_SCENE: String = "res://scenes/ui/pavilion_screen.tscn"

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
# Exact copies of the visually approved Treasury frame and its fitted mask.
# Production owns its copies so a future LAB cleanup cannot break this screen.
const FRAME_ART: Texture2D = preload(
	"res://assets/ui/liveops/event_center_production/treasury_frame_approved.png"
)
const INTERIOR_ART: Texture2D = preload(
	"res://assets/ui/liveops/event_center_production/frame_interior_silhouette.png"
)

const GOLD: Color = Color(0.93, 0.74, 0.35, 1.0)
const GOLD_LIGHT: Color = Color(1.0, 0.91, 0.67, 1.0)
const JADE: Color = Color(0.44, 0.91, 0.79, 1.0)
const IVORY: Color = Color(0.97, 0.97, 0.92, 1.0)
const MUTED: Color = Color(0.73, 0.84, 0.82, 1.0)
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
var _dragging: bool = false
var _tap_guard_until: int = 0
var _press_scroll_y: Dictionary = {}
var _layout_generation: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_live_ops = get_node_or_null("/root/LiveOpsManager")
	if _live_ops == null:
		push_error("EventCenterScreen: LiveOpsManager tidak tersedia.")
		return
	# Popup mode receives a Back handler from LiveOpsManager after add_child().
	if not bool(get_meta("liveops_popup", false)):
		SceneTransitionManager.set_back_handler(_back)
	_build_production()
	# Hold only the initial layout until responsive container measurements settle.
	# This prevents the blank tall popup from appearing for one frame.
	_popup.visible = false
	_refresh_event_status()
	_fit_layout()
	resized.connect(_fit_layout)
	if _live_ops != null and _live_ops.has_signal("live_ops_changed"):
		var refresh_callback: Callable = Callable(self, "_refresh_event_status")
		if not _live_ops.is_connected("live_ops_changed", refresh_callback):
			_live_ops.connect("live_ops_changed", refresh_callback)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		_refresh_event_status()
		_fit_layout()

func _build_production() -> void:
	# Home owns its actual backdrop, wallet and bottom navigation when this
	# scene is embedded as a LiveOps popup. Only standalone mode adds key art.
	if not bool(get_meta("liveops_popup", false)):
		var backdrop := TextureRect.new()
		backdrop.name = "StandaloneHomeBackdrop"
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
	_popup.name = "CelestialEventsProductionPopup"
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
		"EVENT REWARDS ARE CLAIMED IN THEIR OWN SCREENS",
		12, MUTED
	)
	footer.name = "EventCenterFooter"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.custom_minimum_size.y = 26.0
	body.add_child(footer)

	_scroll.scroll_started.connect(_on_scroll_started)
	_scroll.scroll_ended.connect(_on_scroll_ended)

	# Frame is drawn over only the noninteractive outer edge.
	# All interactive content remains inset from its opaque ornament.
	_chrome_frame = _texture(FRAME_ART)
	_chrome_frame.name = "ExactTreasuryApprovedOrnamentalFrame"
	_chrome_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_chrome_frame.visible = false
	_chrome_frame.z_index = 2
	add_child(_chrome_frame)

	_close_button = _button("×", false)
	_close_button.name = "CloseEventCenter"
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
	_close_button.pressed.connect(_back)
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
	open.name = "OpenSevenDayEvent"
	open.custom_minimum_size = Vector2(153.0, 48.0)
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wire_navigation_button(open, "seven_day")
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
	_wire_navigation_button(cta, preview_id)
	card_content.add_child(cta)


func _refresh_event_status() -> void:
	if _event_status == null or _event_progress == null:
		return
	if _live_ops == null:
		return
	var day_count: int = int(_live_ops.get_active_login_day_count())
	var total: int = int(_live_ops.LOGIN_DAY_COUNT)
	var claimable: int = int(_live_ops.get_login_claimable_count())
	_event_progress.text = tr("DAY %d / %d") % [day_count, total]
	if bool(_live_ops.is_new_player_event_complete()):
		_event_status.text = tr("COMPLETED")
	elif claimable > 0:
		_event_status.text = tr("%d READY") % claimable
	else:
		_event_status.text = tr("IN PROGRESS")


func _wire_navigation_button(button: Button, id: String) -> void:
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.keep_pressed_outside = false
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.button_down.connect(_record_button_down.bind(id))
	button.pressed.connect(_open_destination.bind(id))


func _record_button_down(id: String) -> void:
	if is_instance_valid(_scroll):
		_press_scroll_y[id] = _scroll.scroll_vertical


func _open_destination(id: String) -> void:
	var before: int = int(_press_scroll_y.get(id, -1))
	_press_scroll_y.erase(id)
	if _dragging or Time.get_ticks_msec() < _tap_guard_until:
		return
	if before >= 0 and absi(_scroll.scroll_vertical - before) >= SCROLL_DEADZONE:
		return

	var scene_path: String = ""
	match id:
		"seven_day":
			scene_path = NEW_PLAYER_SCENE
		"daily":
			scene_path = DAILY_SCENE
		"pavilion":
			scene_path = PAVILION_SCENE
		_:
			return

	# Seven Days remains a popup when Event Center was opened from Home.
	# For other destinations retain the existing lightweight menu transition.
	if bool(get_meta("liveops_popup", false)) and id == "seven_day":
		if _live_ops != null and _live_ops.has_method("open_live_popup"):
			_live_ops.call("open_live_popup", scene_path)
			return

	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		scene_path, 1
	)
	if change_error != OK:
		push_error(
			"EventCenterScreen: gagal membuka scene. Error code: "
			+ str(change_error)
		)


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
	_featured_tag.text = tr("FEATURED") if compact else tr("FEATURED EVENT")
	_featured_tag.custom_minimum_size.x = 92.0 if compact else 155.0
	_event_status.custom_minimum_size.x = 122.0 if compact else 126.0
	var ribbon_row: HBoxContainer = _featured_tag.get_parent() as HBoxContainer
	if ribbon_row != null:
		ribbon_row.add_theme_constant_override("separation", 5 if compact else 9)

	var inner_w: float = popup_w - float(safe_x) * 2.0
	var target_title_font: int = 22 if compact else 28
	if _header_title.get_theme_font_size("font_size") != target_title_font:
		_header_title.add_theme_font_size_override("font_size", target_title_font)
	_header_title.size = Vector2(inner_w, 40.0)
	var eye := _header.get_node_or_null("EventEyebrow") as Label
	if eye != null:
		eye.text = (
			tr("JADE ASCENDANT  /  EVENTS")
			if compact else tr("JADE ASCENDANT  /  LIVE EVENTS")
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
	_back()


func _back() -> void:
	LiveOpsUi.return_home(self)


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
	l.text = tr(value)
	# Author the production 16px floor before first paint, so the global
	# readability manager has no deferred adjustment to apply.
	var final_size: int = maxi(size_value, 16)
	l.add_theme_font_size_override("font_size", final_size)
	l.add_theme_color_override("font_color", ink)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(value: String, main: bool) -> Button:
	var b := Button.new()
	b.text = tr(value)
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
