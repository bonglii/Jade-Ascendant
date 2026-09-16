extends CanvasLayer

## In-Run HUD
## Presentation authority for runtime status only.
## Combat, progression, wave, boss and checkpoint state remain owned by their managers.

const HUD_JADE: Color = Color(0.20, 0.92, 0.78, 1.0)
const HUD_GOLD: Color = Color(0.98, 0.79, 0.30, 1.0)
const HUD_IVORY: Color = Color(0.96, 0.94, 0.84, 1.0)
const HP_HEALTHY: Color = Color(0.66, 0.10, 0.12, 1.0)
const HP_WARNING: Color = Color(0.92, 0.48, 0.12, 1.0)
const HP_CRITICAL: Color = Color(0.94, 0.12, 0.18, 1.0)
const BOSS_CRIMSON: Color = Color(0.74, 0.10, 0.12, 1.0)

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
var _last_health_state: int = -1
var _boss_tween: Tween = null
var _level_up_tween: Tween = null
var _pause_tween: Tween = null
var _pause_checkpoint_base_text: String = ""
var _encounter_banner: PanelContainer = null
var _encounter_banner_name: Label = null
var _encounter_banner_phase: Label = null
var _encounter_banner_top_line: ColorRect = null
var _encounter_banner_bottom_line: ColorRect = null
var _encounter_banner_tween: Tween = null

func _ready() -> void:
	boss_panel.visible = false
	pause_overlay.visible = false
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	pause_main_menu_button.pressed.connect(_on_pause_main_menu_pressed)
	if not level_up_panel.visibility_changed.is_connected(_on_level_up_visibility_changed):
		level_up_panel.visibility_changed.connect(_on_level_up_visibility_changed)
	_capture_pause_presentation_baseline()
	_build_encounter_banner()
	SceneTransitionManager.set_back_handler(handle_system_back)
	_validate_hud_references()
	_connect_boss_spawn_signal()
	_apply_runtime_presentation()
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

func _apply_runtime_presentation() -> void:
	exp_bar.add_theme_stylebox_override(
		"fill",
		_make_bar_fill_style(HUD_JADE)
	)
	hp_bar.add_theme_stylebox_override(
		"fill",
		_make_bar_fill_style(HP_HEALTHY)
	)
	boss_hp_bar.add_theme_stylebox_override(
		"fill",
		_make_bar_fill_style(BOSS_CRIMSON)
	)
	level_label.add_theme_color_override("font_color", HUD_GOLD)
	wave_label.add_theme_color_override("font_color", HUD_IVORY)
	timer_label.add_theme_color_override("font_color", HUD_IVORY)
	boss_name_label.add_theme_color_override("font_color", HUD_GOLD)
	boss_phase_label.add_theme_color_override("font_color", HUD_IVORY)

func _make_bar_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

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
		if not force and last_level >= 0:
			_pulse_control(level_label, HUD_GOLD, 1.18)
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
	_update_health_presentation(current_health, current_max_health, force)
	last_health = current_health
	last_max_health = current_max_health

func _update_health_presentation(
	current_health: float,
	current_max_health: float,
	force: bool
) -> void:
	var ratio: float = current_health / maxf(current_max_health, 1.0)
	var health_state: int = 0
	var fill_color: Color = HP_HEALTHY
	if ratio <= 0.30:
		health_state = 2
		fill_color = HP_CRITICAL
	elif ratio <= 0.55:
		health_state = 1
		fill_color = HP_WARNING
	hp_bar.add_theme_stylebox_override(
		"fill",
		_make_bar_fill_style(fill_color)
	)
	if force or health_state == _last_health_state:
		_last_health_state = health_state
		return
	if health_state == 2:
		_pulse_control(hp_label, HP_CRITICAL, 1.08)
	elif _last_health_state == 2 and health_state < 2:
		_pulse_control(hp_label, HUD_JADE, 1.05)
	_last_health_state = health_state

func _refresh_wave(force: bool) -> void:
	var current_wave: int = int(wave_manager.current_wave)
	if not force and current_wave == last_wave:
		return
	wave_label.text = tr("WAVE %d") % current_wave
	if not force and last_wave >= 0:
		_pulse_control(wave_label, HUD_JADE, 1.13)
	last_wave = current_wave

func _refresh_timer(force: bool) -> void:
	var survival_second: int = int(floor(float(survival_manager.survival_time)))
	if not force and survival_second == last_survival_second:
		return
	timer_label.text = str(survival_manager.format_time())
	last_survival_second = survival_second

func _pulse_control(
	control: Control,
	accent: Color,
	peak_scale: float
) -> void:
	if control == null or not is_instance_valid(control):
		return
	if _is_reduced_effects_enabled():
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE
	control.modulate = Color.WHITE
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		control,
		"scale",
		Vector2.ONE * peak_scale,
		0.10
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"modulate",
		accent,
		0.08
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().set_parallel(true)
	tween.tween_property(
		control,
		"scale",
		Vector2.ONE,
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"modulate",
		Color.WHITE,
		0.20
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _is_reduced_effects_enabled() -> bool:
	return bool(SettingsManager.reduced_effects)

func _capture_pause_presentation_baseline() -> void:
	var checkpoint_hint: Label = pause_overlay.find_child(
		"CheckpointHint",
		true,
		false
	) as Label
	if checkpoint_hint != null:
		_pause_checkpoint_base_text = checkpoint_hint.text

func _on_level_up_visibility_changed() -> void:
	if not level_up_panel.visible:
		_reset_level_up_presentation()
		return
	_present_level_up_breakthrough()

func _present_level_up_breakthrough() -> void:
	var frame: Control = level_up_panel.find_child("Frame", true, false) as Control
	var dim: ColorRect = level_up_panel.find_child("Dim", true, false) as ColorRect
	var title: Label = level_up_panel.find_child("Title", true, false) as Label
	var breakthrough_label: Label = level_up_panel.find_child(
		"BreakthroughLevelLabel",
		true,
		false
	) as Label
	var divider: ColorRect = level_up_panel.find_child(
		"Divider",
		true,
		false
	) as ColorRect
	if frame == null:
		return
	if _level_up_tween != null and _level_up_tween.is_valid():
		_level_up_tween.kill()
	frame.pivot_offset = frame.size * 0.5
	frame.scale = Vector2.ONE
	frame.modulate = Color.WHITE
	if dim != null:
		dim.modulate = Color.WHITE
	var accent: Color = HUD_JADE
	var state_labels: Array[Node] = level_up_panel.find_children(
		"StateLabel",
		"Label",
		true,
		false
	)
	for state_node in state_labels:
		var state_label := state_node as Label
		if state_label == null:
			continue
		var state_text: String = state_label.text.to_upper()
		if state_text.contains("RESONANCE") or state_text.contains("MILESTONE"):
			accent = HUD_GOLD
			break
	if breakthrough_label != null:
		breakthrough_label.add_theme_color_override("font_color", accent)
	if divider != null:
		divider.color = Color(accent.r, accent.g, accent.b, 0.62)
	if _is_reduced_effects_enabled():
		if title != null:
			title.modulate = Color.WHITE
		return
	frame.scale = Vector2(0.955, 0.955)
	frame.modulate = Color(1.0, 0.92, 0.70, 0.0)
	if dim != null:
		dim.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_level_up_tween = level_up_panel.create_tween()
	_level_up_tween.set_parallel(true)
	_level_up_tween.tween_property(
		frame,
		"scale",
		Vector2.ONE,
		0.32
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_level_up_tween.tween_property(
		frame,
		"modulate",
		Color.WHITE,
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if dim != null:
		_level_up_tween.tween_property(
			dim,
			"modulate",
			Color.WHITE,
			0.20
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if breakthrough_label != null:
		_pulse_control(breakthrough_label, accent, 1.12)
	if title != null:
		_pulse_control(title, HUD_IVORY, 1.035)
	_present_upgrade_cards(accent)

func _present_upgrade_cards(accent: Color) -> void:
	var buttons: Array[Node] = level_up_panel.find_children(
		"UpgradeButton*",
		"Button",
		true,
		false
	)
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		if button == null or not button.visible:
			continue
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2.ONE
		button.modulate = Color.WHITE
		if _is_reduced_effects_enabled():
			continue
		button.scale = Vector2(0.975, 0.975)
		button.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var card_tween := level_up_panel.create_tween()
		card_tween.set_parallel(true)
		var delay: float = 0.08 + float(index) * 0.07
		card_tween.tween_property(
			button,
			"modulate",
			Color.WHITE,
			0.18
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		card_tween.tween_property(
			button,
			"scale",
			Vector2.ONE,
			0.24
		).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var state_label: Label = button.find_child(
			"StateLabel",
			true,
			false
		) as Label
		if state_label != null:
			var state_text: String = state_label.text.to_upper()
			if state_text.contains("RESONANCE") or state_text.contains("MILESTONE"):
				state_label.add_theme_color_override("font_color", HUD_GOLD)
			else:
				state_label.add_theme_color_override(
					"font_color",
					Color(accent.r, accent.g, accent.b, 0.96)
				)

func _reset_level_up_presentation() -> void:
	if _level_up_tween != null and _level_up_tween.is_valid():
		_level_up_tween.kill()
	var frame: Control = level_up_panel.find_child("Frame", true, false) as Control
	if frame != null:
		frame.scale = Vector2.ONE
		frame.modulate = Color.WHITE
	var dim: ColorRect = level_up_panel.find_child("Dim", true, false) as ColorRect
	if dim != null:
		dim.modulate = Color.WHITE
	var buttons: Array[Node] = level_up_panel.find_children(
		"UpgradeButton*",
		"Button",
		true,
		false
	)
	for button_node in buttons:
		var button := button_node as Button
		if button == null:
			continue
		button.scale = Vector2.ONE
		button.modulate = Color.WHITE

func _present_pause_overlay() -> void:
	var panel: Control = pause_overlay.find_child("Panel", true, false) as Control
	var dim: ColorRect = pause_overlay.find_child("Dim", true, false) as ColorRect
	var title: Label = pause_overlay.find_child("Title", true, false) as Label
	var checkpoint_hint: Label = pause_overlay.find_child(
		"CheckpointHint",
		true,
		false
	) as Label
	if checkpoint_hint != null and not _pause_checkpoint_base_text.is_empty():
		checkpoint_hint.text = (
			_pause_checkpoint_base_text
			+ "\n"
			+ wave_label.text
			+ "  •  "
			+ timer_label.text
			+ "  •  "
			+ level_label.text
		)
	if title != null:
		title.add_theme_color_override("font_color", HUD_GOLD)
	if panel == null or _is_reduced_effects_enabled():
		return
	if _pause_tween != null and _pause_tween.is_valid():
		_pause_tween.kill()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.965, 0.965)
	panel.modulate = Color(1.0, 0.93, 0.76, 0.0)
	if dim != null:
		dim.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_pause_tween = pause_overlay.create_tween()
	_pause_tween.set_parallel(true)
	_pause_tween.tween_property(
		panel,
		"scale",
		Vector2.ONE,
		0.26
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pause_tween.tween_property(
		panel,
		"modulate",
		Color.WHITE,
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if dim != null:
		_pause_tween.tween_property(
			dim,
			"modulate",
			Color.WHITE,
			0.16
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_control(resume_button, HUD_JADE, 1.025)

func _reset_pause_overlay_presentation() -> void:
	if _pause_tween != null and _pause_tween.is_valid():
		_pause_tween.kill()
	var panel: Control = pause_overlay.find_child("Panel", true, false) as Control
	if panel != null:
		panel.scale = Vector2.ONE
		panel.modulate = Color.WHITE
	var dim: ColorRect = pause_overlay.find_child("Dim", true, false) as ColorRect
	if dim != null:
		dim.modulate = Color.WHITE
	var checkpoint_hint: Label = pause_overlay.find_child(
		"CheckpointHint",
		true,
		false
	) as Label
	if checkpoint_hint != null and not _pause_checkpoint_base_text.is_empty():
		checkpoint_hint.text = _pause_checkpoint_base_text

func _build_encounter_banner() -> void:
	var safe_area: Control = get_node_or_null("ScreenRoot/HUDSafeArea") as Control
	if safe_area == null:
		return
	_encounter_banner = PanelContainer.new()
	_encounter_banner.name = "EncounterBanner"
	_encounter_banner.visible = false
	_encounter_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_encounter_banner.anchor_left = 0.08
	_encounter_banner.anchor_top = 0.28
	_encounter_banner.anchor_right = 0.92
	_encounter_banner.anchor_bottom = 0.42
	_encounter_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_encounter_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_encounter_banner.add_theme_stylebox_override(
		"panel",
		_make_encounter_banner_style()
	)
	safe_area.add_child(_encounter_banner)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	_encounter_banner.add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	_encounter_banner_top_line = ColorRect.new()
	_encounter_banner_top_line.custom_minimum_size = Vector2(0.0, 2.0)
	_encounter_banner_top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_encounter_banner_top_line.color = Color(HUD_GOLD.r, HUD_GOLD.g, HUD_GOLD.b, 0.92)
	content.add_child(_encounter_banner_top_line)

	_encounter_banner_phase = Label.new()
	_encounter_banner_phase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_encounter_banner_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_encounter_banner_phase.add_theme_font_size_override("font_size", 12)
	_encounter_banner_phase.add_theme_color_override("font_color", HUD_JADE)
	content.add_child(_encounter_banner_phase)

	_encounter_banner_name = Label.new()
	_encounter_banner_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_encounter_banner_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_encounter_banner_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_encounter_banner_name.add_theme_font_size_override("font_size", 22)
	_encounter_banner_name.add_theme_color_override("font_color", HUD_GOLD)
	_encounter_banner_name.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.90)
	)
	_encounter_banner_name.add_theme_constant_override("shadow_offset_x", 1)
	_encounter_banner_name.add_theme_constant_override("shadow_offset_y", 2)
	content.add_child(_encounter_banner_name)

	_encounter_banner_bottom_line = ColorRect.new()
	_encounter_banner_bottom_line.custom_minimum_size = Vector2(0.0, 2.0)
	_encounter_banner_bottom_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_encounter_banner_bottom_line.color = Color(HUD_GOLD.r, HUD_GOLD.g, HUD_GOLD.b, 0.92)
	content.add_child(_encounter_banner_bottom_line)


func _make_encounter_banner_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.018, 0.025, 0.93)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.93, 0.68, 0.22, 0.72)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 12
	return style


func _show_encounter_banner(phase_text: String, accent: Color) -> void:
	if _encounter_banner == null or _encounter_banner_name == null:
		return
	_encounter_banner_name.text = boss_name_label.text
	_encounter_banner_phase.text = phase_text
	_encounter_banner_phase.add_theme_color_override("font_color", accent)
	_encounter_banner_name.add_theme_color_override("font_color", HUD_GOLD)
	if _encounter_banner_top_line != null:
		_encounter_banner_top_line.color = Color(accent.r, accent.g, accent.b, 0.94)
	if _encounter_banner_bottom_line != null:
		_encounter_banner_bottom_line.color = Color(accent.r, accent.g, accent.b, 0.94)
	if _encounter_banner_tween != null and _encounter_banner_tween.is_valid():
		_encounter_banner_tween.kill()
	_encounter_banner.visible = true
	_encounter_banner.pivot_offset = _encounter_banner.size * 0.5
	_encounter_banner.scale = Vector2.ONE
	_encounter_banner.modulate = Color.WHITE
	if _is_reduced_effects_enabled():
		var reduced_tween := create_tween()
		reduced_tween.tween_interval(0.70)
		reduced_tween.tween_callback(_hide_encounter_banner)
		_encounter_banner_tween = reduced_tween
		return
	_encounter_banner.scale = Vector2(0.93, 0.93)
	_encounter_banner.modulate = Color(1.0, 0.88, 0.58, 0.0)
	_encounter_banner_tween = create_tween()
	_encounter_banner_tween.set_parallel(true)
	_encounter_banner_tween.tween_property(
		_encounter_banner,
		"scale",
		Vector2.ONE,
		0.28
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_encounter_banner_tween.tween_property(
		_encounter_banner,
		"modulate",
		Color.WHITE,
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_encounter_banner_tween.chain().tween_interval(0.58)
	_encounter_banner_tween.chain().set_parallel(true)
	_encounter_banner_tween.tween_property(
		_encounter_banner,
		"modulate:a",
		0.0,
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_encounter_banner_tween.tween_property(
		_encounter_banner,
		"scale",
		Vector2(1.035, 1.035),
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_encounter_banner_tween.chain().tween_callback(_hide_encounter_banner)


func _hide_encounter_banner() -> void:
	if _encounter_banner == null:
		return
	_encounter_banner.visible = false
	_encounter_banner.modulate = Color.WHITE
	_encounter_banner.scale = Vector2.ONE


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
	_present_pause_overlay()
	get_tree().paused = true

func _on_resume_pressed() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	_reset_pause_overlay_presentation()
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
	_present_boss_arrival()
	_show_encounter_banner(boss_phase_label.text, HUD_JADE)
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

func _present_boss_arrival() -> void:
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	if _is_reduced_effects_enabled():
		boss_panel.scale = Vector2.ONE
		boss_panel.modulate = Color.WHITE
		return
	boss_panel.pivot_offset = boss_panel.size * 0.5
	boss_panel.scale = Vector2(0.94, 0.94)
	boss_panel.modulate = Color(1.0, 0.84, 0.52, 0.0)
	_boss_tween = create_tween()
	_boss_tween.set_parallel(true)
	_boss_tween.tween_property(
		boss_panel,
		"scale",
		Vector2.ONE,
		0.34
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_boss_tween.tween_property(
		boss_panel,
		"modulate",
		Color.WHITE,
		0.24
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _format_boss_name(raw_name: String) -> String:
	return raw_name.replace("_", " ").to_upper()

func _set_boss_phase(current_phase: int) -> void:
	boss_phase_label.text = tr("PHASE %d") % maxi(1, current_phase)

func _on_boss_phase_changed(current_phase: int) -> void:
	_set_boss_phase(current_phase)
	_pulse_control(boss_phase_label, HUD_GOLD, 1.18)
	_pulse_control(boss_name_label, Color(1.0, 0.74, 0.30, 1.0), 1.05)
	_show_encounter_banner(boss_phase_label.text, Color(1.0, 0.42, 0.22, 1.0))
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
	if _encounter_banner_tween != null and _encounter_banner_tween.is_valid():
		_encounter_banner_tween.kill()
	_hide_encounter_banner()
	if _is_reduced_effects_enabled():
		_hide_boss_panel()
		return
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.set_parallel(true)
	_boss_tween.tween_property(
		boss_panel,
		"modulate:a",
		0.0,
		0.20
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_boss_tween.tween_property(
		boss_panel,
		"scale",
		Vector2(1.04, 1.04),
		0.20
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_boss_tween.chain().tween_callback(_hide_boss_panel)

func _hide_boss_panel() -> void:
	boss_panel.visible = false
	boss_panel.modulate = Color.WHITE
	boss_panel.scale = Vector2.ONE
