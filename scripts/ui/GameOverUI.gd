extends CanvasLayer

## Game Over UI
## Menangani Retry stage yang sama dan kembali ke Main Menu.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

@onready var stage_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/StageLabel
)
@onready var wave_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/WaveLabel
)
@onready var reward_summary_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel/RewardMargin/RewardContent/RewardSummaryLabel
)
@onready var balance_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel/RewardMargin/RewardContent/BalanceLabel
)
@onready var retry_button: Button = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RetryButton
)
@onready var main_menu_button: Button = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/MainMenuButton
)
@onready var defeat_backdrop: ColorRect = $ColorRect
@onready var defeat_panel: PanelContainer = (
	$ColorRect/SafeArea/CenterContainer/Panel
)

const DEFEAT_BACKDROP_FADE_DURATION: float = 0.52
const DEFEAT_PANEL_DELAY: float = 0.16
const DEFEAT_PANEL_FADE_DURATION: float = 0.30

var last_game_over_reward: Dictionary = {}
var intro_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	retry_button.pressed.connect(_on_retry_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	if not RewardManager.reward_granted.is_connected(_on_reward_granted):
		RewardManager.reward_granted.connect(_on_reward_granted)
	hide()

func show_game_over() -> void:
	_refresh_stage_identity()
	_refresh_reward_summary()
	retry_button.disabled = SaveManager.is_progress_read_only()
	if retry_button.disabled:
		reward_summary_label.text = "A save needs recovery. Close and reopen the game before continuing."

	# The final player hit already owns immediate combat feedback. Let the arena
	# remain visible for a fraction of a second instead of replacing it with the
	# defeat panel on the same frame.
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()
	defeat_backdrop.modulate.a = 0.0
	defeat_panel.modulate.a = 0.0
	show()

	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(
		defeat_backdrop,
		"modulate:a",
		1.0,
		DEFEAT_BACKDROP_FADE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(
		defeat_panel,
		"modulate:a",
		1.0,
		DEFEAT_PANEL_FADE_DURATION
	).set_delay(DEFEAT_PANEL_DELAY).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)

func _on_reward_granted(
	source_type: String,
	source_id: String,
	reward_data: Dictionary
) -> void:
	if source_type != RewardManager.SOURCE_GAME_OVER:
		return
	last_game_over_reward = {
		"source_id": source_id,
		"reward_data": RewardManager.get_last_grant_result().get("applied_reward_data", reward_data).duplicate(true)
	}

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
	var reached_wave: int = _get_reached_wave()
	var reward_data: Dictionary = last_game_over_reward.get(
		"reward_data",
		{}
	)
	wave_label.text = tr("WAVE %d REACHED") % reached_wave
	reward_summary_label.text = RewardManager.get_reward_summary(
		reward_data,
		"No Reward Recovered"
	)
	balance_label.text = tr("SPIRIT STONE BALANCE  •  %s") % (
		_format_number(ProgressionManager.spirit_stone)
	)
	DebugLogger.system(str(
		"GameOverUI Reward Presentation: Wave ",
		reached_wave,
		" | ",
		reward_summary_label.text.replace("\n", " | ")
	))

func _get_reached_wave() -> int:
	var wave_manager: Node = get_parent().get_node_or_null("WaveManager")
	if wave_manager == null:
		return 0
	return int(wave_manager.current_wave)

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


func _reset_intro_visual_state() -> void:
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()
	defeat_backdrop.modulate.a = 1.0
	defeat_panel.modulate.a = 1.0

func _on_retry_pressed() -> void:
	if SaveManager.is_progress_read_only():
		return
	if SceneTransitionManager.is_transitioning:
		return
	_reset_intro_visual_state()
	var selected_stage_data: Dictionary = JourneyManager.get_selected_stage_data()
	if selected_stage_data.is_empty():
		push_error("GameOverUI: data stage untuk Retry tidak ditemukan.")
		return
	var expected_scene_path: String = str(
		selected_stage_data.get("scene_path", "")
	)
	if expected_scene_path.is_empty():
		push_error("GameOverUI: stage untuk Retry belum memiliki scene.")
		return
	if not ResourceLoader.exists(expected_scene_path):
		push_error(
			"GameOverUI: scene Retry tidak ditemukan: "
			+ expected_scene_path
		)
		return
	GameSession.start_new_game()
	var stage_scene_path: String = JourneyManager.begin_selected_stage()
	if stage_scene_path.is_empty():
		get_tree().paused = true
		push_error("GameOverUI: JourneyManager gagal memulai Retry.")
		return
	DebugLogger.system(str(
		"Retry Chapter ",
		JourneyManager.active_run_chapter_id,
		" Stage ",
		JourneyManager.active_run_stage_id,
		" -> ",
		stage_scene_path
	))
	var change_error: Error = SceneTransitionManager.transition_to(
		stage_scene_path,
		{
			"title": "Rekindling the Dao Heart",
			"subtitle": "Returning to the battlefield",
			"minimum_display_time": 0.65
		}
	)
	if change_error != OK:
		JourneyManager.clear_active_run()
		get_tree().paused = true
		push_error(
			"GameOverUI: gagal membuka stage Retry. Error code: "
			+ str(change_error)
		)

func _on_main_menu_pressed() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	_reset_intro_visual_state()
	var change_error: Error = SceneTransitionManager.transition_to(
		MAIN_MENU_SCENE,
		{
			"title": "Returning to Jade Sanctuary",
			"subtitle": "Reflect, refine, and rise again",
			"minimum_display_time": 0.4
		}
	)
	if change_error != OK:
		get_tree().paused = true
		push_error(
			"GameOverUI: gagal kembali ke Main Menu. Error code: "
			+ str(change_error)
		)
