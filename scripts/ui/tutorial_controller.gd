extends Control

## Contextual First-Run Tutorial
## Mengajarkan loop inti melalui aksi runtime nyata tanpa mengubah combat logic.
## Setiap guidance prompt bersifat modal singkat: battlefield dipause sampai pemain
## mengonfirmasi, lalu aksi gameplay kembali berjalan.
## Completion disimpan terpisah dari gameplay save domains di user://tutorial.cfg.
## Interactive guidance hanya presentation-layer: pointer, pulse, dan target hint
## tidak mengubah input, combat, progression, save domain, atau gameplay authority.

const SAVE_PATH: String = "user://tutorial.cfg"
const SAVE_VERSION: int = 1
const TARGET_CHAPTER_ID: int = 1
const TARGET_STAGE_ID: int = 1
const MOVE_DISTANCE_REQUIRED: float = 72.0
const MIN_STEP_DISPLAY_TIME: float = 1.25

const GUIDANCE_RING_SIZE: float = 78.0
const GUIDANCE_ARROW_SIZE: Vector2 = Vector2(52.0, 46.0)
const GUIDANCE_HINT_SIZE: Vector2 = Vector2(250.0, 38.0)
const GUIDANCE_EDGE_MARGIN: float = 30.0
const GUIDANCE_TARGET_GAP: float = 16.0
const GUIDANCE_BOB_DISTANCE: float = 6.0
const GUIDANCE_PULSE_SCALE: float = 0.055
const GUIDANCE_JADE: Color = Color(0.20, 0.94, 0.78, 1.0)
const GUIDANCE_GOLD: Color = Color(1.0, 0.80, 0.30, 1.0)
const GUIDANCE_DARK: Color = Color(0.002, 0.026, 0.035, 0.96)

enum TutorialStep {
	MOVE,
	AUTO_ARTS,
	GATHER_QI,
	BREAKTHROUGH,
	ASCENSION,
	COMPLETE
}

@onready var tutorial_panel: PanelContainer = %TutorialPanel
@onready var step_label: Label = %TutorialStepLabel
@onready var title_label: Label = %TutorialTitleLabel
@onready var body_label: Label = %TutorialBodyLabel
@onready var status_label: Label = %TutorialStatusLabel
@onready var continue_button: Button = %TutorialContinueButton
@onready var skip_button: Button = %TutorialSkipButton

var player: Node2D = null
var enemy_spawner: Node = null
var level_up_panel: Control = null
var pause_overlay: Control = null
var game_over_ui: CanvasLayer = null
var victory_ui: CanvasLayer = null
var virtual_joystick: Control = null
var exp_bar: Control = null

var current_step: int = TutorialStep.MOVE
var start_player_position: Vector2 = Vector2.ZERO
var initial_player_level: int = 1
var initial_experience: int = 0
var observed_kills: int = 0
var step_elapsed: float = 0.0
var breakthrough_panel_seen: bool = false
var tutorial_active: bool = false
var prompt_waiting: bool = false
var prompt_presented: bool = false
var tutorial_owns_pause: bool = false

var guidance_root: Control = null
var guidance_ring: PanelContainer = null
var guidance_arrow: Label = null
var guidance_hint_panel: PanelContainer = null
var guidance_hint_label: Label = null
var guidance_phase: float = 0.0
var guidance_last_target_key: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tutorial_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interactive_guidance()

	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)

	if not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)

	call_deferred("_initialize_tutorial")

func _initialize_tutorial() -> void:
	if _is_tutorial_completed():
		_hide_interactive_guidance()
		set_process(false)
		return

	if not _is_target_stage():
		_hide_interactive_guidance()
		set_process(false)
		return

	# SceneTransitionManager menahan SceneTree dalam keadaan paused sampai
	# Celestial Gate selesai. Tutorial harus menunggu signal completion supaya
	# pause milik tutorial tidak ditimpa oleh transition manager.
	if SceneTransitionManager.is_transitioning:
		var transition_callable: Callable = Callable(
			self,
			"_on_scene_transition_completed"
		)
		if not SceneTransitionManager.transition_completed.is_connected(
			transition_callable
		):
			SceneTransitionManager.transition_completed.connect(
				transition_callable
			)
		return

	_start_tutorial_runtime()

func _on_scene_transition_completed(_scene_path: String) -> void:
	var transition_callable: Callable = Callable(
		self,
		"_on_scene_transition_completed"
	)
	if SceneTransitionManager.transition_completed.is_connected(
		transition_callable
	):
		SceneTransitionManager.transition_completed.disconnect(
			transition_callable
		)

	_start_tutorial_runtime()

func _start_tutorial_runtime() -> void:
	if tutorial_active:
		return

	if _is_tutorial_completed() or not _is_target_stage():
		_hide_interactive_guidance()
		set_process(false)
		return

	player = get_tree().get_first_node_in_group("player") as Node2D

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		_hide_interactive_guidance()
		set_process(false)
		return

	enemy_spawner = scene_root.get_node_or_null("EnemySpawner")
	level_up_panel = scene_root.get_node_or_null("HUD/LevelUpPanel") as Control
	pause_overlay = scene_root.get_node_or_null(
		"HUD/ScreenRoot/PauseOverlay"
	) as Control
	game_over_ui = scene_root.get_node_or_null("GameOverUI") as CanvasLayer
	victory_ui = scene_root.get_node_or_null("VictoryUI") as CanvasLayer
	virtual_joystick = scene_root.get_node_or_null(
		"HUD/ScreenRoot/HUDSafeArea/VirtualJoystick"
	) as Control
	exp_bar = scene_root.get_node_or_null(
		"HUD/ScreenRoot/HUDSafeArea/TopHUD/Margin/Content/StatusRow/EXPGroup/EXPBar"
	) as Control

	if player == null:
		push_warning("Tutorial: Player tidak ditemukan. Guidance dinonaktifkan.")
		_hide_interactive_guidance()
		set_process(false)
		return

	start_player_position = player.global_position
	initial_player_level = _read_player_level()
	initial_experience = _read_player_experience()

	if enemy_spawner != null and enemy_spawner.has_signal("enemy_killed"):
		var kill_callable: Callable = Callable(self, "_on_enemy_killed")
		if not enemy_spawner.is_connected("enemy_killed", kill_callable):
			enemy_spawner.connect("enemy_killed", kill_callable)

	tutorial_active = true
	_set_step(TutorialStep.MOVE)
	DebugLogger.system(str("Contextual Tutorial aktif! Stage 1-1 guidance dimulai."))

func _process(delta: float) -> void:
	if not tutorial_active:
		_hide_interactive_guidance()
		return

	if level_up_panel != null and level_up_panel.visible:
		breakthrough_panel_seen = true

	if prompt_waiting:
		_try_present_pending_prompt()
		_update_interactive_guidance(delta)
		return

	if _is_presentationally_blocked():
		tutorial_panel.visible = false
		_update_interactive_guidance(delta)
		return

	# Saat objective sedang dimainkan, card guidance disembunyikan agar
	# battlefield tetap bersih dan input touch tidak tertutup. Pointer interaktif
	# tetap boleh tampil karena seluruh visual memakai MOUSE_FILTER_IGNORE.
	tutorial_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_elapsed += delta
	_update_interactive_guidance(delta)

	match current_step:
		TutorialStep.MOVE:
			_update_move_step()

		TutorialStep.AUTO_ARTS:
			if (
				observed_kills > 0
				and step_elapsed >= MIN_STEP_DISPLAY_TIME
			):
				_set_step(TutorialStep.GATHER_QI)

		TutorialStep.GATHER_QI:
			var gained_experience: bool = (
				_read_player_experience() > initial_experience
				or _read_player_level() > initial_player_level
			)

			if gained_experience and step_elapsed >= MIN_STEP_DISPLAY_TIME:
				_set_step(TutorialStep.BREAKTHROUGH)

		TutorialStep.BREAKTHROUGH:
			if (
				breakthrough_panel_seen
				and level_up_panel != null
				and not level_up_panel.visible
				and _read_player_level() > initial_player_level
			):
				_set_step(TutorialStep.ASCENSION)

		TutorialStep.ASCENSION:
			return

		TutorialStep.COMPLETE:
			return

func _unhandled_input(event: InputEvent) -> void:
	if not tutorial_active or not prompt_waiting:
		return

	if event.is_action_pressed("ui_accept"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()
		return

	# Jangan izinkan Android Back / Esc membuka Pause di belakang prompt modal.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func _update_move_step() -> void:
	if player == null:
		return

	var traveled_distance: float = player.global_position.distance_to(
		start_player_position
	)

	if (
		traveled_distance >= MOVE_DISTANCE_REQUIRED
		and step_elapsed >= 0.5
	):
		_set_step(TutorialStep.AUTO_ARTS)

func _set_step(next_step: int) -> void:
	current_step = next_step
	step_elapsed = 0.0
	prompt_waiting = false
	prompt_presented = false
	guidance_last_target_key = ""

	match current_step:
		TutorialStep.MOVE:
			_set_copy(
				"DAO GUIDANCE  •  1 / 5",
				"FLOWING STEPS",
				"Move Lin Yue to attune with the battlefield. Staying mobile is your first defense.",
				"OBJECTIVE • MOVE TO CONTINUE"
			)

		TutorialStep.AUTO_ARTS:
			_set_copy(
				"DAO GUIDANCE  •  2 / 5",
				"SELF-MOVING ARTS",
				"Your equipped weapons strike automatically. Focus on positioning while Spirit Sword hunts nearby enemies.",
				"OBJECTIVE • DEFEAT 1 ENEMY"
			)

		TutorialStep.GATHER_QI:
			_set_copy(
				"DAO GUIDANCE  •  3 / 5",
				"ABSORB SPIRIT ESSENCE",
				"Collect essence from fallen enemies. Spirit essence fills EXP and drives your next breakthrough.",
				"OBJECTIVE • GAIN EXP"
			)

		TutorialStep.BREAKTHROUGH:
			_set_copy(
				"DAO GUIDANCE  •  4 / 5",
				"BREAKTHROUGH",
				"When EXP is full, time seals itself. Choose one cultivation path to shape this run, then return to battle.",
				"OBJECTIVE • REACH YOUR FIRST BREAKTHROUGH"
			)

		TutorialStep.ASCENSION:
			_set_copy(
				"DAO GUIDANCE  •  5 / 5",
				"ASCENSION TRIAL",
				"Foundation forged. Survive the rising waves, refine your build, and defeat the stage guardian.",
				"DAO GUIDANCE COMPLETE"
			)

		TutorialStep.COMPLETE:
			tutorial_panel.visible = false
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hide_interactive_guidance()
			return

	prompt_waiting = true
	_try_present_pending_prompt()

func _set_copy(
	eyebrow_text: String,
	title_text: String,
	body_text: String,
	status_text: String
) -> void:
	step_label.text = tr(eyebrow_text)
	title_label.text = tr(title_text)
	body_label.text = tr(body_text)
	status_label.text = tr(status_text)
	continue_button.text = tr(_get_continue_button_text())

func _try_present_pending_prompt() -> void:
	if not prompt_waiting or prompt_presented:
		return

	if _is_presentationally_blocked():
		tutorial_panel.visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	prompt_presented = true
	tutorial_panel.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_claim_pause_for_prompt()

func _claim_pause_for_prompt() -> void:
	if get_tree().paused:
		tutorial_owns_pause = false
		return

	get_tree().paused = true
	tutorial_owns_pause = true

func _release_tutorial_pause() -> void:
	if not tutorial_owns_pause:
		return

	get_tree().paused = false
	tutorial_owns_pause = false

func _get_continue_button_text() -> String:
	match current_step:
		TutorialStep.MOVE:
			return "BEGIN TRIAL"
		TutorialStep.ASCENSION:
			return "ENTER THE TRIAL"
		_:
			return "CONTINUE"

func _on_continue_pressed() -> void:
	if not tutorial_active or not prompt_waiting:
		return

	prompt_waiting = false
	prompt_presented = false
	tutorial_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_elapsed = 0.0
	guidance_last_target_key = ""

	if current_step == TutorialStep.ASCENSION:
		_complete_tutorial(false)
		return

	_release_tutorial_pause()

func _on_enemy_killed() -> void:
	observed_kills += 1

func _on_skip_pressed() -> void:
	_complete_tutorial(true)

func _complete_tutorial(was_skipped: bool) -> void:
	if not tutorial_active:
		return

	prompt_waiting = false
	prompt_presented = false
	current_step = TutorialStep.COMPLETE
	tutorial_active = false
	tutorial_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_interactive_guidance()
	_release_tutorial_pause()
	_save_tutorial_completed()
	set_process(false)

	if was_skipped:
		DebugLogger.system(str("Contextual Tutorial dilewati dan ditandai selesai."))
	else:
		DebugLogger.system(str("Contextual Tutorial selesai!"))

func _is_target_stage() -> bool:
	if JourneyManager.has_active_run():
		return (
			JourneyManager.active_run_chapter_id == TARGET_CHAPTER_ID
			and JourneyManager.active_run_stage_id == TARGET_STAGE_ID
		)

	# Memungkinkan direct scene testing di editor selama Stage 1-1 dipilih.
	return (
		JourneyManager.selected_chapter_id == TARGET_CHAPTER_ID
		and JourneyManager.selected_stage_id == TARGET_STAGE_ID
	)

func _is_presentationally_blocked() -> bool:
	if level_up_panel != null and level_up_panel.visible:
		return true

	if pause_overlay != null and pause_overlay.visible:
		return true

	if game_over_ui != null and game_over_ui.visible:
		return true

	if victory_ui != null and victory_ui.visible:
		return true

	return false

func _read_player_level() -> int:
	if player == null:
		return 1

	return int(player.get("level"))

func _read_player_experience() -> int:
	if player == null:
		return 0

	return int(player.get("experience"))

func _is_tutorial_completed() -> bool:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(SAVE_PATH)

	if load_error != OK:
		return false

	return bool(
		config.get_value(
			"tutorial",
			"completed",
			false
		)
	)

func _save_tutorial_completed() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("tutorial", "version", SAVE_VERSION)
	config.set_value("tutorial", "completed", true)

	var save_error: Error = config.save(SAVE_PATH)
	if save_error != OK:
		push_warning(
			"Tutorial: gagal menyimpan completion state ke %s"
			% SAVE_PATH
		)

func _build_interactive_guidance() -> void:
	guidance_root = Control.new()
	guidance_root.name = "InteractiveGuidance"
	guidance_root.process_mode = Node.PROCESS_MODE_ALWAYS
	guidance_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guidance_root.z_index = 80
	add_child(guidance_root)
	guidance_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	guidance_ring = PanelContainer.new()
	guidance_ring.name = "TargetRing"
	guidance_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guidance_ring.size = Vector2(GUIDANCE_RING_SIZE, GUIDANCE_RING_SIZE)
	guidance_ring.pivot_offset = guidance_ring.size * 0.5
	guidance_ring.add_theme_stylebox_override(
		"panel",
		_make_guidance_ring_style()
	)
	guidance_root.add_child(guidance_ring)

	guidance_arrow = Label.new()
	guidance_arrow.name = "GuidanceArrow"
	guidance_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guidance_arrow.size = GUIDANCE_ARROW_SIZE
	guidance_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guidance_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guidance_arrow.add_theme_font_size_override("font_size", 28)
	guidance_arrow.add_theme_color_override("font_color", GUIDANCE_GOLD)
	guidance_arrow.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.88)
	)
	guidance_arrow.add_theme_constant_override("shadow_offset_x", 1)
	guidance_arrow.add_theme_constant_override("shadow_offset_y", 2)
	guidance_root.add_child(guidance_arrow)

	guidance_hint_panel = PanelContainer.new()
	guidance_hint_panel.name = "GuidanceHint"
	guidance_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guidance_hint_panel.size = GUIDANCE_HINT_SIZE
	guidance_hint_panel.add_theme_stylebox_override(
		"panel",
		_make_guidance_hint_style()
	)
	guidance_root.add_child(guidance_hint_panel)

	guidance_hint_label = Label.new()
	guidance_hint_label.name = "HintLabel"
	guidance_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guidance_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guidance_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guidance_hint_label.add_theme_font_size_override("font_size", 11)
	guidance_hint_label.add_theme_color_override("font_color", GUIDANCE_GOLD)
	guidance_hint_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.88)
	)
	guidance_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	guidance_hint_panel.add_child(guidance_hint_label)
	guidance_hint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_hide_interactive_guidance()

func _make_guidance_ring_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.30, 0.24, 0.10)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(
		GUIDANCE_JADE.r,
		GUIDANCE_JADE.g,
		GUIDANCE_JADE.b,
		0.92
	)
	var radius: int = int(round(GUIDANCE_RING_SIZE * 0.5))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(
		GUIDANCE_JADE.r,
		GUIDANCE_JADE.g,
		GUIDANCE_JADE.b,
		0.18
	)
	style.shadow_size = 8
	return style

func _make_guidance_hint_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GUIDANCE_DARK
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(
		GUIDANCE_JADE.r,
		GUIDANCE_JADE.g,
		GUIDANCE_JADE.b,
		0.72
	)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 6
	return style

func _update_interactive_guidance(delta: float) -> void:
	if guidance_root == null or not tutorial_active:
		_hide_interactive_guidance()
		return

	if size.x <= 1.0 or size.y <= 1.0:
		_hide_interactive_guidance()
		return

	if (
		pause_overlay != null and pause_overlay.visible
	) or (
		game_over_ui != null and game_over_ui.visible
	) or (
		victory_ui != null and victory_ui.visible
	):
		_hide_interactive_guidance()
		return

	if not SettingsManager.reduced_effects:
		guidance_phase = fmod(guidance_phase + delta, TAU * 10.0)

	if level_up_panel != null and level_up_panel.visible:
		if current_step != TutorialStep.BREAKTHROUGH:
			_hide_interactive_guidance()
			return
		var choice_target: Control = _get_first_visible_upgrade_choice()
		if choice_target == null:
			_hide_interactive_guidance()
			return
		_present_guidance_at(
			_control_center_in_overlay(choice_target),
			tr("CHOOSE 1 CULTIVATION PATH"),
			"breakthrough_choice"
		)
		return

	if prompt_waiting:
		if not tutorial_panel.visible:
			_hide_interactive_guidance()
			return
		_present_guidance_at(
			_control_center_in_overlay(continue_button),
			tr(_get_prompt_guidance_text()),
			"prompt_%d" % current_step
		)
		return

	match current_step:
		TutorialStep.MOVE:
			var joystick_target: Vector2 = _get_virtual_joystick_target()
			if joystick_target == Vector2.INF:
				_hide_interactive_guidance()
				return
			_present_guidance_at(
				joystick_target,
				tr("TOUCH & DRAG TO MOVE"),
				"move_joystick"
			)

		TutorialStep.AUTO_ARTS:
			if player == null:
				_hide_interactive_guidance()
				return
			_present_guidance_at(
				_node2d_center_in_overlay(player),
				tr("STAY MOBILE • WEAPONS AUTO-CAST"),
				"auto_arts_player"
			)

		TutorialStep.GATHER_QI:
			if exp_bar == null:
				_hide_interactive_guidance()
				return
			_present_guidance_at(
				_control_center_in_overlay(exp_bar),
				tr("COLLECT ESSENCE • FILL EXP"),
				"gather_qi_exp"
			)

		TutorialStep.BREAKTHROUGH:
			if exp_bar == null:
				_hide_interactive_guidance()
				return
			_present_guidance_at(
				_control_center_in_overlay(exp_bar),
				tr("FILL EXP TO BREAK THROUGH"),
				"breakthrough_exp"
			)

		_:
			_hide_interactive_guidance()

func _present_guidance_at(
	target_position: Vector2,
	hint_text: String,
	target_key: String
) -> void:
	if guidance_root == null:
		return
	if not target_position.is_finite():
		_hide_interactive_guidance()
		return

	guidance_root.visible = true
	guidance_ring.visible = true
	guidance_arrow.visible = true
	guidance_hint_panel.visible = true
	guidance_hint_label.text = hint_text

	var clamped_target := Vector2(
		clampf(
			target_position.x,
			GUIDANCE_EDGE_MARGIN,
			maxf(size.x - GUIDANCE_EDGE_MARGIN, GUIDANCE_EDGE_MARGIN)
		),
		clampf(
			target_position.y,
			GUIDANCE_EDGE_MARGIN,
			maxf(size.y - GUIDANCE_EDGE_MARGIN, GUIDANCE_EDGE_MARGIN)
		)
	)

	guidance_ring.position = clamped_target - guidance_ring.size * 0.5

	var pulse: float = 0.0
	var bob: float = 0.0
	if not SettingsManager.reduced_effects:
		pulse = sin(guidance_phase * 3.2) * GUIDANCE_PULSE_SCALE
		bob = sin(guidance_phase * 4.4) * GUIDANCE_BOB_DISTANCE
	guidance_ring.scale = Vector2.ONE * (1.0 + pulse)
	guidance_ring.modulate = Color(1.0, 1.0, 1.0, 0.88 + abs(pulse) * 1.5)

	var point_down: bool = clamped_target.y >= size.y * 0.36
	guidance_arrow.text = "▼" if point_down else "▲"
	var arrow_y: float
	var hint_y: float
	if point_down:
		arrow_y = (
			clamped_target.y
			- GUIDANCE_RING_SIZE * 0.5
			- GUIDANCE_ARROW_SIZE.y
			- GUIDANCE_TARGET_GAP
			+ bob
		)
		hint_y = arrow_y - GUIDANCE_HINT_SIZE.y - 5.0
	else:
		arrow_y = (
			clamped_target.y
			+ GUIDANCE_RING_SIZE * 0.5
			+ GUIDANCE_TARGET_GAP
			+ bob
		)
		hint_y = arrow_y + GUIDANCE_ARROW_SIZE.y + 5.0

	guidance_arrow.position = Vector2(
		clampf(
			clamped_target.x - GUIDANCE_ARROW_SIZE.x * 0.5,
			0.0,
			maxf(size.x - GUIDANCE_ARROW_SIZE.x, 0.0)
		),
		clampf(
			arrow_y,
			0.0,
			maxf(size.y - GUIDANCE_ARROW_SIZE.y, 0.0)
		)
	)
	guidance_hint_panel.position = Vector2(
		clampf(
			clamped_target.x - GUIDANCE_HINT_SIZE.x * 0.5,
			8.0,
			maxf(size.x - GUIDANCE_HINT_SIZE.x - 8.0, 8.0)
		),
		clampf(
			hint_y,
			8.0,
			maxf(size.y - GUIDANCE_HINT_SIZE.y - 8.0, 8.0)
		)
	)

	if guidance_last_target_key != target_key:
		guidance_last_target_key = target_key
		_play_guidance_arrival()

func _play_guidance_arrival() -> void:
	if guidance_root == null or SettingsManager.reduced_effects:
		return
	guidance_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(
		guidance_root,
		"modulate",
		Color.WHITE,
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _hide_interactive_guidance() -> void:
	if guidance_root == null:
		return
	guidance_root.visible = false
	guidance_root.modulate = Color.WHITE
	guidance_last_target_key = ""

func _get_prompt_guidance_text() -> String:
	match current_step:
		TutorialStep.MOVE:
			return "TAP BEGIN TRIAL"
		TutorialStep.AUTO_ARTS:
			return "CONTINUE TO SEE AUTO-CAST"
		TutorialStep.GATHER_QI:
			return "CONTINUE • WATCH YOUR EXP"
		TutorialStep.BREAKTHROUGH:
			return "CONTINUE TO BREAK THROUGH"
		TutorialStep.ASCENSION:
			return "ENTER THE TRIAL"
		_:
			return "CONTINUE"

func _get_virtual_joystick_target() -> Vector2:
	if virtual_joystick == null:
		return Vector2.INF

	var local_target: Vector2 = Vector2(
		virtual_joystick.size.x * 0.18,
		virtual_joystick.size.y * 0.82
	)
	var floating_center_value: Variant = virtual_joystick.get("floating_center")
	if floating_center_value is Vector2:
		var floating_center: Vector2 = floating_center_value as Vector2
		if floating_center != Vector2.ZERO:
			local_target = floating_center

	return _canvas_point_to_overlay(
		virtual_joystick.get_global_transform_with_canvas() * local_target
	)

func _get_first_visible_upgrade_choice() -> Control:
	if level_up_panel == null:
		return null
	var buttons: Array[Node] = level_up_panel.find_children(
		"UpgradeButton*",
		"Button",
		true,
		false
	)
	for button_node: Node in buttons:
		var button := button_node as Button
		if button != null and button.visible and not button.disabled:
			return button
	return null

func _control_center_in_overlay(control: Control) -> Vector2:
	if control == null or not is_instance_valid(control):
		return Vector2.INF
	var canvas_point: Vector2 = (
		control.get_global_transform_with_canvas()
		* (control.size * 0.5)
	)
	return _canvas_point_to_overlay(canvas_point)

func _node2d_center_in_overlay(node: Node2D) -> Vector2:
	if node == null or not is_instance_valid(node):
		return Vector2.INF
	return _canvas_point_to_overlay(
		node.get_global_transform_with_canvas().origin
	)

func _canvas_point_to_overlay(canvas_point: Vector2) -> Vector2:
	return (
		get_global_transform_with_canvas().affine_inverse()
		* canvas_point
	)
