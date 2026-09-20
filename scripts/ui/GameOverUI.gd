extends CanvasLayer

## Game Over UI
## Menangani Retry stage yang sama dan kembali ke Main Menu.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const DEFEAT_BACKDROP_ART: String = "res://assets/ui/results/defeat_sanctum.svg"
const DEFEAT_SEAL_ART: String = "res://assets/ui/results/defeat_seal.svg"
const SPIRIT_STONE_ICON: String = "res://assets/ui/icons/spirit_stone.svg"
const EndRunAtmosphereScript = preload("res://scripts/ui/end_run_atmosphere.gd")
const RewardedBridge = preload(
	"res://scripts/monetization/game_over_rewarded_bridge.gd"
)
const RewardedLocalization = preload(
	"res://scripts/monetization/monetization_localization.gd"
)

const DEFEAT_BACKDROP_FADE_DURATION: float = 0.52
const DEFEAT_PANEL_DELAY: float = 0.16
const DEFEAT_PANEL_FADE_DURATION: float = 0.30

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
@onready var content: VBoxContainer = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content
)
@onready var eyebrow_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/Eyebrow
)
@onready var game_over_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/GameOverLabel
)
@onready var reward_panel: PanelContainer = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel
)
@onready var reward_header_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel/RewardMargin/RewardContent/RewardHeader
)
@onready var hint_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/Hint
)

var last_game_over_reward: Dictionary = {}
var intro_tween: Tween = null
var defeat_seal: TextureRect = null
var result_atmosphere: Control = null
var recovery_chip: PanelContainer = null
var revive_button: Button = null
var revive_refresh_left: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	RewardedLocalization.install()
	_apply_premium_visuals()
	retry_button.pressed.connect(_on_retry_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	if not RewardManager.reward_granted.is_connected(_on_reward_granted):
		RewardManager.reward_granted.connect(_on_reward_granted)
	if not MonetizationManager.reward_delivery_finished.is_connected(
		_on_reward_delivery_finished
	):
		MonetizationManager.reward_delivery_finished.connect(
			_on_reward_delivery_finished
		)
	if not MonetizationManager.rewarded_request_finished.is_connected(
		_on_rewarded_request_finished
	):
		MonetizationManager.rewarded_request_finished.connect(
			_on_rewarded_request_finished
		)
	hide()


func _process(delta: float) -> void:
	if not visible or revive_button == null:
		return
	revive_refresh_left -= delta
	if revive_refresh_left > 0.0:
		return
	revive_refresh_left = 0.75
	_refresh_revive_button()


func show_game_over() -> void:
	last_game_over_reward.clear()
	_refresh_stage_identity()
	_refresh_reward_summary()
	_refresh_revive_button()
	retry_button.disabled = SaveManager.is_progress_read_only()
	if retry_button.disabled:
		reward_summary_label.visible = true
		if recovery_chip != null:
			recovery_chip.visible = false
		reward_summary_label.text = tr(
			"A save needs recovery. Close and reopen the game before continuing."
		)

	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()

	defeat_backdrop.modulate.a = 0.0
	defeat_panel.modulate.a = 0.0
	wave_label.modulate.a = 0.0
	reward_panel.modulate.a = 0.0
	if revive_button != null:
		revive_button.modulate.a = 0.0
	retry_button.modulate.a = 0.0
	main_menu_button.modulate.a = 0.0

	if defeat_seal != null:
		defeat_seal.modulate.a = 0.0
		defeat_seal.scale = (
			Vector2.ONE
			if SettingsManager.reduced_effects
			else Vector2.ONE * 0.80
		)

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

	if defeat_seal != null:
		intro_tween.tween_property(
			defeat_seal,
			"modulate:a",
			1.0,
			0.24
		).set_delay(0.20)
		if not SettingsManager.reduced_effects:
			intro_tween.tween_property(
				defeat_seal,
				"scale",
				Vector2.ONE,
				0.30
			).set_delay(0.20).set_trans(
				Tween.TRANS_QUAD
			).set_ease(Tween.EASE_OUT)

	intro_tween.tween_property(
		wave_label,
		"modulate:a",
		1.0,
		0.22
	).set_delay(0.28)
	intro_tween.tween_property(
		reward_panel,
		"modulate:a",
		1.0,
		0.24
	).set_delay(0.34)
	if revive_button != null:
		intro_tween.tween_property(
			revive_button,
			"modulate:a",
			1.0,
			0.22
		).set_delay(0.42)
	intro_tween.tween_property(
		retry_button,
		"modulate:a",
		1.0,
		0.22
	).set_delay(0.47)
	intro_tween.tween_property(
		main_menu_button,
		"modulate:a",
		1.0,
		0.22
	).set_delay(0.52)


func _on_reward_granted(
	source_type: String,
	source_id: String,
	reward_data: Dictionary
) -> void:
	if source_type != RewardManager.SOURCE_GAME_OVER:
		return
	last_game_over_reward = {
		"source_id": source_id,
		"reward_data": RewardManager.get_last_grant_result().get(
			"applied_reward_data",
			reward_data
		).duplicate(true)
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
	if reward_data.is_empty():
		reward_data = RewardManager.get_game_over_reward(reached_wave)
	wave_label.text = tr("WAVE %d REACHED") % reached_wave
	reward_header_label.text = (
		tr("RECOVERY IF RUN ENDS")
		if last_game_over_reward.is_empty()
		else tr("REWARD RECOVERED")
	)
	reward_summary_label.text = RewardManager.get_reward_summary(
		reward_data,
		"No Reward Recovered"
	)
	_refresh_recovery_chip(reward_data)
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

func _apply_premium_visuals() -> void:
	defeat_backdrop.color = Color(0.016, 0.006, 0.018, 0.965)
	_ensure_backdrop_art()
	_ensure_atmosphere()
	_ensure_result_seal()
	_ensure_recovery_chip()
	_ensure_revive_button()

	defeat_panel.custom_minimum_size = Vector2(530.0, 780.0)
	defeat_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.055, 0.020, 0.035, 0.95),
			Color(0.74, 0.35, 0.30, 0.92),
			24,
			2
		)
	)

	var margin: MarginContainer = (
		$ColorRect/SafeArea/CenterContainer/Panel/Margin
	)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	content.add_theme_constant_override("separation", 12)

	eyebrow_label.text = tr("DAO HEART SHAKEN • REVIVE WINDOW")
	eyebrow_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.48, 0.40, 1.0)
	)
	eyebrow_label.add_theme_font_size_override("font_size", 13)

	game_over_label.text = tr("FALLEN IN BATTLE")
	game_over_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.79, 0.50, 1.0)
	)
	game_over_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.72)
	)
	game_over_label.add_theme_constant_override("shadow_offset_x", 0)
	game_over_label.add_theme_constant_override("shadow_offset_y", 3)
	game_over_label.add_theme_font_size_override("font_size", 35)

	stage_label.add_theme_color_override(
		"font_color",
		Color(0.87, 0.89, 0.89, 1.0)
	)
	stage_label.add_theme_font_size_override("font_size", 14)
	wave_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.76, 0.35, 1.0)
	)
	wave_label.add_theme_font_size_override("font_size", 20)
	wave_label.custom_minimum_size = Vector2(0.0, 42.0)
	wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_label.add_theme_stylebox_override(
		"normal",
		_make_pill_style(
			Color(0.115, 0.055, 0.035, 0.92),
			Color(0.94, 0.58, 0.31, 0.70)
		)
	)

	reward_panel.custom_minimum_size = Vector2(0.0, 150.0)
	reward_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.070, 0.025, 0.038, 0.94),
			Color(0.71, 0.31, 0.28, 0.76),
			16,
			1
		)
	)
	reward_header_label.text = tr("REWARD RECOVERED")
	reward_header_label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.52, 0.40, 1.0)
	)
	reward_header_label.add_theme_font_size_override("font_size", 12)
	reward_summary_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.92, 0.72, 1.0)
	)
	reward_summary_label.add_theme_font_size_override("font_size", 18)
	balance_label.add_theme_color_override(
		"font_color",
		Color(0.69, 0.72, 0.72, 1.0)
	)
	balance_label.add_theme_font_size_override("font_size", 12)

	retry_button.text = tr("REKINDLE • RETRY")
	retry_button.custom_minimum_size = Vector2(0.0, 66.0)
	retry_button.add_theme_font_size_override("font_size", 18)
	retry_button.add_theme_color_override(
		"font_color",
		Color(0.025, 0.085, 0.070, 1.0)
	)
	retry_button.add_theme_color_override(
		"font_hover_color",
		Color(0.015, 0.065, 0.055, 1.0)
	)
	retry_button.add_theme_color_override(
		"font_disabled_color",
		Color(0.48, 0.49, 0.48, 1.0)
	)
	retry_button.add_theme_stylebox_override(
		"normal",
		_make_button_style(
			Color(0.83, 0.67, 0.30, 1.0),
			Color(0.97, 0.83, 0.48, 1.0),
			16
		)
	)
	retry_button.add_theme_stylebox_override(
		"hover",
		_make_button_style(
			Color(0.94, 0.78, 0.38, 1.0),
			Color(1.0, 0.92, 0.65, 1.0),
			16
		)
	)
	retry_button.add_theme_stylebox_override(
		"pressed",
		_make_button_style(
			Color(0.70, 0.53, 0.22, 1.0),
			Color(0.90, 0.70, 0.32, 1.0),
			16
		)
	)
	retry_button.add_theme_stylebox_override(
		"focus",
		_make_button_style(
			Color(0.83, 0.67, 0.30, 1.0),
			Color(0.35, 0.90, 0.72, 1.0),
			16,
			2
		)
	)
	retry_button.add_theme_stylebox_override(
		"disabled",
		_make_button_style(
			Color(0.15, 0.15, 0.15, 0.92),
			Color(0.34, 0.34, 0.34, 0.90),
			16
		)
	)

	main_menu_button.text = tr("RETURN HOME")
	main_menu_button.custom_minimum_size = Vector2(0.0, 58.0)
	main_menu_button.add_theme_font_size_override("font_size", 16)
	main_menu_button.add_theme_color_override(
		"font_color",
		Color(0.87, 0.93, 0.91, 1.0)
	)
	main_menu_button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.88, 0.62, 1.0)
	)
	main_menu_button.add_theme_stylebox_override(
		"normal",
		_make_button_style(
			Color(0.055, 0.075, 0.085, 0.94),
			Color(0.30, 0.48, 0.49, 0.78),
			15
		)
	)
	main_menu_button.add_theme_stylebox_override(
		"hover",
		_make_button_style(
			Color(0.075, 0.105, 0.110, 0.98),
			Color(0.48, 0.74, 0.67, 0.90),
			15
		)
	)
	main_menu_button.add_theme_stylebox_override(
		"pressed",
		_make_button_style(
			Color(0.035, 0.055, 0.065, 0.98),
			Color(0.38, 0.59, 0.57, 0.88),
			15
		)
	)
	main_menu_button.add_theme_stylebox_override(
		"focus",
		_make_button_style(
			Color(0.055, 0.075, 0.085, 0.94),
			Color(0.90, 0.66, 0.33, 0.95),
			15,
			2
		)
	)

	hint_label.text = tr(
		"Revive keeps this run. Retry starts the stage over. Return Home ends the run."
	)
	hint_label.add_theme_color_override(
		"font_color",
		Color(0.68, 0.73, 0.73, 1.0)
	)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _ensure_revive_button() -> void:
	if revive_button != null and is_instance_valid(revive_button):
		return
	revive_button = Button.new()
	revive_button.name = "RewardedReviveButton"
	revive_button.custom_minimum_size = Vector2(0.0, 64.0)
	revive_button.focus_mode = Control.FOCUS_ALL
	revive_button.text = tr("REVIVE • WATCH AD")
	revive_button.add_theme_font_size_override("font_size", 17)
	revive_button.add_theme_color_override(
		"font_color",
		Color(0.95, 1.0, 0.82, 1.0)
	)
	revive_button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.94, 0.62, 1.0)
	)
	revive_button.add_theme_color_override(
		"font_disabled_color",
		Color(0.48, 0.54, 0.52, 1.0)
	)
	revive_button.add_theme_stylebox_override(
		"normal",
		_make_button_style(
			Color(0.030, 0.18, 0.14, 0.98),
			Color(0.35, 0.92, 0.72, 0.92),
			16,
			2
		)
	)
	revive_button.add_theme_stylebox_override(
		"hover",
		_make_button_style(
			Color(0.045, 0.24, 0.18, 1.0),
			Color(0.96, 0.76, 0.34, 1.0),
			16,
			2
		)
	)
	revive_button.add_theme_stylebox_override(
		"pressed",
		_make_button_style(
			Color(0.020, 0.13, 0.11, 1.0),
			Color(0.75, 0.56, 0.25, 1.0),
			16,
			2
		)
	)
	revive_button.add_theme_stylebox_override(
		"focus",
		_make_button_style(
			Color(0.030, 0.18, 0.14, 0.98),
			Color(1.0, 0.84, 0.42, 1.0),
			16,
			2
		)
	)
	revive_button.add_theme_stylebox_override(
		"disabled",
		_make_button_style(
			Color(0.055, 0.070, 0.072, 0.94),
			Color(0.28, 0.35, 0.34, 0.80),
			16
		)
	)
	revive_button.pressed.connect(_on_revive_pressed)
	content.add_child(revive_button)
	content.move_child(
		revive_button,
		retry_button.get_index()
	)


func _refresh_revive_button() -> void:
	if revive_button == null or not is_instance_valid(revive_button):
		return
	var game_over_manager: Node = get_parent().get_node_or_null(
		"GameOverManager"
	)
	if game_over_manager == null:
		revive_button.disabled = true
		revive_button.text = tr("REVIVE UNAVAILABLE")
		return

	if bool(game_over_manager.call("has_rewarded_revive_been_used")):
		revive_button.disabled = true
		revive_button.text = tr("REVIVE USED")
		return

	if SaveManager.is_progress_read_only():
		revive_button.disabled = true
		revive_button.text = tr("REVIVE UNAVAILABLE")
		return

	if MonetizationManager.is_rewarded_request_active(
		RewardedBridge.PLACEMENT_ID
	):
		revive_button.disabled = true
		revive_button.text = tr("REVIVING...")
		return

	var policy: Dictionary = MonetizationManager.get_rewarded_policy_status(
		RewardedBridge.PLACEMENT_ID
	)
	if bool(policy.get("available", false)):
		revive_button.disabled = false
		revive_button.text = tr("REVIVE • WATCH AD")
		return

	revive_button.disabled = true
	var runtime: Dictionary = MonetizationManager.get_provider_runtime_status()
	var provider_state: String = str(runtime.get("state", ""))
	if provider_state in [
		"consent_updating",
		"consent_form_loading",
		"consent_form_showing",
		"ads_initializing",
		"ads_initialized",
		"rewarded_loading",
	]:
		revive_button.text = tr("REVIVE • PREPARING")
	else:
		revive_button.text = tr("REVIVE UNAVAILABLE")


func _on_revive_pressed() -> void:
	var game_over_manager: Node = get_parent().get_node_or_null(
		"GameOverManager"
	)
	if (
		game_over_manager == null
		or not bool(game_over_manager.call("prepare_rewarded_revive"))
	):
		hint_label.text = tr("Rewarded revive is not available for this run.")
		_refresh_revive_button()
		return

	if not MonetizationManager.show_rewarded(
		RewardedBridge.PLACEMENT_ID
	):
		game_over_manager.call("cancel_pending_rewarded_revive")
		hint_label.text = tr("Rewarded ad unavailable. Try again shortly.")
		_refresh_revive_button()
		return

	hint_label.text = tr(
		"Watch the optional ad to revive at 60% HP with brief protection."
	)
	_refresh_revive_button()


func _on_reward_delivery_finished(
	placement: String,
	success: bool,
	_amount: int,
	message: String
) -> void:
	if placement != RewardedBridge.PLACEMENT_ID:
		return
	if success:
		return
	hint_label.text = (
		message
		if not message.is_empty()
		else tr("Rewarded revive failed. You can still Retry or Return Home.")
	)
	_refresh_revive_button()


func _on_rewarded_request_finished(
	placement: String,
	status: String
) -> void:
	if placement != RewardedBridge.PLACEMENT_ID:
		return
	if status != "completed":
		var game_over_manager: Node = get_parent().get_node_or_null(
			"GameOverManager"
		)
		if game_over_manager != null:
			game_over_manager.call("cancel_pending_rewarded_revive")
		hint_label.text = (
			tr("Ad closed before revive. Retry and Return Home remain available.")
			if status == "cancelled"
			else tr("Rewarded ad unavailable. Try again shortly.")
		)
	_refresh_revive_button()


func hide_after_revive() -> void:
	_reset_intro_visual_state()
	last_game_over_reward.clear()
	hide()


func _ensure_backdrop_art() -> void:
	if defeat_backdrop.has_node("ResultBackdropArt"):
		return
	var texture: Texture2D = load(DEFEAT_BACKDROP_ART) as Texture2D
	if texture == null:
		push_warning("GameOverUI: artwork kekalahan tidak dapat dimuat.")
		return
	var backdrop_art := TextureRect.new()
	backdrop_art.name = "ResultBackdropArt"
	backdrop_art.texture = texture
	backdrop_art.anchor_left = 0.0
	backdrop_art.anchor_top = 0.0
	backdrop_art.anchor_right = 1.0
	backdrop_art.anchor_bottom = 1.0
	backdrop_art.offset_left = 0.0
	backdrop_art.offset_top = 0.0
	backdrop_art.offset_right = 0.0
	backdrop_art.offset_bottom = 0.0
	backdrop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop_art.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_art.modulate = Color(1.0, 1.0, 1.0, 0.94)
	defeat_backdrop.add_child(backdrop_art)
	defeat_backdrop.move_child(backdrop_art, 0)


func _ensure_atmosphere() -> void:
	if defeat_backdrop.has_node("EndRunAtmosphere"):
		result_atmosphere = (
			defeat_backdrop.get_node("EndRunAtmosphere")
			as Control
		)
		return

	result_atmosphere = EndRunAtmosphereScript.new() as Control
	if result_atmosphere == null:
		return

	result_atmosphere.name = "EndRunAtmosphere"
	result_atmosphere.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	result_atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_atmosphere.call("configure", "defeat")
	defeat_backdrop.add_child(result_atmosphere)
	defeat_backdrop.move_child(
		result_atmosphere,
		mini(1, defeat_backdrop.get_child_count() - 1)
	)


func _ensure_result_seal() -> void:
	if content.has_node("DefeatSeal"):
		defeat_seal = content.get_node("DefeatSeal") as TextureRect
		return

	var texture: Texture2D = load(DEFEAT_SEAL_ART) as Texture2D
	if texture == null:
		push_warning("GameOverUI: segel kekalahan tidak dapat dimuat.")
		return

	defeat_seal = TextureRect.new()
	defeat_seal.name = "DefeatSeal"
	defeat_seal.texture = texture
	defeat_seal.custom_minimum_size = Vector2(108.0, 108.0)
	defeat_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	defeat_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	defeat_seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	defeat_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defeat_seal.pivot_offset = Vector2(54.0, 54.0)
	content.add_child(defeat_seal)
	content.move_child(defeat_seal, 1)


func _ensure_recovery_chip() -> void:
	if recovery_chip != null:
		return

	var reward_content: VBoxContainer = (
		$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel/RewardMargin/RewardContent
	)

	if reward_content.has_node("RecoveryChip"):
		recovery_chip = reward_content.get_node("RecoveryChip") as PanelContainer
		return

	recovery_chip = PanelContainer.new()
	recovery_chip.name = "RecoveryChip"
	recovery_chip.custom_minimum_size = Vector2(0.0, 64.0)
	reward_content.add_child(recovery_chip)
	reward_content.move_child(recovery_chip, 1)


func _refresh_recovery_chip(reward_data: Dictionary) -> void:
	_ensure_recovery_chip()
	if recovery_chip == null:
		return

	for child: Node in recovery_chip.get_children():
		child.queue_free()

	var stone_amount: int = int(
		reward_data.get(
			RewardManager.REWARD_KEY_SPIRIT_STONE,
			0
		)
	)

	var has_reward: bool = stone_amount > 0
	var accent := (
		Color(0.96, 0.70, 0.31, 1.0)
		if has_reward
		else Color(0.58, 0.62, 0.62, 1.0)
	)
	recovery_chip.add_theme_stylebox_override(
		"panel",
		_make_recovery_style(accent, has_reward)
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	recovery_chip.add_child(row)

	if has_reward and ResourceLoader.exists(SPIRIT_STONE_ICON):
		var texture := load(SPIRIT_STONE_ICON) as Texture2D
		if texture != null:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(34.0, 34.0)
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", -1)
	row.add_child(copy)

	var value_label := Label.new()
	value_label.text = (
		"+%s SPIRIT STONE" % _format_number(stone_amount)
		if has_reward
		else tr("No Reward Recovered")
	)
	value_label.theme_type_variation = &"JadeHeroName"
	value_label.add_theme_font_size_override(
		"font_size",
		17 if has_reward else 15
	)
	value_label.add_theme_color_override("font_color", accent)
	copy.add_child(value_label)

	var caption_label := Label.new()
	caption_label.text = (
		tr("RECOVERY PREVIEW")
		if last_game_over_reward.is_empty() and has_reward
		else (
			tr("REWARD RECOVERED")
			if has_reward
			else tr("DAO ESSENCE COULD NOT BE RECOVERED")
		)
	)
	caption_label.theme_type_variation = &"JadeMutedLabel"
	caption_label.add_theme_font_size_override("font_size", 10)
	caption_label.add_theme_color_override(
		"font_color",
		Color(0.70, 0.74, 0.74, 0.96)
	)
	copy.add_child(caption_label)

	reward_summary_label.visible = false


func _make_recovery_style(
	accent: Color,
	has_reward: bool
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.095, 0.055, 0.035, 0.94)
		if has_reward
		else Color(0.035, 0.042, 0.045, 0.94)
	)
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.58
	)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style


func _make_pill_style(
	background: Color,
	border: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 13
	style.corner_radius_top_right = 13
	style.corner_radius_bottom_left = 13
	style.corner_radius_bottom_right = 13
	style.content_margin_left = 12.0
	style.content_margin_top = 5.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 5.0
	return style


func _make_panel_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0.0, 9.0)
	return style

func _make_button_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int = 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18.0
	style.content_margin_top = 10.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 3.0)
	return style

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
	wave_label.modulate.a = 1.0
	reward_panel.modulate.a = 1.0
	if revive_button != null:
		revive_button.modulate.a = 1.0
	retry_button.modulate.a = 1.0
	main_menu_button.modulate.a = 1.0
	if defeat_seal != null:
		defeat_seal.modulate.a = 1.0
		defeat_seal.scale = Vector2.ONE

func _on_retry_pressed() -> void:
	if SaveManager.is_progress_read_only():
		return
	if SceneTransitionManager.is_transitioning:
		return
	_reset_intro_visual_state()
	var game_over_manager: Node = get_parent().get_node_or_null("GameOverManager")
	if (
		game_over_manager == null
		or not bool(game_over_manager.call("finalize_defeat"))
	):
		hint_label.text = tr(
			"Run end could not be saved. Please try again."
		)
		return
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
	var game_over_manager: Node = get_parent().get_node_or_null("GameOverManager")
	if (
		game_over_manager == null
		or not bool(game_over_manager.call("finalize_defeat"))
	):
		hint_label.text = tr(
			"Run end could not be saved. Please try again."
		)
		return
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
