extends Control

## Trials Hub — Eternal Achievement Records.
## AchievementManager remains the sole authority for progress, unlock,
## reward claim, reward grant and save persistence.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const DAILY_QUEST_SCENE: String = "res://scenes/ui/daily_quest_screen.tscn"
const TrialsRecordSealScript = preload(
	"res://scripts/ui/trials_record_seal.gd"
)

@onready var spirit_stone_label: Label = %SpiritStoneLabel
@onready var record_label: Label = %RecordLabel
@onready var discovered_value_label: Label = %DiscoveredValueLabel
@onready var ready_value_label: Label = %ReadyValueLabel
@onready var total_reward_value_label: Label = %TotalRewardValueLabel
@onready var record_progress_bar: ProgressBar = %RecordProgressBar
@onready var record_progress_label: Label = %RecordProgressLabel
@onready var claim_all_button: Button = %ClaimAllButton
@onready var achievement_list: VBoxContainer = %AchievementList
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
		"Trials Hub aktif! Section: Eternal Achievement Records"
	)


func _connect_manager_signals() -> void:
	if not AchievementManager.achievement_unlocked.is_connected(
		_on_achievement_state_changed
	):
		AchievementManager.achievement_unlocked.connect(
			_on_achievement_state_changed
		)

	if not AchievementManager.achievement_claimed.is_connected(
		_on_achievement_claimed
	):
		AchievementManager.achievement_claimed.connect(
			_on_achievement_claimed
		)

	if not AchievementManager.achievement_progressed.is_connected(
		_on_achievement_progressed
	):
		AchievementManager.achievement_progressed.connect(
			_on_achievement_progressed
		)


func _refresh_screen() -> void:
	spirit_stone_label.text = "%d" % ProgressionManager.spirit_stone

	var total_count: int = AchievementManager.get_achievement_ids().size()
	var unlocked_count: int = AchievementManager.get_unlocked_count()
	var claimable_count: int = AchievementManager.get_claimable_count()
	var claimable_reward: int = AchievementManager.get_total_claimable_reward()
	var daily_claimable: int = DailyQuestManager.get_claimable_count()

	daily_tab.text = _build_trials_tab_text(
		tr("DAILY"),
		daily_claimable
	)
	achievement_tab.text = _build_trials_tab_text(
		tr("ACHIEVEMENTS"),
		claimable_count
	)

	record_label.text = tr(
		"Permanent milestones across combat, cultivation and the journey."
	)
	discovered_value_label.text = "%d / %d" % [
		unlocked_count,
		total_count
	]
	ready_value_label.text = "%d" % claimable_count
	total_reward_value_label.text = "%d" % claimable_reward

	record_progress_bar.max_value = float(maxi(total_count, 1))
	record_progress_bar.value = float(unlocked_count)
	record_progress_bar.add_theme_stylebox_override(
		"background",
		_make_progress_background()
	)
	record_progress_bar.add_theme_stylebox_override(
		"fill",
		_make_overall_progress_fill()
	)
	record_progress_label.text = tr("%d OF %d RECORDS DISCOVERED") % [
		unlocked_count,
		total_count
	]

	claim_all_button.disabled = claimable_count == 0
	claim_all_button.text = (
		tr("CLAIM ALL  •  %d") % claimable_reward
		if claimable_count > 0
		else tr("ALL REWARDS SETTLED")
	)

	_rebuild_achievement_list()


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


func _rebuild_achievement_list() -> void:
	for child: Node in achievement_list.get_children():
		child.queue_free()

	var sorted_ids: Array[String] = _get_sorted_achievement_ids()

	if sorted_ids.is_empty():
		achievement_list.add_child(
			_create_empty_state(
				tr("No eternal records are available yet.")
			)
		)
		return

	for achievement_id: String in sorted_ids:
		achievement_list.add_child(
			_create_achievement_card(achievement_id)
		)


func _get_sorted_achievement_ids() -> Array[String]:
	var ready_ids: Array[String] = []
	var active: Array[String] = []
	var claimed: Array[String] = []

	for achievement_id: String in AchievementManager.get_achievement_ids():
		if AchievementManager.is_claimable(achievement_id):
			ready_ids.append(achievement_id)
		elif AchievementManager.is_claimed(achievement_id):
			claimed.append(achievement_id)
		else:
			active.append(achievement_id)

	ready_ids.sort()
	active.sort()
	claimed.sort()

	var result: Array[String] = []
	result.append_array(ready_ids)
	result.append_array(active)
	result.append_array(claimed)
	return result


func _create_achievement_card(
	achievement_id: String
) -> PanelContainer:
	var data: Dictionary = AchievementManager.get_achievement_data(
		achievement_id
	)
	var progress: int = AchievementManager.get_progress(achievement_id)
	var target: int = AchievementManager.get_target(achievement_id)
	var reward: int = AchievementManager.get_reward(achievement_id)
	var claimed: bool = AchievementManager.is_claimed(achievement_id)
	var claimable: bool = AchievementManager.is_claimable(achievement_id)
	var state_key: String = _get_record_state_key(
		claimed,
		claimable
	)
	var category: String = str(
		data.get("category", "achievement")
	)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 154.0)
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
	seal_panel.custom_minimum_size = Vector2(62.0, 62.0)
	seal_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	seal_panel.add_theme_stylebox_override(
		"panel",
		_make_seal_panel_style(category, state_key)
	)
	row.add_child(seal_panel)

	var seal: Control = TrialsRecordSealScript.new()
	seal.custom_minimum_size = Vector2(58.0, 58.0)
	seal.call(
		"configure",
		category,
		state_key,
		false
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
	title_label.text = tr(str(data.get(
		"title",
		achievement_id
	)))
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
		tr("PERMANENT RECORD")
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
	_configure_achievement_action(
		action_button,
		achievement_id,
		state_key
	)
	action_row.add_child(action_button)

	return card


func _configure_achievement_action(
	button: Button,
	achievement_id: String,
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
				_on_claim_pressed.bind(achievement_id)
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
		"boss":
			return Color(1.0, 0.72, 0.24, 1.0)
		"cultivation":
			return Color(0.76, 0.58, 1.0, 1.0)
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


func _make_overall_progress_fill() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.73, 0.30, 0.96)
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


func _on_claim_pressed(achievement_id: String) -> void:
	AchievementManager.claim_reward(achievement_id)


func _on_claim_all_pressed() -> void:
	AchievementManager.claim_all_rewards()
	_refresh_screen()


func _on_daily_tab_pressed() -> void:
	_change_trials_section(DAILY_QUEST_SCENE)


func _on_achievement_tab_pressed() -> void:
	return


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
			-1
		)
	)

	if change_error != OK:
		push_error(
			"TrialsHub: gagal membuka section. Error code: "
			+ str(change_error)
		)


func _on_achievement_state_changed(
	_achievement_id: String
) -> void:
	_refresh_screen()


func _on_achievement_claimed(
	_achievement_id: String,
	_spirit_stone_reward: int
) -> void:
	_refresh_screen()


func _on_achievement_progressed(
	_achievement_id: String,
	_current_progress: int,
	_target_progress: int
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
