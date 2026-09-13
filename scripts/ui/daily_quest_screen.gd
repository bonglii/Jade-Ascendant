extends Control

## Trials Hub — Daily Trials
## DailyQuestManager remains the authority for progress, claim state, reward and save.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const ACHIEVEMENT_SCENE: String = "res://scenes/ui/achievement_screen.tscn"

@onready var spirit_stone_label: Label = %SpiritStoneLabel
@onready var date_label: Label = %DateLabel
@onready var completed_value_label: Label = %CompletedValueLabel
@onready var claimable_value_label: Label = %ClaimableValueLabel
@onready var claim_all_button: Button = %ClaimAllButton
@onready var quest_list: VBoxContainer = %QuestList
@onready var cycle_progress_bar: ProgressBar = %CycleProgressBar
@onready var cycle_progress_label: Label = %CycleProgressLabel
@onready var cycle_hint_label: Label = %CycleHintLabel
@onready var daily_tab: Button = %DailyTab
@onready var achievement_tab: Button = %AchievementTab
@onready var challenge_tab: Button = %ChallengeTab

func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)
	claim_all_button.pressed.connect(_on_claim_all_pressed)
	daily_tab.pressed.connect(_on_daily_tab_pressed)
	achievement_tab.pressed.connect(_on_achievement_tab_pressed)
	challenge_tab.visible = false

	DailyQuestManager.daily_quest_progressed.connect(_on_daily_quest_progressed)
	DailyQuestManager.daily_quest_completed.connect(_on_daily_quest_completed)
	DailyQuestManager.daily_quest_claimed.connect(_on_daily_quest_claimed)
	DailyQuestManager.daily_quests_reset.connect(_on_daily_quests_reset)

	_refresh_screen()
	DebugLogger.system(str("Trials Hub aktif! Section: Daily Trials"))

func _refresh_screen() -> void:
	spirit_stone_label.text = "%d" % ProgressionManager.spirit_stone
	date_label.text = tr("DAILY CYCLE  •  ") + DailyQuestManager.active_date_key

	var completed_count: int = DailyQuestManager.get_completed_count()
	var total_count: int = DailyQuestManager.get_daily_quest_ids().size()
	var claimable_count: int = DailyQuestManager.get_claimable_count()
	var claimable_reward: int = DailyQuestManager.get_total_claimable_reward()
	var achievement_claimable: int = AchievementManager.get_claimable_count()

	daily_tab.text = _build_trials_tab_text(tr("DAILY"), claimable_count)
	achievement_tab.text = _build_trials_tab_text(tr("ACHIEVEMENTS"), achievement_claimable)

	completed_value_label.text = "%d / %d" % [completed_count, total_count]
	claimable_value_label.text = "%d" % claimable_count
	claim_all_button.disabled = claimable_count == 0
	claim_all_button.text = (
		tr("CLAIM ALL  •  %d") % claimable_reward
		if claimable_count > 0
		else tr("NO REWARDS")
	)

	cycle_progress_bar.max_value = float(maxi(total_count, 1))
	cycle_progress_bar.value = float(completed_count)
	cycle_progress_bar.add_theme_stylebox_override("background", _make_progress_background())
	cycle_progress_bar.add_theme_stylebox_override(
		"fill",
		_make_progress_fill(false, completed_count >= total_count and total_count > 0, false)
	)
	cycle_progress_label.text = tr("%d / %d COMPLETE") % [completed_count, total_count]
	cycle_hint_label.text = (
		tr("All daily disciplines complete. Claim any remaining rewards before the next reset.")
		if total_count > 0 and completed_count >= total_count
		else tr("Complete every daily discipline to finish today's trial cycle.")
	)
	_rebuild_quest_list()


func _build_trials_tab_text(label: String, ready_count: int) -> String:
	if ready_count <= 0:
		return label
	var count_text: String = "9+" if ready_count > 9 else str(ready_count)
	return "%s  •  %s" % [label, count_text]

func _rebuild_quest_list() -> void:
	for child in quest_list.get_children():
		child.queue_free()

	for quest_id_value in DailyQuestManager.get_daily_quest_ids():
		var quest_id: String = str(quest_id_value)
		quest_list.add_child(_create_quest_card(quest_id))

func _create_quest_card(quest_id: String) -> PanelContainer:
	var data: Dictionary = DailyQuestManager.get_daily_quest_data(quest_id)
	var progress: int = DailyQuestManager.get_progress(quest_id)
	var target: int = DailyQuestManager.get_target(quest_id)
	var reward: int = DailyQuestManager.get_reward(quest_id)
	var claimed: bool = DailyQuestManager.is_claimed(quest_id)
	var claimable: bool = DailyQuestManager.is_claimable(quest_id)
	var completed: bool = DailyQuestManager.is_completed(quest_id)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 132.0)
	card.add_theme_stylebox_override("panel", _make_card_style(claimable, completed, claimed))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	margin.add_child(body)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)

	var title_label: Label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text = tr(str(data.get("title", quest_id)))
	title_label.theme_type_variation = &"JadeHeroName"
	title_label.add_theme_font_size_override("font_size", 16)
	header.add_child(title_label)

	var state_label: Label = Label.new()
	state_label.text = _get_daily_state_text(claimed, claimable, completed)
	state_label.theme_type_variation = &"JadeSubtitle"
	state_label.add_theme_font_size_override("font_size", 10)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.add_theme_color_override("font_color", _get_state_color(claimed, claimable, completed))
	header.add_child(state_label)

	var meta_label: Label = Label.new()
	meta_label.text = tr(str(data.get("category", "daily"))).to_upper() + tr("  •  DAILY DISCIPLINE")
	meta_label.theme_type_variation = &"JadeSubtitle"
	meta_label.add_theme_font_size_override("font_size", 10)
	body.add_child(meta_label)

	var description_label: Label = Label.new()
	description_label.text = tr(str(data.get("description", "")))
	description_label.theme_type_variation = &"JadeMutedLabel"
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(description_label)

	var progress_row: HBoxContainer = HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	body.add_child(progress_row)

	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0.0, 8.0)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.min_value = 0.0
	progress_bar.max_value = float(maxi(target, 1))
	progress_bar.value = float(progress)
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _make_progress_background())
	progress_bar.add_theme_stylebox_override("fill", _make_progress_fill(claimable, completed, claimed))
	progress_row.add_child(progress_bar)

	var progress_label: Label = Label.new()
	progress_label.custom_minimum_size = Vector2(58.0, 0.0)
	progress_label.text = "%d / %d" % [progress, target]
	progress_label.theme_type_variation = &"JadeMutedLabel"
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_row.add_child(progress_label)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	body.add_child(action_row)

	var reward_label: Label = Label.new()
	reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_label.text = tr("REWARD  •  %d SPIRIT STONE") % reward
	reward_label.theme_type_variation = &"JadeCurrencyLabel"
	reward_label.add_theme_font_size_override("font_size", 11)
	action_row.add_child(reward_label)

	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(120.0, 34.0)
	action_button.add_theme_font_size_override("font_size", 12)
	_configure_daily_action(action_button, quest_id, claimed, claimable, completed)
	action_row.add_child(action_button)

	return card

func _configure_daily_action(
	button: Button,
	quest_id: String,
	claimed: bool,
	claimable: bool,
	completed: bool
) -> void:
	if claimed:
		button.disabled = true
		button.text = tr("CLAIMED")
		button.theme_type_variation = &"JadeSecondaryButton"
		return
	if claimable:
		button.disabled = false
		button.text = tr("CLAIM REWARD")
		button.theme_type_variation = &"JadePrimaryButton"
		button.pressed.connect(_on_claim_pressed.bind(quest_id))
		return
	button.disabled = true
	button.text = tr("COMPLETED") if completed else tr("IN PROGRESS")
	button.theme_type_variation = &"JadeSecondaryButton"

func _get_daily_state_text(claimed: bool, claimable: bool, completed: bool) -> String:
	if claimed:
		return tr("CLAIMED")
	if claimable:
		return tr("REWARD READY")
	if completed:
		return tr("COMPLETED")
	return tr("IN PROGRESS")

func _get_state_color(claimed: bool, claimable: bool, completed: bool) -> Color:
	if claimable:
		return Color(0.98, 0.82, 0.39, 1.0)
	if completed or claimed:
		return Color(0.44, 0.83, 0.70, 1.0)
	return Color(0.48, 0.62, 0.60, 0.92)

func _make_card_style(claimable: bool, completed: bool, claimed: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	if claimable:
		style.bg_color = Color(0.012, 0.086, 0.078, 0.96)
		style.border_color = Color(0.98, 0.80, 0.36, 0.96)
	elif claimed:
		style.bg_color = Color(0.002, 0.022, 0.033, 0.90)
		style.border_color = Color(0.22, 0.50, 0.45, 0.38)
	elif completed:
		style.bg_color = Color(0.005, 0.052, 0.058, 0.94)
		style.border_color = Color(0.28, 0.74, 0.64, 0.72)
	else:
		style.bg_color = Color(0.002, 0.029, 0.043, 0.92)
		style.border_color = Color(0.18, 0.52, 0.50, 0.50)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 2
	return style

func _make_progress_background() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.018, 0.026, 0.90)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _make_progress_fill(claimable: bool, completed: bool, claimed: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if claimable:
		style.bg_color = Color(0.95, 0.74, 0.29, 1.0)
	elif claimed or completed:
		style.bg_color = Color(0.27, 0.74, 0.62, 0.92)
	else:
		style.bg_color = Color(0.18, 0.72, 0.62, 1.0)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

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
		push_error("TrialsHub: scene section tidak ditemukan: " + scene_path)
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(scene_path, 1)
	if change_error != OK:
		push_error("TrialsHub: gagal membuka section. Error code: " + str(change_error))

func _on_daily_quest_progressed(_quest_id: String, _current_progress: int, _target_progress: int) -> void:
	_refresh_screen()

func _on_daily_quest_completed(_quest_id: String) -> void:
	_refresh_screen()

func _on_daily_quest_claimed(_quest_id: String, _spirit_stone_reward: int) -> void:
	_refresh_screen()

func _on_daily_quests_reset(_date_key: String) -> void:
	_refresh_screen()

func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	_return_to_journey()

func _return_to_journey() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error("TrialsHub: Main Menu scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(MAIN_MENU_SCENE, -1)
	if change_error != OK:
		push_error("TrialsHub: gagal kembali ke Journey. Error code: " + str(change_error))
