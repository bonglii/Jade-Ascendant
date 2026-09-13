extends Control

## Contextual First-Run Tutorial
## Mengajarkan loop inti melalui aksi runtime nyata tanpa mengubah combat logic.
## Setiap guidance prompt bersifat modal singkat: battlefield dipause sampai pemain
## mengonfirmasi, lalu aksi gameplay kembali berjalan.
## Completion disimpan terpisah dari gameplay save domains di user://tutorial.cfg.

const SAVE_PATH: String = "user://tutorial.cfg"
const SAVE_VERSION: int = 1
const TARGET_CHAPTER_ID: int = 1
const TARGET_STAGE_ID: int = 1
const MOVE_DISTANCE_REQUIRED: float = 72.0
const MIN_STEP_DISPLAY_TIME: float = 1.25

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tutorial_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)

	if not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)

	call_deferred("_initialize_tutorial")

func _initialize_tutorial() -> void:
	if _is_tutorial_completed():
		set_process(false)
		return

	if not _is_target_stage():
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
		set_process(false)
		return

	player = get_tree().get_first_node_in_group("player") as Node2D

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		set_process(false)
		return

	enemy_spawner = scene_root.get_node_or_null("EnemySpawner")
	level_up_panel = scene_root.get_node_or_null("HUD/LevelUpPanel") as Control
	pause_overlay = scene_root.get_node_or_null(
		"HUD/ScreenRoot/PauseOverlay"
	) as Control
	game_over_ui = scene_root.get_node_or_null("GameOverUI") as CanvasLayer
	victory_ui = scene_root.get_node_or_null("VictoryUI") as CanvasLayer

	if player == null:
		push_warning("Tutorial: Player tidak ditemukan. Guidance dinonaktifkan.")
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
		return

	if level_up_panel != null and level_up_panel.visible:
		breakthrough_panel_seen = true

	if prompt_waiting:
		_try_present_pending_prompt()
		return

	if _is_presentationally_blocked():
		tutorial_panel.visible = false
		return

	# Saat objective sedang dimainkan, card guidance disembunyikan agar
	# battlefield tetap bersih dan input touch di masa depan tidak tertutup.
	tutorial_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_elapsed += delta

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
