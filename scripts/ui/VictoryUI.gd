extends CanvasLayer

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

@onready var stage_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/StageLabel
)
@onready var clear_state_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/ClearStateLabel
)
@onready var reward_summary_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel/RewardMargin/RewardContent/RewardSummaryLabel
)
@onready var balance_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel/RewardMargin/RewardContent/BalanceLabel
)
@onready var main_menu_button: Button = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/MainMenuButton
)

var victory_reward_entries: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	if not RewardManager.reward_granted.is_connected(_on_reward_granted):
		RewardManager.reward_granted.connect(_on_reward_granted)
	hide()

func show_victory() -> void:
	_refresh_stage_identity()
	_refresh_reward_summary()
	if SaveManager.is_progress_read_only():
		clear_state_label.text = "SAVE PENDING"
		reward_summary_label.text = "A save needs recovery. Close and reopen the game before continuing."
	DebugLogger.system(str("VictoryUI ditampilkan!"))
	show()

func _on_reward_granted(
	source_type: String,
	source_id: String,
	reward_data: Dictionary
) -> void:
	if source_type not in [
		RewardManager.SOURCE_STAGE_CLEAR,
		RewardManager.SOURCE_BOSS_DEFEAT
	]:
		return
	victory_reward_entries.append({
		"source_type": source_type,
		"source_id": source_id,
		"reward_data": RewardManager.get_last_grant_result().get("applied_reward_data", reward_data).duplicate(true)
	})

func _refresh_stage_identity() -> void:
	var chapter_id: int = JourneyManager.selected_chapter_id
	var stage_id: int = JourneyManager.selected_stage_id
	var chapter_data: Dictionary = JourneyManager.get_chapter_data(chapter_id)
	var stage_data: Dictionary = JourneyManager.get_selected_stage_data()
	var chapter_name: String = str(
		chapter_data.get("display_name", "Chapter %d" % chapter_id)
	)
	var stage_name: String = str(
		stage_data.get("display_name", "Stage %d" % stage_id)
	)
	stage_label.text = "%s  •  %s" % [chapter_name, stage_name]

func _refresh_reward_summary() -> void:
	var presentation_blocks: Array[String] = []
	var clear_state: String = "STAGE CLEAR"
	for raw_reward_entry in victory_reward_entries:
		var reward_entry: Dictionary = raw_reward_entry
		var source_type: String = str(
			reward_entry.get("source_type", "")
		)
		var source_id: String = str(
			reward_entry.get("source_id", "")
		)
		var reward_data: Dictionary = reward_entry.get(
			"reward_data",
			{}
		)
		var reward_title: String = _get_reward_title(source_type, source_id)
		presentation_blocks.append(
			tr(reward_title).to_upper()
			+ "\n"
			+ RewardManager.get_reward_summary(reward_data)
		)
		if source_type == RewardManager.SOURCE_STAGE_CLEAR:
			clear_state = _get_clear_state(source_id)
	if presentation_blocks.is_empty():
		presentation_blocks.append(
			tr("Stage Clear Reward").to_upper()
			+ "\n"
			+ tr("No Reward")
		)
	clear_state_label.text = clear_state
	reward_summary_label.text = "\n\n".join(
		PackedStringArray(presentation_blocks)
	)
	balance_label.text = tr("SPIRIT STONE BALANCE  •  %s") % (
		_format_number(ProgressionManager.spirit_stone)
	)
	DebugLogger.system(str(
		"VictoryUI Reward Presentation: ",
		reward_summary_label.text.replace("\n", " | ")
	))

func _get_reward_title(source_type: String, source_id: String) -> String:
	if source_type == RewardManager.SOURCE_BOSS_DEFEAT:
		return "Boss Reward"
	if source_id.ends_with("_first_clear"):
		return "First Clear Reward"
	if source_id.ends_with("_repeat_clear"):
		return "Repeat Clear Reward"
	return "Stage Clear Reward"

func _get_clear_state(source_id: String) -> String:
	if source_id.ends_with("_first_clear"):
		return "FIRST CLEAR • PROGRESS RECORDED"
	if source_id.ends_with("_repeat_clear"):
		return "REPEAT CLEAR • REWARD SECURED"
	return "STAGE CLEAR • REWARD SECURED"

func _format_number(value: int) -> String:
	var magnitude: int = value
	if magnitude < 0:
		magnitude = -magnitude
	var raw_value: String = str(magnitude)
	var formatted: String = ""
	var digit_count: int = 0
	for index in range(raw_value.length() - 1, -1, -1):
		if digit_count > 0 and digit_count % 3 == 0:
			formatted = "," + formatted
		formatted = raw_value.substr(index, 1) + formatted
		digit_count += 1
	if value < 0:
		formatted = "-" + formatted
	return formatted

func _on_main_menu_pressed() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_to(
		MAIN_MENU_SCENE,
		{
			"title": "Returning in Triumph",
			"subtitle": "The Jade Sanctuary welcomes you",
			"minimum_display_time": 0.45
		}
	)
	if change_error != OK:
		push_error(
			"VictoryUI: gagal kembali ke Main Menu. Error code: "
			+ str(change_error)
		)
