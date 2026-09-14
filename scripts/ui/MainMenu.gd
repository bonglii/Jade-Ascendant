extends Control

## Home / Jade Sanctuary. Journey owns trial selection and fresh-run confirmation.
## Continue remains driven by the validated checkpoint, independent of selection.
const CHAPTER_SELECT_SCENE: String = "res://scenes/ui/chapter_select.tscn"
const ACHIEVEMENT_SCENE: String = "res://scenes/ui/achievement_screen.tscn"
const DAILY_QUEST_SCENE: String = "res://scenes/ui/daily_quest_screen.tscn"
const SETTINGS_SCENE: String = "res://scenes/ui/settings_screen.tscn"
const CheckpointData = preload("res://scripts/managers/checkpoint_manager.gd")

@onready var spirit_stone_label: Label = %SpiritStoneLabel
@onready var realm_summary_label: Label = %RealmSummaryLabel
@onready var home_hint_label: Label = %HomeHintLabel
@onready var chapter_badge_label: Label = %ChapterBadgeLabel
@onready var realm_status_label: Label = %RealmStatusLabel
@onready var realm_progress_bar: ProgressBar = %RealmProgressBar
@onready var realm_progress_label: Label = %RealmProgressLabel
@onready var continue_button: Button = %ContinueButton
@onready var journey_button: Button = %JourneyButton
@onready var daily_quick_button: Button = %DailyQuickButton
@onready var achievement_quick_button: Button = %AchievementQuickButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var key_art: TextureRect = %KeyArt
@onready var home_ui: Control = %HomeUI

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	journey_button.pressed.connect(_on_journey_pressed)
	daily_quick_button.pressed.connect(_on_daily_quick_pressed)
	achievement_quick_button.pressed.connect(_on_achievement_quick_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	SceneTransitionManager.set_back_handler(handle_system_back)
	_refresh_home()
	_configure_platform_ui()
	call_deferred("_play_intro_animation")

func _refresh_home() -> void:
	spirit_stone_label.text = _format_amount(int(ProgressionManager.spirit_stone))
	var chapter_id: int = JourneyManager.selected_chapter_id
	var chapter: Dictionary = JourneyManager.get_chapter_data(chapter_id)
	var progress: Dictionary = JourneyManager.get_chapter_progress(chapter_id)
	var cleared: int = int(progress.get("cleared_stages", 0))
	var total: int = maxi(int(progress.get("total_stages", 5)), 1)
	var chapter_complete: bool = cleared >= total

	chapter_badge_label.text = tr("CHAPTER %02d") % chapter_id
	realm_summary_label.text = str(chapter.get("display_name", "Jade Sanctuary"))
	realm_progress_bar.max_value = float(total)
	realm_progress_bar.value = float(clampi(cleared, 0, total))
	realm_progress_label.text = tr("%d / %d COMPLETE") % [cleared, total]

	if chapter_complete:
		realm_status_label.text = tr("COMPLETED")
		realm_status_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.40, 1.0))
		home_hint_label.text = tr("CHAPTER COMPLETE  •  Revisit any trial in Journey")
		journey_button.text = tr("SELECT CHAPTER")
	else:
		realm_status_label.text = tr("IN PROGRESS")
		realm_status_label.add_theme_color_override("font_color", Color(0.48, 0.96, 0.83, 1.0))
		home_hint_label.text = tr("%d / %d trials cleared  •  Your path to ascension") % [cleared, total]
		journey_button.text = tr("ENTER JOURNEY")

	var has_checkpoint: bool = _has_checkpoint()
	continue_button.visible = has_checkpoint
	continue_button.disabled = not has_checkpoint
	continue_button.text = _get_continue_button_text() if has_checkpoint else "CONTINUE RUN"
	var daily_count: int = DailyQuestManager.get_claimable_count()
	var achievement_count: int = AchievementManager.get_claimable_count()
	daily_quick_button.text = tr("DAILY TRIALS") + ("  •  %d" % daily_count if daily_count > 0 else "")
	achievement_quick_button.text = tr("ACHIEVEMENTS") + ("  •  %d" % achievement_count if achievement_count > 0 else "")
	_refresh_quick_action_emphasis(daily_count, achievement_count)
	if SaveManager.is_progress_read_only():
		continue_button.disabled = true
		journey_button.disabled = true
		realm_status_label.text = tr("SAVE RECOVERY REQUIRED")
		realm_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45, 1.0))
		home_hint_label.text = "A save needs recovery. Close and reopen the game before continuing."


func _refresh_quick_action_emphasis(daily_count: int, achievement_count: int) -> void:
	var daily_color: Color = (
		Color(0.88, 1.0, 0.96, 1.0)
		if daily_count > 0
		else Color(0.68, 0.84, 0.80, 1.0)
	)
	var achievement_color: Color = (
		Color(1.0, 0.88, 0.52, 1.0)
		if achievement_count > 0
		else Color(0.78, 0.80, 0.70, 1.0)
	)
	daily_quick_button.add_theme_color_override("font_color", daily_color)
	achievement_quick_button.add_theme_color_override("font_color", achievement_color)

func _on_journey_pressed() -> void:
	_open_hub_scene_fast(CHAPTER_SELECT_SCENE, "Journey")

func handle_system_back() -> void:
	if not SceneTransitionManager.is_transitioning:
		get_tree().quit()

func _on_continue_pressed() -> void:
	if SaveManager.is_progress_read_only():
		return
	if not _has_checkpoint():
		_refresh_home()
		return
	var stage_scene_path: String = _get_continue_scene_path()
	if stage_scene_path.is_empty():
		return
	GameSession.continue_saved_game()
	DebugLogger.system(str("Continue menuju: ", stage_scene_path))
	var change_error: Error = SceneTransitionManager.transition_to(
		stage_scene_path,
		{
			"title": "Resuming Cultivation",
			"subtitle": _get_continue_loading_subtitle(),
			"minimum_display_time": 0.65
		}
	)
	if change_error != OK:
		GameSession.start_new_game()
		push_error(
			"MainMenu: gagal membuka scene Continue. Error code: "
			+ str(change_error)
		)

func _get_continue_button_text() -> String:
	var checkpoint_data: Dictionary = _get_continue_checkpoint_data()
	if not checkpoint_data.has("chapter_id"):
		return "CONTINUE RUN"
	return tr("CONTINUE  •  STAGE %d-%d") % [
		int(checkpoint_data["chapter_id"]),
		int(checkpoint_data["stage_id"])
	]

func _get_continue_loading_subtitle() -> String:
	var checkpoint_data: Dictionary = _get_continue_checkpoint_data()
	if not checkpoint_data.has("chapter_id"):
		return "Restoring the latest checkpoint"
	return tr("Chapter %d  •  Stage %d-%d") % [
		int(checkpoint_data["chapter_id"]),
		int(checkpoint_data["chapter_id"]),
		int(checkpoint_data["stage_id"])
	]

func _get_continue_scene_path() -> String:
	return _resolve_continue_scene_path(_get_continue_checkpoint_data())

func _get_continue_checkpoint_data() -> Dictionary:
	var io_result: Dictionary = CheckpointData.read_checkpoint_result()
	if not bool(io_result.get("success", false)):
		return {}
	return io_result.get("data", {})

func _resolve_continue_scene_path(checkpoint_data: Dictionary) -> String:
	if checkpoint_data.is_empty():
		return ""
	# The checkpoint owns the identity of the snapshot being resumed. Journey
	# selection or stale active-run metadata must not choose a different scene.
	var chapter_id: int = int(checkpoint_data.get("chapter_id", JourneyManager.DEFAULT_CHAPTER_ID))
	var stage_id: int = int(checkpoint_data.get("stage_id", JourneyManager.DEFAULT_STAGE_ID))
	if not JourneyManager.is_stage_implemented(chapter_id, stage_id):
		return ""
	var stage_data: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
	var scene_path: String = str(stage_data.get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		return ""
	return scene_path

func _has_checkpoint() -> bool:
	return not _get_continue_scene_path().is_empty()

func _on_daily_quick_pressed() -> void:
	_open_hub_scene_fast(DAILY_QUEST_SCENE, "Daily Quest")

func _on_achievement_quick_pressed() -> void:
	_open_hub_scene_fast(ACHIEVEMENT_SCENE, "Achievement")

func _on_settings_pressed() -> void:
	_open_hub_scene_fast(SETTINGS_SCENE, "Settings")

func _open_hub_scene_fast(scene_path: String, screen_name: String) -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error("MainMenu: scene " + screen_name + " tidak ditemukan: " + scene_path)
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(scene_path, 1)
	if change_error != OK:
		push_error(
			"MainMenu: gagal membuka "
			+ screen_name
			+ ". Error code: "
			+ str(change_error)
		)

func _configure_platform_ui() -> void:
	exit_button.visible = not (
		OS.has_feature("android") or OS.has_feature("ios")
	)
	settings_button.disabled = false
	settings_button.tooltip_text = "Settings"

func _play_intro_animation() -> void:
	if SettingsManager.reduced_effects:
		return
	key_art.pivot_offset = key_art.size * 0.5
	key_art.modulate = Color(0.58, 0.68, 0.72, 0.0)
	key_art.scale = Vector2(1.025, 1.025)
	home_ui.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var intro_tween: Tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(
		key_art,
		"modulate",
		Color.WHITE,
		0.72
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(
		key_art,
		"scale",
		Vector2.ONE,
		1.0
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(
		home_ui,
		"modulate",
		Color.WHITE,
		0.42
	).set_delay(0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _format_amount(value: int) -> String:
	var sign_prefix: String = ""
	var digits: String = str(value)
	if value < 0:
		sign_prefix = "-"
		digits = digits.trim_prefix("-")
	var formatted: String = ""
	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	return sign_prefix + digits + formatted

func _on_exit_pressed() -> void:
	get_tree().quit()
