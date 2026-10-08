extends Control

## Read-only, paused snapshot of the active combat character.
## Does not calculate weapon damage, mutate combat, or write checkpoints.
const EquipmentSetRuntime = preload("res://scripts/data/equipment_set_runtime.gd")
const JADE: Color = Color(0.20, 0.92, 0.78, 1.0)
const GOLD: Color = Color(0.98, 0.79, 0.30, 1.0)
const IVORY: Color = Color(0.96, 0.94, 0.84, 1.0)

var _player: Node = null
var _health: PlayerHealth = null
var _rows: Dictionary = {}
var _owns_pause: bool = false
var _frame_style: StyleBox = null


func setup(player_node: Node, health_node: PlayerHealth, frame_style: StyleBox) -> void:
	_player = player_node
	_health = health_node
	_frame_style = frame_style
	if is_node_ready():
		_apply_frame_style()


func _ready() -> void:
	name = "InRunStatsOverlay"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_panel()
	_apply_frame_style()


func open_snapshot() -> void:
	if visible or get_tree().paused:
		return
	if not is_instance_valid(_player) or not is_instance_valid(_health):
		return
	var stats: Node = _player.get_node_or_null("PlayerStats")
	if stats == null:
		return
	_refresh_snapshot(stats)
	_owns_pause = true
	visible = true
	get_tree().paused = true


func close_snapshot() -> void:
	if not visible:
		return
	visible = false
	if _owns_pause:
		_owns_pause = false
		get_tree().paused = false


func _exit_tree() -> void:
	if _owns_pause:
		_owns_pause = false
		get_tree().paused = false


func _build_panel() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.001, 0.010, 0.016, 0.83)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var safe := MarginContainer.new()
	safe.name = "SafeMargin"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 20)
	add_child(safe)

	var centered := CenterContainer.new()
	centered.name = "Center"
	centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(centered)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(540.0, 805.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	centered.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)

	var title := Label.new()
	title.text = "IN-RUN STATS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(94, 44)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_snapshot)
	header.add_child(close_button)

	var description := Label.new()
	description.text = "Current combat snapshot. The run is paused while this is open."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", IVORY)
	content.add_child(description)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	content.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	scroll.add_child(body)

	_add_section(body, "SURVIVAL")
	_add_row(body, "hp", "CURRENT HP")
	_add_row(body, "shield", "QI SHIELD CHARGES")
	_add_row(body, "body_refinement", "BODY REFINEMENT")
	_add_section(body, "COMBAT - LIVE SNAPSHOT")
	_add_row(body, "power", "POWER MULTIPLIER")
	_add_row(body, "damage", "PRE-HIT DAMAGE MULTIPLIER")
	_add_row(body, "conditional", "ACTIVE HIT BONUS")
	_add_row(body, "crit_rate", "CRITICAL CHANCE")
	_add_row(body, "crit_damage", "CRITICAL DAMAGE")
	_add_row(body, "sword_intent", "SWORD INTENT")
	_add_row(body, "attack_speed", "ATTACK SPEED BONUS")
	_add_section(body, "MOBILITY AND GROWTH")
	_add_row(body, "movement", "MAX MOVEMENT SPEED")
	_add_row(body, "exp", "EXP MULTIPLIER")

	var footnote := Label.new()
	footnote.text = "Damage excludes each weapon's base damage and critical roll. Attack speed excludes weapon-specific cooldown and its 0.1s floor."
	footnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footnote.add_theme_font_size_override("font_size", 13)
	footnote.add_theme_color_override("font_color", IVORY)
	content.add_child(footnote)


func _apply_frame_style() -> void:
	var panel: PanelContainer = get_node_or_null("SafeMargin/Center/Panel") as PanelContainer
	if panel != null and _frame_style != null:
		panel.add_theme_stylebox_override("panel", _frame_style.duplicate(true))


func _add_section(parent: VBoxContainer, caption: String) -> void:
	var section := Label.new()
	section.text = caption
	section.add_theme_font_size_override("font_size", 16)
	section.add_theme_color_override("font_color", GOLD)
	parent.add_child(section)


func _add_row(parent: VBoxContainer, key: String, caption: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 38.0
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", IVORY)
	row.add_child(name_label)
	var value := Label.new()
	value.text = "--"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 17)
	value.add_theme_color_override("font_color", JADE)
	row.add_child(value)
	_rows[key] = value


func _set_value(key: String, value: String) -> void:
	var label: Label = _rows.get(key, null) as Label
	if label != null:
		label.text = value


func _refresh_snapshot(stats: Node) -> void:
	var current_hp: float = float(_health.current_health)
	var max_hp: float = maxf(float(_health.max_health), 0.001)
	_set_value("hp", "%.0f / %.0f" % [current_hp, max_hp])
	_set_value("shield", str(_health.qi_shield_charges))
	_set_value("body_refinement", "LV %d" % int(_health.body_refinement_level))

	var power: float = float(stats.get("power_multiplier"))
	var equipment_damage: float = (
		EquipmentManager.get_damage_multiplier()
		+ EquipmentSetRuntime.get_bonus("damage_bonus")
	)
	_set_value("power", "%.3fx" % power)
	_set_value("damage", "%.3fx" % (power * equipment_damage))

	var hit_bonus: float = 0.0
	var actor: CharacterBody2D = _player as CharacterBody2D
	if actor != null and actor.velocity.length_squared() > 1.0:
		hit_bonus += EquipmentSetRuntime.get_capped_combined_secondary_bonus(
			"moving_damage_bonus", 0.08
		)
	else:
		hit_bonus += EquipmentSetRuntime.get_bonus("stationary_damage_bonus")
	var hp_ratio: float = current_hp / max_hp
	if hp_ratio <= 0.50:
		hit_bonus += EquipmentSetRuntime.get_capped_combined_secondary_bonus(
			"low_health_damage_bonus", 0.10
		)
	elif hp_ratio >= 0.80:
		hit_bonus += EquipmentSetRuntime.get_bonus("high_health_damage_bonus")
	_set_value("conditional", "+%.1f%%" % (hit_bonus * 100.0))

	_set_value("crit_rate", "%.1f%%" % (
		float(stats.call("get_critical_chance")) * 100.0
	))
	var crit_damage: float = 2.0 + EquipmentSetRuntime.get_capped_combined_secondary_bonus(
		"critical_damage_bonus", 0.15
	)
	_set_value("crit_damage", "%.0f%%" % (crit_damage * 100.0))
	_set_value("sword_intent", "LV %d" % int(stats.get("sword_intent_level")))

	var cooldown_reduction: float = EquipmentSetRuntime.get_capped_combined_secondary_bonus(
		"attack_cooldown_reduction", 0.10
	)
	var cooldown_factor: float = maxf(
		float(stats.get("attack_cooldown")) * maxf(1.0 - cooldown_reduction, 0.50),
		0.0001
	)
	_set_value("attack_speed", "+%.1f%%" % (
		(maxf(1.0 / cooldown_factor, 0.0) - 1.0) * 100.0
	))
	if _player.has_method("get_effective_movement_speed"):
		_set_value("movement", "%.0f px/s" % float(
			_player.call("get_effective_movement_speed")
		))
	if _player.has_method("get_experience_multiplier"):
		_set_value("exp", "%.3fx" % float(
			_player.call("get_experience_multiplier")
		))
