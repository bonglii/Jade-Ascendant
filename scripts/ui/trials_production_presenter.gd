extends Node
class_name TrialsProductionPresenter

## Production presentation bridge for the approved Trials LAB direction.
##
## Presentation only. DailyQuestManager / AchievementManager remain the sole
## authorities for progress, eligibility, reward grant, persistence and reset.
## This script never mutates save or economy state directly.

const DAILY_SCENE: String = "res://scenes/ui/daily_quest_screen.tscn"
const ACHIEVEMENT_SCENE: String = "res://scenes/ui/achievement_screen.tscn"

const DAILY_ICON_PATH: String = "res://assets/ui/icons/actions/daily.png"
const ACHIEVEMENT_ICON_PATH: String = (
	"res://assets/ui/icons/actions/achievement.png"
)
const SPIRIT_STONE_ICON_PATH: String = (
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)

const GOLD := Color(0.96, 0.78, 0.34, 1.0)
const JADE := Color(0.25, 0.88, 0.72, 1.0)
const CYAN := Color(0.30, 0.78, 0.92, 1.0)
const MUTED := Color(0.67, 0.76, 0.75, 1.0)

const SINGLE_RESULT_DELAY: float = 0.78
const CLAIM_ALL_RESULT_DELAY: float = 0.96
const MOBILE_SCROLL_DEADZONE: int = 6
const MOBILE_SCROLL_CLAIM_GUARD_MS: int = 180

var scene_root: Control = null
var content_root: Control = null
var active_section: String = "daily"

var presentation_root: Control = null
var section_title: Label = null
var section_icon: TextureRect = null
var ready_value_label: Label = null
var reward_value_label: Label = null
var claim_all_button: Button = null
var daily_tab: Button = null
var achievement_tab: Button = null
var list_host: VBoxContainer = null
var trials_scroll: ScrollContainer = null

var reward_overlay: Control = null
var reward_overlay_panel: PanelContainer = null
var reward_overlay_title: Label = null
var reward_overlay_source: Label = null
var reward_overlay_amount: Label = null
var reward_overlay_balance: Label = null
var reward_overlay_icon: TextureRect = null
var reward_overlay_chips: HBoxContainer = null
var reward_overlay_tween: Tween = null

var intro_tween: Tween = null
var refresh_queued: bool = false
var result_generation: int = 0
var scroll_touch_active: bool = false
var scroll_touch_origin: Vector2 = Vector2.ZERO
var scroll_dragged: bool = false
var block_claim_until_msec: int = 0


func setup(new_scene_root: Node) -> void:
	if not (new_scene_root is Control):
		return

	scene_root = new_scene_root as Control
	content_root = scene_root.get_node_or_null("Content") as Control
	if content_root == null:
		push_warning("TrialsProductionPresenter: Content root tidak ditemukan.")
		return

	active_section = (
		"achievement"
		if scene_root.scene_file_path == ACHIEVEMENT_SCENE
		else "daily"
	)

	_hide_legacy_trials_panels()
	_build_presentation()
	_build_reward_overlay()
	_connect_manager_signals()
	_refresh()
	call_deferred("_configure_mobile_scroll_behavior")
	call_deferred("_play_intro")


func _hide_legacy_trials_panels() -> void:
	for node_name: String in [
		"TopBar",
		"HeaderPanel",
		"SectionTabs",
		"SummaryPanel",
		"ListPanel",
	]:
		var legacy_node: CanvasItem = content_root.get_node_or_null(node_name) as CanvasItem
		if legacy_node != null:
			legacy_node.visible = false

	var hub_nav: CanvasItem = content_root.get_node_or_null("HubNav") as CanvasItem
	if hub_nav != null:
		hub_nav.visible = true


func _build_presentation() -> void:
	presentation_root = Control.new()
	presentation_root.name = "ApprovedTrialsPresentation"
	presentation_root.mouse_filter = Control.MOUSE_FILTER_PASS
	presentation_root.anchor_left = 0.03
	presentation_root.anchor_top = 0.0
	presentation_root.anchor_right = 0.97
	presentation_root.anchor_bottom = 1.0
	presentation_root.offset_top = 78.0
	presentation_root.offset_bottom = -108.0
	content_root.add_child(presentation_root)

	var layout := VBoxContainer.new()
	layout.name = "ProductionLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 9)
	presentation_root.add_child(layout)

	layout.add_child(_build_hero_panel())
	layout.add_child(_build_tabs())

	trials_scroll = ScrollContainer.new()
	trials_scroll.name = "TrialsScroll"
	trials_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trials_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	trials_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	trials_scroll.gui_input.connect(_on_trials_scroll_gui_input)
	layout.add_child(trials_scroll)

	list_host = VBoxContainer.new()
	list_host.name = "TrialsList"
	list_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_host.add_theme_constant_override("separation", 10)
	trials_scroll.add_child(list_host)


func _build_hero_panel() -> PanelContainer:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(0.0, 184.0)
	outer.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(0.001, 0.018, 0.029, 0.99),
			Color(1.0, 0.78, 0.30, 0.92),
			Color(0.20, 0.86, 0.72, 0.36),
			18
		)
	)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 4)
	outer_margin.add_theme_constant_override("margin_top", 4)
	outer_margin.add_theme_constant_override("margin_right", 4)
	outer_margin.add_theme_constant_override("margin_bottom", 4)
	outer.add_child(outer_margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_ornate_inner_style(
			Color(0.002, 0.030, 0.043, 0.97),
			Color(0.29, 0.88, 0.75, 0.46),
			14
		)
	)
	outer_margin.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_box)

	var eyebrow := Label.new()
	eyebrow.text = tr("CELESTIAL TRIALS HALL")
	eyebrow.theme_type_variation = &"JadeSubtitle"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", CYAN)
	title_box.add_child(eyebrow)

	section_title = Label.new()
	section_title.name = "SectionTitle"
	section_title.theme_type_variation = &"JadeTitle"
	section_title.add_theme_font_size_override("font_size", 29)
	title_box.add_child(section_title)

	var subtitle := Label.new()
	subtitle.text = tr("Complete trials. Claim rewards. Temper your path.")
	subtitle.theme_type_variation = &"JadeMutedLabel"
	subtitle.add_theme_font_size_override("font_size", 13)
	title_box.add_child(subtitle)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(88.0, 88.0)
	icon_frame.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(0.008, 0.050, 0.058, 0.92),
			Color(1.0, 0.77, 0.29, 0.78),
			Color(0.28, 0.90, 0.75, 0.34),
			18
		)
	)
	top.add_child(icon_frame)

	section_icon = TextureRect.new()
	section_icon.name = "SectionIcon"
	section_icon.custom_minimum_size = Vector2(82.0, 82.0)
	section_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	section_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	section_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(section_icon)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	box.add_child(stats)

	var ready_chip: PanelContainer = _stat_chip(tr("READY"), "0", GOLD)
	var reward_chip: PanelContainer = _stat_chip(tr("REWARD"), "0", JADE)
	stats.add_child(ready_chip)
	stats.add_child(reward_chip)
	ready_value_label = ready_chip.find_child("Value", true, false) as Label
	reward_value_label = reward_chip.find_child("Value", true, false) as Label

	claim_all_button = Button.new()
	claim_all_button.custom_minimum_size = Vector2(176.0, 48.0)
	claim_all_button.theme_type_variation = &"JadePrimaryButton"
	claim_all_button.add_theme_font_size_override("font_size", 14)
	claim_all_button.pressed.connect(_on_claim_all_pressed)
	stats.add_child(claim_all_button)
	return outer


func _stat_chip(
	label_text: String,
	value_text: String,
	accent: Color
) -> PanelContainer:
	var outer := PanelContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(0.003, 0.034, 0.043, 0.97),
			Color(accent.r, accent.g, accent.b, 0.66),
			Color(1.0, 0.78, 0.30, 0.24),
			11
		)
	)

	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 2)
	inset.add_theme_constant_override("margin_top", 2)
	inset.add_theme_constant_override("margin_right", 2)
	inset.add_theme_constant_override("margin_bottom", 2)
	outer.add_child(inset)

	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override(
		"panel",
		_ornate_inner_style(
			Color(0.005, 0.048, 0.058, 0.94),
			Color(accent.r, accent.g, accent.b, 0.28),
			8
		)
	)
	inset.add_child(inner)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(box)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", MUTED)
	box.add_child(label)

	var value := Label.new()
	value.name = "Value"
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", accent)
	box.add_child(value)
	return outer


func _build_tabs() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 50.0
	row.add_theme_constant_override("separation", 8)

	daily_tab = Button.new()
	daily_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	daily_tab.text = tr("DAILY")
	daily_tab.add_theme_font_size_override("font_size", 14)
	daily_tab.pressed.connect(_switch_section.bind("daily"))
	row.add_child(daily_tab)

	achievement_tab = Button.new()
	achievement_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_tab.text = tr("ACHIEVEMENTS")
	achievement_tab.add_theme_font_size_override("font_size", 14)
	achievement_tab.pressed.connect(_switch_section.bind("achievement"))
	row.add_child(achievement_tab)
	return row


func _connect_manager_signals() -> void:
	if active_section == "daily":
		if not DailyQuestManager.daily_quest_progressed.is_connected(_queue_refresh):
			DailyQuestManager.daily_quest_progressed.connect(_queue_refresh)
		if not DailyQuestManager.daily_quest_completed.is_connected(_queue_refresh):
			DailyQuestManager.daily_quest_completed.connect(_queue_refresh)
		if not DailyQuestManager.daily_quest_claimed.is_connected(_queue_refresh):
			DailyQuestManager.daily_quest_claimed.connect(_queue_refresh)
		if not DailyQuestManager.daily_quests_reset.is_connected(_queue_refresh):
			DailyQuestManager.daily_quests_reset.connect(_queue_refresh)
	else:
		if not AchievementManager.achievement_unlocked.is_connected(_queue_refresh):
			AchievementManager.achievement_unlocked.connect(_queue_refresh)
		if not AchievementManager.achievement_claimed.is_connected(_queue_refresh):
			AchievementManager.achievement_claimed.connect(_queue_refresh)
		if not AchievementManager.achievement_progressed.is_connected(_queue_refresh):
			AchievementManager.achievement_progressed.connect(_queue_refresh)


func _queue_refresh(_arg1: Variant = null, _arg2: Variant = null, _arg3: Variant = null) -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_deferred_refresh")


func _deferred_refresh() -> void:
	refresh_queued = false
	if is_instance_valid(scene_root):
		_refresh()


func _refresh() -> void:
	if list_host == null:
		return

	if active_section == "daily":
		DailyQuestManager.refresh_daily_date()

	var ready_count: int = _get_claimable_count()
	var reward_total: int = _get_total_claimable_reward()

	section_title.text = (
		tr("DAILY DISCIPLINES")
		if active_section == "daily"
		else tr("ETERNAL RECORDS")
	)
	section_icon.texture = load(
		DAILY_ICON_PATH
		if active_section == "daily"
		else ACHIEVEMENT_ICON_PATH
	) as Texture2D

	daily_tab.theme_type_variation = (
		&"JadePrimaryButton"
		if active_section == "daily"
		else &"JadeSecondaryButton"
	)
	achievement_tab.theme_type_variation = (
		&"JadePrimaryButton"
		if active_section == "achievement"
		else &"JadeSecondaryButton"
	)

	ready_value_label.text = str(ready_count)
	reward_value_label.text = str(reward_total)
	claim_all_button.disabled = ready_count <= 0
	claim_all_button.text = (
		tr("CLAIM ALL  ◆  %d") % reward_total
		if ready_count > 0
		else tr("ALL REWARDS SETTLED")
	)

	for child: Node in list_host.get_children():
		child.queue_free()

	var record_ids: Array[String] = _get_sorted_record_ids()
	if record_ids.is_empty():
		list_host.add_child(
			_create_empty_state(
				tr("No Trials records are available yet.")
			)
		)
		call_deferred("_configure_mobile_scroll_behavior")
		return

	for record_id: String in record_ids:
		list_host.add_child(_build_trial_card(record_id))
	call_deferred("_configure_mobile_scroll_behavior")


func _get_claimable_count() -> int:
	if active_section == "daily":
		return DailyQuestManager.get_claimable_count()
	return AchievementManager.get_claimable_count()


func _get_total_claimable_reward() -> int:
	if active_section == "daily":
		return DailyQuestManager.get_total_claimable_reward()
	return AchievementManager.get_total_claimable_reward()


func _get_sorted_record_ids() -> Array[String]:
	var ready_ids: Array[String] = []
	var active_ids: Array[String] = []
	var claimed_ids: Array[String] = []
	var source_ids: Array[String] = []

	if active_section == "daily":
		source_ids.assign(DailyQuestManager.get_daily_quest_ids())
	else:
		source_ids.assign(AchievementManager.get_achievement_ids())

	for record_id: String in source_ids:
		if _is_claimable(record_id):
			ready_ids.append(record_id)
		elif _is_claimed(record_id):
			claimed_ids.append(record_id)
		else:
			active_ids.append(record_id)

	ready_ids.sort()
	active_ids.sort()
	claimed_ids.sort()

	var result: Array[String] = []
	result.append_array(ready_ids)
	result.append_array(active_ids)
	result.append_array(claimed_ids)
	return result


func _get_record_data(record_id: String) -> Dictionary:
	if active_section == "daily":
		return DailyQuestManager.get_daily_quest_data(record_id)
	return AchievementManager.get_achievement_data(record_id)


func _get_progress(record_id: String) -> int:
	if active_section == "daily":
		return DailyQuestManager.get_progress(record_id)
	return AchievementManager.get_progress(record_id)


func _get_target(record_id: String) -> int:
	if active_section == "daily":
		return DailyQuestManager.get_target(record_id)
	return AchievementManager.get_target(record_id)


func _get_reward(record_id: String) -> int:
	if active_section == "daily":
		return DailyQuestManager.get_reward(record_id)
	return AchievementManager.get_reward(record_id)


func _is_claimed(record_id: String) -> bool:
	if active_section == "daily":
		return DailyQuestManager.is_claimed(record_id)
	return AchievementManager.is_claimed(record_id)


func _is_claimable(record_id: String) -> bool:
	if active_section == "daily":
		return DailyQuestManager.is_claimable(record_id)
	return AchievementManager.is_claimable(record_id)


func _build_trial_card(record_id: String) -> PanelContainer:
	var data: Dictionary = _get_record_data(record_id)
	var progress_value: int = _get_progress(record_id)
	var target_value: int = _get_target(record_id)
	var reward_amount: int = _get_reward(record_id)
	var is_claimed: bool = _is_claimed(record_id)
	var is_reward_ready: bool = _is_claimable(record_id)
	var category: String = str(data.get("category", "trial")).to_upper()
	var accent: Color = _category_color(category)

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(0.0, 164.0)
	outer.modulate = Color(1.0, 1.0, 1.0, 0.76 if is_claimed else 1.0)
	outer.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(0.002, 0.019, 0.029, 0.99),
			GOLD if is_reward_ready else Color(accent.r, accent.g, accent.b, 0.76),
			Color(0.26, 0.88, 0.73, 0.32),
			14
		)
	)

	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 3)
	inset.add_theme_constant_override("margin_top", 3)
	inset.add_theme_constant_override("margin_right", 3)
	inset.add_theme_constant_override("margin_bottom", 3)
	outer.add_child(inset)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override(
		"panel",
		_ornate_inner_style(
			Color(
				0.008 if is_reward_ready else 0.003,
				0.041 if is_reward_ready else 0.026,
				0.044 if is_reward_ready else 0.036,
				0.98
			),
			Color(
				1.0 if is_reward_ready else accent.r,
				0.78 if is_reward_ready else accent.g,
				0.30 if is_reward_ready else accent.b,
				0.36 if is_reward_ready else 0.28
			),
			11
		)
	)
	inset.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 9)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	margin.add_child(row)

	var icon_outer := PanelContainer.new()
	icon_outer.custom_minimum_size = Vector2(76.0, 76.0)
	icon_outer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon_outer.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(accent.r * 0.05, accent.g * 0.05, accent.b * 0.05, 0.98),
			GOLD if is_reward_ready else Color(accent.r, accent.g, accent.b, 0.76),
			Color(0.95, 0.76, 0.30, 0.20),
			14
		)
	)
	row.add_child(icon_outer)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(66.0, 66.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(
		DAILY_ICON_PATH
		if active_section == "daily"
		else ACHIEVEMENT_ICON_PATH
	) as Texture2D
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_outer.add_child(icon)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	row.add_child(body)

	var rune_rail := HBoxContainer.new()
	rune_rail.add_theme_constant_override("separation", 5)
	body.add_child(rune_rail)

	var rune := Label.new()
	rune.text = "◆"
	rune.add_theme_font_size_override("font_size", 8)
	rune.add_theme_color_override(
		"font_color",
		GOLD if is_reward_ready else Color(accent.r, accent.g, accent.b, 0.82)
	)
	rune_rail.add_child(rune)
	rune_rail.add_child(
		_ornament_line(
			Color(
				1.0 if is_reward_ready else accent.r,
				0.78 if is_reward_ready else accent.g,
				0.30 if is_reward_ready else accent.b,
				0.38
			)
		)
	)

	var title_row := HBoxContainer.new()
	body.add_child(title_row)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = tr(str(data.get("title", record_id)))
	title.theme_type_variation = &"JadeHeroName"
	title.add_theme_font_size_override("font_size", 19)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title_row.add_child(title)

	var state_label := Label.new()
	state_label.text = (
		tr("REWARD READY")
		if is_reward_ready
		else (tr("CLAIMED") if is_claimed else tr("IN PROGRESS"))
	)
	state_label.add_theme_font_size_override("font_size", 12)
	state_label.add_theme_color_override(
		"font_color",
		GOLD if is_reward_ready else (JADE if is_claimed else accent)
	)
	if is_reward_ready:
		state_label.add_theme_color_override(
			"font_shadow_color",
			Color(1.0, 0.66, 0.16, 0.42)
		)
		state_label.add_theme_constant_override("shadow_offset_y", 1)
	title_row.add_child(state_label)

	var meta := Label.new()
	meta.text = "%s  •  %s" % [
		tr(category),
		tr("DAILY DISCIPLINE")
		if active_section == "daily"
		else tr("PERMANENT RECORD")
	]
	meta.theme_type_variation = &"JadeSubtitle"
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", accent)
	body.add_child(meta)

	var description := Label.new()
	description.text = tr(str(data.get("description", "")))
	description.theme_type_variation = &"JadeMutedLabel"
	description.add_theme_font_size_override("font_size", 14)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2
	body.add_child(description)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	body.add_child(progress_row)

	var progress_bar := ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size = Vector2(0.0, 11.0)
	progress_bar.max_value = float(maxi(target_value, 1))
	progress_bar.value = float(progress_value)
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override(
		"background",
		_panel_style(
			Color(0.002, 0.012, 0.020, 0.98),
			Color(0.28, 0.82, 0.70, 0.38),
			5,
			1
		)
	)
	progress_bar.add_theme_stylebox_override(
		"fill",
		_make_trial_progress_fill(
			GOLD if is_reward_ready else accent,
			is_reward_ready
		)
	)
	progress_row.add_child(progress_bar)

	var progress_text := Label.new()
	progress_text.custom_minimum_size = Vector2(64.0, 0.0)
	progress_text.text = "%d / %d" % [progress_value, target_value]
	progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_text.add_theme_font_size_override("font_size", 12)
	progress_row.add_child(progress_text)

	var action_row := HBoxContainer.new()
	body.add_child(action_row)

	var reward := Label.new()
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward.text = tr("REWARD  ◆  %d SPIRIT STONE") % reward_amount
	reward.theme_type_variation = &"JadeCurrencyLabel"
	reward.add_theme_font_size_override("font_size", 12)
	action_row.add_child(reward)

	var action := Button.new()
	action.custom_minimum_size = Vector2(132.0, 40.0)
	action.add_theme_font_size_override("font_size", 12)
	if is_reward_ready:
		action.text = tr("CLAIM  ◆  +%d") % reward_amount
		action.theme_type_variation = &"JadePrimaryButton"
		_apply_reward_ready_button_style(action)
		action.pressed.connect(_on_single_claim.bind(record_id))
	elif is_claimed:
		action.text = tr("CLAIMED")
		action.disabled = true
		action.theme_type_variation = &"JadeSecondaryButton"
	else:
		action.text = tr("IN PROGRESS")
		action.disabled = true
		action.theme_type_variation = &"JadeSecondaryButton"
	action_row.add_child(action)
	return outer


func _is_mobile_display() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


func _configure_mobile_scroll_behavior() -> void:
	if not _is_mobile_display():
		return
	if not is_instance_valid(trials_scroll):
		return

	# Match Pavilion's mobile scroll contract from mobile_safe_area.gd:
	# direct-touch deadzone, no desktop-style scrollbar pipe, and PASS through
	# interactive descendants so the ScrollContainer can arbitrate a drag.
	trials_scroll.scroll_deadzone = MOBILE_SCROLL_DEADZONE
	if (
		trials_scroll.vertical_scroll_mode
		!= ScrollContainer.SCROLL_MODE_DISABLED
	):
		trials_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_SHOW_NEVER
		)
	_configure_scroll_descendants(trials_scroll)


func _configure_scroll_descendants(root_node: Node) -> void:
	for child_node: Node in root_node.get_children():
		if child_node is Control:
			var child_control := child_node as Control
			if child_control.mouse_filter == Control.MOUSE_FILTER_STOP:
				child_control.mouse_filter = Control.MOUSE_FILTER_PASS
		_configure_scroll_descendants(child_node)


func _on_trials_scroll_gui_input(event: InputEvent) -> void:
	if not _is_mobile_display():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			scroll_touch_active = true
			scroll_touch_origin = touch.position
			scroll_dragged = false
		else:
			if scroll_dragged:
				block_claim_until_msec = (
					Time.get_ticks_msec()
					+ MOBILE_SCROLL_CLAIM_GUARD_MS
				)
			scroll_touch_active = false
			scroll_dragged = false
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not scroll_touch_active:
			scroll_touch_active = true
			scroll_touch_origin = drag.position
		if (
			drag.position.distance_to(scroll_touch_origin)
			>= float(MOBILE_SCROLL_DEADZONE)
		):
			scroll_dragged = true
			block_claim_until_msec = (
				Time.get_ticks_msec()
				+ MOBILE_SCROLL_CLAIM_GUARD_MS
			)


func _claim_input_blocked() -> bool:
	return (
		_is_mobile_display()
		and Time.get_ticks_msec() < block_claim_until_msec
	)


func _on_single_claim(record_id: String) -> void:
	if _claim_input_blocked():
		return
	if not _is_claimable(record_id):
		return

	var data: Dictionary = _get_record_data(record_id)
	var source_title: String = tr(str(data.get("title", record_id)))
	var expected_amount: int = _get_reward(record_id)
	var previous_balance: int = ProgressionManager.spirit_stone
	var claimed: bool = false

	if active_section == "daily":
		claimed = DailyQuestManager.claim_reward(record_id)
	else:
		claimed = AchievementManager.claim_reward(record_id)

	if not claimed:
		return

	var new_balance: int = ProgressionManager.spirit_stone
	var applied_amount: int = maxi(new_balance - previous_balance, 0)
	if applied_amount <= 0:
		applied_amount = expected_amount

	_schedule_reward_result(
		source_title,
		applied_amount,
		1,
		previous_balance,
		new_balance,
		SINGLE_RESULT_DELAY
	)


func _on_claim_all_pressed() -> void:
	if _claim_input_blocked():
		return
	var ready_ids: Array[String] = []
	for record_id: String in _get_sorted_record_ids():
		if _is_claimable(record_id):
			ready_ids.append(record_id)
	if ready_ids.is_empty():
		return

	var previous_balance: int = ProgressionManager.spirit_stone
	var expected_total: int = 0
	for record_id: String in ready_ids:
		expected_total += _get_reward(record_id)

	var claimed_count: int = 0
	if active_section == "daily":
		claimed_count = DailyQuestManager.claim_all_rewards()
	else:
		claimed_count = AchievementManager.claim_all_rewards()

	if claimed_count <= 0:
		return

	var new_balance: int = ProgressionManager.spirit_stone
	var applied_total: int = maxi(new_balance - previous_balance, 0)
	if applied_total <= 0:
		applied_total = expected_total

	_schedule_reward_result(
		tr("Daily Rewards")
		if active_section == "daily"
		else tr("Eternal Records"),
		applied_total,
		claimed_count,
		previous_balance,
		new_balance,
		CLAIM_ALL_RESULT_DELAY
	)


func _schedule_reward_result(
	source_title: String,
	amount: int,
	reward_count: int,
	previous_balance: int,
	new_balance: int,
	delay_seconds: float
) -> void:
	result_generation += 1
	var generation: int = result_generation
	await get_tree().create_timer(delay_seconds).timeout
	if generation != result_generation:
		return
	if not is_instance_valid(scene_root):
		return
	_show_reward_overlay(
		source_title,
		amount,
		reward_count,
		previous_balance,
		new_balance
	)


func _build_reward_overlay() -> void:
	reward_overlay = Control.new()
	reward_overlay.name = "RewardSecuredOverlay"
	reward_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reward_overlay.visible = false
	reward_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_overlay.z_index = 140
	scene_root.add_child(reward_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.006, 0.012, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_overlay.add_child(center)

	reward_overlay_panel = PanelContainer.new()
	reward_overlay_panel.custom_minimum_size = Vector2(520.0, 566.0)
	reward_overlay_panel.pivot_offset = Vector2(260.0, 274.0)
	reward_overlay_panel.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(0.001, 0.020, 0.031, 0.995),
			Color(1.0, 0.79, 0.30, 0.98),
			Color(0.27, 0.90, 0.75, 0.52),
			24
		)
	)
	center.add_child(reward_overlay_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	reward_overlay_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)

	var eyebrow := Label.new()
	eyebrow.text = tr("CELESTIAL TRIALS")
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.theme_type_variation = &"JadeSubtitle"
	eyebrow.add_theme_font_size_override("font_size", 13)
	box.add_child(eyebrow)

	reward_overlay_title = Label.new()
	reward_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_overlay_title.theme_type_variation = &"JadeTitle"
	reward_overlay_title.add_theme_font_size_override("font_size", 34)
	box.add_child(reward_overlay_title)

	var divider := HSeparator.new()
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	box.add_child(divider)

	var halo := PanelContainer.new()
	halo.custom_minimum_size = Vector2(164.0, 164.0)
	halo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	halo.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.02, 0.12, 0.11, 0.78),
			Color(1.0, 0.79, 0.30, 0.88),
			82,
			2
		)
	)
	box.add_child(halo)

	reward_overlay_icon = TextureRect.new()
	reward_overlay_icon.custom_minimum_size = Vector2(136.0, 136.0)
	reward_overlay_icon.pivot_offset = Vector2(68.0, 68.0)
	reward_overlay_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reward_overlay_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reward_overlay_icon.texture = load(SPIRIT_STONE_ICON_PATH) as Texture2D
	reward_overlay_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.add_child(reward_overlay_icon)

	reward_overlay_amount = Label.new()
	reward_overlay_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_overlay_amount.theme_type_variation = &"JadeTitle"
	reward_overlay_amount.add_theme_font_size_override("font_size", 46)
	box.add_child(reward_overlay_amount)

	var currency := Label.new()
	currency.text = tr("SPIRIT STONES")
	currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	currency.theme_type_variation = &"JadeCurrencyLabel"
	currency.add_theme_font_size_override("font_size", 15)
	box.add_child(currency)

	reward_overlay_source = Label.new()
	reward_overlay_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_overlay_source.theme_type_variation = &"JadeHeroName"
	reward_overlay_source.add_theme_font_size_override("font_size", 18)
	box.add_child(reward_overlay_source)

	reward_overlay_chips = HBoxContainer.new()
	reward_overlay_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_overlay_chips.add_theme_constant_override("separation", 8)
	box.add_child(reward_overlay_chips)

	reward_overlay_balance = Label.new()
	reward_overlay_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_overlay_balance.theme_type_variation = &"JadeMutedLabel"
	reward_overlay_balance.add_theme_font_size_override("font_size", 13)
	box.add_child(reward_overlay_balance)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(300.0, 54.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.theme_type_variation = &"JadePrimaryButton"
	close_button.text = tr("CONTINUE")
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.pressed.connect(_hide_reward_overlay)
	box.add_child(close_button)


func _show_reward_overlay(
	source_title: String,
	amount: int,
	reward_count: int,
	previous_balance: int,
	new_balance: int
) -> void:
	if reward_overlay == null:
		return

	reward_overlay.visible = true
	reward_overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)

	reward_overlay_title.text = (
		tr("REWARDS SECURED")
		if reward_count > 1
		else tr("REWARD SECURED")
	)
	reward_overlay_source.text = source_title
	reward_overlay_amount.text = "+%d" % amount
	reward_overlay_balance.text = tr("BALANCE  %s  →  %s") % [
		_format_number(previous_balance),
		_format_number(new_balance)
	]

	for child: Node in reward_overlay_chips.get_children():
		child.queue_free()
	if reward_count > 1:
		for reward_index: int in range(reward_count):
			var chip := Label.new()
			chip.text = tr("REWARD %02d") % (reward_index + 1)
			chip.add_theme_font_size_override("font_size", 10)
			chip.add_theme_color_override("font_color", GOLD)
			reward_overlay_chips.add_child(chip)

	if SettingsManager.reduced_effects:
		reward_overlay_panel.scale = Vector2.ONE
		reward_overlay_icon.scale = Vector2.ONE
		return

	if reward_overlay_tween != null and reward_overlay_tween.is_valid():
		reward_overlay_tween.kill()
	reward_overlay.modulate.a = 0.0
	reward_overlay_panel.scale = Vector2(0.84, 0.84)
	reward_overlay_icon.scale = Vector2(0.60, 0.60)
	reward_overlay_icon.modulate = Color(1.0, 1.0, 1.0, 0.20)

	reward_overlay_tween = create_tween()
	reward_overlay_tween.set_parallel(true)
	reward_overlay_tween.tween_property(
		reward_overlay,
		"modulate:a",
		1.0,
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reward_overlay_tween.tween_property(
		reward_overlay_panel,
		"scale",
		Vector2.ONE,
		0.34
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reward_overlay_tween.tween_property(
		reward_overlay_icon,
		"modulate:a",
		1.0,
		0.20
	)

	var icon_tween: Tween = create_tween()
	icon_tween.tween_property(
		reward_overlay_icon,
		"scale",
		Vector2(1.12, 1.12),
		0.24
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	icon_tween.tween_property(
		reward_overlay_icon,
		"scale",
		Vector2.ONE,
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _hide_reward_overlay() -> void:
	if reward_overlay == null or not reward_overlay.visible:
		return
	result_generation += 1

	if SettingsManager.reduced_effects:
		reward_overlay.visible = false
		_queue_refresh()
		return

	if reward_overlay_tween != null and reward_overlay_tween.is_valid():
		reward_overlay_tween.kill()
	reward_overlay_tween = create_tween()
	reward_overlay_tween.set_parallel(true)
	reward_overlay_tween.tween_property(
		reward_overlay,
		"modulate:a",
		0.0,
		0.14
	)
	reward_overlay_tween.tween_property(
		reward_overlay_panel,
		"scale",
		Vector2(0.94, 0.94),
		0.14
	)
	await reward_overlay_tween.finished
	if is_instance_valid(reward_overlay):
		reward_overlay.visible = false
		_queue_refresh()


func _switch_section(section: String) -> void:
	if section == active_section:
		return
	if SceneTransitionManager.is_transitioning:
		return

	var scene_path: String = (
		DAILY_SCENE
		if section == "daily"
		else ACHIEVEMENT_SCENE
	)
	if not ResourceLoader.exists(scene_path):
		push_error("TrialsProductionPresenter: scene section tidak ditemukan: " + scene_path)
		return

	var direction: int = -1 if section == "daily" else 1
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		scene_path,
		direction
	)
	if change_error != OK:
		push_error(
			"TrialsProductionPresenter: gagal membuka section. Error code: "
			+ str(change_error)
		)


func _play_intro() -> void:
	if presentation_root == null or SettingsManager.reduced_effects:
		return
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()

	presentation_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	presentation_root.position.y += 18.0
	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(
		presentation_root,
		"modulate:a",
		1.0,
		0.24
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(
		presentation_root,
		"position:y",
		presentation_root.position.y - 18.0,
		0.30
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _create_empty_state(message: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 120.0)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.002, 0.020, 0.030, 0.92),
			Color(0.28, 0.72, 0.62, 0.42),
			10,
			1
		)
	)

	var label := Label.new()
	label.text = message
	label.theme_type_variation = &"JadeMutedLabel"
	label.add_theme_font_size_override("font_size", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return panel


func _category_color(category: String) -> Color:
	match category.to_upper():
		"COMBAT":
			return Color(0.98, 0.43, 0.33, 1.0)
		"PROGRESSION":
			return Color(0.36, 0.82, 1.0, 1.0)
		"JOURNEY":
			return Color(0.30, 0.91, 0.69, 1.0)
		"BOSS":
			return Color(1.0, 0.68, 0.22, 1.0)
		"CULTIVATION":
			return Color(0.78, 0.60, 1.0, 1.0)
		_:
			return JADE


func _make_trial_progress_fill(
	accent: Color,
	is_reward_ready: bool
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = (
		Color(1.0, 0.72, 0.20, 0.34)
		if is_reward_ready
		else Color(accent.r, accent.g, accent.b, 0.18)
	)
	style.shadow_size = 3
	return style


func _apply_reward_ready_button_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.012, 0.105, 0.090, 0.98)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.98, 0.78, 0.30, 0.98)
	normal.corner_radius_top_left = 9
	normal.corner_radius_top_right = 9
	normal.corner_radius_bottom_left = 9
	normal.corner_radius_bottom_right = 9
	normal.shadow_color = Color(0.92, 0.66, 0.18, 0.26)
	normal.shadow_size = 5
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.018, 0.145, 0.122, 0.99)
	hover.border_color = Color(1.0, 0.88, 0.52, 1.0)
	hover.shadow_color = Color(0.34, 0.92, 0.75, 0.26)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.004, 0.066, 0.066, 1.0)
	pressed.border_color = Color(0.32, 0.91, 0.76, 0.96)
	pressed.shadow_size = 2
	button.add_theme_stylebox_override("pressed", pressed)


func _ornament_line(color: Color) -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _panel_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
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
	return style


func _ornate_outer_style(
	background: Color,
	primary_border: Color,
	secondary_border: Color,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = primary_border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(
		secondary_border.r,
		secondary_border.g,
		secondary_border.b,
		minf(secondary_border.a, 0.34)
	)
	style.shadow_size = 6
	return style


func _ornate_inner_style(
	background: Color,
	border: Color,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _format_number(value: int) -> String:
	var remaining: String = str(maxi(value, 0))
	var groups: Array[String] = []
	while remaining.length() > 3:
		groups.push_front(remaining.right(3))
		remaining = remaining.left(remaining.length() - 3)
	groups.push_front(remaining)
	return ".".join(groups)
