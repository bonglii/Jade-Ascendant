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
var _panel: PanelContainer
var _previous_back: Callable
var _caption_rows: Dictionary = {}
var _sections: Array[Label] = []

func _id() -> bool:
	return str(get_node("/root/SettingsManager").get("language")) == "id"

func _text(english: String, indonesian: String) -> String:
	return indonesian if _id() else english


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
	resized.connect(_fit)
	_fit.call_deferred()
	preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(self)


func open_snapshot() -> void:
	if visible or get_tree().paused:
		return
	if not is_instance_valid(_player) or not is_instance_valid(_health):
		return
	var stats: Node = _player.get_node_or_null("PlayerStats")
	if stats == null:
		return
	_refresh_language()
	_refresh_snapshot(stats)
	_owns_pause = true
	visible = true
	get_tree().paused = true
	var transition: Node = get_node("/root/SceneTransitionManager")
	_previous_back = transition.back_handler
	transition.set_back_handler(close_snapshot)
	_fit.call_deferred()


func close_snapshot() -> void:
	if not visible:
		return
	visible = false
	_restore_back()
	if _owns_pause:
		_owns_pause = false
		get_tree().paused = false


func _exit_tree() -> void:
	_restore_back()
	if _owns_pause:
		_owns_pause = false
		get_tree().paused = false

func _restore_back() -> void:
	var transition: Node = get_node_or_null("/root/SceneTransitionManager")
	if transition != null and transition.back_handler == Callable(self, "close_snapshot"):
		transition.set_back_handler(_previous_back)

func _fit() -> void:
	if not is_instance_valid(_panel) or size.x <= 1.0 or size.y <= 1.0:
		return
	var desired: Vector2 = Vector2(minf(540.0, size.x - 32.0), minf(805.0, size.y - 40.0))
	_panel.custom_minimum_size = desired
	_panel.size = desired


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
	_panel = panel
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	centered.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
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
	title.name = "CombatStatsTitle"
	title.text = _text("COMBAT STATS", "STAT COMBAT")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)

	var close_button := Button.new()
	close_button.name = "CloseCombatStats"
	close_button.text = _text("CLOSE", "TUTUP")
	preload("res://scripts/ui/result_ceremony.gd").style_button(close_button, "navy")
	close_button.add_theme_font_size_override("font_size", 13)
	close_button.custom_minimum_size = Vector2(72, 46)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_snapshot)
	header.add_child(close_button)

	var description := Label.new()
	description.name = "CombatStatsDescription"
	description.text = _text("Your active build. Combat is paused.", "Build aktifmu. Combat dijeda.")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", IVORY)
	content.add_child(description)

	var scroll := ScrollContainer.new()
	scroll.name = "CombatStatsScroll"
	scroll.custom_minimum_size.y = 80
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	content.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	scroll.add_child(body)

	_add_section(body, "SURVIVAL", "PERTAHANAN")
	_add_row(body, "hp", "CURRENT HP")
	_add_row(body, "shield", "QI SHIELD CHARGES")
	_add_row(body, "body_refinement", "BODY REFINEMENT")
	_add_section(body, "DAMAGE & GROWTH", "DAMAGE & PERTUMBUHAN")
	_add_row(body, "power", "POWER MULTIPLIER")
	_add_row(body, "damage", "PRE-HIT DAMAGE MULTIPLIER")
	_add_row(body, "conditional", "ACTIVE HIT BONUS")
	_add_row(body, "crit_rate", "CRITICAL CHANCE")
	_add_row(body, "crit_damage", "CRITICAL DAMAGE")
	_add_row(body, "sword_intent", "SWORD INTENT")
	_add_row(body, "attack_speed", "CAST SPEED BEFORE LIMITS")
	_add_section(body, "ACTIVE WEAPONS", "SENJATA AKTIF")
	_add_row(body, "weapon_spirit_sword", "SPIRIT SWORD")
	_add_row(body, "weapon_fire_orb", "FIRE ORB")
	_add_row(body, "weapon_thunder_talisman", "THUNDER TALISMAN")
	_add_row(body, "weapon_yin_yang_blades", "YIN-YANG BLADES")
	_add_row(body, "weapon_heavenly_sword_rain", "HEAVENLY SWORD RAIN")
	_add_row(body, "weapon_eight_trigrams_formation", "EIGHT TRIGRAMS")
	_add_section(body, "RESONANCE UNLOCKS", "RESONANSI")
	_add_row(body, "resonance_sword", "SWORD DAO")
	_add_row(body, "resonance_reversal", "YIN-YANG REVERSAL")
	_add_row(body, "resonance_tribulation", "HEAVENLY TRIBULATION")
	_add_section(body, "MOBILITY AND GROWTH", "GERAK & EXP")
	_add_row(body, "movement", "MAX MOVEMENT SPEED")
	_add_row(body, "exp", "EXP MULTIPLIER")

	var footnote := Label.new()
	footnote.name = "CombatStatsFootnote"
	footnote.text = _text("CAST: cast interval. TEMPO: cast potency.\nOrbit/formation use separate hit timers.", "CAST: jeda cast. TEMPO: kekuatan cast.\nOrbit/formasi punya jeda hit sendiri.")
	footnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footnote.add_theme_font_size_override("font_size", 12)
	footnote.add_theme_color_override("font_color", IVORY)
	content.add_child(footnote)


func _refresh_language() -> void:
	var title: Label = find_child("CombatStatsTitle", true, false) as Label
	var close: Button = find_child("CloseCombatStats", true, false) as Button
	var description: Label = find_child("CombatStatsDescription", true, false) as Label
	var note: Label = find_child("CombatStatsFootnote", true, false) as Label
	title.text = _text("COMBAT STATS", "STAT COMBAT")
	close.text = _text("CLOSE", "TUTUP")
	description.text = _text("Your active build. Combat is paused.", "Build aktifmu. Combat dijeda.")
	note.text = _text("CAST: cast interval. TEMPO: cast potency.\nOrbit/formation use separate hit timers.", "CAST: jeda cast. TEMPO: kekuatan cast.\nOrbit/formasi punya jeda hit sendiri.")
	for section: Label in _sections:
		var captions: Array = section.get_meta("combat_captions")
		section.text = _text(str(captions[0]), str(captions[1]))
	var captions: Dictionary = {
		"hp": ["CURRENT HP", "HP SAAT INI"], "shield": ["QI SHIELD CHARGES", "MUATAN QI SHIELD"],
		"body_refinement": ["BODY REFINEMENT", "BODY REFINEMENT"], "power": ["POWER MULTIPLIER", "PENGALI POWER"],
		"damage": ["BASE DAMAGE MULTIPLIER", "PENGALI DAMAGE DASAR"], "conditional": ["ACTIVE HIT BONUS", "BONUS HIT AKTIF"],
		"crit_rate": ["CRITICAL CHANCE", "PELUANG CRITICAL"], "crit_damage": ["CRITICAL DAMAGE", "DAMAGE CRITICAL"],
		"sword_intent": ["SWORD INTENT", "SWORD INTENT"], "attack_speed": ["CAST SPEED BEFORE LIMITS", "SPEED SEBELUM BATAS CAST"],
		"movement": ["MAX MOVEMENT SPEED", "KECEPATAN GERAK"], "exp": ["EXP MULTIPLIER", "PENGALI EXP"]
	}
	for key: String in captions:
		var label: Label = _caption_rows.get(key) as Label
		if label != null:
			label.text = _text(str(captions[key][0]), str(captions[key][1]))



func _apply_frame_style() -> void:
	var panel: PanelContainer = get_node_or_null("SafeMargin/Center/Panel") as PanelContainer
	if panel != null:
		var frame := StyleBoxTexture.new()
		frame.texture = preload("res://assets/ui/trials/ascendant_v2/record_frame.svg")
		for edge: String in ["left", "right", "top", "bottom"]:
			frame.set("texture_margin_" + edge, 18)
			frame.set("content_margin_" + edge, 0)
		panel.add_theme_stylebox_override("panel", frame)


func _add_section(parent: VBoxContainer, caption: String, translation: String) -> void:
	var section := Label.new()
	section.text = _text(caption, translation)
	section.set_meta("combat_captions", [caption, translation])
	_sections.append(section)
	section.add_theme_font_size_override("font_size", 16)
	section.add_theme_color_override("font_color", GOLD)
	parent.add_child(section)


func _add_row(parent: VBoxContainer, key: String, caption: String) -> void:
	var row := VBoxContainer.new()
	row.custom_minimum_size.y = 38.0
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = caption
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", IVORY)
	row.add_child(name_label)
	var value := Label.new()
	value.text = "--"
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_size_override("font_size", 17)
	value.add_theme_color_override("font_color", JADE)
	row.add_child(value)
	_rows[key] = value
	_caption_rows[key] = name_label


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

	var hit_bonus: float = float(stats.call("get_conditional_damage_bonus", true))
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
			_player.call("get_effective_movement_speed", true)
		))
	if _player.has_method("get_experience_multiplier"):
		_set_value("exp", "%.3fx" % float(
			_player.call("get_experience_multiplier")
		))
	_refresh_live_loadout(stats)


func _refresh_live_loadout(stats: Node) -> void:
	# Snapshot-only: no gameplay calculation, no timers, no equipment mutation.
	var manager: Node = _player.get_node_or_null("WeaponManager")
	var weapon_specs: Array[Dictionary] = [
		{"key": "weapon_spirit_sword", "name": "Spirit Sword"},
		{"key": "weapon_fire_orb", "name": "Fire Orb"},
		{"key": "weapon_thunder_talisman", "name": "Thunder Talisman"},
		{"key": "weapon_yin_yang_blades", "name": "Yin-Yang Blades"},
		{"key": "weapon_heavenly_sword_rain", "name": "Heavenly Sword Rain"},
		{"key": "weapon_eight_trigrams_formation", "name": "Eight Trigrams Formation"}
	]
	for spec: Dictionary in weapon_specs:
		var key: String = str(spec["key"])
		var weapon: Node = null
		if manager != null and manager.has_method("get_weapon_by_name"):
			weapon = manager.call("get_weapon_by_name", str(spec["name"])) as Node
		var value_label: Label = _rows.get(key, null) as Label
		if value_label == null:
			continue
		var row: Control = value_label.get_parent() as Control
		if row != null:
			row.visible = weapon != null and is_instance_valid(weapon)
		if weapon != null and is_instance_valid(weapon):
			if key == "weapon_spirit_sword" and row != null:
				var caption: Label = row.get_child(0) as Label
				if caption != null: caption.text = weapon.get_combat_display_name().to_upper()
			_set_value(key, "LV %d" % int(weapon.get("level")))
			var cadence: Dictionary = manager.get_cadence_snapshot(weapon)
			var cadence_text: String = "LV %d  ·  CAST %.2fs" % [int(weapon.get("level")), float(cadence.seconds)]
			if key == "weapon_yin_yang_blades":
				cadence_text = "LV %d  ·  ORBIT %.2fs" % [int(weapon.get("level")), TAU / float(weapon.get_current_orbit_speed())]
			if bool(cadence.tempo):
				cadence_text += "  ·  TEMPO %.2f×" % float(cadence.potency)
			_set_value(key, cadence_text)

	var sword_unlocked: bool = (
		stats.has_method("has_sword_dao_resonance")
		and bool(stats.call("has_sword_dao_resonance"))
	)
	var reversal_unlocked: bool = (
		stats.has_method("has_yin_yang_reversal")
		and bool(stats.call("has_yin_yang_reversal"))
	)
	var tribulation_unlocked: bool = (
		stats.has_method("has_heavenly_tribulation")
		and bool(stats.call("has_heavenly_tribulation"))
	)
	_set_value("resonance_sword", "UNLOCKED" if sword_unlocked else "LOCKED")
	_set_value("resonance_tribulation", "UNLOCKED" if tribulation_unlocked else "LOCKED")

	var reversal_text: String = "UNLOCKED" if reversal_unlocked else "LOCKED"
	var reversal_active: bool = false
	if reversal_unlocked and manager != null and manager.has_method("get_weapon_by_name"):
		var blades: Node = manager.call("get_weapon_by_name", "Yin-Yang Blades") as Node
		if blades != null and is_instance_valid(blades):
			reversal_active = bool(blades.get("reversal_active"))
			if reversal_active:
				var remaining: float = maxf(float(blades.get("reversal_time_remaining")), 0.0)
				reversal_text = "ACTIVE %.1fs" % remaining
	_set_value("resonance_reversal", reversal_text)
	var reversal_label: Label = _rows.get("resonance_reversal", null) as Label
	if reversal_label != null:
		reversal_label.add_theme_color_override(
			"font_color", GOLD if reversal_active else JADE
		)
