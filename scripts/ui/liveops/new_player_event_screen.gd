extends Control

## CELESTIAL SIGN-IN — PRODUCTION POPUP
## Presentation and input only. LiveOpsManager handles the active-day ledger,
## catalog, claim verification and save. Existing RewardManager signals drive
## Universal Reward Claim Result and Reward Delivery presenters.
## Visual layout promoted from the user-approved warning-clean LAB V3.8.

const HOME_SCENE: String = "res://scenes/ui/main_menu.tscn"
const APPROVED_HERO_PATH: String = (
	"res://assets/ui/liveops/seven_day/"
	+ "seven_day_ascension_hero_portrait_bg.png"
)
const HOME_ART: Texture2D = preload(
	"res://assets/ui/main_menu/main_menu_key_art_lin_yue.png"
)
const SEVEN_DAY_BADGE: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/seven_day_premium.png"
)
const SPIRIT_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)
const SHARD_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/refinement_shard_premium.png"
)
const CLAIM_GOLD: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/claim_gold.png"
)
const CLAIM_BLUE: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/claim_blue.png"
)
const PLAQUE_JADE: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/reward_spirit.png"
)
const PLAQUE_CELESTIAL: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/reward_shard.png"
)

const GOLD: Color = Color(0.95, 0.73, 0.30, 1.0)
const GOLD_LIGHT: Color = Color(1.00, 0.90, 0.62, 1.0)
const JADE: Color = Color(0.42, 0.95, 0.82, 1.0)
const SKY: Color = Color(0.62, 0.86, 1.00, 1.0)
const TEXT: Color = Color(0.97, 0.98, 0.96, 1.0)
const MUTED: Color = Color(0.76, 0.84, 0.83, 1.0)
const DIM: Color = Color(0.57, 0.67, 0.71, 1.0)
const SCROLL_DEADZONE: int = 6
const SCROLL_TAP_GUARD_MS: int = 190

var live_ops: Node = null
var _claim_busy: bool = false
var _selected_day: int = 1
var _root: PanelContainer = null
var _top_scroll: ScrollContainer = null
var _top_contents: VBoxContainer = null
var _day_section: VBoxContainer = null
var _layout_generation: int = 0
var _pressed_scroll_y: Dictionary = {}
var _header: Control = null
var _day_scroll: ScrollContainer = null
var _day_strip: HBoxContainer = null
# Keep selected/unselected plaques alive; only update their visual state.
var _day_card_refs: Dictionary = {}
var _active_label: Label = null
var _day_title: Label = null
var _day_status: Label = null
var _reward_row: GridContainer = null
# Preserve reward tile controls/font normalization when switching days.
var _stone_reward_value: Label = null
var _shard_reward_value: Label = null
var _shard_reward_slot: PanelContainer = null
var _action: Button = null
var _action_art: TextureRect = null
var _footer_note: Label = null
var _tap_guard_until: int = 0
var _pressed_scroll_x: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	live_ops = get_node_or_null("/root/LiveOpsManager")
	if live_ops == null:
		push_error("NewPlayerEventScreen: LiveOpsManager unavailable.")
		return

	_selected_day = _preferred_active_day()
	_build_background()
	_build_popup()
	_refresh()
	var refresh_callback: Callable = Callable(self, "_on_live_ops_changed")
	if (
		live_ops.has_signal("live_ops_changed")
		and not live_ops.is_connected("live_ops_changed", refresh_callback)
	):
		live_ops.connect("live_ops_changed", refresh_callback)

	SceneTransitionManager.set_back_handler(_close_event)
	call_deferred("_layout_to_viewport")
	call_deferred("_focus_selected_card")


func _preferred_active_day() -> int:
	if live_ops == null:
		return 1
	var total: int = int(live_ops.get_active_login_day_count())
	for day: int in range(1, int(live_ops.LOGIN_DAY_COUNT) + 1):
		if (
			bool(live_ops.is_login_day_unlocked(day))
			and not bool(live_ops.is_login_day_claimed(day))
		):
			return day
	return clampi(total, 1, int(live_ops.LOGIN_DAY_COUNT))


func _on_live_ops_changed() -> void:
	if is_inside_tree() and _active_label != null:
		_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_layout_to_viewport")


func _layout_to_viewport() -> void:
	_layout_generation += 1
	var generation: int = _layout_generation
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _layout_generation:
		return
	if (
		_top_scroll == null or not is_instance_valid(_top_scroll)
		or _top_contents == null or not is_instance_valid(_top_contents)
		or _header == null or not is_instance_valid(_header)
		or _day_section == null or not is_instance_valid(_day_section)
		or _day_scroll == null or not is_instance_valid(_day_scroll)
	):
		return

	# Fill spare vertical space with the approved hero and readable plaques;
	# do not leave an empty black spacer above the pinned reward panel.
	var target_track: float = clampf(
		get_viewport_rect().size.y * 0.22, 216.0, 272.0
	)
	_day_scroll.custom_minimum_size.y = target_track
	var section_minimum: float = (
		_day_section.get_combined_minimum_size().y
		+ float(_top_contents.get_theme_constant("separation"))
	)
	_header.custom_minimum_size.y = maxf(
		122.0,
		_top_scroll.size.y - section_minimum - 4.0
	)



func _build_background() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.texture = HOME_ART
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.78, 0.88, 0.94, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.001, 0.008, 0.018, 0.68)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_backdrop_input)
	add_child(scrim)


func _build_popup() -> void:
	_root = PanelContainer.new()
	_root.name = "SevenDayAscensionProductionPopup"
	_root.anchor_left = 0.035
	_root.anchor_top = 0.055
	_root.anchor_right = 0.965
	_root.anchor_bottom = 0.945
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_theme_stylebox_override(
		"panel",
		_style(
			Color(0.003, 0.021, 0.032, 0.22),
			Color(1.0, 0.80, 0.34, 0.96),
			20,
			13,
			2
		)
	)
	add_child(_root)

	var popup_background := TextureRect.new()
	popup_background.name = "SevenDayPopupBackground"
	popup_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	popup_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	popup_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var popup_texture: Resource = ResourceLoader.load(
		APPROVED_HERO_PATH,
		"Texture2D",
		ResourceLoader.CACHE_MODE_REUSE
	)
	popup_background.texture = (
		popup_texture as Texture2D
		if popup_texture is Texture2D
		else HOME_ART
	)
	popup_background.modulate = Color(0.98, 0.98, 0.98, 1.0)
	_root.add_child(popup_background)

	var popup_scrim := ColorRect.new()
	popup_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_scrim.color = Color(0.0, 0.015, 0.026, 0.10)
	popup_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(popup_scrim)

	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 10)
	inset.add_theme_constant_override("margin_top", 11)
	inset.add_theme_constant_override("margin_right", 10)
	inset.add_theme_constant_override("margin_bottom", 11)
	_root.add_child(inset)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 7)
	inset.add_child(stack)

	_top_scroll = ScrollContainer.new()
	_top_scroll.name = "SevenDayContentScroll"
	_top_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_top_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_top_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_top_scroll.scroll_deadzone = SCROLL_DEADZONE
	_top_scroll.follow_focus = false
	_top_scroll.scroll_started.connect(_mark_drag)
	_top_scroll.scroll_ended.connect(_mark_drag)
	stack.add_child(_top_scroll)

	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 9)
	_top_contents = contents
	_top_scroll.add_child(contents)

	_build_header(contents)
	_build_day_track(contents)
	_build_footer(stack)


func _build_header(parent: VBoxContainer) -> void:
	_header = Control.new()
	_header.name = "ApprovedSevenDayHero"
	_header.custom_minimum_size = Vector2(0.0, 122.0)
	_header.clip_contents = true
	_header.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(_header)

	var header_glass := ColorRect.new()
	header_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_glass.color = Color(0.01, 0.03, 0.05, 0.0)
	header_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(header_glass)

	var title_inset := MarginContainer.new()
	title_inset.anchor_left = 0.0
	title_inset.anchor_top = 0.0
	title_inset.anchor_right = 1.0
	title_inset.anchor_bottom = 0.0
	title_inset.offset_top = 10.0
	title_inset.offset_bottom = 108.0
	title_inset.add_theme_constant_override("margin_left", 13)
	title_inset.add_theme_constant_override("margin_top", 7)
	title_inset.add_theme_constant_override("margin_right", 13)
	title_inset.add_theme_constant_override("margin_bottom", 7)
	title_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(title_inset)

	var title_column := VBoxContainer.new()
	title_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_column.alignment = BoxContainer.ALIGNMENT_CENTER
	title_column.add_theme_constant_override("separation", 1)
	title_inset.add_child(title_column)

	var eyebrow := _label("✦  SEVEN-DAY BLESSING  ✦", 13, JADE)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_title_shadow(eyebrow)
	title_column.add_child(eyebrow)

	var heading := _label("CELESTIAL SIGN-IN", 30, GOLD_LIGHT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_title_shadow(heading)
	title_column.add_child(heading)

	var subtitle := _label("Seven active days. Your ascension awaits.", 15, TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_title_shadow(subtitle)
	title_column.add_child(subtitle)

	var close := Button.new()
	close.anchor_left = 1.0
	close.anchor_top = 0.0
	close.anchor_right = 1.0
	close.anchor_bottom = 0.0
	close.offset_left = -52.0
	close.offset_top = 7.0
	close.offset_right = -8.0
	close.offset_bottom = 51.0
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_filter = Control.MOUSE_FILTER_PASS
	close.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	close.keep_pressed_outside = false
	close.add_theme_font_size_override("font_size", 28)
	close.add_theme_color_override("font_color", GOLD_LIGHT)
	close.add_theme_stylebox_override(
		"normal", _style(Color(0.01, 0.035, 0.05, 0.93), GOLD, 24, 2, 2)
	)
	close.pressed.connect(_close_event)
	_header.add_child(close)


func _build_day_track(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	_day_section = section
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 7)
	parent.add_child(section)

	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 4)
	section.add_child(heading_row)

	var path_title := _label("ASCENSION PATH", 15, GOLD_LIGHT)
	path_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(path_title)

	_active_label = _label("04 / 07 ACTIVE", 13, JADE)
	heading_row.add_child(_active_label)


	var rail := PanelContainer.new()
	rail.add_theme_stylebox_override(
		"panel",
		_style(Color(0.005, 0.04, 0.053, 0.26), Color(0.93, 0.76, 0.33, 0.48), 15, 1, 1)
	)
	section.add_child(rail)

	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 4)
	inset.add_theme_constant_override("margin_top", 6)
	inset.add_theme_constant_override("margin_right", 4)
	inset.add_theme_constant_override("margin_bottom", 6)
	rail.add_child(inset)

	_day_scroll = ScrollContainer.new()
	_day_scroll.name = "DayPlaquesHorizontalScroll"
	_day_scroll.custom_minimum_size = Vector2(0.0, 228.0)
	_day_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_day_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_day_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_day_scroll.scroll_deadzone = SCROLL_DEADZONE
	_day_scroll.follow_focus = false
	_day_scroll.scroll_started.connect(_mark_drag)
	_day_scroll.scroll_ended.connect(_mark_drag)
	inset.add_child(_day_scroll)

	_day_strip = HBoxContainer.new()
	_day_strip.name = "SevenHangingPlaques"
	_day_strip.add_theme_constant_override("separation", 8)
	_day_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	_day_scroll.add_child(_day_strip)

	var guide := _label("←  SWIPE FOR DAYS 1–7  →", 14, MUTED)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.modulate = Color(1.0, 1.0, 1.0, 0.78)
	section.add_child(guide)

	var day_bar: HScrollBar = _day_scroll.get_h_scroll_bar()
	day_bar.visible = false
	day_bar.modulate = Color(1,1,1,0)
	day_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_bar.custom_minimum_size = Vector2.ZERO


func _build_footer(parent: VBoxContainer) -> void:
	# A plain Control reserves exactly one fixed footprint in the parent VBox.
	# Unlike PanelContainer, its minimum height does not grow when the day
	# switches from one visible reward to two (or the labels change).
	var footer_slot := Control.new()
	footer_slot.name = "SelectedDayDetailsFixedSlot"
	footer_slot.custom_minimum_size = Vector2(0.0, 262.0)
	footer_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_slot.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(footer_slot)

	var footer := PanelContainer.new()
	footer.name = "SelectedDayDetailsPinned"
	footer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	footer.mouse_filter = Control.MOUSE_FILTER_PASS
	footer.add_theme_stylebox_override(
		"panel",
		_style(Color(0.004, 0.038, 0.05, 0.28), Color(0.99, 0.79, 0.36, 0.68), 16, 1, 1)
	)
	footer_slot.add_child(footer)

	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 10)
	inset.add_theme_constant_override("margin_top", 6)
	inset.add_theme_constant_override("margin_right", 10)
	inset.add_theme_constant_override("margin_bottom", 7)
	footer.add_child(inset)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	inset.add_child(column)

	_day_title = _label("DAY 04", 22, GOLD_LIGHT)
	_day_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_day_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_day_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_day_title)

	_day_status = _label("READY TO CLAIM", 13, JADE)
	_day_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_day_status)

	_reward_row = GridContainer.new()
	_reward_row.columns = 2
	_reward_row.custom_minimum_size = Vector2(0.0, 90.0)
	_reward_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_row.add_theme_constant_override("h_separation", 8)
	_reward_row.add_theme_constant_override("v_separation", 8)
	column.add_child(_reward_row)

	_action = Button.new()
	_action.custom_minimum_size = Vector2(0.0, 56.0)
	_action.text = "CLAIM REWARD"
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action.focus_mode = Control.FOCUS_NONE
	_action.mouse_filter = Control.MOUSE_FILTER_PASS
	_action.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_action.keep_pressed_outside = false
	_action.add_theme_font_size_override("font_size", 20)
	_action.add_theme_color_override("font_color", Color(0.20, 0.13, 0.02, 1.0))
	_action.add_theme_color_override("font_disabled_color", Color(0.30, 0.28, 0.18, 1.0))
	for style_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var transparent := StyleBoxFlat.new()
		transparent.bg_color = Color.TRANSPARENT
		_action.add_theme_stylebox_override(style_name, transparent)
	column.add_child(_action)
	_action_art = _texture(CLAIM_GOLD, Vector2.ZERO, TextureRect.STRETCH_SCALE)
	_action_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_action_art.show_behind_parent = true
	_action.add_child(_action_art)
	_action.pressed.connect(_on_claim_pressed)

	_footer_note = _label("REWARDS SAVE ON CLAIM", 13, MUTED)
	_footer_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_footer_note)


func _refresh() -> void:
	if live_ops == null or _active_label == null:
		return
	_selected_day = clampi(
		_selected_day,
		1,
		int(live_ops.LOGIN_DAY_COUNT)
	)
	_active_label.text = "%d/7 ACTIVE" % int(
		live_ops.get_active_login_day_count()
	)
	_render_day_cards()
	_refresh_footer()

func _render_day_cards() -> void:
	var total: int = int(live_ops.LOGIN_DAY_COUNT)
	if _day_card_refs.size() == total and _day_strip.get_child_count() == total:
		# A different selected day does not require rebuilding seven buttons.
		# Rebuilding gave new text a second, delayed readability/layout pass.
		for day: int in range(1, total + 1):
			_refresh_day_card(day)
		call_deferred("_focus_selected_card")
		return

	_day_card_refs.clear()
	_clear(_day_strip)
	_pressed_scroll_x.clear()
	_pressed_scroll_y.clear()
	for day: int in range(1, total + 1):
		_day_strip.add_child(_make_day_card(day))
	call_deferred("_layout_to_viewport")
	call_deferred("_focus_selected_card")


func _refresh_day_card(day: int) -> void:
	var refs: Dictionary = _day_card_refs.get(day, {})
	var card: Button = refs.get("card") as Button
	var frame: TextureRect = refs.get("frame") as TextureRect
	var day_label: Label = refs.get("day_label") as Label
	var status_label: Label = refs.get("status") as Label
	var reward_icon: TextureRect = refs.get("reward_icon") as TextureRect
	var gift_amount: Label = refs.get("gift_amount") as Label
	var secondary: Label = refs.get("secondary") as Label
	if (
		not is_instance_valid(card)
		or not is_instance_valid(frame)
		or not is_instance_valid(day_label)
		or not is_instance_valid(status_label)
		or not is_instance_valid(reward_icon)
		or not is_instance_valid(gift_amount)
		or not is_instance_valid(secondary)
	):
		return

	var state: String = _state(day)
	var selected: bool = day == _selected_day
	var final_day: bool = day == 7
	var accent: Color = _accent(day, state)
	var desired_size := Vector2(170.0 if final_day else (151.0 if selected else 145.0), 247.0)
	if card.custom_minimum_size != desired_size:
		card.custom_minimum_size = desired_size
	var next_texture: Texture2D = PLAQUE_CELESTIAL if final_day or selected else PLAQUE_JADE
	if frame.texture != next_texture:
		frame.texture = next_texture
	var tint: Color = (
		Color(1.0, 0.97, 0.83, 1.0)
		if final_day or selected else (
			Color(0.78, 0.98, 0.91, 0.98)
			if state == "claimed" else Color(0.62, 0.70, 0.73, 0.94)
		)
	)
	if frame.modulate != tint:
		frame.modulate = tint
	var day_color: Color = GOLD_LIGHT if selected or final_day else TEXT
	if day_label.get_theme_color("font_color") != day_color:
		day_label.add_theme_color_override("font_color", day_color)
	var status_text: String = "✓ CLAIMED" if state == "claimed" else ("✦ READY" if state == "ready" else "◈ LOCKED")
	if status_label.text != status_text:
		status_label.text = status_text
	if status_label.get_theme_color("font_color") != accent:
		status_label.add_theme_color_override("font_color", accent)
	var icon_tint: Color = Color.WHITE if state != "locked" else Color(0.66, 0.71, 0.72, 0.78)
	if reward_icon.modulate != icon_tint:
		reward_icon.modulate = icon_tint
	var reward: Dictionary = _reward(day)
	var stone_text: String = "+%d" % int(reward.get("spirit_stone", 0))
	if gift_amount.text != stone_text:
		gift_amount.text = stone_text
	var shard_count: int = int(reward.get("refinement_shard", 0))
	var secondary_text: String = "+%d SHARDS" % shard_count if shard_count > 0 else "STONES"
	if secondary.text != secondary_text:
		secondary.text = secondary_text


func _make_day_card(day: int) -> Button:
	var state: String = _state(day)
	var selected: bool = day == _selected_day
	var final_day: bool = day == 7
	var accent: Color = _accent(day, state)

	var card := Button.new()
	card.name = "DayPlaque_%02d" % day
	card.custom_minimum_size = Vector2(
		170.0 if final_day else (151.0 if selected else 145.0), 247.0
	)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	card.keep_pressed_outside = false
	card.text = ""
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var transparent := StyleBoxFlat.new()
		transparent.bg_color = Color.TRANSPARENT
		card.add_theme_stylebox_override(style_name, transparent)

	var frame := _texture(
		PLAQUE_CELESTIAL if final_day or selected else PLAQUE_JADE,
		Vector2.ZERO,
		TextureRect.STRETCH_SCALE
	)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 1.0
	frame.offset_top = 3.0
	frame.offset_right = -1.0
	frame.offset_bottom = -3.0
	frame.modulate = (
		Color(1.0, 0.97, 0.83, 1.0)
		if final_day or selected else (
			Color(0.78, 0.98, 0.91, 0.98)
			if state == "claimed" else Color(0.62, 0.70, 0.73, 0.94)
		)
	)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)

	var insets := MarginContainer.new()
	insets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	insets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	insets.add_theme_constant_override("margin_left", 12)
	insets.add_theme_constant_override("margin_top", 31)
	insets.add_theme_constant_override("margin_right", 12)
	insets.add_theme_constant_override("margin_bottom", 12)
	card.add_child(insets)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	insets.add_child(content)

	var day_label := _label("DAY %d" % day, 20, GOLD_LIGHT if selected or final_day else TEXT)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(day_label)

	var status := _label(
		"✓ CLAIMED" if state == "claimed" else ("✦ READY" if state == "ready" else "◈ LOCKED"),
		15,
		accent
	)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 5.0)
	content.add_child(spacer)

	var reward_icon := _texture(
		SEVEN_DAY_BADGE if final_day else (SHARD_ICON if day in [2, 3, 4, 5, 6] else SPIRIT_ICON),
		Vector2(68.0, 68.0),
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	reward_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reward_icon.modulate = Color.WHITE if state != "locked" else Color(0.66, 0.71, 0.72, 0.78)
	content.add_child(reward_icon)

	var gift_amount := _label("+%d" % int(_reward(day).get("spirit_stone", 0)), 21, GOLD_LIGHT)
	gift_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(gift_amount)

	var shard_count: int = int(_reward(day).get("refinement_shard", 0))
	var secondary := _label(
		"+%d SHARDS" % shard_count if shard_count > 0 else "STONES",
		14,
		MUTED
	)
	secondary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(secondary)

	card.button_down.connect(_capture_card_press.bind(day))
	card.pressed.connect(_on_card_pressed.bind(day))
	_day_card_refs[day] = {
		"card": card,
		"frame": frame,
		"day_label": day_label,
		"status": status,
		"reward_icon": reward_icon,
		"gift_amount": gift_amount,
		"secondary": secondary,
	}
	return card


func _refresh_footer() -> void:
	var state: String = _state(_selected_day)
	var final_day: bool = _selected_day == 7
	var reward: Dictionary = _reward(_selected_day)

	_day_title.text = "DAY 07  •  THE SEVENTH GATE" if final_day else "DAY %02d  •  ASCENSION REWARD" % _selected_day
	_day_title.add_theme_color_override("font_color", GOLD_LIGHT if final_day or state == "ready" else JADE)
	_day_status.text = _state_text(state)
	_day_status.add_theme_color_override("font_color", _accent(_selected_day, state))

	# Keep the two pinned reward tiles and their normalized typography alive.
	# Selection changes update amounts/visibility, not footer geometry.
	_reward_row.columns = 2
	if (
		not is_instance_valid(_stone_reward_value)
		or not is_instance_valid(_shard_reward_value)
		or not is_instance_valid(_shard_reward_slot)
	):
		_clear(_reward_row)
		var stone_tile := _footer_reward_item(SPIRIT_ICON, "0", "SPIRIT STONES")
		_reward_row.add_child(stone_tile)
		_stone_reward_value = stone_tile.find_child("RewardValue", true, false) as Label
		_shard_reward_slot = _footer_reward_item(SHARD_ICON, "0", "REFINEMENT SHARDS")
		_shard_reward_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reward_row.add_child(_shard_reward_slot)
		_shard_reward_value = _shard_reward_slot.find_child("RewardValue", true, false) as Label
	if is_instance_valid(_stone_reward_value):
		_stone_reward_value.text = str(int(reward.get("spirit_stone", 0)))
	var shard_amount: int = int(reward.get("refinement_shard", 0))
	if is_instance_valid(_shard_reward_value):
		_shard_reward_value.text = str(shard_amount)
	_shard_reward_slot.modulate.a = 1.0 if shard_amount > 0 else 0.0

	var progress_locked: bool = SaveManager.is_progress_read_only()
	if state == "ready":
		_action.text = "CLAIM FINAL GIFT" if final_day else "CLAIM REWARD"
		_action.disabled = progress_locked or _claim_busy
		_action_art.texture = CLAIM_GOLD if not _action.disabled else CLAIM_BLUE
	elif state == "claimed":
		_action.text = "CLAIMED"
		_action.disabled = true
		_action_art.texture = CLAIM_BLUE
	else:
		_action.text = "UNLOCK ON DAY %d" % _selected_day
		_action.disabled = true
		_action_art.texture = CLAIM_BLUE

	_footer_note.text = (
		"SAVING UNAVAILABLE" if progress_locked
		else "REWARDS SAVE ON CLAIM"
	)


func _footer_reward_item(icon_texture: Texture2D, amount: String, label_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	# Keep two readable cards even on a narrow portrait viewport.
	var cell_width: float = (
		112.0 if get_viewport_rect().size.x < 350.0 else 148.0
	)
	panel.custom_minimum_size = Vector2(cell_width, 90.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_style(
			Color(0.010, 0.067, 0.080, 0.97),
			Color(0.95, 0.77, 0.37, 0.72), 11, 0, 1
		)
	)
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 7)
	inset.add_theme_constant_override("margin_top", 5)
	inset.add_theme_constant_override("margin_right", 7)
	inset.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(inset)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 3)
	inset.add_child(content)
	var icon_and_value := HBoxContainer.new()
	icon_and_value.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_and_value.add_theme_constant_override("separation", 6)
	content.add_child(icon_and_value)
	var icon := _texture(
		icon_texture, Vector2(37.0, 37.0),
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	icon_and_value.add_child(icon)
	var value := _label(amount, 24, GOLD_LIGHT)
	value.name = "RewardValue"
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	icon_and_value.add_child(value)
	# Two intentional words, not automatic one-character wrapping.
	var readable_name: String = (
		"REFINEMENT\nSHARDS"
		if label_text == "REFINEMENT SHARDS"
		else label_text
	)
	var title := _label(readable_name, 14, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Do not wrap the label into one-letter columns when the panel narrows.
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(title)
	return panel


func _footer_placeholder_item() -> PanelContainer:
	# Same exact card subtree as a real shard reward, kept in the layout
	# but hidden from view on one-reward days. No second grant implied.
	var empty_slot: PanelContainer = _footer_reward_item(
		SHARD_ICON,
		"0",
		"REFINEMENT SHARDS"
	)
	empty_slot.modulate.a = 0.0
	empty_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return empty_slot

func _capture_card_press(day: int) -> void:
	_pressed_scroll_x[day] = _day_scroll.scroll_horizontal
	_pressed_scroll_y[day] = _top_scroll.scroll_vertical


func _on_card_pressed(day: int) -> void:
	if Time.get_ticks_msec() < _tap_guard_until:
		return
	var start_scroll_x: int = int(_pressed_scroll_x.get(day, _day_scroll.scroll_horizontal))
	if absi(_day_scroll.scroll_horizontal - start_scroll_x) >= SCROLL_DEADZONE:
		return
	var start_scroll_y: int = int(
		_pressed_scroll_y.get(day, _top_scroll.scroll_vertical)
	)
	if absi(_top_scroll.scroll_vertical - start_scroll_y) >= SCROLL_DEADZONE:
		return
	_selected_day = day
	_refresh()


func _mark_drag() -> void:
	_tap_guard_until = Time.get_ticks_msec() + SCROLL_TAP_GUARD_MS


func _on_claim_pressed() -> void:
	if _claim_busy or live_ops == null or _action == null:
		return
	if _action.disabled or _state(_selected_day) != "ready":
		return
	if SaveManager.is_progress_read_only():
		_refresh_footer()
		return

	_claim_busy = true
	_action.disabled = true
	var day: int = _selected_day
	# Do NOT grant rewards directly. LiveOpsManager commits the permanent
	# claim marker and reward atomically, then RewardManager broadcasts to
	# both existing presentation systems (flying and unified result).
	var claimed: bool = bool(live_ops.claim_login_day(day))
	_claim_busy = false
	if not is_inside_tree():
		return
	_refresh()
	if not claimed:
		_footer_note.text = "CLAIM UNAVAILABLE"


func _on_backdrop_input(event: InputEvent) -> void:
	if (
		(event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	):
		_close_event()

func _focus_selected_card() -> void:
	if _day_scroll == null or not is_instance_valid(_day_scroll) or _day_strip == null:
		return
	await get_tree().process_frame
	if _day_scroll == null or not is_instance_valid(_day_scroll) or _day_strip == null:
		return
	var selected: Control = _day_strip.get_node_or_null("DayPlaque_%02d" % _selected_day) as Control
	if selected == null:
		return
	var max_scroll: int = maxi(
		int(_day_scroll.get_h_scroll_bar().max_value - _day_scroll.size.x),
		0
	)
	var centered_x: float = selected.position.x + selected.size.x * 0.5 - _day_scroll.size.x * 0.5
	_day_scroll.scroll_horizontal = clampi(roundi(centered_x), 0, max_scroll)


func _close_event() -> void:
	if bool(get_meta("liveops_popup", false)):
		if live_ops != null and live_ops.has_method("close_live_popup"):
			live_ops.close_live_popup()
		else:
			queue_free()
		return
	if SceneTransitionManager.is_transitioning:
		return
	var error: Error = SceneTransitionManager.transition_menu_to(
		HOME_SCENE, -1
	)
	if error != OK:
		push_error(
			"NewPlayerEventScreen: failed to return Home: " + str(error)
		)

func _state(day: int) -> String:
	if live_ops == null:
		return "locked"
	if bool(live_ops.is_login_day_claimed(day)):
		return "claimed"
	if bool(live_ops.is_login_day_unlocked(day)):
		return "ready"
	return "locked"

func _state_text(state: String) -> String:
	match state:
		"claimed":
			return "CLAIMED"
		"ready":
			return "READY TO CLAIM"
		_:
			return "SEALED  •  RETURN ON THIS ACTIVE DAY"


func _accent(day: int, state: String) -> Color:
	if state == "claimed":
		return JADE
	if state == "locked":
		return DIM
	return GOLD_LIGHT if day == 7 or day == _selected_day else SKY


func _reward(day: int) -> Dictionary:
	if live_ops == null:
		return {}
	var data: Dictionary = live_ops.get_login_reward(day)
	var items_raw: Variant = data.get("items", {})
	var shards: int = 0
	if items_raw is Dictionary:
		shards = int(
			(items_raw as Dictionary).get(
				InventoryManager.REFINEMENT_SHARD, 0
			)
		)
	return {
		"spirit_stone": int(data.get("spirit_stone", 0)),
		"refinement_shard": shards,
	}

func _texture(texture: Texture2D, minimum_size: Vector2, stretch_mode: int) -> TextureRect:
	var result := TextureRect.new()
	result.custom_minimum_size = minimum_size
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.texture = texture
	result.stretch_mode = stretch_mode as TextureRect.StretchMode
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _apply_title_shadow(label: Label) -> void:
	label.add_theme_color_override(
		"font_shadow_color", Color(0.0, 0.015, 0.025, 0.98)
	)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 2)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _style(background: Color, border: Color, radius: int, shadow_size: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	style.shadow_size = shadow_size
	style.content_margin_left = 8.0
	style.content_margin_top = 5.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 5.0
	return style


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()