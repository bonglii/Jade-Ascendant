extends Node

## Production HUD visual extension. Installed by BossHudPhaseGuard after scene
## initialization so HUD, EnemySpawner, scene and save schemas stay untouched.
## Presentation tracks existing HP/EXP and wave values without mutating gameplay.
## This pass aggressively redesigns the boss pre-warning and arrival reveal so
## Realm 4 and Realm 5 feel like premium encounter events rather than prototype
## debug cards.

const BOSS_PRE_WARNING_LEAD: float = 4.25
const BOSS_PRE_WARNING_HOLD: float = 4.20
const BOSS_ARRIVAL_NAME_HOLD: float = 2.85
const BOSS_ARRIVAL_FADE: float = 0.30

const EXP_JADE: Color = Color(0.20, 0.97, 0.81, 1.0)
const HP_HEALTHY: Color = Color(0.86, 0.15, 0.20, 1.0)
const HP_WARNING: Color = Color(1.0, 0.55, 0.18, 1.0)
const HP_CRITICAL: Color = Color(1.0, 0.24, 0.27, 1.0)
const BOSS_CRIMSON: Color = Color(0.90, 0.16, 0.21, 1.0)
const GOLD: Color = Color(1.0, 0.80, 0.39, 1.0)
const IVORY: Color = Color(0.98, 0.96, 0.86, 1.0)

const REALM_FALLBACK: int = 0

var _hud: Node = null
var _enemy_spawner: Node = null
var _wave_manager: Node = null
var _level_root: Node = null
var _player_health: PlayerHealth = null
var _hp_bar: ProgressBar = null
var _exp_bar: ProgressBar = null
var _boss_bar: ProgressBar = null
var _hp_highlight: ColorRect = null
var _exp_highlight: ColorRect = null
var _hp_fill_styles: Array[StyleBoxFlat] = []
var _exp_fill_style: StyleBoxFlat = null
var _boss_fill_style: StyleBoxFlat = null
var _health_state: int = -1
var _last_hp_ratio: float = -1.0
var _last_exp_ratio: float = -1.0
var _boss_warning_shown: bool = false
var _warning_panel: PanelContainer = null
var _warning_tween: Tween = null
var _warning_header: Label = null
var _warning_main: Label = null
var _warning_subtitle: Label = null
var _warning_stage_chip: PanelContainer = null
var _warning_stage_label: Label = null
var _warning_side_left: Control = null
var _warning_side_right: Control = null
var _active_realm_id: int = REALM_FALLBACK
var _active_stage_id: int = 0


func _ready() -> void:
	set_process(false)
	call_deferred("_initialize_hud_presentation")


func _initialize_hud_presentation() -> void:
	var guard: Node = get_parent()
	if guard == null:
		return
	_enemy_spawner = guard.get_parent()
	if _enemy_spawner == null:
		return
	_level_root = _enemy_spawner.get_parent()
	if _level_root == null:
		return
	_hud = _level_root.get_node_or_null("HUD")
	_wave_manager = _level_root.get_node_or_null("WaveManager")
	var player: Node = _level_root.get_node_or_null("player_1")
	if _hud == null or _wave_manager == null or player == null:
		# Some off-tree smoke fixtures intentionally have no production HUD.
		return

	_player_health = player.get_node_or_null("PlayerHealth") as PlayerHealth
	_hp_bar = _hud.get("hp_bar") as ProgressBar
	_exp_bar = _hud.get("exp_bar") as ProgressBar
	_boss_bar = _hud.get("boss_hp_bar") as ProgressBar
	if _player_health == null or _hp_bar == null or _exp_bar == null:
		return

	_active_realm_id = _detect_realm_id()
	_active_stage_id = _detect_stage_id()

	_polish_player_bars()
	_polish_boss_bar()
	_build_pre_boss_warning()

	if _enemy_spawner.has_signal("boss_spawned_signal"):
		var boss_callable: Callable = Callable(self, "_on_boss_spawned")
		if not _enemy_spawner.is_connected("boss_spawned_signal", boss_callable):
			_enemy_spawner.connect("boss_spawned_signal", boss_callable)

	set_process(true)
	_refresh_visual_ratios()


func _polish_player_bars() -> void:
	_exp_fill_style = _make_fill(EXP_JADE)
	_hp_fill_styles = [
		_make_fill(HP_HEALTHY),
		_make_fill(HP_WARNING),
		_make_fill(HP_CRITICAL)
	]

	_exp_bar.custom_minimum_size.y = 21.0
	_hp_bar.custom_minimum_size.y = 28.0
	_exp_bar.add_theme_stylebox_override(
		"background",
		_make_track(Color(0.18, 0.74, 0.66, 1.0))
	)
	_hp_bar.add_theme_stylebox_override(
		"background",
		_make_track(Color(0.76, 0.30, 0.26, 1.0))
	)
	_exp_bar.add_theme_stylebox_override("fill", _exp_fill_style)
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill_styles[0])

	_exp_highlight = _make_fill_glint(
		_exp_bar,
		"JadeExpGlint",
		Color(0.89, 1.0, 0.96, 0.29)
	)
	_hp_highlight = _make_fill_glint(
		_hp_bar,
		"VermilionHpGlint",
		Color(1.0, 0.92, 0.76, 0.23)
	)

	var hp_label: Label = _hud.get("hp_label") as Label
	var exp_label: Label = _hud.get("exp_label") as Label
	var level_label: Label = _hud.get("level_label") as Label
	if hp_label != null:
		_style_label(hp_label, 19, IVORY)
		hp_label.custom_minimum_size.x = 154.0
	if exp_label != null:
		_style_label(exp_label, 17, IVORY)
		exp_label.custom_minimum_size.x = 94.0
	if level_label != null:
		_style_label(level_label, 19, GOLD)

	var exp_tag: Label = _hud.get_node_or_null(
		"ScreenRoot/HUDSafeArea/TopHUD/Margin/Content/StatusRow/EXPGroup/EXPHeader/EXPTag"
	) as Label
	if exp_tag != null:
		_style_label(exp_tag, 14, EXP_JADE)

	var exp_group: Control = _exp_bar.get_parent() as Control
	if exp_group != null:
		exp_group.custom_minimum_size.x = 190.0


func _polish_boss_bar() -> void:
	if _boss_bar == null:
		return
	_boss_fill_style = _make_fill(BOSS_CRIMSON)
	_boss_bar.add_theme_stylebox_override(
		"background",
		_make_track(Color(0.89, 0.50, 0.22, 1.0))
	)
	_boss_bar.add_theme_stylebox_override("fill", _boss_fill_style)

	var boss_name: Label = _hud.get("boss_name_label") as Label
	if boss_name != null:
		_style_label(boss_name, 13, GOLD)


func _make_track(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.003, 0.016, 0.023, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = accent.darkened(0.18)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.14)
	style.shadow_size = 5
	return style


func _make_fill(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = accent
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = accent.lightened(0.32)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _style_label(label_node: Label, font_size: int, accent: Color) -> void:
	label_node.add_theme_font_size_override("font_size", font_size)
	label_node.add_theme_color_override("font_color", accent)
	label_node.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.91)
	)
	label_node.add_theme_constant_override("shadow_offset_x", 1)
	label_node.add_theme_constant_override("shadow_offset_y", 1)


func _make_fill_glint(
	bar: ProgressBar,
	glint_name: String,
	accent: Color
) -> ColorRect:
	var glint: ColorRect = bar.get_node_or_null(glint_name) as ColorRect
	if glint != null:
		return glint
	glint = ColorRect.new()
	glint.name = glint_name
	glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glint.color = accent
	glint.anchor_left = 0.0
	glint.anchor_top = 0.13
	glint.anchor_right = 1.0
	glint.anchor_bottom = 0.29
	glint.offset_left = 4.0
	glint.offset_right = -4.0
	bar.clip_contents = true
	bar.add_child(glint)
	return glint


func _process(_delta: float) -> void:
	_refresh_visual_ratios()
	_check_boss_pre_warning()


func _refresh_visual_ratios() -> void:
	if _hp_bar != null and _player_health != null:
		var max_hp: float = maxf(_player_health.max_health, 1.0)
		var hp_ratio: float = clampf(_player_health.current_health / max_hp, 0.0, 1.0)
		var next_state: int = 0
		if hp_ratio <= 0.30:
			next_state = 2
		elif hp_ratio <= 0.55:
			next_state = 1
		var expected_fill: StyleBoxFlat = _hp_fill_styles[next_state]
		# The original HUD refreshes its fill style after damage. Restore the
		# premium treatment when that happens, but do not rebuild resources.
		if _hp_bar.get_theme_stylebox("fill") != expected_fill:
			_hp_bar.add_theme_stylebox_override("fill", expected_fill)
		if next_state != _health_state:
			_health_state = next_state
			if _hp_highlight != null:
				_hp_highlight.color = Color(
					1.0, 0.94, 0.82,
					0.23 if next_state == 0 else 0.31
				)
		if not is_equal_approx(hp_ratio, _last_hp_ratio):
			_last_hp_ratio = hp_ratio
			_set_glint_ratio(_hp_highlight, hp_ratio)

	if _exp_bar != null:
		var exp_ratio: float = clampf(
			_exp_bar.value / maxf(_exp_bar.max_value, 1.0),
			0.0,
			1.0
		)
		if not is_equal_approx(exp_ratio, _last_exp_ratio):
			_last_exp_ratio = exp_ratio
			_set_glint_ratio(_exp_highlight, exp_ratio)


func _set_glint_ratio(glint: ColorRect, fraction: float) -> void:
	if glint == null:
		return
	glint.visible = fraction >= 0.055
	glint.anchor_right = fraction


func _check_boss_pre_warning() -> void:
	if _boss_warning_shown or _wave_manager == null or _enemy_spawner == null:
		return
	if bool(_enemy_spawner.get("boss_spawned")):
		return
	var final_wave: int = int(_wave_manager.get("final_wave"))
	var current_wave: int = int(_wave_manager.get("current_wave"))
	if final_wave < 2 or current_wave != final_wave - 1:
		return
	var remaining: float = float(_wave_manager.get("wave_timer"))
	if remaining <= 0.0 or remaining > BOSS_PRE_WARNING_LEAD:
		return
	_boss_warning_shown = true
	_active_realm_id = _detect_realm_id()
	_active_stage_id = _detect_stage_id()
	_apply_warning_theme(_theme_for_realm(_active_realm_id), false)
	_show_boss_warning()


func _build_pre_boss_warning() -> void:
	var safe_area: Control = _hud.get_node_or_null(
		"ScreenRoot/HUDSafeArea"
	) as Control
	if safe_area == null:
		return

	_warning_panel = PanelContainer.new()
	_warning_panel.name = "BossPreWarning"
	_warning_panel.visible = false
	_warning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_panel.anchor_left = 0.115
	_warning_panel.anchor_top = 0.165
	_warning_panel.anchor_right = 0.885
	_warning_panel.anchor_bottom = 0.262
	_warning_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warning_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	safe_area.add_child(_warning_panel)

	var shell: MarginContainer = MarginContainer.new()
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_theme_constant_override("margin_left", 12)
	shell.add_theme_constant_override("margin_top", 10)
	shell.add_theme_constant_override("margin_right", 12)
	shell.add_theme_constant_override("margin_bottom", 10)
	_warning_panel.add_child(shell)

	var root: HBoxContainer = HBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 10)
	shell.add_child(root)

	_warning_side_left = _build_warning_side()
	root.add_child(_warning_side_left)

	var center: VBoxContainer = VBoxContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 2)
	root.add_child(center)

	_warning_header = Label.new()
	_warning_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_warning_header)

	_warning_main = Label.new()
	_warning_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_main.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_warning_main)

	var footer_row: HBoxContainer = HBoxContainer.new()
	footer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_row.add_theme_constant_override("separation", 8)
	center.add_child(footer_row)

	var line_left: ColorRect = ColorRect.new()
	line_left.name = "LineLeft"
	line_left.custom_minimum_size = Vector2(52.0, 2.0)
	line_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_row.add_child(line_left)

	_warning_subtitle = Label.new()
	_warning_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_row.add_child(_warning_subtitle)

	var line_right: ColorRect = ColorRect.new()
	line_right.name = "LineRight"
	line_right.custom_minimum_size = Vector2(52.0, 2.0)
	line_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_row.add_child(line_right)

	_warning_side_right = _build_warning_side()
	root.add_child(_warning_side_right)

	_warning_stage_chip = PanelContainer.new()
	_warning_stage_chip.name = "StageTag"
	_warning_stage_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_stage_chip.anchor_left = 0.5
	_warning_stage_chip.anchor_right = 0.5
	_warning_stage_chip.anchor_top = 1.0
	_warning_stage_chip.anchor_bottom = 1.0
	_warning_stage_chip.offset_left = -92.0
	_warning_stage_chip.offset_right = 92.0
	_warning_stage_chip.offset_top = -11.0
	_warning_stage_chip.offset_bottom = 17.0
	_warning_stage_chip.z_index = 2
	_warning_panel.add_child(_warning_stage_chip)

	_warning_stage_label = Label.new()
	_warning_stage_label.anchor_right = 1.0
	_warning_stage_label.anchor_bottom = 1.0
	_warning_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning_stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_stage_chip.add_child(_warning_stage_label)

	_apply_warning_theme(_theme_for_realm(_active_realm_id), false)


func _build_warning_side() -> Control:
	var side: MarginContainer = MarginContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override("margin_top", 8)
	side.add_theme_constant_override("margin_bottom", 8)

	var holder: VBoxContainer = VBoxContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 6)
	side.add_child(holder)

	for idx in 3:
		var chip: ColorRect = ColorRect.new()
		chip.name = "Chip%d" % idx
		chip.custom_minimum_size = Vector2(12.0 if idx == 1 else 8.0, 12.0 if idx == 1 else 8.0)
		chip.rotation_degrees = 45.0
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(chip)

	return side


func _warning_copy(english_text: String, indonesian_text: String) -> String:
	return (
		indonesian_text
		if str(SettingsManager.language).begins_with("id")
		else english_text
	)


func _theme_for_realm(realm_id: int) -> Dictionary:
	if realm_id == 4:
		return {
			"panel_bg": Color(0.015, 0.062, 0.082, 0.94),
			"panel_bg_2": Color(0.006, 0.024, 0.034, 0.96),
			"border": Color(0.41, 0.97, 1.0, 1.0),
			"border_outer": Color(0.92, 0.78, 0.38, 0.96),
			"title": Color(0.95, 0.98, 1.0, 1.0),
			"header": Color(0.68, 0.96, 1.0, 1.0),
			"subtitle": Color(0.94, 0.84, 0.56, 1.0),
			"line": Color(0.36, 0.88, 1.0, 0.86),
			"chip": Color(0.76, 0.98, 1.0, 0.92),
			"stage_bg": Color(0.05, 0.15, 0.20, 0.98),
			"stage_border": Color(0.92, 0.80, 0.46, 0.96),
			"shadow": Color(0.15, 0.95, 1.0, 0.24),
			"pre_header_en": "FROST SIGIL • FINAL WAVE",
			"pre_header_id": "SIGIL EMBUN • GELOMBANG TERAKHIR",
			"pre_main_en": "THE FROST LORD AWAKENS",
			"pre_main_id": "PENGUASA FROST TERBANGUN",
			"pre_sub_en": "Steady your breath • gather your qi",
			"pre_sub_id": "Tenangkan napas • kumpulkan qi-mu",
			"realm_tag": "FROSTVEIL ABYSS",
			"arrival_header": "PHASE %d",
			"stage_tag": "TRIAL %d-%d"
		}
	elif realm_id == 5:
		return {
			"panel_bg": Color(0.086, 0.020, 0.010, 0.95),
			"panel_bg_2": Color(0.034, 0.010, 0.006, 0.97),
			"border": Color(1.0, 0.48, 0.20, 1.0),
			"border_outer": Color(1.0, 0.84, 0.42, 0.96),
			"title": Color(1.0, 0.97, 0.91, 1.0),
			"header": Color(1.0, 0.77, 0.31, 1.0),
			"subtitle": Color(1.0, 0.89, 0.58, 1.0),
			"line": Color(1.0, 0.56, 0.19, 0.88),
			"chip": Color(1.0, 0.90, 0.56, 0.94),
			"stage_bg": Color(0.19, 0.07, 0.02, 0.99),
			"stage_border": Color(1.0, 0.84, 0.42, 0.96),
			"shadow": Color(1.0, 0.42, 0.12, 0.28),
			"pre_header_en": "SOLAR OATH • FINAL WAVE",
			"pre_header_id": "SUMPAH SURYA • GELOMBANG TERAKHIR",
			"pre_main_en": "THE SUN THRONE DESCENDS",
			"pre_main_id": "TAHTA SURYA TURUN",
			"pre_sub_en": "Brace your spirit • withstand the blaze",
			"pre_sub_id": "Siapkan jiwamu • tahan kobaran api",
			"realm_tag": "SOLAR NIRVANA",
			"arrival_header": "PHASE %d",
			"stage_tag": "TRIAL %d-%d"
		}
	return {
		"panel_bg": Color(0.061, 0.009, 0.012, 0.94),
		"panel_bg_2": Color(0.022, 0.009, 0.012, 0.96),
		"border": Color(1.0, 0.66, 0.25, 0.95),
		"border_outer": Color(0.96, 0.35, 0.18, 0.95),
		"title": IVORY,
		"header": Color(1.0, 0.62, 0.31, 1.0),
		"subtitle": GOLD,
		"line": Color(1.0, 0.43, 0.20, 0.78),
		"chip": Color(1.0, 0.84, 0.52, 0.90),
		"stage_bg": Color(0.10, 0.03, 0.02, 0.99),
		"stage_border": Color(1.0, 0.66, 0.25, 0.95),
		"shadow": Color(0.94, 0.19, 0.14, 0.34),
		"pre_header_en": "DANGER • FINAL WAVE",
		"pre_header_id": "BAHAYA • GELOMBANG TERAKHIR",
		"pre_main_en": "BOSS APPROACHING",
		"pre_main_id": "BOSS SEGERA MUNCUL",
		"pre_sub_en": "Prepare your qi",
		"pre_sub_id": "Siapkan qi-mu",
		"realm_tag": "BOSS ENCOUNTER",
		"arrival_header": "PHASE %d",
		"stage_tag": "TRIAL %d-%d"
	}


func _apply_warning_theme(theme: Dictionary, is_arrival: bool) -> void:
	if _warning_panel == null:
		return
	_warning_panel.add_theme_stylebox_override(
		"panel",
		_make_warning_style(theme, is_arrival)
	)
	if _warning_header != null:
		_warning_header.text = _warning_copy(
			str(theme.get("pre_header_en", "DANGER • FINAL WAVE")),
			str(theme.get("pre_header_id", "BAHAYA • GELOMBANG TERAKHIR"))
		)
		_style_label(_warning_header, 13, theme.get("header", GOLD))
	if _warning_main != null:
		_warning_main.text = _warning_copy(
			str(theme.get("pre_main_en", "BOSS APPROACHING")),
			str(theme.get("pre_main_id", "BOSS SEGERA MUNCUL"))
		)
		_style_label(_warning_main, 26, theme.get("title", IVORY))
	if _warning_subtitle != null:
		_warning_subtitle.text = _warning_copy(
			str(theme.get("pre_sub_en", "Prepare your qi")),
			str(theme.get("pre_sub_id", "Siapkan qi-mu"))
		)
		_style_label(_warning_subtitle, 12, theme.get("subtitle", GOLD))
	if _warning_stage_chip != null:
		_warning_stage_chip.add_theme_stylebox_override(
			"panel",
			_make_stage_tag_style(theme)
		)
	if _warning_stage_label != null:
		_warning_stage_label.text = "%s  •  %s" % [
			str(theme.get("realm_tag", "BOSS ENCOUNTER")),
			str(theme.get("stage_tag", "TRIAL %d-%d") % [_active_realm_id, maxi(_active_stage_id, 1)])
		]
		_style_label(_warning_stage_label, 11, theme.get("subtitle", GOLD))
		_warning_stage_label.clip_text = true

	var shell: Control = _warning_panel.get_child(0) as Control
	if shell != null:
		var center_root: HBoxContainer = shell.get_child(0) as HBoxContainer
		if center_root != null:
			var center: VBoxContainer = center_root.get_child(1) as VBoxContainer
			if center != null:
				var footer_row: HBoxContainer = center.get_child(2) as HBoxContainer
				if footer_row != null:
					for line_name in ["LineLeft", "LineRight"]:
						var line_node: ColorRect = footer_row.get_node_or_null(line_name) as ColorRect
						if line_node != null:
							line_node.color = theme.get("line", GOLD)

	_apply_warning_side_theme(_warning_side_left, theme)
	_apply_warning_side_theme(_warning_side_right, theme)


func _make_warning_style(theme: Dictionary, is_arrival: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = theme.get("panel_bg", Color(0.061, 0.009, 0.012, 0.94))
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = theme.get("border_outer", GOLD)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = theme.get("shadow", Color(0.94, 0.19, 0.14, 0.34))
	style.shadow_size = 16 if is_arrival else 13
	style.draw_center = true
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _make_stage_tag_style(theme: Dictionary) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = theme.get("stage_bg", Color(0.10, 0.03, 0.02, 0.99))
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = theme.get("stage_border", GOLD)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 10
	style.content_margin_top = 2
	style.content_margin_right = 10
	style.content_margin_bottom = 2
	return style


func _apply_warning_side_theme(side: Control, theme: Dictionary) -> void:
	if side == null:
		return
	var holder: VBoxContainer = side.get_child(0) as VBoxContainer
	if holder == null:
		return
	for child in holder.get_children():
		var chip: ColorRect = child as ColorRect
		if chip != null:
			chip.color = theme.get("chip", GOLD)


func _show_boss_warning() -> void:
	if _warning_panel == null:
		return
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()
	_warning_panel.visible = true
	_warning_panel.scale = Vector2.ONE
	_warning_panel.modulate = Color.WHITE

	_warning_tween = _warning_panel.create_tween()
	if bool(SettingsManager.reduced_effects):
		_warning_tween.tween_interval(BOSS_PRE_WARNING_HOLD)
		_warning_tween.tween_callback(_hide_boss_warning)
		return

	_warning_panel.pivot_offset = _warning_panel.size * 0.5
	_warning_panel.scale = Vector2(0.90, 0.90)
	_warning_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_warning_panel.position = Vector2(0.0, -16.0)
	_warning_tween.tween_property(
		_warning_panel,
		"modulate:a",
		1.0,
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_warning_tween.parallel().tween_property(
		_warning_panel,
		"scale",
		Vector2.ONE,
		0.28
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_warning_tween.parallel().tween_property(
		_warning_panel,
		"position:y",
		_warning_panel.position.y + 16.0,
		0.26
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_warning_tween.tween_interval(BOSS_PRE_WARNING_HOLD - 0.54)
	_warning_tween.tween_property(
		_warning_panel,
		"modulate:a",
		0.0,
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_warning_tween.parallel().tween_property(
		_warning_panel,
		"scale",
		Vector2(0.97, 0.97),
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_warning_tween.tween_callback(_hide_boss_warning)


func _hide_boss_warning() -> void:
	if _warning_panel == null:
		return
	_warning_panel.visible = false
	_warning_panel.modulate = Color.WHITE
	_warning_panel.scale = Vector2.ONE
	_warning_panel.position = Vector2.ZERO


func _on_boss_spawned(boss: Node) -> void:
	_boss_warning_shown = true
	if boss != null and is_instance_valid(boss):
		_active_realm_id = int(boss.get("realm_id")) if boss.get("realm_id") != null else _detect_realm_id()
		_active_stage_id = int(boss.get("boss_stage_id")) if boss.get("boss_stage_id") != null else _detect_stage_id()
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()
	_hide_boss_warning()
	# The HUD applies the original boss banner inside this same spawn signal.
	# Defer to extend the already-instantiated banner instead of replaying it.
	call_deferred("_extend_boss_arrival_banner", boss)


func _extend_boss_arrival_banner(boss: Node) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	if bool(boss.get("is_dead")):
		return
	if _hud == null:
		return

	var banner: PanelContainer = _hud.get("_encounter_banner") as PanelContainer
	if banner == null or not banner.visible:
		return
	var old_tween: Tween = _hud.get("_encounter_banner_tween") as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()

	var realm_id: int = int(boss.get("realm_id")) if boss.get("realm_id") != null else _active_realm_id
	var stage_id: int = int(boss.get("boss_stage_id")) if boss.get("boss_stage_id") != null else _active_stage_id
	var current_phase: int = int(boss.get("current_phase")) if boss.get("current_phase") != null else 1
	var theme: Dictionary = _theme_for_realm(realm_id)

	var banner_name: Label = _hud.get("_encounter_banner_name") as Label
	var banner_phase: Label = _hud.get("_encounter_banner_phase") as Label
	if banner_name != null:
		var long_name: bool = banner_name.text.length() >= 29
		_style_label(banner_name, 24 if long_name else 28, theme.get("title", IVORY))
		banner_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if banner_phase != null:
		banner_phase.text = str(theme.get("arrival_header", "PHASE %d") % current_phase)
		_style_label(banner_phase, 14, theme.get("header", GOLD))

	banner.add_theme_stylebox_override(
		"panel",
		_make_warning_style(theme, true)
	)
	# More compact, less gameplay occlusion, and positioned as a ceremonial plaque
	# beneath the boss HP strip.
	banner.anchor_left = 0.12
	banner.anchor_top = 0.165
	banner.anchor_right = 0.88
	banner.anchor_bottom = 0.275
	banner.visible = true
	banner.scale = Vector2.ONE
	banner.modulate = Color.WHITE

	_add_arrival_ornaments(banner, theme, realm_id, stage_id)

	var name_tween: Tween = banner.create_tween()
	if bool(SettingsManager.reduced_effects):
		name_tween.tween_interval(BOSS_ARRIVAL_NAME_HOLD)
	else:
		banner.pivot_offset = banner.size * 0.5
		banner.scale = Vector2(0.92, 0.92)
		banner.modulate = Color(1.0, 0.95, 0.84, 0.0)
		banner.position = Vector2(0.0, -12.0)
		name_tween.tween_property(
			banner,
			"modulate",
			Color.WHITE,
			0.20
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		name_tween.parallel().tween_property(
			banner,
			"scale",
			Vector2.ONE,
			0.28
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		name_tween.parallel().tween_property(
			banner,
			"position:y",
			banner.position.y + 12.0,
			0.26
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		name_tween.tween_interval(BOSS_ARRIVAL_NAME_HOLD)
		name_tween.tween_property(
			banner,
			"modulate:a",
			0.0,
			BOSS_ARRIVAL_FADE
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	name_tween.tween_callback(Callable(_hud, "_hide_encounter_banner"))
	_hud.set("_encounter_banner_tween", name_tween)


func _add_arrival_ornaments(banner: PanelContainer, theme: Dictionary, realm_id: int, stage_id: int) -> void:
	if banner == null:
		return
	var old: Control = banner.get_node_or_null("EncounterArrivalPolish") as Control
	if old != null:
		old.queue_free()

	var overlay: Control = Control.new()
	overlay.name = "EncounterArrivalPolish"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.z_index = 2
	banner.add_child(overlay)

	var top_line: ColorRect = ColorRect.new()
	top_line.anchor_left = 0.08
	top_line.anchor_right = 0.92
	top_line.anchor_top = 0.19
	top_line.anchor_bottom = 0.19
	top_line.offset_top = -1
	top_line.offset_bottom = 1
	top_line.color = theme.get("line", GOLD)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(top_line)

	var bottom_line: ColorRect = ColorRect.new()
	bottom_line.anchor_left = 0.10
	bottom_line.anchor_right = 0.90
	bottom_line.anchor_top = 0.80
	bottom_line.anchor_bottom = 0.80
	bottom_line.offset_top = -1
	bottom_line.offset_bottom = 1
	bottom_line.color = theme.get("line", GOLD)
	bottom_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bottom_line)

	for side_name in ["Left", "Right"]:
		var sigil: ColorRect = ColorRect.new()
		sigil.name = side_name + "Sigil"
		sigil.custom_minimum_size = Vector2(14.0, 14.0)
		sigil.color = theme.get("chip", GOLD)
		sigil.rotation_degrees = 45.0
		sigil.anchor_left = 0.08 if side_name == "Left" else 0.92
		sigil.anchor_right = sigil.anchor_left
		sigil.anchor_top = 0.50
		sigil.anchor_bottom = 0.50
		sigil.offset_left = -7.0
		sigil.offset_right = 7.0
		sigil.offset_top = -7.0
		sigil.offset_bottom = 7.0
		sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(sigil)

	var tag: Label = Label.new()
	tag.name = "RealmTag"
	tag.text = "%s  •  %s" % [
		str(theme.get("realm_tag", "BOSS ENCOUNTER")),
		str(theme.get("stage_tag", "TRIAL %d-%d") % [realm_id, maxi(stage_id, 1)])
	]
	tag.anchor_left = 0.20
	tag.anchor_right = 0.80
	tag.anchor_top = 0.03
	tag.anchor_bottom = 0.18
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(tag, 10, theme.get("subtitle", GOLD))
	overlay.add_child(tag)


func _detect_realm_id() -> int:
	if _level_root != null and _level_root.has_method("get"):
		var candidate: Variant = _level_root.get("realm_id")
		if candidate != null:
			return int(candidate)
	var scene_name: String = str(_level_root.name if _level_root != null else "")
	if scene_name.begins_with("Stage_4_"):
		return 4
	if scene_name.begins_with("Stage_5_"):
		return 5
	return REALM_FALLBACK


func _detect_stage_id() -> int:
	if _level_root != null and _level_root.has_method("get"):
		var candidate: Variant = _level_root.get("stage_id")
		if candidate != null:
			return int(candidate)
	var scene_name: String = str(_level_root.name if _level_root != null else "")
	var chunks: PackedStringArray = scene_name.split("_")
	if chunks.size() >= 3:
		return int(chunks[chunks.size() - 1])
	return 0
