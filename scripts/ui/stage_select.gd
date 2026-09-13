extends Control

## Stage Select — Journey UI production polish v3: stage-specific atmosphere.
## Stage availability and progression remain owned by JourneyManager.

const CHAPTER_SELECT_SCENE: String = "res://scenes/ui/chapter_select.tscn"
const JourneyVisualCatalog = preload("res://scripts/ui/journey_visual_catalog.gd")
const WuxiaPlaqueButton = preload("res://scripts/ui/wuxia_plaque_button.gd")
const StageLandmarkPreview = preload("res://scripts/ui/stage_landmark_preview.gd")

@onready var chapter_label: Label = %ChapterLabel
@onready var chapter_name_label: Label = %ChapterNameLabel
@onready var realm_epithet_label: Label = %RealmEpithetLabel
@onready var realm_backdrop: Control = %RealmBackdrop
@onready var top_accent: ColorRect = $TopAccent
@onready var stage_list: VBoxContainer = %StageList
@onready var selected_stage_label: Label = %SelectedStageLabel
@onready var selected_stage_status_label: Label = %SelectedStageStatusLabel
@onready var selected_realm_label: Label = %SelectedRealmLabel
@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton
@onready var start_confirm_dialog: Control = %StartConfirmDialog
@onready var confirm_stage_label: Label = %ConfirmStageLabel
@onready var confirm_body_label: Label = %ConfirmBodyLabel
@onready var cancel_start_button: Button = %CancelStartButton
@onready var start_new_button: Button = %StartNewButton

var stage_buttons: Dictionary = {}
var stage_views: Dictionary = {}
var chapter_id: int = 0
var realm_profile: Dictionary = {}

func _ready() -> void:
	chapter_id = JourneyManager.selected_chapter_id
	_connect_signals()
	SceneTransitionManager.set_back_handler(handle_system_back)
	_apply_realm_visuals()
	_build_stage_buttons()
	_refresh_screen()

func _connect_signals() -> void:
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	cancel_start_button.pressed.connect(_hide_start_confirm_dialog)
	start_new_button.pressed.connect(_confirm_start_new_stage)

func _apply_realm_visuals() -> void:
	realm_profile = JourneyVisualCatalog.get_chapter_profile(chapter_id)
	if realm_backdrop.has_method("apply_profile"):
		realm_backdrop.call("apply_profile", realm_profile)
	if back_button.has_method("apply_visual_state"):
		back_button.call("apply_visual_state", realm_profile, false, false)
	if start_button.has_method("apply_visual_state"):
		start_button.call("apply_visual_state", realm_profile, true, false)
	realm_epithet_label.text = str(
		realm_profile.get("realm_epithet", "CULTIVATION REALM")
	)

func _build_stage_buttons() -> void:
	stage_buttons.clear()
	stage_views.clear()
	for child: Node in stage_list.get_children():
		child.queue_free()
	var stage_ids: Array = JourneyManager.get_stage_ids(chapter_id)
	for raw_stage_id: Variant in stage_ids:
		var stage_id: int = int(raw_stage_id)
		var card: Button = _create_stage_card(stage_id)
		stage_list.add_child(card)
		stage_buttons[stage_id] = card

func _create_stage_card(stage_id: int) -> Button:
	var button: Button = WuxiaPlaqueButton.new() as Button
	button.custom_minimum_size = Vector2(0.0, 118.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.theme_type_variation = &"JadeStageCard"
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.clip_contents = false
	button.set("plaque_style", 3)
	button.pressed.connect(_on_stage_pressed.bind(stage_id))

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 13)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var index_panel: PanelContainer = PanelContainer.new()
	index_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	index_panel.custom_minimum_size = Vector2(86.0, 72.0)
	index_panel.theme_type_variation = &"JadeRealmSeal"
	row.add_child(index_panel)
	var preview: Control = StageLandmarkPreview.new()
	preview.set("chapter_id", chapter_id)
	preview.set("stage_id", stage_id)
	preview.custom_minimum_size = Vector2(78.0, 66.0)
	index_panel.add_child(preview)

	var index_label: Label = Label.new()
	index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	index_label.theme_type_variation = &"JadeTitle"
	index_label.add_theme_font_size_override("font_size", 10)
	index_label.text = "%d-%d" % [chapter_id, stage_id]
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	index_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	index_panel.add_child(index_label)

	var content: VBoxContainer = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 3)
	row.add_child(content)

	var title: Label = Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.theme_type_variation = &"JadeHeroName"
	title.add_theme_font_size_override("font_size", 17)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)

	var detail: Label = Label.new()
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.theme_type_variation = &"JadeMutedLabel"
	detail.add_theme_font_size_override("font_size", 10)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)

	var badge_panel: PanelContainer = PanelContainer.new()
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.custom_minimum_size = Vector2(78.0, 26.0)
	badge_panel.theme_type_variation = &"JadeJourneyBadge"
	row.add_child(badge_panel)

	var badge: Label = Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size", 9)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_panel.add_child(badge)

	stage_views[stage_id] = {
		"title": title,
		"detail": detail,
		"badge": badge,
		"badge_panel": badge_panel,
		"index_panel": index_panel,
		"index_label": index_label
	}
	return button

func _refresh_screen() -> void:
	var chapter_data: Dictionary = JourneyManager.get_chapter_data(chapter_id)
	if chapter_data.is_empty():
		chapter_label.text = "CHAPTER"
		chapter_name_label.text = "Unavailable"
		selected_realm_label.text = ""
		_disable_all_stages()
		_refresh_selected_stage_panel()
		return
	chapter_label.text = tr("CHAPTER %02d") % chapter_id
	chapter_name_label.text = str(chapter_data.get("display_name", "Unknown Realm"))
	var stage_ids: Array = JourneyManager.get_stage_ids(chapter_id)
	for raw_stage_id: Variant in stage_ids:
		_refresh_stage_card(int(raw_stage_id))
	_ensure_playable_stage_selected()
	_refresh_selected_stage_panel()

func _refresh_stage_card(stage_id: int) -> void:
	var button: Button = _get_stage_button(stage_id)
	if button == null or not stage_views.has(stage_id):
		return
	var view: Dictionary = stage_views[stage_id]
	var title: Label = view.get("title") as Label
	var detail: Label = view.get("detail") as Label
	var badge: Label = view.get("badge") as Label
	var badge_panel: PanelContainer = view.get("badge_panel") as PanelContainer
	var index_panel: PanelContainer = view.get("index_panel") as PanelContainer
	var stage_data: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
	if stage_data.is_empty():
		title.text = tr("Stage %d-%d") % [chapter_id, stage_id]
		detail.text = "Trial data unavailable"
		badge.text = "UNAVAILABLE"
		button.disabled = true
		_apply_stage_badge_color(badge, "UNAVAILABLE")
		_apply_stage_badge_panel(badge_panel, "UNAVAILABLE")
		if button.has_method("set_dimmed_visual"):
			button.call("set_dimmed_visual", true)
		return

	var display_name: String = str(
		stage_data.get(
			"display_name",
			tr("Stage %d-%d") % [chapter_id, stage_id]
		)
	)
	var status: String = _get_stage_status(stage_id)
	var is_boss: bool = bool(stage_data.get("is_chapter_boss", false))
	var is_selected: bool = (
		JourneyManager.selected_chapter_id == chapter_id
		and JourneyManager.selected_stage_id == stage_id
	)
	var is_locked_visual: bool = status == "LOCKED" or status == "COMING SOON"
	title.text = display_name
	detail.text = tr(str(stage_data.get("encounter_hint", ""))) + "\n" + tr(_build_stage_detail(status, is_boss))
	badge.text = "SELECTED" if is_selected else status
	button.disabled = (
		not JourneyManager.is_stage_unlocked(chapter_id, stage_id)
		or not JourneyManager.is_stage_implemented(chapter_id, stage_id)
	)
	var stage_profile: Dictionary = _build_stage_visual_profile(stage_data)
	_apply_stage_plaque(button, is_selected, is_locked_visual, stage_profile)
	_apply_stage_index_palette(index_panel, is_locked_visual, stage_profile)
	_apply_stage_badge_color(badge, badge.text, stage_profile)
	_apply_stage_badge_panel(badge_panel, badge.text, stage_profile)
	button.tooltip_text = (
		"Chapter %d Stage %d — %s\n%s"
	) % [chapter_id, stage_id, display_name, detail.text]

func _build_stage_detail(status: String, is_boss: bool) -> String:
	var default_trial_label: String = str(
		realm_profile.get("trial_label", "CULTIVATION TRIAL")
	)
	var trial_type: String = "CHAPTER BOSS" if is_boss else default_trial_label
	var state_detail: String = "READY"
	if status == "COMING SOON":
		state_detail = "COMING SOON"
	elif status == "LOCKED":
		state_detail = "COMPLETE PRIOR TRIAL"
	elif status == "CLEARED":
		state_detail = "CLEARED • REPLAY AVAILABLE"
	return tr(trial_type) + "   •   " + tr(state_detail)

func _apply_stage_plaque(
	button: Button,
	is_selected: bool,
	is_dimmed: bool,
	stage_profile: Dictionary
) -> void:
	if button.has_method("apply_visual_state"):
		button.call("apply_visual_state", stage_profile, is_selected, is_dimmed)

func _apply_stage_badge_color(
	label: Label,
	status: String,
	visual_profile: Dictionary = {}
) -> void:
	var profile: Dictionary = realm_profile if visual_profile.is_empty() else visual_profile
	var accent: Color = profile.get(
		"accent",
		Color(0.298, 0.82, 0.647, 1.0)
	)
	var gold: Color = profile.get(
		"gold",
		Color(0.957, 0.78, 0.357, 1.0)
	)
	match status:
		"SELECTED":
			label.add_theme_color_override("font_color", gold)
		"AVAILABLE", "CLEARED":
			label.add_theme_color_override("font_color", accent)
		_:
			label.add_theme_color_override(
				"font_color",
				Color(0.502, 0.553, 0.557, 0.9)
			)

func _apply_stage_badge_panel(
	badge_panel: PanelContainer,
	status: String,
	visual_profile: Dictionary = {}
) -> void:
	if badge_panel == null:
		return
	var profile: Dictionary = realm_profile if visual_profile.is_empty() else visual_profile
	var accent: Color = profile.get(
		"accent",
		Color(0.298, 0.82, 0.647, 1.0)
	)
	var gold: Color = profile.get(
		"gold",
		Color(0.957, 0.78, 0.357, 1.0)
	)
	var source: StyleBox = badge_panel.get_theme_stylebox("panel")
	if source is StyleBoxFlat:
		var style: StyleBoxFlat = source.duplicate() as StyleBoxFlat
		match status:
			"SELECTED":
				style.border_color = gold
				style.bg_color = Color(0.12, 0.09, 0.02, 0.82)
			"AVAILABLE", "CLEARED":
				style.border_color = accent
				style.bg_color = Color(0.01, 0.09, 0.08, 0.82)
			_:
				style.border_color = Color(0.35, 0.38, 0.37, 0.48)
				style.bg_color = Color(0.025, 0.035, 0.035, 0.78)
		badge_panel.add_theme_stylebox_override("panel", style)

func _apply_stage_index_palette(
	index_panel: PanelContainer,
	is_dimmed: bool,
	visual_profile: Dictionary = {}
) -> void:
	if index_panel == null:
		return
	var profile: Dictionary = realm_profile if visual_profile.is_empty() else visual_profile
	var accent_soft: Color = profile.get(
		"accent_soft",
		Color(0.184, 0.62, 0.471, 1.0)
	)
	var gold: Color = profile.get(
		"gold",
		Color(0.957, 0.78, 0.357, 1.0)
	)
	var source: StyleBox = index_panel.get_theme_stylebox("panel")
	if source is StyleBoxFlat:
		var style: StyleBoxFlat = source.duplicate() as StyleBoxFlat
		if is_dimmed:
			style.bg_color = Color(0.04, 0.055, 0.055, 0.78)
			style.border_color = Color(0.35, 0.38, 0.37, 0.55)
		else:
			style.bg_color = Color(
				accent_soft.r * 0.22,
				accent_soft.g * 0.22,
				accent_soft.b * 0.22,
				0.96
			)
			style.border_color = gold
		index_panel.add_theme_stylebox_override("panel", style)

## Builds UI-only stage atmosphere directly from the canonical stage palette.
## Gameplay data remains owned by the chapter catalogs/JourneyManager.
func _build_stage_visual_profile(stage_data: Dictionary) -> Dictionary:
	var profile: Dictionary = realm_profile.duplicate(true)
	var accent: Color = stage_data.get(
		"accent",
		profile.get("accent", Color(0.298, 0.82, 0.647, 1.0))
	)
	var ground: Color = stage_data.get(
		"ground",
		Color(0.020, 0.067, 0.061, 1.0)
	)
	var moss: Color = stage_data.get(
		"moss",
		Color(0.041, 0.145, 0.108, 1.0)
	)
	var stone: Color = stage_data.get(
		"stone",
		Color(0.028, 0.087, 0.083, 1.0)
	)
	var stage_mist: Color = stage_data.get(
		"mist",
		Color(0.055, 0.26, 0.19, 1.0)
	)

	profile["accent"] = accent
	profile["accent_soft"] = accent.lerp(moss, 0.45)
	profile["sky_top"] = ground.darkened(0.24)
	profile["sky_bottom"] = ground.lerp(accent, 0.08)
	profile["mountain_far"] = Color(
		stage_mist.r, stage_mist.g, stage_mist.b, 0.72
	)
	profile["mountain_near"] = Color(
		stone.r, stone.g, stone.b, 0.97
	)
	profile["mist"] = Color(
		stage_mist.r, stage_mist.g, stage_mist.b, 0.12
	)
	profile["moon"] = Color(accent.r, accent.g, accent.b, 0.09)

	# The chapter finale intentionally lets its gold-stage accent own the frame.
	if bool(stage_data.get("is_chapter_boss", false)):
		profile["gold"] = accent
	return profile

func _get_stage_status(stage_id: int) -> String:
	if not JourneyManager.is_stage_unlocked(chapter_id, stage_id):
		return "LOCKED"
	if not JourneyManager.is_stage_implemented(chapter_id, stage_id):
		return "COMING SOON"
	if JourneyManager.is_stage_cleared(chapter_id, stage_id):
		return "CLEARED"
	return "AVAILABLE"

func _get_stage_button(stage_id: int) -> Button:
	if not stage_buttons.has(stage_id):
		return null
	return stage_buttons[stage_id] as Button

func _ensure_playable_stage_selected() -> void:
	if (
		JourneyManager.selected_chapter_id == chapter_id
		and JourneyManager.is_stage_unlocked(
			chapter_id,
			JourneyManager.selected_stage_id
		)
		and JourneyManager.is_stage_implemented(
			chapter_id,
			JourneyManager.selected_stage_id
		)
	):
		return
	var stage_ids: Array = JourneyManager.get_stage_ids(chapter_id)
	for raw_stage_id: Variant in stage_ids:
		var stage_id: int = int(raw_stage_id)
		if (
			JourneyManager.is_stage_unlocked(chapter_id, stage_id)
			and JourneyManager.is_stage_implemented(chapter_id, stage_id)
		):
			JourneyManager.select_stage(chapter_id, stage_id)
			return

func _refresh_selected_stage_panel() -> void:
	var stage_id: int = JourneyManager.selected_stage_id
	var stage_data: Dictionary = JourneyManager.get_stage_data(chapter_id, stage_id)
	var chapter_data: Dictionary = JourneyManager.get_chapter_data(chapter_id)
	var can_start: bool = (
		JourneyManager.selected_chapter_id == chapter_id
		and not stage_data.is_empty()
		and JourneyManager.is_stage_unlocked(chapter_id, stage_id)
		and JourneyManager.is_stage_implemented(chapter_id, stage_id)
	)
	if not can_start:
		selected_stage_label.text = "No playable stage selected"
		selected_stage_status_label.text = ""
		selected_realm_label.text = ""
		start_button.disabled = true
		if realm_backdrop.has_method("apply_profile"):
			realm_backdrop.call("apply_profile", realm_profile)
		var realm_gold: Color = realm_profile.get(
			"gold",
			Color(0.957, 0.78, 0.357, 1.0)
		)
		top_accent.color = Color(realm_gold.r, realm_gold.g, realm_gold.b, 0.76)
		if start_button.has_method("set_dimmed_visual"):
			start_button.call("set_dimmed_visual", true)
		return
	selected_stage_label.text = str(
		stage_data.get(
			"display_name",
			tr("Stage %d-%d") % [chapter_id, stage_id]
		)
	)
	selected_stage_status_label.text = _get_stage_status(stage_id)
	var first_clear: bool = not JourneyManager.is_stage_cleared(chapter_id, stage_id)
	var reward: Dictionary = RewardManager.get_stage_clear_reward(chapter_id, stage_id, first_clear)
	selected_realm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_realm_label.text = "%s\n%s: %s" % [
		tr(str(stage_data.get("description", chapter_data.get("display_name", "")))),
		tr("First clear") if first_clear else tr("Replay reward"),
		RewardManager.get_reward_summary(RewardManager.preview_received_reward(reward))
	]
	var selected_profile: Dictionary = _build_stage_visual_profile(stage_data)
	_apply_stage_badge_color(
		selected_stage_status_label,
		selected_stage_status_label.text,
		selected_profile
	)
	if realm_backdrop.has_method("apply_profile"):
		realm_backdrop.call("apply_profile", selected_profile)
	var selected_accent: Color = selected_profile.get(
		"accent",
		Color(0.298, 0.82, 0.647, 1.0)
	)
	top_accent.color = Color(
		selected_accent.r,
		selected_accent.g,
		selected_accent.b,
		0.78
	)
	start_button.disabled = false
	if start_button.has_method("apply_visual_state"):
		start_button.call("apply_visual_state", selected_profile, true, false)

func _on_stage_pressed(stage_id: int) -> void:
	if not JourneyManager.select_stage(chapter_id, stage_id):
		push_warning(
			"StageSelect: Stage %d-%d belum dapat dimainkan."
			% [chapter_id, stage_id]
		)
		_refresh_screen()
		return
	DebugLogger.system(str("Stage dipilih: Chapter ", chapter_id, " Stage ", stage_id))
	_refresh_screen()

func _on_start_pressed() -> void:
	if start_button.disabled:
		return
	if SaveManager.has_save_file("checkpoint"):
		_show_start_confirm_dialog()
		return
	_start_selected_stage()

func _show_start_confirm_dialog() -> void:
	var selected_stage_data: Dictionary = JourneyManager.get_selected_stage_data()
	var display_name: String = str(
		selected_stage_data.get(
			"display_name",
			tr("Stage %d-%d") % [chapter_id, JourneyManager.selected_stage_id]
		)
	)
	confirm_stage_label.text = display_name
	confirm_body_label.text = tr(
		"A saved run already exists. Starting this trial will replace that checkpoint."
	)
	start_confirm_dialog.modulate = Color(1.0, 1.0, 1.0, 0.0)
	start_confirm_dialog.show()
	start_new_button.grab_focus()
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(start_confirm_dialog, "modulate", Color.WHITE, 0.14)

func _hide_start_confirm_dialog() -> void:
	if not start_confirm_dialog.visible:
		return
	start_confirm_dialog.hide()
	start_button.grab_focus()

func _confirm_start_new_stage() -> void:
	_hide_start_confirm_dialog()
	_start_selected_stage()

func _start_selected_stage() -> void:
	if SaveManager.is_progress_read_only():
		return
	var selected_stage_data: Dictionary = JourneyManager.get_selected_stage_data()
	if selected_stage_data.is_empty():
		push_error("StageSelect: data stage terpilih tidak ditemukan.")
		return
	var expected_scene_path: String = str(selected_stage_data.get("scene_path", ""))
	if expected_scene_path.is_empty():
		push_error("StageSelect: stage terpilih belum memiliki scene.")
		return
	if not ResourceLoader.exists(expected_scene_path):
		push_error(
			"StageSelect: scene stage tidak ditemukan: "
			+ expected_scene_path
		)
		return
	if not _delete_checkpoint_if_present():
		return
	GameSession.start_new_game()
	var stage_scene_path: String = JourneyManager.begin_selected_stage()
	if stage_scene_path.is_empty():
		push_error("StageSelect: JourneyManager gagal memulai stage.")
		return
	DebugLogger.system(str(
		"Memulai Chapter ",
		JourneyManager.active_run_chapter_id,
		" Stage ",
		JourneyManager.active_run_stage_id,
		" -> ",
		stage_scene_path
	))
	var change_error: Error = SceneTransitionManager.transition_to(
		stage_scene_path,
		{
			"title": str(selected_stage_data.get("display_name", "Entering the trial")),
			"subtitle": tr("Stage %d-%d") % [
				JourneyManager.active_run_chapter_id,
				JourneyManager.active_run_stage_id
			],
			"minimum_display_time": 0.65
		}
	)
	if change_error != OK:
		JourneyManager.clear_active_run()
		push_error(
			"StageSelect: gagal membuka stage. Error code: "
			+ str(change_error)
		)

func _delete_checkpoint_if_present() -> bool:
	var reset_result: Dictionary = SaveManager.reset_active_run_saves()
	if bool(reset_result.get("success", false)):
		return true
	push_error(
		"StageSelect: gagal membersihkan active-run save: "
		+ str(reset_result.get("failed_domain_ids", []))
	)
	return false

func _disable_all_stages() -> void:
	for button_value: Variant in stage_buttons.values():
		var button: Button = button_value as Button
		if button != null:
			button.disabled = true
			if button.has_method("set_dimmed_visual"):
				button.call("set_dimmed_visual", true)

func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if start_confirm_dialog.visible:
		_hide_start_confirm_dialog()
		return
	_on_back_pressed()

func _on_back_pressed() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_to(
		CHAPTER_SELECT_SCENE,
		{
			"title": "Realm Selection",
			"subtitle": "Choose your cultivation path",
			"minimum_display_time": 0.3
		}
	)
	if change_error != OK:
		push_error(
			"StageSelect: gagal kembali ke Chapter Select. Error code: "
			+ str(change_error)
		)
