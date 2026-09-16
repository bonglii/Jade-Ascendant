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
@onready var profile_text_box: VBoxContainer = (
	$HomeUI/TopBar/Row/Profile/ProfileContent/ProfileText
)
@onready var profile_path_label: Label = (
	$HomeUI/TopBar/Row/Profile/ProfileContent/ProfileText/Path
)
@onready var profile_panel: PanelContainer = (
	$HomeUI/TopBar/Row/Profile
)
@onready var profile_seal: TextureRect = (
	$HomeUI/TopBar/Row/Profile/ProfileContent/ProfileSeal
)

var hero_level_label: Label = null
var hero_level_bar: ProgressBar = null

var profile_overlay: Control = null
var profile_sheet_panel: PanelContainer = null
var profile_sheet_body: VBoxContainer = null
var profile_sheet_rank_label: Label = null
var profile_sheet_level_label: Label = null
var profile_sheet_exp_bar: ProgressBar = null

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	journey_button.pressed.connect(_on_journey_pressed)
	daily_quick_button.pressed.connect(_on_daily_quick_pressed)
	achievement_quick_button.pressed.connect(_on_achievement_quick_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	SceneTransitionManager.set_back_handler(handle_system_back)
	_ensure_hero_level_profile()
	_configure_profile_interaction()
	_ensure_profile_sheet()
	_ensure_hero_progression_initialized()
	_refresh_home()
	_configure_platform_ui()
	call_deferred("_play_intro_animation")

func _refresh_home() -> void:
	spirit_stone_label.text = _format_amount(int(ProgressionManager.spirit_stone))
	_refresh_hero_level_profile()
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

	var has_checkpoint: bool = _has_checkpoint()
	_refresh_progress_guidance(chapter_id, cleared, total, chapter_complete, has_checkpoint)

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

	if profile_overlay != null and profile_overlay.visible:
		_refresh_profile_sheet()

func _ensure_hero_progression_initialized() -> void:
	if ProgressionManager.hero_progression_initialized:
		return

	# Saves created before this feature did not track repeat-clear history. Seed
	# only known first clears, which is deterministic and cannot over-credit.
	var historical_exp: int = 0
	for chapter_id: int in range(1, 4):
		var stage_ids: Array = JourneyManager.get_stage_ids(chapter_id)
		for raw_stage_id: Variant in stage_ids:
			var stage_id: int = int(raw_stage_id)
			if not JourneyManager.is_stage_cleared(chapter_id, stage_id):
				continue
			historical_exp += RewardManager.get_stage_clear_hero_exp(
				chapter_id,
				stage_id,
				true
			)

	if ProgressionManager.initialize_hero_progression(historical_exp):
		DebugLogger.system(str(
			"Lin Yue Hero Level initialized | Level: ",
			ProgressionManager.get_hero_level(),
			" | Historical EXP: ",
			historical_exp
		))

func _ensure_hero_level_profile() -> void:
	if hero_level_label != null and hero_level_bar != null:
		return

	hero_level_label = Label.new()
	hero_level_label.name = "HeroLevelLabel"
	hero_level_label.add_theme_font_size_override("font_size", 9)
	hero_level_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.84, 0.46, 0.96)
	)
	profile_text_box.add_child(hero_level_label)

	hero_level_bar = ProgressBar.new()
	hero_level_bar.name = "HeroLevelBar"
	hero_level_bar.custom_minimum_size = Vector2(0.0, 5.0)
	hero_level_bar.show_percentage = false
	hero_level_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.002, 0.020, 0.026, 0.90)
	background.corner_radius_top_left = 3
	background.corner_radius_top_right = 3
	background.corner_radius_bottom_left = 3
	background.corner_radius_bottom_right = 3
	hero_level_bar.add_theme_stylebox_override("background", background)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.20, 0.82, 0.68, 0.98)
	fill.border_width_top = 1
	fill.border_color = Color(0.96, 0.76, 0.30, 0.92)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	hero_level_bar.add_theme_stylebox_override("fill", fill)
	profile_text_box.add_child(hero_level_bar)

func _refresh_hero_level_profile() -> void:
	if hero_level_label == null or hero_level_bar == null:
		return
	var hero_level: int = ProgressionManager.get_hero_level()
	profile_path_label.text = tr(ProgressionManager.get_hero_rank_title())
	if hero_level >= ProgressionManager.HERO_MAX_LEVEL:
		hero_level_label.text = "LV %02d  •  MAX" % hero_level
		hero_level_bar.max_value = 1.0
		hero_level_bar.value = 1.0
		return
	var current_exp: int = ProgressionManager.get_hero_current_level_experience()
	var required_exp: int = ProgressionManager.get_hero_experience_to_next_level()
	hero_level_label.text = "LV %02d  •  %d / %d EXP" % [
		hero_level,
		current_exp,
		required_exp
	]
	hero_level_bar.max_value = float(maxi(required_exp, 1))
	hero_level_bar.value = float(clampi(current_exp, 0, maxi(required_exp, 1)))

func _refresh_progress_guidance(
	chapter_id: int,
	cleared: int,
	total: int,
	chapter_complete: bool,
	has_checkpoint: bool
) -> void:
	# FTUE stays non-modal on Home. The battlefield tutorial teaches combat;
	# Home only tells the player what the next meaningful action is.
	if has_checkpoint:
		realm_status_label.text = tr("IN PROGRESS")
		realm_status_label.add_theme_color_override("font_color", Color(0.48, 0.96, 0.83, 1.0))
		home_hint_label.text = tr("CONTINUE RUN") + "  •  " + tr("Your path to ascension")
		journey_button.text = tr("ENTER JOURNEY")
		return

	if chapter_complete:
		realm_status_label.text = tr("COMPLETED")
		realm_status_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.40, 1.0))
		home_hint_label.text = tr("CHAPTER COMPLETE  •  Revisit any trial in Journey")
		journey_button.text = tr("SELECT CHAPTER")
		return

	realm_status_label.text = tr("IN PROGRESS")
	realm_status_label.add_theme_color_override("font_color", Color(0.48, 0.96, 0.83, 1.0))

	if cleared <= 0:
		home_hint_label.text = tr("BEGIN TRIAL") + "  •  " + tr("Your path to ascension")
		journey_button.text = tr("ENTER JOURNEY")
		return

	if chapter_id == 1 and cleared == 1:
		# Stage 1-1 first clear is the cleanest moment to teach the permanent
		# progression loop without another blocking tutorial popup.
		home_hint_label.text = (
			tr("CULTIVATION")
			+ "  •  "
			+ tr("Permanent upgrade • persists between journeys.")
		)
		journey_button.text = tr("ENTER JOURNEY")
		return

	home_hint_label.text = tr("%d / %d trials cleared  •  Your path to ascension") % [
		cleared,
		maxi(total, 1)
	]
	journey_button.text = tr("ENTER JOURNEY")

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
	if profile_overlay != null and profile_overlay.visible:
		_close_profile_sheet()
		return
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

func _configure_profile_interaction() -> void:
	profile_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	profile_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	profile_panel.tooltip_text = tr("Open Lin Yue profile")
	for child: Node in profile_panel.get_children():
		_set_profile_child_mouse_ignore(child)
	if not profile_panel.gui_input.is_connected(_on_profile_gui_input):
		profile_panel.gui_input.connect(_on_profile_gui_input)

func _set_profile_child_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_profile_child_mouse_ignore(child)

func _on_profile_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			mouse_event.button_index == MOUSE_BUTTON_LEFT
			and mouse_event.pressed
		):
			_open_profile_sheet()
			accept_event()
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_open_profile_sheet()
			accept_event()

func _ensure_profile_sheet() -> void:
	if profile_overlay != null:
		return

	profile_overlay = Control.new()
	profile_overlay.name = "LinYueProfileOverlay"
	profile_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	profile_overlay.z_index = 300
	profile_overlay.visible = false
	add_child(profile_overlay)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.001, 0.008, 0.014, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_profile_dim_gui_input)
	profile_overlay.add_child(dim)

	var outer_margin := MarginContainer.new()
	outer_margin.name = "OuterMargin"
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 18)
	outer_margin.add_theme_constant_override("margin_top", 24)
	outer_margin.add_theme_constant_override("margin_right", 18)
	outer_margin.add_theme_constant_override("margin_bottom", 24)
	outer_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_overlay.add_child(outer_margin)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_margin.add_child(center)

	profile_sheet_panel = PanelContainer.new()
	profile_sheet_panel.name = "ProfileSheet"
	profile_sheet_panel.custom_minimum_size = Vector2(588.0, 930.0)
	profile_sheet_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet_style := _make_profile_style(
		Color(0.003, 0.030, 0.040, 0.992),
		Color(0.90, 0.69, 0.25, 0.96),
		18,
		2
	)
	sheet_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	sheet_style.shadow_size = 18
	profile_sheet_panel.add_theme_stylebox_override("panel", sheet_style)
	center.add_child(profile_sheet_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	profile_sheet_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 14)
	content.add_child(header)

	var seal := TextureRect.new()
	seal.custom_minimum_size = Vector2(70.0, 70.0)
	seal.texture = profile_seal.texture
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(seal)

	var header_text := VBoxContainer.new()
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_text.add_theme_constant_override("separation", 1)
	header.add_child(header_text)

	var name_label := Label.new()
	name_label.text = "LIN YUE"
	name_label.theme_type_variation = &"JadeHeroName"
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override(
		"font_color",
		Color(0.95, 1.0, 0.98, 1.0)
	)
	header_text.add_child(name_label)

	profile_sheet_rank_label = Label.new()
	profile_sheet_rank_label.theme_type_variation = &"JadeSubtitle"
	profile_sheet_rank_label.add_theme_font_size_override("font_size", 15)
	profile_sheet_rank_label.add_theme_color_override(
		"font_color",
		Color(0.58, 0.95, 0.86, 1.0)
	)
	header_text.add_child(profile_sheet_rank_label)

	profile_sheet_level_label = Label.new()
	profile_sheet_level_label.add_theme_font_size_override("font_size", 14)
	profile_sheet_level_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.83, 0.43, 1.0)
	)
	header_text.add_child(profile_sheet_level_label)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.custom_minimum_size = Vector2(48.0, 48.0)
	close_button.text = "×"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_color_override(
		"font_color",
		Color(0.83, 0.91, 0.89, 1.0)
	)
	close_button.add_theme_stylebox_override(
		"normal",
		_make_profile_style(
			Color(0.008, 0.055, 0.064, 0.92),
			Color(0.22, 0.59, 0.56, 0.62),
			11,
			1
		)
	)
	close_button.add_theme_stylebox_override(
		"hover",
		_make_profile_style(
			Color(0.018, 0.110, 0.105, 0.98),
			Color(0.92, 0.72, 0.29, 0.92),
			11,
			1
		)
	)
	close_button.add_theme_stylebox_override(
		"pressed",
		close_button.get_theme_stylebox("hover")
	)
	close_button.pressed.connect(_close_profile_sheet)
	header.add_child(close_button)

	profile_sheet_exp_bar = ProgressBar.new()
	profile_sheet_exp_bar.custom_minimum_size = Vector2(0.0, 10.0)
	profile_sheet_exp_bar.show_percentage = false
	profile_sheet_exp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_sheet_exp_bar.add_theme_stylebox_override(
		"background",
		_make_profile_style(
			Color(0.001, 0.014, 0.020, 0.96),
			Color(0.12, 0.42, 0.40, 0.60),
			4,
			1
		)
	)
	profile_sheet_exp_bar.add_theme_stylebox_override(
		"fill",
		_make_profile_style(
			Color(0.12, 0.77, 0.65, 0.98),
			Color(0.92, 0.72, 0.28, 0.85),
			4,
			1
		)
	)
	content.add_child(profile_sheet_exp_bar)

	var eyebrow := Label.new()
	eyebrow.text = tr("PERMANENT COMBAT PROFILE")
	eyebrow.theme_type_variation = &"JadeSubtitle"
	eyebrow.add_theme_font_size_override("font_size", 16)
	eyebrow.add_theme_color_override(
		"font_color",
		Color(0.98, 0.80, 0.39, 1.0)
	)
	content.add_child(eyebrow)

	var subtitle := Label.new()
	subtitle.text = tr(
		"Permanent stats • before run-only upgrades"
	)
	subtitle.theme_type_variation = &"JadeMutedLabel"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0.0, 0.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(scroll)

	profile_sheet_body = VBoxContainer.new()
	profile_sheet_body.name = "Body"
	profile_sheet_body.custom_minimum_size = Vector2(0.0, 0.0)
	profile_sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_sheet_body.add_theme_constant_override("separation", 10)
	scroll.add_child(profile_sheet_body)

func _make_profile_style(
	background_color: Color,
	border_color: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _on_profile_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			mouse_event.button_index == MOUSE_BUTTON_LEFT
			and mouse_event.pressed
		):
			_close_profile_sheet()
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_close_profile_sheet()

func _open_profile_sheet() -> void:
	_ensure_profile_sheet()
	_refresh_profile_sheet()
	profile_overlay.visible = true
	if SettingsManager.reduced_effects:
		profile_sheet_panel.modulate = Color.WHITE
		profile_sheet_panel.scale = Vector2.ONE
		return

	profile_sheet_panel.pivot_offset = profile_sheet_panel.size * 0.5
	profile_sheet_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	profile_sheet_panel.scale = Vector2(0.97, 0.97)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		profile_sheet_panel,
		"modulate",
		Color.WHITE,
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		profile_sheet_panel,
		"scale",
		Vector2.ONE,
		0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_profile_sheet() -> void:
	if profile_overlay == null or not profile_overlay.visible:
		return
	profile_overlay.visible = false

func _refresh_profile_sheet() -> void:
	if profile_sheet_body == null:
		return

	var hero_level: int = ProgressionManager.get_hero_level()
	profile_sheet_rank_label.text = tr(
		ProgressionManager.get_hero_rank_title()
	)
	if hero_level >= ProgressionManager.HERO_MAX_LEVEL:
		profile_sheet_level_label.text = "LV %02d  •  MAX" % hero_level
		profile_sheet_exp_bar.max_value = 1.0
		profile_sheet_exp_bar.value = 1.0
	else:
		var current_exp: int = (
			ProgressionManager.get_hero_current_level_experience()
		)
		var required_exp: int = (
			ProgressionManager.get_hero_experience_to_next_level()
		)
		profile_sheet_level_label.text = (
			"LV %02d  •  %d / %d EXP"
			% [hero_level, current_exp, required_exp]
		)
		profile_sheet_exp_bar.max_value = float(maxi(required_exp, 1))
		profile_sheet_exp_bar.value = float(
			clampi(current_exp, 0, maxi(required_exp, 1))
		)

	for child: Node in profile_sheet_body.get_children():
		profile_sheet_body.remove_child(child)
		child.queue_free()

	var stats: Dictionary = _build_permanent_profile_snapshot()
	_add_profile_section_title(tr("CORE STATS"))
	_add_profile_stat_row(
		tr("MAX HP BONUS"),
		"+%.0f" % float(stats["max_health_bonus"]),
		""
	)
	_add_profile_stat_row(
		tr("DAMAGE BONUS"),
		"+%.1f%%" % (float(stats["damage_bonus"]) * 100.0),
		""
	)
	_add_profile_stat_row(
		tr("ATTACK SPEED"),
		"+%.1f%%" % (float(stats["attack_speed_bonus"]) * 100.0),
		""
	)
	_add_profile_stat_row(
		tr("MOVEMENT SPEED"),
		"+%.1f%%" % (float(stats["movement_speed_bonus"]) * 100.0),
		""
	)
	_add_profile_stat_row(
		tr("EXP GAIN"),
		"+%.1f%%" % (float(stats["experience_bonus"]) * 100.0),
		""
	)
	_add_profile_stat_row(
		tr("CRITICAL CHANCE"),
		"+%.1f%%" % (float(stats["critical_chance"]) * 100.0),
		""
	)
	_add_profile_stat_row(
		tr("CRITICAL DAMAGE"),
		"%.0f%%" % (float(stats["critical_damage_multiplier"]) * 100.0),
		""
	)

	var has_signature_stat: bool = _has_profile_signature_stat(stats)
	if has_signature_stat:
		_add_profile_section_title(tr("SIGNATURE EFFECTS"))
		if float(stats["attack_cooldown_reduction"]) > 0.0001:
			_add_profile_stat_row(
				tr("COOLDOWN REDUCTION"),
				"-%.1f%%" % (
					float(stats["attack_cooldown_reduction"]) * 100.0
				),
				tr("Reduces weapon-art cooldown time.")
			)
		if float(stats["pickup_radius_bonus"]) > 0.0001:
			_add_profile_stat_row(
				tr("PICKUP RADIUS"),
				"+%.0f px" % float(stats["pickup_radius_bonus"]),
				tr("Qi shards begin following Lin Yue from farther away.")
			)
		if float(stats["starting_shield_charges"]) > 0.0001:
			_add_profile_stat_row(
				tr("STARTING QI SHIELD"),
				"+%d" % int(round(float(stats["starting_shield_charges"]))),
				tr("Fresh runs begin with this many shield charges.")
			)
		if float(stats["level_up_heal"]) > 0.0001:
			_add_profile_stat_row(
				tr("LEVEL-UP RECOVERY"),
				"+%.1f HP" % float(stats["level_up_heal"]),
				tr("Healing received whenever run level increases.")
			)
		if float(stats["blood_qi_heal_bonus"]) > 0.0001:
			_add_profile_stat_row(
				tr("BLOOD QI RECOVERY"),
				"+%.2f HP" % float(stats["blood_qi_heal_bonus"]),
				tr("Additional healing when Blood Qi triggers.")
			)
		if float(stats["moving_damage_bonus"]) > 0.0001:
			_add_profile_stat_row(
				tr("MOVING DAMAGE"),
				"+%.1f%%" % (
					float(stats["moving_damage_bonus"]) * 100.0
				),
				tr("Conditional bonus while Lin Yue is moving.")
			)
		if float(stats["low_health_damage_bonus"]) > 0.0001:
			_add_profile_stat_row(
				tr("LOW-HP DAMAGE"),
				"+%.1f%%" % (
					float(stats["low_health_damage_bonus"]) * 100.0
				),
				tr("Conditional bonus at or below 50% HP.")
			)
		if float(stats["low_health_critical_chance"]) > 0.0001:
			_add_profile_stat_row(
				tr("LOW-HP CRITICAL"),
				"+%.1f%%" % (
					float(stats["low_health_critical_chance"]) * 100.0
				),
				tr("Extra critical chance at or below 50% HP.")
			)

	_add_profile_section_title(tr("CULTIVATION"))
	_add_profile_cultivation_row(
		tr("VITALITY"),
		"LV %d" % ProgressionManager.vitality_level,
		tr("Raises permanent Max HP.")
	)
	_add_profile_cultivation_row(
		tr("SWORD POWER"),
		"LV %d" % ProgressionManager.sword_power_level,
		tr("Raises permanent outgoing damage.")
	)
	_add_profile_cultivation_row(
		tr("SWIFT QI"),
		"LV %d" % ProgressionManager.swift_qi_level,
		tr("Shortens base weapon-art cooldowns.")
	)

	_add_profile_milestones(hero_level)

func _build_permanent_profile_snapshot() -> Dictionary:
	# These coefficients mirror the audited runtime authorities:
	# PlayerHealth health_per_vitality_level = 5.0,
	# PlayerStats Sword Power = +10% per level,
	# PlayerStats Swift Qi cooldown = x0.95 per level.
	var vitality_bonus: float = (
		float(ProgressionManager.vitality_level) * 5.0
	)
	var equipment_health: float = (
		EquipmentManager.get_loadout_total_max_health_bonus()
	)
	var sword_power_multiplier: float = (
		1.0
		+ (float(ProgressionManager.sword_power_level) * 0.10)
	)
	var equipment_damage_multiplier: float = (
		EquipmentManager.get_loadout_damage_multiplier()
	)
	var damage_bonus: float = maxf(
		(sword_power_multiplier * equipment_damage_multiplier) - 1.0,
		0.0
	)

	var swift_qi_cooldown_multiplier: float = pow(
		0.95,
		float(ProgressionManager.swift_qi_level)
	)
	var cooldown_reduction: float = (
		EquipmentManager.get_loadout_secondary_bonus(
			"attack_cooldown_reduction",
			0.10
		)
	)
	var equipment_cooldown_multiplier: float = maxf(
		1.0 - cooldown_reduction,
		0.50
	)
	var combined_cooldown_multiplier: float = maxf(
		swift_qi_cooldown_multiplier
		* equipment_cooldown_multiplier,
		0.0001
	)
	var attack_speed_bonus: float = maxf(
		(1.0 / combined_cooldown_multiplier) - 1.0,
		0.0
	)

	return {
		"max_health_bonus": vitality_bonus + equipment_health,
		"damage_bonus": damage_bonus,
		"attack_speed_bonus": attack_speed_bonus,
		"movement_speed_bonus": maxf(
			EquipmentManager.get_loadout_movement_speed_multiplier() - 1.0,
			0.0
		),
		"experience_bonus": maxf(
			EquipmentManager.get_loadout_experience_multiplier() - 1.0,
			0.0
		),
		"critical_chance": EquipmentManager.get_loadout_critical_chance_bonus(),
		"critical_damage_multiplier": (
			2.0
			+ EquipmentManager.get_loadout_secondary_bonus(
				"critical_damage_bonus",
				0.15
			)
		),
		"attack_cooldown_reduction": cooldown_reduction,
		"pickup_radius_bonus": EquipmentManager.get_loadout_secondary_bonus(
			"pickup_radius_bonus",
			72.0
		),
		"starting_shield_charges": EquipmentManager.get_loadout_secondary_bonus(
			"starting_shield_charges",
			1.0
		),
		"level_up_heal": EquipmentManager.get_loadout_secondary_bonus(
			"level_up_heal_flat",
			4.0
		),
		"blood_qi_heal_bonus": EquipmentManager.get_loadout_secondary_bonus(
			"blood_qi_heal_bonus",
			0.75
		),
		"moving_damage_bonus": EquipmentManager.get_loadout_secondary_bonus(
			"moving_damage_bonus",
			0.08
		),
		"low_health_damage_bonus": EquipmentManager.get_loadout_secondary_bonus(
			"low_health_damage_bonus",
			0.10
		),
		"low_health_critical_chance": (
			EquipmentManager.get_loadout_secondary_bonus(
				"low_health_critical_chance_bonus",
				0.05
			)
		)
	}

func _has_profile_signature_stat(stats: Dictionary) -> bool:
	for stat_id: String in [
		"attack_cooldown_reduction",
		"pickup_radius_bonus",
		"starting_shield_charges",
		"level_up_heal",
		"blood_qi_heal_bonus",
		"moving_damage_bonus",
		"low_health_damage_bonus",
		"low_health_critical_chance"
	]:
		if float(stats.get(stat_id, 0.0)) > 0.0001:
			return true
	return false

func _add_profile_section_title(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(0.0, 28.0)
	label.theme_type_variation = &"JadeSubtitle"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override(
		"font_color",
		Color(0.98, 0.80, 0.39, 1.0)
	)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.78)
	)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	profile_sheet_body.add_child(label)

func _add_profile_stat_row(
	stat_name: String,
	value_text: String,
	description: String
) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_profile_style(
			Color(0.006, 0.047, 0.055, 0.92),
			Color(0.15, 0.55, 0.50, 0.60),
			11,
			1
		)
	)
	profile_sheet_body.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.text = stat_name
	name_label.theme_type_variation = &"JadeSubtitle"
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override(
		"font_color",
		Color(0.87, 0.97, 0.94, 1.0)
	)
	text_box.add_child(name_label)

	if not description.is_empty():
		var description_label := Label.new()
		description_label.text = description
		description_label.theme_type_variation = &"JadeMutedLabel"
		description_label.add_theme_font_size_override("font_size", 13)
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_box.add_child(description_label)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(118.0, 0.0)
	value_label.text = value_text
	value_label.theme_type_variation = &"JadeHeroName"
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.84, 0.45, 1.0)
	)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)

func _add_profile_cultivation_row(
	stat_name: String,
	value_text: String,
	description: String
) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_profile_style(
			Color(0.012, 0.064, 0.066, 0.95),
			Color(0.76, 0.61, 0.25, 0.72),
			12,
			1
		)
	)
	profile_sheet_body.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.text = stat_name
	name_label.theme_type_variation = &"JadeHeroName"
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override(
		"font_color",
		Color(0.90, 1.0, 0.96, 1.0)
	)
	text_box.add_child(name_label)

	var description_label := Label.new()
	description_label.text = description
	description_label.theme_type_variation = &"JadeMutedLabel"
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(description_label)

	var level_label := Label.new()
	level_label.custom_minimum_size = Vector2(118.0, 0.0)
	level_label.text = value_text
	level_label.theme_type_variation = &"JadeHeroName"
	level_label.add_theme_font_size_override("font_size", 19)
	level_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.82, 0.38, 1.0)
	)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(level_label)

func _add_profile_milestones(hero_level: int) -> void:
	_add_profile_section_title(tr("HERO MILESTONES"))

	var milestones: Array[int] = ProgressionManager.get_hero_milestone_levels()
	var claimable_milestone: int = (
		ProgressionManager.get_next_claimable_hero_milestone()
	)
	var next_milestone: int = ProgressionManager.get_next_hero_milestone()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_profile_style(
			Color(0.009, 0.052, 0.058, 0.96),
			Color(0.62, 0.51, 0.24, 0.68),
			12,
			1
		)
	)
	profile_sheet_body.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var milestone_row := HBoxContainer.new()
	milestone_row.add_theme_constant_override("separation", 7)
	box.add_child(milestone_row)

	for milestone_level: int in milestones:
		var reached: bool = hero_level >= milestone_level
		var claimed: bool = (
			ProgressionManager.is_hero_milestone_claimed(milestone_level)
		)
		var is_claimable: bool = milestone_level == claimable_milestone
		var is_next: bool = (
			claimable_milestone <= 0
			and milestone_level == next_milestone
		)
		var milestone_panel := PanelContainer.new()
		milestone_panel.custom_minimum_size = Vector2(0.0, 52.0)
		milestone_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var background_color := Color(0.004, 0.031, 0.037, 0.90)
		var border_color := Color(0.13, 0.34, 0.33, 0.52)
		var label_color := Color(0.48, 0.60, 0.58, 0.88)
		if claimed:
			background_color = Color(0.014, 0.100, 0.092, 0.96)
			border_color = Color(0.31, 0.82, 0.70, 0.84)
			label_color = Color(0.72, 1.0, 0.91, 1.0)
		elif is_claimable:
			background_color = Color(0.104, 0.071, 0.012, 0.98)
			border_color = Color(1.0, 0.77, 0.26, 1.0)
			label_color = Color(1.0, 0.91, 0.58, 1.0)
		elif reached:
			background_color = Color(0.056, 0.052, 0.020, 0.95)
			border_color = Color(0.78, 0.60, 0.24, 0.78)
			label_color = Color(0.94, 0.79, 0.45, 1.0)
		elif is_next:
			background_color = Color(0.082, 0.061, 0.016, 0.95)
			border_color = Color(0.94, 0.72, 0.28, 0.96)
			label_color = Color(1.0, 0.85, 0.46, 1.0)
		milestone_panel.add_theme_stylebox_override(
			"panel",
			_make_profile_style(
				background_color,
				border_color,
				9,
				1
			)
		)
		milestone_row.add_child(milestone_panel)

		var milestone_label := Label.new()
		milestone_label.text = "LV %d" % milestone_level
		milestone_label.theme_type_variation = &"JadeHeroName"
		milestone_label.add_theme_font_size_override("font_size", 14)
		milestone_label.add_theme_color_override(
			"font_color",
			label_color
		)
		milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		milestone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		milestone_panel.add_child(milestone_label)

	var focus_milestone: int = claimable_milestone
	if focus_milestone <= 0:
		focus_milestone = next_milestone

	if focus_milestone > 0:
		var reward_summary: String = (
			RewardManager.get_hero_milestone_reward_summary(focus_milestone)
		).replace("\n", "  •  ")
		var reward_label := Label.new()
		reward_label.text = "%s  •  %s" % [
			tr(ProgressionManager.get_hero_rank_title_for_level(focus_milestone)),
			reward_summary
		]
		reward_label.theme_type_variation = &"JadeMutedLabel"
		reward_label.add_theme_font_size_override("font_size", 12)
		reward_label.add_theme_color_override(
			"font_color",
			Color(0.72, 0.82, 0.78, 0.96)
		)
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(reward_label)

	var status_label := Label.new()
	status_label.theme_type_variation = &"JadeSubtitle"
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if claimable_milestone > 0:
		status_label.text = tr("MILESTONE READY  •  LV %d") % claimable_milestone
		status_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.84, 0.40, 1.0)
		)
	elif next_milestone > 0:
		status_label.text = tr("NEXT MILESTONE  •  LV %d") % next_milestone
		status_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.82, 0.40, 1.0)
		)
	else:
		status_label.text = tr("ALL HERO MILESTONES CLAIMED")
		status_label.add_theme_color_override(
			"font_color",
			Color(0.58, 0.95, 0.84, 1.0)
		)
	box.add_child(status_label)

	if claimable_milestone > 0:
		var claim_button := Button.new()
		claim_button.custom_minimum_size = Vector2(0.0, 48.0)
		claim_button.text = (
			tr("CLAIM MILESTONE REWARD  •  LV %d") % claimable_milestone
		)
		claim_button.focus_mode = Control.FOCUS_NONE
		claim_button.disabled = SaveManager.is_progress_read_only()
		claim_button.add_theme_font_size_override("font_size", 14)
		claim_button.add_theme_color_override(
			"font_color",
			Color(0.96, 1.0, 0.95, 1.0)
		)
		claim_button.add_theme_stylebox_override(
			"normal",
			_make_profile_style(
				Color(0.025, 0.145, 0.120, 0.98),
				Color(0.92, 0.72, 0.28, 0.92),
				10,
				1
			)
		)
		claim_button.add_theme_stylebox_override(
			"hover",
			_make_profile_style(
				Color(0.041, 0.205, 0.163, 1.0),
				Color(1.0, 0.82, 0.34, 1.0),
				10,
				1
			)
		)
		claim_button.add_theme_stylebox_override(
			"pressed",
			_make_profile_style(
				Color(0.012, 0.098, 0.088, 1.0),
				Color(0.83, 0.66, 0.27, 1.0),
				10,
				1
			)
		)
		claim_button.pressed.connect(
			_on_hero_milestone_claim_pressed.bind(claimable_milestone)
		)
		box.add_child(claim_button)

func _on_hero_milestone_claim_pressed(milestone_level: int) -> void:
	if SaveManager.is_progress_read_only():
		return
	var result: Dictionary = RewardManager.claim_hero_milestone(milestone_level)
	if not bool(result.get("success", false)):
		_refresh_profile_sheet()
		return
	_refresh_home()

func _on_exit_pressed() -> void:
	get_tree().quit()
