extends VBoxContainer
## Shared next-run comparison across the five Hero slots.
const Visual = preload("res://scripts/ui/equipment_visual_catalog.gd")
const GearProjection = preload("res://scripts/companion/equipment_projection.gd")
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

func refresh(current: String, selected: String, can_compare: bool, slot: String = "armament") -> void:
	var weapon: bool = slot == "armament"
	var candidate: String = selected if selected != current else ""
	var left: Dictionary = EquipmentManager.get_loadout_equipped_item_data(slot)
	var right: Dictionary = EquipmentManager._build_effective_item_data(candidate, EquipmentManager.get_backpack_item_star(candidate))
	var projection: Dictionary = GearProjection.compare(candidate) if not weapon and not candidate.is_empty() else {}
	var key: Array = [slot, current, candidate, left, right, projection, can_compare, SettingsManager.language]
	if _display_key == key:
		return
	_display_key = key
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 5)
	mouse_filter = MOUSE_FILTER_IGNORE
	var cards := HBoxContainer.new()
	cards.mouse_filter = MOUSE_FILTER_IGNORE
	cards.add_theme_constant_override("separation", 8)
	add_child(cards)
	cards.add_child(_card(current, left, true, can_compare, weapon))
	cards.add_child(_card(candidate, right, false, can_compare, weapon))
	if candidate.is_empty():
		return
	var changed: int = 0
	var item_stats: bool = weapon or current.is_empty()
	var before_stats: Dictionary = left if item_stats else projection.get("before", {})
	var after_stats: Dictionary = right if item_stats else projection.get("after", {})
	for metric: Array in ROWS:
		var before: float = _stat(before_stats, metric[0], metric[3])
		var after: float = _stat(after_stats, metric[0], metric[3])
		if is_equal_approx(before, after):
			continue
		_add_stat(metric, before, after, not weapon and current.is_empty())
		changed += 1
	if changed == 0:
		add_child(_centered(Sheet.copy("Same numeric bonuses", "Bonus angka sama"), 13, MUTED))

func _card(id: String, data: Dictionary, equipped: bool, can_compare: bool, weapon: bool) -> PanelContainer:
	var accent: Color = Sheet.JADE if equipped else Sheet.GOLD
	var card := PanelContainer.new()
	card.name = ("EquippedWeapon" if equipped else "CandidateWeapon") if weapon else ("EquippedGear" if equipped else "CandidateGear")
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
	if id.is_empty() and (not equipped or not weapon):
		column.add_child(_centered(badge, 12, accent))
		var empty: String = Sheet.copy("Slot empty", "Slot kosong")
		if not equipped:
			empty = Sheet.copy("Choose an item above.", "Pilih item di atas.") if can_compare else Sheet.copy("No other item owned.", "Belum punya item lain.")
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
		rank = "★ %d/5" % int(data.get("ascension_star", 1))
		if weapon:
			rank = "Lv. %d  ·  %s" % [int(data.get("weapon_level", 1)), rank]
		rank_color = Visual.get_rarity_color(str(data.get("rarity", "common")))
	var progression: Label = _centered(rank, 12, rank_color)
	progression.name = "WeaponRank"
	column.add_child(progression)
	return card

func _add_stat(metric: Array, before: float, after: float, empty_slot: bool) -> void:
	var row := HBoxContainer.new()
	row.name = str(metric[0])
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var suffix: String = "%" if metric[3] else ""
	var before_label: Label = _centered("—" if empty_slot else _number(before) + suffix, 14, Sheet.TEXT)
	before_label.name = "Before"
	before_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(before_label)
	var caption: Label = _centered(Sheet.copy(metric[1], metric[2]), 12, MUTED)
	caption.custom_minimum_size.x = 87
	row.add_child(caption)
	var right := VBoxContainer.new()
	right.mouse_filter = MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	row.add_child(right)
	var shown: float = after - before if empty_slot else after
	var after_label: Label = _centered(_number(shown) + suffix, 14, Sheet.TEXT)
	after_label.name = "After"
	right.add_child(after_label)
	if not empty_slot:
		var delta: float = snappedf(after - before, .1)
		var change: Label = _centered(("+" if delta > 0.0 else "−") + _number(absf(delta)) + suffix, 12, Sheet.JADE if delta > 0.0 else DOWN)
		change.name = "Change"
		right.add_child(change)

func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

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
