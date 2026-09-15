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


func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)

	claim_all_button.pressed.connect(_on_claim_all_pressed)
	daily_tab.pressed.connect(_on_daily_tab_pressed)
	achievement_tab.pressed.connect(_on_achievement_tab_pressed)
	challenge_tab.visible = false

	_connect_manager_signals()
	_refresh_screen()

	DebugLogger.system(
		"Trials Hub aktif! Section: Daily Disciplines"
	)


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
