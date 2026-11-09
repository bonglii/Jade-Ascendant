extends VBoxContainer
## Read-only comparison of permanent weapon bonuses and progression.
const Visual = preload("res://scripts/ui/equipment_visual_catalog.gd")
const Guidance = preload("res://scripts/data/build_guidance_catalog.gd")
const Sheet = preload("res://scripts/companion/player_journal.gd")
const SERIF: Font = preload("res://assets/ui/library/fonts/archive_serif.ttf")
const STARTER_ICON: Texture2D = preload("res://assets/ui/level_up/skill_art/spirit_sword.png")
const MUTED := Color("acc8bf")
const DOWN := Color("f6a089")
const ROWS := [
	["damage_bonus", "Gear damage", "Damage gear", true],
	["weapon_damage_multiplier", "Level damage", "Damage level", true],
	["max_health_flat", "Gear HP", "HP gear", false],
	["critical_chance_bonus", "Crit chance", "Peluang crit", true],
	["critical_damage_bonus", "Crit damage", "Damage crit", true],
	["attack_cooldown_reduction", "Cooldown cut", "Potong cooldown", true],
	["low_health_damage_bonus", "Dmg ≤50% HP", "Dmg ≤50% HP", true],
	["movement_speed_bonus", "Movement", "Gerak", true],
	["experience_bonus", "EXP", "EXP", true],
	["pickup_radius_bonus", "Pickup range", "Jarak ambil", false],
	["starting_shield_charges", "Starting shield", "Perisai awal", false],
	["blood_qi_heal_bonus", "Blood Qi healing", "Heal Blood Qi", false],
]

var _display_key: Array = []

func refresh(current: String, selected: String, can_compare: bool) -> void:
	var candidate: String = selected if selected != current else ""
	var left: Dictionary = _data(current)
	var right: Dictionary = _data(candidate)
	if left.is_empty():
		current = ""
	var key: Array = [current, candidate, left, right, can_compare, SettingsManager.language]
	if _display_key == key:
		return
	_display_key = key
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 4)
	mouse_filter = MOUSE_FILTER_IGNORE
	var cards := HBoxContainer.new()
	cards.mouse_filter = MOUSE_FILTER_IGNORE
	cards.add_theme_constant_override("separation", 8)
	add_child(cards)
	cards.add_child(_card(current, left, true, can_compare))
	cards.add_child(_card(candidate, right, false, can_compare))
	if not candidate.is_empty():
		for row: Array in ROWS:
			var before: float = _stat(left, row[0], row[3])
			var after: float = _stat(right, row[0], row[3])
			if row[0] not in ["damage_bonus", "weapon_damage_multiplier"] and is_zero_approx(before) and is_zero_approx(after):
				continue
			_add_stat(row, before, after)
		add_child(Sheet.label(Sheet.copy(
			"Permanent weapon bonuses. See Weapon Details below for the attack effect.",
			"Bonus permanen senjata. Lihat Detail Senjata di bawah untuk efek serangannya."
		), 12, MUTED))

func _data(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	return EquipmentManager._build_effective_item_data(id, EquipmentManager.get_backpack_item_star(id))

func _card(id: String, data: Dictionary, equipped: bool, can_compare: bool) -> PanelContainer:
	var accent: Color = Sheet.JADE if equipped else Sheet.GOLD
	var card := PanelContainer.new()
	card.name = "EquippedWeapon" if equipped else "CandidateWeapon"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("092527") if equipped else Color("231d15")
	skin.border_color = Color(accent, .62)
	skin.set_border_width_all(1)
	skin.border_width_top = 2
	skin.set_corner_radius_all(8)
	skin.content_margin_left = 6
	skin.content_margin_right = 6
	skin.content_margin_top = 5
	skin.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", skin)
	var column := VBoxContainer.new()
	column.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	var badge: String = Sheet.copy("EQUIPPED", "TERPASANG") if equipped else Sheet.copy("CANDIDATE", "KANDIDAT")
	if id.is_empty() and not equipped:
		column.add_child(_centered(badge, 12, accent))
		var empty: String = Sheet.copy("Pick another weapon above.", "Pilih senjata lain di atas.") if can_compare else Sheet.copy("No other weapon owned yet.", "Belum punya senjata lain.")
		var hint: Label = _centered(empty, 13, MUTED)
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(hint)
		return card
	var header := HBoxContainer.new()
	header.mouse_filter = MOUSE_FILTER_IGNORE
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 4)
	column.add_child(header)
	var icon := TextureRect.new()
	icon.name = "WeaponIcon"
	var path: String = Visual.get_icon_path(id)
	if id.is_empty():
		icon.texture = STARTER_ICON
	elif not path.is_empty():
		icon.texture = load(path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(36, 36)
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	header.add_child(icon)
	var caption: Label = _centered(badge, 12, accent)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(caption)
	var title: Label = _centered(tr(str(data.get("display_name", "Spirit Sword"))), 15, Sheet.TEXT)
	title.name = "WeaponName"
	title.add_theme_font_override("font", SERIF)
	column.add_child(title)
	var rank: String = Sheet.copy("Starter weapon", "Senjata awal")
	var rank_color: Color = MUTED
	if not id.is_empty():
		rank = "Lv. %d  ·  ★ %d/5" % [int(data.weapon_level), int(data.ascension_star)]
		rank_color = Visual.get_rarity_color(str(data.get("rarity", "common")))
	var progression: Label = _centered(rank, 12, rank_color)
	progression.name = "WeaponRank"
	column.add_child(progression)
	var role: String = str(Guidance.WEAPON_ROLES.get(id, data.get("signature_effect_name", "")))
	if not role.is_empty():
		column.add_child(_centered(tr(role), 12, MUTED))
	return card

func _add_stat(metric: Array, before: float, after: float) -> void:
	var row := HBoxContainer.new()
	row.name = str(metric[0])
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var suffix: String = "%" if metric[3] else ""
	var before_label: Label = _centered("%.1f%s" % [before, suffix], 14, Sheet.TEXT)
	before_label.name = "Before"
	before_label.custom_minimum_size.x = 64
	before_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(before_label)
	var caption: Label = _centered(Sheet.copy(metric[1], metric[2]), 12, MUTED)
	caption.custom_minimum_size.x = 96
	row.add_child(caption)
	var right := HBoxContainer.new()
	right.mouse_filter = MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 64
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 5)
	row.add_child(right)
	var after_label: Label = _centered("%.1f%s" % [after, suffix], 14, Sheet.TEXT)
	after_label.name = "After"
	after_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	right.add_child(after_label)
	var delta: float = snappedf(after - before, .1)
	if not is_zero_approx(delta):
		var change: Label = _centered("%+.1f" % delta, 12, Sheet.JADE if delta > 0.0 else DOWN)
		change.name = "Change"
		change.autowrap_mode = TextServer.AUTOWRAP_OFF
		right.add_child(change)

func _stat(data: Dictionary, stat: String, percent: bool) -> float:
	var raw: float = float(data.get(stat, 0.0))
	if stat == "weapon_damage_multiplier":
		raw = float(data.get(stat, 1.0)) - 1.0
	return snappedf(raw * (100.0 if percent else 1.0), .1)

func _centered(value: String, font_size: int, color: Color) -> Label:
	var label: Label = Sheet.label(value, font_size, color)
	label.set_meta(&"jade_mobile_readability_v2", true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
