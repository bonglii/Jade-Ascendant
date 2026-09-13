extends CanvasLayer

## In-Run HUD
## Presentation authority for runtime status only.
## Combat, progression, wave, boss and checkpoint state remain owned by their managers.

@onready var exp_bar: ProgressBar = %EXPBar
@onready var exp_label: Label = %EXPLabel
@onready var level_label: Label = %LevelLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var wave_label: Label = %WaveLabel
@onready var timer_label: Label = %TimerLabel
@onready var player: Variant = get_parent().get_node_or_null("player_1")
@onready var player_health: PlayerHealth = (
	player.get_node_or_null("PlayerHealth") as PlayerHealth
	if player != null
	else null
)
@onready var survival_manager: Variant = get_parent().get_node_or_null(
	"SurvivalManager"
)
@onready var wave_manager: Variant = get_parent().get_node_or_null(
	"WaveManager"
)
@onready var level_up_panel: Control = %LevelUpPanel
@onready var boss_panel: PanelContainer = %BossPanel
@onready var boss_hp_bar: ProgressBar = %BossHPBar
@onready var boss_hp_label: Label = %BossHPLabel
@onready var boss_name_label: Label = %BossNameLabel
@onready var boss_phase_label: Label = %BossPhaseLabel
@onready var pause_button: Button = %PauseButton
@onready var pause_overlay: Control = %PauseOverlay
@onready var resume_button: Button = %ResumeButton
@onready var pause_main_menu_button: Button = %PauseMainMenuButton
@onready var checkpoint_manager: Variant = get_parent().get_node_or_null(
	"CheckPointManager"
)

var last_level: int = -1
var last_experience: int = -1
var last_experience_to_next: int = -1
var last_health: float = -1.0
var last_max_health: float = -1.0
var last_wave: int = -1
var last_survival_second: int = -1

func _ready() -> void:
	boss_panel.visible = false
	pause_overlay.visible = false
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	pause_main_menu_button.pressed.connect(_on_pause_main_menu_pressed)
	SceneTransitionManager.set_back_handler(handle_system_back)
	_validate_hud_references()
	_connect_boss_spawn_signal()
	_refresh_player_hud(true)

func _process(_delta: float) -> void:
	_refresh_player_hud(false)

func _validate_hud_references() -> void:
	if player == null:
		push_error("HUD: player_1 tidak ditemukan!")
	if player_health == null:
		push_error("HUD: PlayerHealth tidak ditemukan!")
	if survival_manager == null:
		push_error("HUD: SurvivalManager tidak ditemukan!")
	if wave_manager == null:
		push_error("HUD: WaveManager tidak ditemukan!")
	if checkpoint_manager == null:
		push_error("HUD: CheckPointManager tidak ditemukan!")

func _connect_boss_spawn_signal() -> void:
	var enemy_spawner: Node = get_node_or_null("../EnemySpawner")
	if enemy_spawner == null:
		DebugLogger.system(str("HUD ERROR: EnemySpawner tidak ditemukan!"))
		return
	DebugLogger.system(str("HUD: EnemySpawner ditemukan!"))
	if not enemy_spawner.has_signal("boss_spawned_signal"):
		DebugLogger.system(str("HUD ERROR: boss_spawned_signal tidak ditemukan!"))
		return
	var boss_spawned_callable: Callable = Callable(
		self,
		"setup_boss_health_bar"
	)
	if not enemy_spawner.is_connected(
		"boss_spawned_signal",
		boss_spawned_callable
	):
		enemy_spawner.connect(
			"boss_spawned_signal",
			boss_spawned_callable
		)
	DebugLogger.system(str("HUD: boss_spawned_signal berhasil terhubung!"))

func _refresh_player_hud(force: bool) -> void:
	if player != null:
		_refresh_level_and_exp(force)
	if player_health != null:
		_refresh_health(force)
	if wave_manager != null:
		_refresh_wave(force)
	if survival_manager != null:
		_refresh_timer(force)

func _refresh_level_and_exp(force: bool) -> void:
	var current_level: int = int(player.level)
	var current_experience: int = int(player.experience)
	var current_experience_to_next: int = int(
		player.experience_to_next_level
	)
	if force or current_level != last_level:
		level_label.text = "LV. %d" % current_level
		last_level = current_level
	if (
		force
		or current_experience != last_experience
		or current_experience_to_next != last_experience_to_next
	):
		exp_bar.max_value = maxi(1, current_experience_to_next)
		exp_bar.value = current_experience
		exp_label.text = "%d / %d" % [
			current_experience,
			current_experience_to_next
		]
		last_experience = current_experience
		last_experience_to_next = current_experience_to_next

func _refresh_health(force: bool) -> void:
	var current_health: float = player_health.current_health
	var current_max_health: float = player_health.max_health
	if (
		not force
		and is_equal_approx(current_health, last_health)
		and is_equal_approx(current_max_health, last_max_health)
	):
		return
	hp_bar.max_value = maxf(1.0, current_max_health)
	hp_bar.value = current_health
	hp_label.text = "HP %d / %d" % [
		int(round(current_health)),
		int(round(current_max_health))
	]
	last_health = current_health
	last_max_health = current_max_health

func _refresh_wave(force: bool) -> void:
	var current_wave: int = int(wave_manager.current_wave)
	if not force and current_wave == last_wave:
		return
	wave_label.text = tr("WAVE %d") % current_wave
	last_wave = current_wave

func _refresh_timer(force: bool) -> void:
	var survival_second: int = int(floor(float(survival_manager.survival_time)))
	if not force and survival_second == last_survival_second:
		return
	timer_label.text = str(survival_manager.format_time())
	last_survival_second = survival_second

func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if level_up_panel.visible:
		return
	if pause_overlay.visible:
		_on_resume_pressed()
		return
	_on_pause_pressed()

func _on_pause_pressed() -> void:
	if get_tree().paused:
		return
	if level_up_panel.visible:
		return
	pause_overlay.visible = true
	get_tree().paused = true

func _on_resume_pressed() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	pause_overlay.visible = false
	get_tree().paused = false

func _on_pause_main_menu_pressed() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if checkpoint_manager == null:
		push_error("HUD: CheckPointManager tidak tersedia saat kembali ke Home.")
		return
	if not bool(checkpoint_manager.save_checkpoint()):
		pause_main_menu_button.text = tr("SAVE FAILED • TRY AGAIN")
		var hint: Label = pause_overlay.find_child("CheckpointHint", true, false) as Label
		if hint != null:
			hint.text = tr("Your run is still open. Free device storage or retry saving before leaving.")
		return
	# Keep pause visible if asynchronous loading fails.
	var change_error: Error = SceneTransitionManager.transition_to(
		"res://scenes/ui/main_menu.tscn",
		{
			"title": "Returning to Jade Sanctuary",
			"subtitle": "Active run checkpoint preserved",
			"minimum_display_time": 0.45
		}
	)
	if change_error != OK:
		get_tree().paused = true
		pause_overlay.visible = true
		push_error(
			"HUD: gagal kembali ke Main Menu. Error code: "
			+ str(change_error)
		)

## Menghubungkan Boss ke Boss HUD ketika Boss muncul.
func setup_boss_health_bar(boss: Node) -> void:
	if boss == null:
		return
	DebugLogger.system(str("HUD: Boss diterima -> ", boss.name))
	if not boss.has_signal("health_changed"):
		DebugLogger.system(str("HUD ERROR: Boss tidak memiliki health_changed!"))
		return
	var display_name: String = str(boss.name)
	if boss.has_method("get_encounter_display_name"):
		display_name = str(boss.call("get_encounter_display_name"))
	boss_name_label.text = _format_boss_name(display_name)
	var initial_phase: int = 1
	var boss_phase_value: Variant = boss.get("current_phase")
	if boss_phase_value != null:
		initial_phase = int(boss_phase_value)
	_set_boss_phase(initial_phase)
	var initial_max_hp: float = float(boss.get("max_hp"))
	var initial_hp: float = float(boss.get("current_hp"))
	boss_hp_bar.max_value = maxf(initial_max_hp, 1.0)
	boss_hp_bar.value = initial_hp
	_update_boss_hp_label(initial_hp, initial_max_hp)
	boss_panel.visible = true
	DebugLogger.system(str("HUD: Boss HP Bar ditampilkan!"))
	DebugLogger.system(str("HUD: Boss HP = ", initial_hp, "/", initial_max_hp))
	if not boss.health_changed.is_connected(_on_boss_health_changed):
		boss.health_changed.connect(_on_boss_health_changed)
	if boss.has_signal("phase_changed"):
		if not boss.phase_changed.is_connected(_on_boss_phase_changed):
			boss.phase_changed.connect(_on_boss_phase_changed)
	else:
		DebugLogger.system(str("HUD ERROR: Boss tidak memiliki phase_changed!"))
	if boss.has_signal("boss_defeated"):
		if not boss.boss_defeated.is_connected(_on_boss_defeated):
			boss.boss_defeated.connect(_on_boss_defeated)

func _format_boss_name(raw_name: String) -> String:
	return raw_name.replace("_", " ").to_upper()

func _set_boss_phase(current_phase: int) -> void:
	boss_phase_label.text = tr("PHASE %d") % maxi(1, current_phase)

func _on_boss_phase_changed(current_phase: int) -> void:
	_set_boss_phase(current_phase)
	DebugLogger.system(str("HUD: Boss Phase -> ", current_phase))

func _on_boss_health_changed(current_hp: float, max_hp: float) -> void:
	boss_hp_bar.max_value = maxf(max_hp, 1.0)
	boss_hp_bar.value = current_hp
	_update_boss_hp_label(current_hp, max_hp)

func _update_boss_hp_label(current_hp: float, max_hp: float) -> void:
	boss_hp_label.text = "%d / %d" % [
		int(round(current_hp)),
		int(round(max_hp))
	]

func _on_boss_defeated() -> void:
	boss_panel.visible = false
