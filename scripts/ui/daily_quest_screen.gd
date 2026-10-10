extends Control

## Trials Hub — Daily Disciplines.
## DailyQuestManager remains the sole authority for active quests, progress,
## completion, claim state, rewards, local-date reset and save persistence.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const ACHIEVEMENT_SCENE: String = "res://scenes/ui/achievement_screen.tscn"
const TrialsRecordSealScript = preload(
	"res://scripts/ui/trials_record_seal.gd"
)

@onready var spirit_stone_label: Label = %SpiritStoneLabel
@onready var date_label: Label = %DateLabel
@onready var completed_value_label: Label = %CompletedValueLabel
@onready var claimable_value_label: Label = %ClaimableValueLabel
@onready var reward_value_label: Label = %RewardValueLabel
@onready var claim_all_button: Button = %ClaimAllButton
@onready var quest_list: VBoxContainer = %QuestList
@onready var cycle_progress_bar: ProgressBar = %CycleProgressBar
@onready var cycle_progress_label: Label = %CycleProgressLabel
@onready var cycle_hint_label: Label = %CycleHintLabel
@onready var daily_tab: Button = %DailyTab
@onready var achievement_tab: Button = %AchievementTab
@onready var challenge_tab: Button = %ChallengeTab

var _m7b_buttons: Dictionary = {}
var _m7b_status_labels: Dictionary = {}
var _m7b_last_message: String = ""
var _m7b_refresh_left: float = 1.0
var _m7c2_focus_button: Button = null
var _m7c2_focus_status: Label = null
var _m7c2_focus_message: String = ""


func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)

	claim_all_button.pressed.connect(_on_claim_all_pressed)
	daily_tab.pressed.connect(_on_daily_tab_pressed)
	achievement_tab.pressed.connect(_on_achievement_tab_pressed)
	challenge_tab.visible = false

	_connect_manager_signals()
	if not DailyQuestManager.m7c2_offer_finished.is_connected(_on_m7c2_offer_finished):
		DailyQuestManager.m7c2_offer_finished.connect(_on_m7c2_offer_finished)
	_refresh_screen()

	DebugLogger.system(
		"Trials Hub aktif! Section: Daily Disciplines"
	)


func _process(delta: float) -> void:
	_m7b_refresh_left -= delta
	if _m7b_refresh_left <= 0.0:
		_m7b_refresh_left = 1.0
		_refresh_m7b_offer_buttons()
		_refresh_m7c2_offer_button()


func _connect_manager_signals() -> void:
	if not DailyQuestManager.daily_quest_progressed.is_connected(
		_on_daily_quest_progressed
	):
		DailyQuestManager.daily_quest_progressed.connect(
			_on_daily_quest_progressed
		)

	if not DailyQuestManager.daily_quest_completed.is_connected(
		_on_daily_quest_completed
	):
		DailyQuestManager.daily_quest_completed.connect(
			_on_daily_quest_completed
		)

	if not DailyQuestManager.daily_quest_claimed.is_connected(
		_on_daily_quest_claimed
	):
		DailyQuestManager.daily_quest_claimed.connect(
			_on_daily_quest_claimed
		)

	if not DailyQuestManager.daily_quests_reset.is_connected(
		_on_daily_quests_reset
	):
		DailyQuestManager.daily_quests_reset.connect(
			_on_daily_quests_reset
		)

	if not DailyQuestManager.m7b_offer_finished.is_connected(_on_m7b_reward_finished):
		DailyQuestManager.m7b_offer_finished.connect(_on_m7b_reward_finished)


func _refresh_screen() -> void:
	DailyQuestManager.refresh_daily_date()

	spirit_stone_label.text = "%d" % ProgressionManager.spirit_stone
	date_label.text = (
		tr("LOCAL CYCLE")
		+ "  •  "
		+ DailyQuestManager.active_date_key
	)

	var completed_count: int = DailyQuestManager.get_completed_count()
	var total_count: int = DailyQuestManager.get_daily_quest_ids().size()
	var claimable_count: int = DailyQuestManager.get_claimable_count()
	var claimable_reward: int = DailyQuestManager.get_total_claimable_reward()
	var achievement_claimable: int = AchievementManager.get_claimable_count()

	daily_tab.text = _build_trials_tab_text(
		tr("DAILY"),
		claimable_count
	)
	achievement_tab.text = _build_trials_tab_text(
		tr("ACHIEVEMENTS"),
		achievement_claimable
	)

	completed_value_label.text = "%d / %d" % [
		completed_count,
		total_count
	]
	claimable_value_label.text = "%d" % claimable_count
	reward_value_label.text = "%d" % claimable_reward

	claim_all_button.disabled = claimable_count == 0
	claim_all_button.text = (
		tr("CLAIM ALL  •  %d") % claimable_reward
		if claimable_count > 0
		else tr("NO REWARDS READY")
	)

	cycle_progress_bar.max_value = float(maxi(total_count, 1))
	cycle_progress_bar.value = float(completed_count)
	cycle_progress_bar.add_theme_stylebox_override(
		"background",
		_make_progress_background()
	)
	cycle_progress_bar.add_theme_stylebox_override(
		"fill",
		_make_cycle_progress_fill(
			completed_count,
			total_count
		)
	)
	cycle_progress_label.text = tr("%d / %d COMPLETE") % [
		completed_count,
		total_count
	]
	cycle_hint_label.text = (
		tr(
			"Daily disciplines complete. Settle any remaining rewards before the local cycle resets."
		)
		if total_count > 0 and completed_count >= total_count
		else tr(
			"Complete today's disciplines to advance the daily cultivation cycle."
		)
	)

	_rebuild_quest_list()


func _build_trials_tab_text(
	label: String,
	ready_count: int
) -> String:
	if ready_count <= 0:
		return label

	var count_text: String = (
		"9+"
		if ready_count > 9
		else str(ready_count)
	)
	return "%s  •  %s" % [label, count_text]


func _rebuild_quest_list() -> void:
	for child: Node in quest_list.get_children():
		child.queue_free()

	quest_list.add_child(_build_m7b_offer_board())
	var sorted_ids: Array[String] = _get_sorted_daily_ids()

	if sorted_ids.is_empty():
		quest_list.add_child(
			_create_empty_state(
				tr("No daily disciplines are active for this cycle.")
			)
		)
		return

	for quest_id: String in sorted_ids:
		quest_list.add_child(
			_create_quest_card(quest_id)
		)


func _get_sorted_daily_ids() -> Array[String]:
	var ready_ids: Array[String] = []
	var active: Array[String] = []
	var claimed: Array[String] = []

	for quest_id: String in DailyQuestManager.get_daily_quest_ids():
		if DailyQuestManager.is_claimable(quest_id):
			ready_ids.append(quest_id)
		elif DailyQuestManager.is_claimed(quest_id):
			claimed.append(quest_id)
		else:
			active.append(quest_id)

	ready_ids.sort()
	active.sort()
	claimed.sort()

	var result: Array[String] = []
	result.append_array(ready_ids)
	result.append_array(active)
	result.append_array(claimed)
	return result


func _create_quest_card(
	quest_id: String
) -> PanelContainer:
	var data: Dictionary = DailyQuestManager.get_daily_quest_data(quest_id)
	var progress: int = DailyQuestManager.get_progress(quest_id)
	var target: int = DailyQuestManager.get_target(quest_id)
	var reward: int = DailyQuestManager.get_reward(quest_id)
	var claimed: bool = DailyQuestManager.is_claimed(quest_id)
	var claimable: bool = DailyQuestManager.is_claimable(quest_id)
	var category: String = str(data.get("category", "daily"))
	var state_key: String = _get_record_state_key(
		claimed,
		claimable
	)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 146.0)
	card.add_theme_stylebox_override(
		"panel",
		_make_card_style(state_key, category)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var seal_panel := PanelContainer.new()
	seal_panel.custom_minimum_size = Vector2(60.0, 60.0)
	seal_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	seal_panel.add_theme_stylebox_override(
		"panel",
		_make_seal_panel_style(category, state_key)
	)
	row.add_child(seal_panel)

	var seal: Control = TrialsRecordSealScript.new()
	seal.custom_minimum_size = Vector2(56.0, 56.0)
	seal.call(
		"configure",
		category,
		state_key,
		true
	)
	seal_panel.add_child(seal)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	row.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)

	var title_label := Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text = tr(str(data.get("title", quest_id)))
	title_label.theme_type_variation = &"JadeHeroName"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	header.add_child(title_label)

	var state_label := Label.new()
	state_label.text = _get_record_state_text(state_key)
	state_label.theme_type_variation = &"JadeSubtitle"
	state_label.add_theme_font_size_override("font_size", 11)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.add_theme_color_override(
		"font_color",
		_get_state_color(state_key, category)
	)
	header.add_child(state_label)

	var meta_label := Label.new()
	meta_label.text = "%s  •  %s" % [
		tr(category).to_upper(),
		tr("DAILY DISCIPLINE")
	]
	meta_label.theme_type_variation = &"JadeSubtitle"
	meta_label.add_theme_font_size_override("font_size", 11)
	meta_label.add_theme_color_override(
		"font_color",
		_get_category_color(category)
	)
	body.add_child(meta_label)

	var description_label := Label.new()
	description_label.text = tr(str(data.get("description", "")))
	description_label.theme_type_variation = &"JadeMutedLabel"
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override(
		"font_color",
		Color(0.81, 0.87, 0.86, 0.99)
	)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = 2
	body.add_child(description_label)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	body.add_child(progress_row)

	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0.0, 10.0)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.min_value = 0.0
	progress_bar.max_value = float(maxi(target, 1))
	progress_bar.value = float(progress)
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override(
		"background",
		_make_progress_background()
	)
	progress_bar.add_theme_stylebox_override(
		"fill",
		_make_progress_fill(state_key, category)
	)
	progress_row.add_child(progress_bar)

	var progress_label := Label.new()
	progress_label.custom_minimum_size = Vector2(58.0, 0.0)
	progress_label.text = "%d / %d" % [progress, target]
	progress_label.theme_type_variation = &"JadeMutedLabel"
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_row.add_child(progress_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	body.add_child(action_row)

	var reward_label := Label.new()
	reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_label.text = tr("REWARD  •  %d SPIRIT STONE") % reward
	reward_label.theme_type_variation = &"JadeCurrencyLabel"
	reward_label.add_theme_font_size_override("font_size", 12)
	action_row.add_child(reward_label)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(112.0, 36.0)
	action_button.add_theme_font_size_override("font_size", 12)
	_configure_daily_action(
		action_button,
		quest_id,
		state_key
	)
	action_row.add_child(action_button)

	return card


func _configure_daily_action(
	button: Button,
	quest_id: String,
	state_key: String
) -> void:
	match state_key:
		"claimed":
			button.disabled = true
			button.text = tr("CLAIMED")
			button.theme_type_variation = &"JadeSecondaryButton"
		"reward_ready":
			button.disabled = false
			button.text = tr("CLAIM")
			button.theme_type_variation = &"JadePrimaryButton"
			button.pressed.connect(
				_on_claim_pressed.bind(quest_id)
			)
		_:
			button.disabled = true
			button.text = tr("IN PROGRESS")
			button.theme_type_variation = &"JadeSecondaryButton"


func _get_record_state_key(
	claimed: bool,
	claimable: bool
) -> String:
	if claimed:
		return "claimed"
	if claimable:
		return "reward_ready"
	return "in_progress"


func _get_record_state_text(state_key: String) -> String:
	match state_key:
		"claimed":
			return tr("CLAIMED")
		"reward_ready":
			return tr("REWARD READY")
		_:
			return tr("IN PROGRESS")


func _get_category_color(category: String) -> Color:
	match category.to_lower():
		"combat":
			return Color(0.96, 0.42, 0.34, 1.0)
		"progression":
			return Color(0.34, 0.82, 1.0, 1.0)
		"journey":
			return Color(0.31, 0.90, 0.69, 1.0)
		_:
			return Color(0.35, 0.86, 0.76, 1.0)


func _get_state_color(
	state_key: String,
	category: String
) -> Color:
	if state_key == "reward_ready":
		return Color(1.0, 0.82, 0.34, 1.0)
	if state_key == "claimed":
		return Color(0.45, 0.78, 0.66, 0.90)

	var category_color: Color = _get_category_color(category)
	return Color(
		category_color.r,
		category_color.g,
		category_color.b,
		0.90
	)


func _make_card_style(
	state_key: String,
	category: String
) -> StyleBoxFlat:
	var accent: Color = _get_category_color(category)
	var style := StyleBoxFlat.new()

	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = 3

	if state_key == "reward_ready":
		style.bg_color = Color(0.030, 0.060, 0.060, 0.97)
		style.border_color = Color(1.0, 0.79, 0.30, 0.98)
	elif state_key == "claimed":
		style.bg_color = Color(0.002, 0.020, 0.030, 0.91)
		style.border_color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.32
		)
	else:
		style.bg_color = Color(
			accent.r * 0.030,
			accent.g * 0.030,
			accent.b * 0.030,
			0.95
		)
		style.border_color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.68
		)

	return style


func _make_seal_panel_style(
	category: String,
	state_key: String
) -> StyleBoxFlat:
	var accent: Color = _get_category_color(category)
	var alpha: float = 0.42 if state_key == "claimed" else 0.78
	var style := StyleBoxFlat.new()

	style.bg_color = Color(
		accent.r * 0.055,
		accent.g * 0.055,
		accent.b * 0.055,
		0.94
	)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		alpha
	)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _make_progress_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.016, 0.025, 0.96)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _make_progress_fill(
	state_key: String,
	category: String
) -> StyleBoxFlat:
	var accent: Color = _get_category_color(category)
	var style := StyleBoxFlat.new()

	if state_key == "reward_ready":
		style.bg_color = Color(0.98, 0.75, 0.27, 1.0)
	elif state_key == "claimed":
		style.bg_color = Color(0.27, 0.62, 0.53, 0.74)
	else:
		style.bg_color = accent

	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _make_cycle_progress_fill(
	completed_count: int,
	total_count: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = (
		Color(0.96, 0.76, 0.29, 1.0)
		if total_count > 0 and completed_count >= total_count
		else Color(0.29, 0.88, 0.68, 1.0)
	)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _create_empty_state(message: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 120.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.020, 0.030, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.28, 0.72, 0.62, 0.42)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = message
	label.theme_type_variation = &"JadeMutedLabel"
	label.add_theme_font_size_override("font_size", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return panel


func _on_claim_pressed(quest_id: String) -> void:
	DailyQuestManager.claim_reward(quest_id)


func _on_claim_all_pressed() -> void:
	DailyQuestManager.claim_all_rewards()
	_refresh_screen()


func _on_daily_tab_pressed() -> void:
	return


func _on_achievement_tab_pressed() -> void:
	_change_trials_section(ACHIEVEMENT_SCENE)


func _change_trials_section(scene_path: String) -> void:
	if SceneTransitionManager.is_transitioning:
		return

	if not ResourceLoader.exists(scene_path):
		push_error(
			"TrialsHub: scene section tidak ditemukan: "
			+ scene_path
		)
		return

	var change_error: Error = (
		SceneTransitionManager.transition_menu_to(
			scene_path,
			1
		)
	)

	if change_error != OK:
		push_error(
			"TrialsHub: gagal membuka section. Error code: "
			+ str(change_error)
		)


func _on_daily_quest_progressed(
	_quest_id: String,
	_current_progress: int,
	_target_progress: int
) -> void:
	_refresh_screen()


func _on_daily_quest_completed(
	_quest_id: String
) -> void:
	_refresh_screen()


func _on_daily_quest_claimed(
	_quest_id: String,
	_spirit_stone_reward: int
) -> void:
	_refresh_screen()


func _on_daily_quests_reset(
	_date_key: String
) -> void:
	_refresh_screen()


func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	_return_to_journey()


func _return_to_journey() -> void:
	if SceneTransitionManager.is_transitioning:
		return

	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error(
			"TrialsHub: Main Menu scene tidak ditemukan."
		)
		return

	var change_error: Error = (
		SceneTransitionManager.transition_menu_to(
			MAIN_MENU_SCENE,
			-1
		)
	)

	if change_error != OK:
		push_error(
			"TrialsHub: gagal kembali ke Journey. Error code: "
			+ str(change_error)
		)

# M7B optional rewards live inside the EXISTING Daily Disciplines scroll.
# Nothing obstructs ordinary quests; SDK ad is only invoked from button taps.
func _build_m7b_offer_board() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "M7BRewardBoard"
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.013, 0.042, 0.050, 0.98)
	frame.border_color = Color(0.88, 0.68, 0.28, 0.84)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", frame)
	var margin := MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	card.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var heading := Label.new()
	heading.text = "DAO REWARDS  •  OPTIONAL ADS"
	heading.theme_type_variation = &"JadeHeroName"
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", Color(1.0, 0.82, 0.44))
	layout.add_child(heading)
	var helper := Label.new()
	helper.text = "Watch only if you want the shown reward. Free daily quests stay available."
	helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	helper.add_theme_font_size_override("font_size", 12)
	layout.add_child(helper)
	_m7b_buttons.clear()
	_m7b_status_labels.clear()
	for offer: Dictionary in [
		{"id": "daily_completion_cache", "title": "+50 SPIRIT STONES"},
		{"id": "refinement_supply", "title": "+2 REFINEMENT SHARDS"},
	]:
		var placement: String = str(offer["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		layout.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var offer_name := Label.new()
		offer_name.text = str(offer["title"])
		offer_name.add_theme_font_size_override("font_size", 13)
		details.add_child(offer_name)
		var status := Label.new()
		status.add_theme_font_size_override("font_size", 11)
		status.add_theme_color_override("font_color", Color(0.76, 0.85, 0.81))
		details.add_child(status)
		var action := Button.new()
		action.custom_minimum_size = Vector2(124.0, 46.0)
		action.text = "WATCH AD"
		action.theme_type_variation = &"JadeSecondaryButton"
		action.pressed.connect(_on_m7b_reward_pressed.bind(placement))
		row.add_child(action)
		_m7b_buttons[placement] = action
		_m7b_status_labels[placement] = status
	var notice := Label.new()
	notice.name = "M7BRewardStatus"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size", 12)
	notice.text = _m7b_last_message
	layout.add_child(notice)
	layout.add_child(_build_m7c2_offer_row())
	_refresh_m7b_offer_buttons()
	_refresh_m7c2_offer_button()
	return card


func _refresh_m7b_offer_buttons() -> void:
	for raw_placement: Variant in _m7b_buttons.keys():
		var placement: String = str(raw_placement)
		var button: Button = _m7b_buttons.get(placement) as Button
		var status_label: Label = _m7b_status_labels.get(placement) as Label
		if not is_instance_valid(button) or not is_instance_valid(status_label):
			continue
		var state: Dictionary = DailyQuestManager.m7b_get_offer_status(placement)
		var ready: bool = bool(state.get("available", false))
		button.disabled = not ready
		button.text = "WATCH AD" if ready else "UNAVAILABLE"
		status_label.text = str(state.get("reason", "UNAVAILABLE"))


func _on_m7b_reward_pressed(placement: String) -> void:
	if DailyQuestManager.m7b_request_rewarded(placement):
		_m7b_last_message = "Playing optional ad for " + placement.replace("_", " ")
	else:
		_m7b_last_message = "Ad unavailable. No reward was claimed."
	_refresh_screen()


func _on_m7b_reward_finished(_placement: String, success: bool, message: String) -> void:
	_m7b_last_message = ("RECEIVED: " if success else "NOT CLAIMED: ") + message
	_refresh_screen()


# M7C2 voluntary Qi Focus offer appended inside the existing Dao Rewards board.
func _build_m7c2_offer_row() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "M7C2QiFocusOffer"
	section.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	section.add_child(row)
	var text_side := VBoxContainer.new()
	text_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_side)
	var title := Label.new()
	title.text = "QI FOCUS • +10% EXP NEXT RUN"
	title.add_theme_font_size_override("font_size", 13)
	text_side.add_child(title)
	_m7c2_focus_status = Label.new()
	_m7c2_focus_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_m7c2_focus_status.add_theme_font_size_override("font_size", 11)
	text_side.add_child(_m7c2_focus_status)
	_m7c2_focus_button = Button.new()
	_m7c2_focus_button.custom_minimum_size = Vector2(124.0, 46.0)
	_m7c2_focus_button.text = "WATCH AD"
	_m7c2_focus_button.theme_type_variation = &"JadeSecondaryButton"
	_m7c2_focus_button.pressed.connect(_on_m7c2_focus_pressed)
	row.add_child(_m7c2_focus_button)
	return section


func _refresh_m7c2_offer_button() -> void:
	if not is_instance_valid(_m7c2_focus_button) or not is_instance_valid(_m7c2_focus_status):
		return
	var state: Dictionary = DailyQuestManager.m7c2_get_offer_status()
	var ready: bool = bool(state.get("available", false))
	_m7c2_focus_button.disabled = not ready
	_m7c2_focus_button.text = "WATCH AD" if ready else "UNAVAILABLE"
	_m7c2_focus_status.text = (
		_m7c2_focus_message if not _m7c2_focus_message.is_empty()
		else str(state.get("reason", "UNAVAILABLE"))
	)


func _on_m7c2_focus_pressed() -> void:
	if DailyQuestManager.m7c2_request_rewarded():
		_m7c2_focus_message = "AD IN PROGRESS • BONUS ON NEXT NEW RUN"
	else:
		_m7c2_focus_message = "AD UNAVAILABLE • NO BONUS CLAIMED"
	_refresh_m7c2_offer_button()


func _on_m7c2_offer_finished(success: bool, message: String) -> void:
	_m7c2_focus_message = ("RECEIVED: " if success else "NOT CLAIMED: ") + message
	_refresh_screen()
