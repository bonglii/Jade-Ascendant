extends Control

## Jade Pavilion — Economy Foundation v2 presentation layer.
## Economy authority remains in PavilionManager / EquipmentManager /
## InventoryManager / ProgressionManager. This UI never grants paid currency.

const EquipmentVisualCatalog = preload("res://scripts/ui/equipment_visual_catalog.gd")

const SPIRIT_STONE_ICON: String = "res://assets/ui/icons/spirit_stone.svg"
const REFINEMENT_SHARD_ICON: String = "res://assets/ui/equipment/refinement_shard.svg"
const PAVILION_SEAL_ICON: String = "res://assets/ui/pavilion/polish/pavilion_seal.svg"
const CELESTIAL_JADE_ICON: String = "res://assets/ui/pavilion/polish/celestial_jade.svg"
const PAVILION_JADE_JIAN_ICON: String = "res://assets/ui/pavilion/polish/wanderer_jade_jian.svg"
const SANCTUARY_BANNER: String = "res://assets/ui/pavilion/polish/pavilion_sanctuary_banner.svg"
const MEDITATION_ALTAR: String = "res://assets/ui/pavilion/polish/meditation_altar.svg"

const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]
const STANDARD_AURA_IDS: Array[String] = ["plain", "jade_aura", "golden_aura", "astral_aura"]
const FEATURED_AURA_ID: String = "ascendant_aura"
const AURA_PREVIEW_PATHS: Dictionary = {
	"plain": "res://assets/ui/pavilion/polish/aura_preview_wanderer.svg",
	"jade_aura": "res://assets/ui/pavilion/polish/aura_preview_shrinekeeper.svg",
	"golden_aura": "res://assets/ui/pavilion/polish/aura_preview_sovereign.svg",
	"astral_aura": "res://assets/ui/pavilion/polish/aura_preview_astral.svg",
	"ascendant_aura": "res://assets/ui/pavilion/polish/aura_preview_ascendant.svg"
}
const AURA_ICON_PATHS: Dictionary = {
	"plain": "res://assets/ui/pavilion/polish/aura_wanderer.svg",
	"jade_aura": "res://assets/ui/pavilion/polish/aura_shrinekeeper.svg",
	"golden_aura": "res://assets/ui/pavilion/polish/aura_sovereign.svg",
	"astral_aura": "res://assets/ui/pavilion/polish/aura_astral.svg",
	"ascendant_aura": "res://assets/ui/pavilion/polish/aura_ascendant.svg"
}

const JADE: Color = Color(0.28, 0.95, 0.78, 1.0)
const JADE_SOFT: Color = Color(0.20, 0.68, 0.58, 1.0)
const GOLD: Color = Color(0.98, 0.78, 0.30, 1.0)
const CYAN: Color = Color(0.28, 0.82, 0.96, 1.0)
const VIOLET: Color = Color(0.72, 0.48, 0.96, 1.0)
const LEGENDARY_GOLD: Color = Color(1.0, 0.72, 0.22, 1.0)
const TEXT_MAIN: Color = Color(0.93, 0.97, 0.95, 1.0)
const TEXT_MUTED: Color = Color(0.62, 0.74, 0.71, 1.0)
const PANEL_DARK: Color = Color(0.002, 0.020, 0.030, 0.94)

var content: VBoxContainer
var stone_balance_label: Label
var shard_balance_label: Label
var jade_balance_label: Label
var seal_balance_label: Label
var wallet_header: PanelContainer
var status_panel: PanelContainer
var status_label: Label

var summon_state_label: Label
var starter_button: Button
var pity_label: Label
var lifetime_label: Label
var wish_rule_label: Label
var wish_option: OptionButton
var wish_item_ids: Array[String] = []
var summon_one_button: Button
var summon_ten_button: Button
var rates_button: Button
var rates_box: VBoxContainer
var summon_result_box: VBoxContainer
var rates_visible: bool = false

var chest: Button
var meditation_state_label: Label
var cadence_label: Label
var meditation_altar_frame: PanelContainer
var meditation_altar_icon: TextureRect
var aura_grid: GridContainer
var aura_featured: VBoxContainer
var equipment_list: VBoxContainer
var rarity_buttons: Dictionary = {}
var selected_rarity: String = "common"


func _ready() -> void:
	content = $SafeArea/Scroll/Content
	SceneTransitionManager.set_back_handler(_back)
	_configure_backdrop()
	_build_wallet_header()
	_build_screen()
	if not PavilionManager.pavilion_changed.is_connected(_refresh):
		PavilionManager.pavilion_changed.connect(_refresh)
	_refresh()


func _configure_backdrop() -> void:
	var backdrop: Control = $Backdrop
	if backdrop != null and backdrop.has_method("apply_profile"):
		backdrop.call("apply_profile", {
			"sky_top": Color(0.001, 0.012, 0.024, 1.0),
			"sky_bottom": Color(0.004, 0.060, 0.066, 1.0),
			"mountain_far": Color(0.018, 0.115, 0.112, 0.84),
			"mountain_near": Color(0.004, 0.046, 0.052, 0.98),
			"mist": Color(0.26, 0.92, 0.78, 0.12),
			"moon": Color(1.0, 0.82, 0.40, 0.10),
			"accent": JADE,
			"gold": GOLD
		})


func _build_screen() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	content.add_theme_constant_override("separation", 14)
	_build_hero_header()
	_build_status_banner()
	_build_summon_section()
	_build_meditation_section()
	_build_aura_section()
	_build_forge_section()
	_build_player_trust_section()
	_add_bottom_safe_spacer()


func _build_wallet_header() -> void:
	var safe_area: Control = $SafeArea
	var scroll: ScrollContainer = $SafeArea/Scroll
	scroll.offset_top = 76.0

	wallet_header = PanelContainer.new()
	wallet_header.name = "WalletHeader"
	wallet_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wallet_header.anchor_left = 0.055
	wallet_header.anchor_right = 0.945
	wallet_header.offset_left = 0.0
	wallet_header.offset_right = 0.0
	wallet_header.offset_top = 10.0
	wallet_header.offset_bottom = 66.0
	wallet_header.add_theme_stylebox_override("panel", _wallet_header_style())
	safe_area.add_child(wallet_header)
	safe_area.move_child(wallet_header, 1)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	wallet_header.add_child(margin)

	var wallet_grid: GridContainer = GridContainer.new()
	wallet_grid.columns = 4
	wallet_grid.add_theme_constant_override("h_separation", 5)
	wallet_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(wallet_grid)

	stone_balance_label = _compact_resource_chip(wallet_grid, SPIRIT_STONE_ICON, tr("Spirit Stone"), GOLD)
	shard_balance_label = _compact_resource_chip(wallet_grid, REFINEMENT_SHARD_ICON, tr("Refinement Shard"), CYAN)
	jade_balance_label = _compact_resource_chip(wallet_grid, CELESTIAL_JADE_ICON, tr("Celestial Jade"), VIOLET)
	seal_balance_label = _compact_resource_chip(wallet_grid, PAVILION_SEAL_ICON, tr("Pavilion Seal"), JADE)


func _compact_resource_chip(parent_node: Node, icon_path: String, tooltip: String, accent: Color) -> Label:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, 40.0)
	panel.tooltip_text = tooltip
	panel.add_theme_stylebox_override("panel", _compact_wallet_chip_style(accent))
	parent_node.add_child(panel)

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(20.0, 20.0)
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var value: Label = Label.new()
	value.text = "0"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68, 1.0))
	row.add_child(value)
	return value


func _build_hero_header() -> void:
	var hero_stage := Control.new()
	hero_stage.custom_minimum_size = Vector2(0.0, 205.0)
	hero_stage.clip_contents = true
	content.add_child(hero_stage)

	var art := TextureRect.new()
	art.texture = load(SANCTUARY_BANNER) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_stage.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title_panel := PanelContainer.new()
	title_panel.anchor_left = 0.025
	title_panel.anchor_right = 0.975
	title_panel.anchor_top = 1.0
	title_panel.anchor_bottom = 1.0
	title_panel.offset_top = -124.0
	title_panel.offset_bottom = -8.0
	title_panel.add_theme_stylebox_override("panel", _hero_overlay_style())
	hero_stage.add_child(title_panel)

	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 7)
	title_panel.add_child(hero_box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	hero_box.add_child(title_row)
	_make_icon_emblem(title_row, PAVILION_SEAL_ICON, JADE, GOLD, 58.0)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	title_row.add_child(title_box)
	_label(title_box, tr("JADE PAVILION"), 11, JADE)
	_label(title_box, tr("Sanctum of Refinement"), 24, Color(1.0, 0.87, 0.50))
	_label(title_box, tr("Cultivate, forge, and call equipment from the Celestial Pavilion."), 12, Color(0.74, 0.85, 0.81, 1.0))



func _build_status_banner() -> void:
	status_panel = _panel(content, _status_style(JADE_SOFT))
	status_label = _label(status_panel, "", 12, Color(0.70, 0.95, 0.86))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size.y = 22.0


func _build_summon_section() -> void:
	var summon := _section_card(
		content,
		tr("CELESTIAL PAVILION"),
		tr("Equipment Summon"),
		tr("Use Pavilion Seals first, or Celestial Jade when no Seal bundle is available. Pity carries across sessions."),
		VIOLET
	)
	summon_state_label = _state_badge(summon, tr("LOCKED • CLEAR CHAPTER 1-5"), VIOLET)
	summon_state_label.add_theme_font_size_override("font_size", 11)
	starter_button = _button(summon, tr("CLAIM INITIATE GIFT • 10 PAVILION SEALS"), _claim_starter_seals, true, JADE)

	var info_grid := GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 8)
	info_grid.add_theme_constant_override("v_separation", 6)
	summon.add_child(info_grid)
	pity_label = _info_chip(info_grid, tr("PITY"), "—", GOLD)
	lifetime_label = _info_chip(info_grid, tr("LIFETIME SUMMONS"), "0", CYAN)

	var wish_panel := _panel(summon, _panel_style(VIOLET, false, 9))
	var wish_box := VBoxContainer.new()
	wish_box.add_theme_constant_override("separation", 5)
	wish_panel.add_child(wish_box)
	_label(wish_box, tr("LEGENDARY WISH"), 11, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.92))
	wish_rule_label = _label(
		wish_box,
		tr("Natural Legendary: 50% target • Miss once: next Legendary target guaranteed • Hard pity: target guaranteed."),
		11,
		TEXT_MUTED
	)
	wish_option = OptionButton.new()
	wish_option.custom_minimum_size.y = 42.0
	wish_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wish_option.add_theme_font_size_override("font_size", 12)
	wish_option.item_selected.connect(_on_wish_selected)
	wish_box.add_child(wish_option)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 7)
	summon.add_child(action_row)
	summon_one_button = _button(action_row, tr("SUMMON ×1"), _summon.bind(1), false, VIOLET)
	summon_ten_button = _button(action_row, tr("SUMMON ×10"), _summon.bind(10), true, GOLD)
	summon_one_button.add_theme_font_size_override("font_size", 11)
	summon_ten_button.add_theme_font_size_override("font_size", 11)

	rates_button = _button(summon, tr("DROP RATES & PITY RULES"), _toggle_rates, false, CYAN)
	rates_box = VBoxContainer.new()
	rates_box.add_theme_constant_override("separation", 5)
	rates_box.visible = false
	summon.add_child(rates_box)

	summon_result_box = VBoxContainer.new()
	summon_result_box.add_theme_constant_override("separation", 7)
	summon_result_box.visible = false
	summon.add_child(summon_result_box)
	_label(
		summon,
		tr("Celestial Jade is premium currency. Real-money purchase stays disabled until the verified billing provider is integrated."),
		11,
		Color(0.58, 0.70, 0.69, 1.0)
	)


func _build_meditation_section() -> void:
	var meditation := _section_card(
		content,
		tr("DAILY RESONANCE"),
		tr("Daily Meditation"),
		tr("A quiet moment grants 20 Spirit Stones once per local day."),
		JADE
	)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	meditation.add_child(body)
	meditation_altar_frame = PanelContainer.new()
	meditation_altar_frame.custom_minimum_size = Vector2(112.0, 112.0)
	meditation_altar_frame.add_theme_stylebox_override("panel", _meditation_altar_style(JADE, true))
	body.add_child(meditation_altar_frame)
	meditation_altar_icon = TextureRect.new()
	meditation_altar_icon.texture = load(MEDITATION_ALTAR) as Texture2D
	meditation_altar_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	meditation_altar_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	meditation_altar_frame.add_child(meditation_altar_icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	body.add_child(copy)
	meditation_state_label = _state_badge(copy, tr("AVAILABLE"), JADE)
	_label(copy, "+20 • " + _spirit_stone_caption(), 16, Color(1.0, 0.86, 0.48))
	cadence_label = _label(copy, "", 10, Color(0.76, 0.88, 0.84, 1.0))
	chest = _button(meditation, tr("MEDITATE • +20 SPIRIT STONES"), _meditate, true, JADE)


func _build_aura_section() -> void:
	var cosmetics := _section_card(
		content,
		tr("COSMETIC ATTUNEMENT"),
		tr("Cultivation Auras"),
		tr("Realm-clear auras are free. Prestige auras use earned currencies only and never add combat power."),
		VIOLET
	)
	aura_grid = GridContainer.new()
	aura_grid.columns = 2
	aura_grid.add_theme_constant_override("h_separation", 8)
	aura_grid.add_theme_constant_override("v_separation", 8)
	cosmetics.add_child(aura_grid)
	aura_featured = VBoxContainer.new()
	aura_featured.add_theme_constant_override("separation", 6)
	cosmetics.add_child(aura_featured)


func _build_forge_section() -> void:
	var forge := _section_card(
		content,
		tr("DETERMINISTIC SAFETY NET"),
		tr("Equipment Forge"),
		tr("Common/Rare may use Spirit Stones. Epic/Legendary use Summon or Refinement Shard forging."),
		GOLD
	)
	_label(forge, tr("RARITY"), 12, TEXT_MUTED)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	forge.add_child(filter_row)
	for rarity: String in RARITIES:
		var button := Button.new()
		button.text = tr(rarity.capitalize()).to_upper()
		button.custom_minimum_size = Vector2(0.0, 42.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_select_rarity.bind(rarity))
		filter_row.add_child(button)
		rarity_buttons[rarity] = button
	equipment_list = VBoxContainer.new()
	equipment_list.add_theme_constant_override("separation", 8)
	forge.add_child(equipment_list)


func _build_player_trust_section() -> void:
	var panel := _panel(content, _panel_style(CYAN, false, 9))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	_label(copy, tr("PLAYER-FIRST ECONOMY"), 11, Color(CYAN.r, CYAN.g, CYAN.b, 0.90))
	_label(copy, tr("Odds visible • Forge safety net • No forced purchase"), 15, Color(1.0, 0.86, 0.48))
	var privacy := _button(row, tr("PRIVACY & SUPPORT"), _open_privacy, false, CYAN)
	privacy.custom_minimum_size = Vector2(142.0, 42.0)


func _refresh() -> void:
	stone_balance_label.text = _format_count(ProgressionManager.spirit_stone)
	shard_balance_label.text = _format_count(InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD))
	jade_balance_label.text = _format_count(PavilionManager.get_celestial_jade())
	seal_balance_label.text = _format_count(PavilionManager.get_pavilion_seals())

	var meditation_ready := PavilionManager.can_claim_meditation()
	chest.disabled = not meditation_ready
	chest.text = tr("MEDITATE • +20 SPIRIT STONES") if meditation_ready else tr("MEDITATED TODAY")
	meditation_state_label.text = tr("AVAILABLE") if meditation_ready else tr("COMPLETED")
	var meditation_accent := JADE if meditation_ready else Color(0.46, 0.62, 0.58, 1.0)
	meditation_state_label.add_theme_color_override("font_color", meditation_accent)
	if meditation_state_label.get_parent() is PanelContainer:
		(meditation_state_label.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _chip_style(meditation_accent))
	if meditation_altar_frame != null:
		meditation_altar_frame.add_theme_stylebox_override("panel", _meditation_altar_style(meditation_accent, meditation_ready))
	if meditation_altar_icon != null:
		meditation_altar_icon.modulate = Color(1, 1, 1, 1.0 if meditation_ready else 0.58)
	_apply_button_style(chest, JADE if meditation_ready else Color(0.34, 0.46, 0.43, 1.0), meditation_ready)
	var cadence: Dictionary = PavilionManager.get_cadence_status()
	if cadence_label != null:
		cadence_label.text = tr("QUEST CADENCE %d/%d • +%d JADE/DAY\n7TH ACTIVE DAY • +%d JADE +%d SEALS") % [
			int(cadence.get("active_days", 0)),
			int(cadence.get("cycle_length", 7)),
			int(cadence.get("daily_jade", 20)),
			int(cadence.get("cycle_bonus_jade", 160)),
			int(cadence.get("cycle_bonus_seals", 4))
		]

	_refresh_status()
	_refresh_summon_panel()
	_sync_rarity_buttons()
	_rebuild_auras()
	_rebuild_equipment()


func _refresh_status() -> void:
	if SaveManager.is_progress_read_only():
		_set_status(tr("SAVE RECOVERY REQUIRED • REOPEN THE GAME BEFORE CHANGING ECONOMY STATE"), Color(0.95, 0.43, 0.38))
	elif not EquipmentManager.can_modify_equipment():
		_set_status(tr("FORGE SEALED DURING ACTIVE GAMEPLAY • SUMMON OWNERSHIP REMAINS PERMANENT"), GOLD)
	else:
		_set_status(tr("PAVILION READY • PERMANENT ECONOMY STATE IS SAFE"), JADE)


func _refresh_summon_panel() -> void:
	var unlocked := PavilionManager.is_summon_unlocked()
	var read_only := SaveManager.is_progress_read_only()
	if unlocked:
		summon_state_label.text = tr("OPEN • UNLOCKED EQUIPMENT ONLY")
		summon_state_label.add_theme_color_override("font_color", JADE)
		starter_button.visible = not PavilionManager.has_claimed_starter_seals()
		starter_button.disabled = not PavilionManager.can_claim_starter_seals()
	else:
		summon_state_label.text = tr("LOCKED • CLEAR CHAPTER 1-5")
		summon_state_label.add_theme_color_override("font_color", Color(0.64, 0.69, 0.68, 1.0))
		starter_button.visible = false

	lifetime_label.text = _format_count(PavilionManager.get_lifetime_pulls())
	var pity: Dictionary = PavilionManager.get_summon_pity_status()
	var legendary_copy := tr("LEG LOCKED")
	if bool(pity.get("legendary_active", false)):
		legendary_copy = tr("LEG %d") % int(pity.get("legendary_remaining", 50))
	pity_label.text = tr("R+ %d • E+ %d • %s") % [
		int(pity.get("rare_plus_remaining", 10)),
		int(pity.get("epic_plus_remaining", 30)),
		legendary_copy
	]
	if wish_rule_label != null:
		if PavilionManager.is_wish_fate_guaranteed():
			wish_rule_label.text = tr("WISH FATE ACTIVE • Your next Legendary is guaranteed to be the current Wish target.")
			wish_rule_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.34, 1.0))
		else:
			wish_rule_label.text = tr("Natural Legendary: 50% target • Miss once: next Legendary target guaranteed • Hard pity: target guaranteed.")
			wish_rule_label.add_theme_color_override("font_color", TEXT_MUTED)
	_sync_wish_options()
	_rebuild_drop_rates()
	summon_one_button.text = _summon_button_text(1)
	summon_ten_button.text = _summon_button_text(10)
	summon_one_button.disabled = read_only or not unlocked or not PavilionManager.can_summon(1)
	summon_ten_button.disabled = read_only or not unlocked or not PavilionManager.can_summon(10)


func _sync_wish_options() -> void:
	var options: Array[String] = PavilionManager.get_wish_target_options()
	var current := PavilionManager.get_wish_target_item_id()
	wish_option.clear()
	wish_item_ids.clear()
	wish_option.add_item(tr("NO WISH TARGET"))
	wish_item_ids.append("")
	var selected_index := 0
	for item_id: String in options:
		var data := EquipmentManager.get_item_data(item_id)
		wish_option.add_item(tr(str(data.get("display_name", item_id))))
		wish_item_ids.append(item_id)
		if item_id == current:
			selected_index = wish_item_ids.size() - 1
	wish_option.select(selected_index)
	wish_option.disabled = options.is_empty() or SaveManager.is_progress_read_only()
	if options.is_empty():
		wish_option.set_item_text(0, tr("WISH UNLOCKS WITH LEGENDARY POOL"))


func _rebuild_drop_rates() -> void:
	for child: Node in rates_box.get_children():
		rates_box.remove_child(child)
		child.queue_free()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 5)
	rates_box.add_child(grid)
	for entry: Dictionary in PavilionManager.get_effective_drop_rate_disclosure():
		var rarity := str(entry.get("rarity", "common"))
		var accent := EquipmentVisualCatalog.get_rarity_color(rarity)
		var chip := _panel(grid, _chip_style(accent))
		var row := HBoxContainer.new()
		chip.add_child(row)
		var rarity_label := _label(row, tr(rarity.capitalize()).to_upper(), 11, accent)
		rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rate_label := _label(row, "%.2f%%" % float(entry.get("percent", 0.0)), 12, TEXT_MAIN)
		rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(rates_box, tr("Rare+ ≤10 • Epic+ ≤30 • Legendary ≤50 once a Legendary pool is unlocked."), 11, Color(0.75, 0.84, 0.82, 1.0))
	_label(rates_box, tr("Wish: natural Legendary has 50% target preference. One miss activates Wish Fate; the next Legendary is guaranteed to be that target. Changing the target clears Fate."), 11, Color(0.82, 0.72, 0.94, 1.0))
	_label(rates_box, tr("Current rates reflect your unlocked pool. Missing rarity chance is redistributed to the nearest available rarity."), 11, TEXT_MUTED)
	if not PavilionManager.has_active_legendary_pool():
		_label(rates_box, tr("Legendary pity is paused until a Legendary equipment item is progression-unlocked."), 11, Color(0.82, 0.68, 0.52, 1.0))
	rates_box.visible = rates_visible
	rates_button.text = tr("HIDE DROP RATES") if rates_visible else tr("DROP RATES & PITY RULES")


func _summon_button_text(pull_count: int) -> String:
	var cost := PavilionManager.get_summon_cost(pull_count)
	var seal_cost := int(cost.get("pavilion_seal", 0))
	var jade_cost := int(cost.get("celestial_jade", 0))
	if seal_cost > 0 and PavilionManager.get_pavilion_seals() >= seal_cost:
		return tr("SUMMON ×%d • %d SEAL%s") % [pull_count, seal_cost, "" if seal_cost == 1 else "S"]
	var suffix := tr(" • 10% JADE SAVED") if pull_count == 10 else ""
	return tr("SUMMON ×%d • %d JADE%s") % [pull_count, jade_cost, suffix]


func _claim_starter_seals() -> void:
	if PavilionManager.claim_starter_seals():
		_set_status(tr("Initiate Gift claimed • +10 Pavilion Seals."), JADE)
	else:
		_set_status(tr(PavilionManager.last_error), Color(0.95, 0.48, 0.42))


func _summon(pull_count: int) -> void:
	var result: Dictionary = PavilionManager.summon_equipment(pull_count)
	if not bool(result.get("success", false)):
		_set_status(tr(str(result.get("error", PavilionManager.last_error))), Color(0.95, 0.48, 0.42))
		return
	_render_summon_result(result)
	var payment_method := str(result.get("payment_method", ""))
	var payment_amount := int(result.get("payment_amount", 0))
	var payment_copy := tr("%d Celestial Jade") % payment_amount
	if payment_method == PavilionManager.PAYMENT_SEAL:
		payment_copy = tr("%d Pavilion Seal%s") % [payment_amount, "" if payment_amount == 1 else "s"]
	var message := tr("Summon complete • %s") % payment_copy
	var shards_gained := int(result.get("refinement_shards_gained", 0))
	if shards_gained > 0:
		message += tr(" • +%d Refinement Shards") % shards_gained
	_set_status(message, GOLD)


func _render_summon_result(result: Dictionary) -> void:
	for child: Node in summon_result_box.get_children():
		summon_result_box.remove_child(child)
		child.queue_free()
	summon_result_box.visible = true
	var pull_count := int(result.get("pull_count", 0))
	var heading := _label(summon_result_box, tr("LATEST SUMMON • %d RESULT%s") % [pull_count, "" if pull_count == 1 else "S"], 13, Color(1.0, 0.87, 0.50))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var result_grid := GridContainer.new()
	result_grid.columns = 2
	result_grid.add_theme_constant_override("h_separation", 7)
	result_grid.add_theme_constant_override("v_separation", 7)
	summon_result_box.add_child(result_grid)
	var entries: Array = result.get("results", [])
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var item_id := str(entry.get("item_id", ""))
		var data := EquipmentManager.get_item_data(item_id)
		var rarity := str(entry.get("rarity", data.get("rarity", "common")))
		var accent := EquipmentVisualCatalog.get_rarity_color(rarity)
		var card := _panel(result_grid, _equipment_card_style(accent, true, true))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		card.add_child(box)
		var icon := TextureRect.new()
		icon.texture = load(_get_pavilion_equipment_icon_path(item_id)) as Texture2D
		icon.custom_minimum_size = Vector2(0.0, 70.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)
		var name_label := _label(box, tr(str(data.get("display_name", item_id))), 12, TEXT_MAIN)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rarity_label := _label(box, tr(rarity.capitalize()).to_upper(), 10, accent)
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if bool(entry.get("duplicate", false)):
			var duplicate_label := _label(box, tr("DUPLICATE • +%d SHARDS") % int(entry.get("duplicate_shards", 0)), 10, CYAN)
			duplicate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			var new_label := _label(box, tr("NEW EQUIPMENT"), 10, JADE)
			new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if bool(entry.get("hard_legendary_pity", false)):
			_state_badge(box, tr("LEGENDARY PITY"), LEGENDARY_GOLD)
		if bool(entry.get("wish_fate_activated", false)):
			_state_badge(box, tr("WISH FATE AWAKENED"), VIOLET)
		elif bool(entry.get("wish_fate_consumed", false)):
			_state_badge(box, tr("WISH FATE • TARGET"), GOLD)


func _toggle_rates() -> void:
	rates_visible = not rates_visible
	_rebuild_drop_rates()


func _on_wish_selected(index: int) -> void:
	if index < 0 or index >= wish_item_ids.size():
		return
	var item_id := wish_item_ids[index]
	if PavilionManager.set_wish_target(item_id):
		if item_id.is_empty():
			_set_status(tr("Legendary Wish cleared."), VIOLET)
		else:
			var data := EquipmentManager.get_item_data(item_id)
			_set_status(tr("Legendary Wish set • %s") % tr(str(data.get("display_name", item_id))), VIOLET)
	else:
		_set_status(tr(PavilionManager.last_error), Color(0.95, 0.48, 0.42))


func _set_status(value: String, accent: Color) -> void:
	status_label.text = value
	status_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.96))
	status_panel.add_theme_stylebox_override("panel", _status_style(accent))


func _rebuild_auras() -> void:
	for child: Node in aura_grid.get_children():
		aura_grid.remove_child(child)
		child.queue_free()
	for child: Node in aura_featured.get_children():
		aura_featured.remove_child(child)
		child.queue_free()
	for cosmetic_id: String in STANDARD_AURA_IDS:
		if PavilionManager.COSMETICS.has(cosmetic_id):
			aura_grid.add_child(_create_aura_card(cosmetic_id, false))
	if PavilionManager.COSMETICS.has(FEATURED_AURA_ID):
		aura_featured.add_child(_create_aura_card(FEATURED_AURA_ID, true))


func _create_aura_card(cosmetic_id: String, featured: bool = false) -> PanelContainer:
	var definition := PavilionManager.get_cosmetic_data(cosmetic_id)
	var accent := _get_aura_color(cosmetic_id)
	var owned := PavilionManager.is_cosmetic_owned(cosmetic_id)
	var current := PavilionManager.get_cosmetic_id() == cosmetic_id
	var unlocked := PavilionManager.is_cosmetic_unlocked(cosmetic_id)
	var cost := PavilionManager.get_cosmetic_cost(cosmetic_id)
	var stone_cost := int(cost.get("spirit_stone", 0))
	var shard_cost := int(cost.get("refinement_shard", 0))
	var card_accent := JADE if current else accent
	if not unlocked:
		card_accent = Color(accent.r * 0.60, accent.g * 0.60, accent.b * 0.60, 1.0)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _aura_card_style(card_accent, featured, current, unlocked))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)

	var preview_stage := Control.new()
	preview_stage.custom_minimum_size = Vector2(0.0, 160.0 if featured else 108.0)
	preview_stage.clip_contents = true
	box.add_child(preview_stage)
	var preview := TextureRect.new()
	preview.texture = load(_get_aura_preview_path(cosmetic_id)) as Texture2D
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1, 1, 1, 1.0 if unlocked else 0.50)
	preview_stage.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay := PanelContainer.new()
	overlay.anchor_left = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_top = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_top = -64.0
	overlay.add_theme_stylebox_override("panel", _aura_overlay_style(card_accent))
	preview_stage.add_child(overlay)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	overlay.add_child(title_row)
	var mini_icon := TextureRect.new()
	mini_icon.texture = load(_get_aura_icon_path(cosmetic_id)) as Texture2D
	mini_icon.custom_minimum_size = Vector2(40.0 if featured else 34.0, 40.0 if featured else 34.0)
	mini_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(mini_icon)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_box)
	_label(title_box, tr(str(definition.get("name", cosmetic_id))), 18 if featured else 14, TEXT_MAIN)
	var state_text := tr("AVAILABLE")
	var state_color := accent
	if current:
		state_text = tr("ATTUNED ✓")
		state_color = JADE
	elif owned:
		state_text = tr("OWNED • ATTUNE")
		state_color = JADE
	elif not unlocked:
		state_text = tr("LOCKED")
		state_color = Color(0.64, 0.69, 0.68, 1.0)
	_label(title_box, state_text, 12, state_color)

	var action := Button.new()
	action.custom_minimum_size.y = 50.0 if featured else 42.0
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.add_theme_font_size_override("font_size", 13 if featured else 12)
	action.pressed.connect(_select_cosmetic.bind(cosmetic_id))
	_apply_button_style(action, accent, featured)
	box.add_child(action)
	if current:
		action.text = tr("ATTUNED ✓")
		action.disabled = true
	elif not unlocked:
		action.disabled = true
		var required_cosmetic := str(definition.get("requires_cosmetic", ""))
		if not PavilionManager.is_cosmetic_stage_unlocked(cosmetic_id):
			action.text = tr("CLEAR %d-%d") % [int(definition.get("chapter", 1)), int(definition.get("stage", 0))]
		elif not required_cosmetic.is_empty() and not PavilionManager.is_cosmetic_owned(required_cosmetic):
			var required_data := PavilionManager.get_cosmetic_data(required_cosmetic)
			action.text = tr("REQUIRES %s") % tr(str(required_data.get("name", required_cosmetic)))
		else:
			action.text = tr("LOCKED")
	elif owned:
		action.text = tr("OWNED • ATTUNE")
		action.disabled = SaveManager.is_progress_read_only()
	elif stone_cost <= 0 and shard_cost <= 0:
		action.text = tr("AVAILABLE")
		action.disabled = SaveManager.is_progress_read_only()
	else:
		action.text = tr("%d STONES + %d SHARDS") % [stone_cost, shard_cost]
		action.disabled = SaveManager.is_progress_read_only() or ProgressionManager.spirit_stone < stone_cost or InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD) < shard_cost
	return card


func _rebuild_equipment() -> void:
	for child: Node in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.queue_free()
	var visible_items: Array[Dictionary] = []
	for item_id: String in EquipmentManager.get_item_ids():
		var data := EquipmentManager.get_item_data(item_id)
		if str(data.get("rarity", "common")) == selected_rarity:
			visible_items.append({"item_id": item_id, "data": data})
	var row: HBoxContainer
	for index: int in range(visible_items.size()):
		if index % 2 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			equipment_list.add_child(row)
		var entry: Dictionary = visible_items[index]
		var entry_data: Dictionary = entry.get("data", {})
		var card := _create_equipment_card(str(entry.get("item_id", "")), entry_data)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)


func _create_equipment_card(item_id: String, data: Dictionary) -> PanelContainer:
	var rarity_id := str(data.get("rarity", "common"))
	var rarity_color := EquipmentVisualCatalog.get_rarity_color(rarity_id)
	var owned_item := InventoryManager.owns_item(item_id)
	var unlocked_item := PavilionManager.is_item_unlocked(item_id)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _equipment_card_style(rarity_color, owned_item, unlocked_item))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)
	var rarity_tag := _label(box, tr(rarity_id.capitalize()).to_upper(), 11, rarity_color)
	rarity_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(0.0, 82.0)
	icon_frame.add_theme_stylebox_override("panel", _equipment_icon_style(rarity_color, unlocked_item))
	box.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.texture = load(_get_pavilion_equipment_icon_path(item_id)) as Texture2D
	icon.custom_minimum_size = Vector2(68.0, 68.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1, 1, 1, 1.0 if unlocked_item else 0.52)
	icon_frame.add_child(icon)
	var name_label := _label(box, tr(str(data.get("display_name", item_id))), 15, TEXT_MAIN)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var slot_label := _label(box, tr(EquipmentVisualCatalog.get_slot_title(str(data.get("slot", "")))), 11, rarity_color)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stat := _label(box, EquipmentVisualCatalog.get_stat_summary(data), 12, Color(0.78, 0.89, 0.85, 1.0))
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if owned_item:
		_state_badge(box, tr("OWNED • EQUIP FROM HERO"), JADE)
	elif not unlocked_item:
		var requirement := PavilionManager.get_item_unlock_requirement(item_id)
		_state_badge(box, tr("LOCKED • CLEAR %d-%d") % [int(requirement.get("chapter_id", 0)), int(requirement.get("stage_id", 0))], Color(0.55, 0.62, 0.61, 1.0))
	else:
		var signature_name := EquipmentVisualCatalog.get_signature_effect_name(data)
		if signature_name != "NO SIGNATURE EFFECT":
			var signature := _label(box, tr(signature_name), 12, Color(0.82, 0.70, 0.98, 1.0))
			signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var shard_price := PavilionManager.get_equipment_forge_cost(item_id)
		var sealed := not EquipmentManager.can_modify_equipment() or SaveManager.is_progress_read_only()
		if PavilionManager.can_buy_equipment_with_stones(item_id):
			var action_row := HBoxContainer.new()
			action_row.add_theme_constant_override("separation", 5)
			box.add_child(action_row)
			var stone_price := int(data.get("price", 0))
			var buy := _button(action_row, tr("%d STONES") % stone_price, _buy.bind(item_id, false), false, GOLD)
			var forge_button := _button(action_row, tr("%d SHARDS") % shard_price, _buy.bind(item_id, true), false, CYAN)
			buy.add_theme_font_size_override("font_size", 11)
			forge_button.add_theme_font_size_override("font_size", 11)
			buy.disabled = sealed or ProgressionManager.spirit_stone < stone_price
			forge_button.disabled = sealed or InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD) < shard_price
		else:
			_state_badge(box, tr("SUMMON • OR FORGE"), VIOLET)
			var forge_only := _button(box, tr("FORGE • %d SHARDS") % shard_price, _buy.bind(item_id, true), false, CYAN)
			forge_only.add_theme_font_size_override("font_size", 11)
			forge_only.disabled = sealed or InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD) < shard_price
	return card


func _sync_rarity_buttons() -> void:
	for rarity: String in RARITIES:
		var button := rarity_buttons.get(rarity) as Button
		if button != null:
			_apply_filter_style(button, EquipmentVisualCatalog.get_rarity_color(rarity), rarity == selected_rarity)


func _select_rarity(rarity: String) -> void:
	if rarity in RARITIES:
		selected_rarity = rarity
		_sync_rarity_buttons()
		_rebuild_equipment()


func _meditate() -> void:
	if PavilionManager.claim_meditation():
		_set_status(tr("Meditation complete. +20 Spirit Stones."), JADE)
	else:
		_set_status(tr(PavilionManager.last_error), Color(0.95, 0.48, 0.42))


func _select_cosmetic(cosmetic_id: String) -> void:
	var cost := PavilionManager.get_cosmetic_cost(cosmetic_id)
	var paid := int(cost.get("spirit_stone", 0)) > 0 or int(cost.get("refinement_shard", 0)) > 0
	var success: bool
	if not PavilionManager.is_cosmetic_owned(cosmetic_id) and paid:
		success = PavilionManager.acquire_cosmetic(cosmetic_id)
	else:
		success = PavilionManager.select_cosmetic(cosmetic_id)
	_set_status(tr("Aura attuned.") if success else tr(PavilionManager.last_error), VIOLET if success else Color(0.95, 0.48, 0.42))


func _buy(item_id: String, use_shards: bool) -> void:
	if PavilionManager.acquire_equipment(item_id, use_shards):
		_set_status(tr("Equipment acquired. Open Hero to equip it."), JADE)
	else:
		_set_status(tr(PavilionManager.last_error), Color(0.95, 0.48, 0.42))


func _open_privacy() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error := SceneTransitionManager.transition_menu_to("res://scenes/ui/privacy_screen.tscn", 1)
	if change_error != OK:
		push_error("PavilionScreen: gagal membuka Privacy. Error code: " + str(change_error))


func _back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error := SceneTransitionManager.transition_menu_to("res://scenes/ui/main_menu.tscn", -1)
	if change_error != OK:
		push_error("PavilionScreen: gagal kembali ke Main Menu. Error code: " + str(change_error))


func _add_bottom_safe_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 122.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)


func _section_card(parent_node: Node, eyebrow: String, title: String, description: String, accent: Color) -> VBoxContainer:
	var panel := _panel(parent_node, _panel_style(accent, false, 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	_label(box, eyebrow, 12, Color(accent.r, accent.g, accent.b, 0.96))
	_label(box, title, 23, Color(1.0, 0.86, 0.48))
	_label(box, description, 14, Color(0.76, 0.84, 0.82, 1.0))
	return box


func _resource_chip(parent_node: Node, icon_path: String, caption: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _chip_style(accent))
	parent_node.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(27.0, 27.0)
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	_label(copy, caption, 9, Color(accent.r, accent.g, accent.b, 0.88))
	return _label(copy, "0", 15, Color(1.0, 0.91, 0.62, 1.0))


func _info_chip(parent_node: Node, caption: String, value: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _chip_style(accent))
	parent_node.add_child(panel)
	var copy := VBoxContainer.new()
	panel.add_child(copy)
	_label(copy, caption, 9, Color(accent.r, accent.g, accent.b, 0.88))
	return _label(copy, value, 12, TEXT_MAIN)


func _make_icon_emblem(parent_node: Node, icon_path: String, accent: Color, secondary: Color, size_value: float) -> void:
	var emblem := PanelContainer.new()
	emblem.custom_minimum_size = Vector2(size_value, size_value)
	emblem.add_theme_stylebox_override("panel", _emblem_style(accent, secondary, size_value))
	parent_node.add_child(emblem)
	var icon := TextureRect.new()
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = size_value * 0.18
	icon.offset_top = size_value * 0.18
	icon.offset_right = -size_value * 0.18
	icon.offset_bottom = -size_value * 0.18


func _get_aura_preview_path(cosmetic_id: String) -> String:
	return str(AURA_PREVIEW_PATHS.get(cosmetic_id, AURA_PREVIEW_PATHS["plain"]))


func _get_aura_icon_path(cosmetic_id: String) -> String:
	return str(AURA_ICON_PATHS.get(cosmetic_id, AURA_ICON_PATHS["plain"]))


func _get_pavilion_equipment_icon_path(item_id: String) -> String:
	if item_id == "wanderer_jade_jian":
		return PAVILION_JADE_JIAN_ICON
	return EquipmentVisualCatalog.get_icon_path(item_id)


func _state_badge(parent_node: Node, value: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _chip_style(accent))
	parent_node.add_child(panel)
	var label := _label(panel, value, 10, Color(accent.r, accent.g, accent.b, 0.96))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _label(parent_node: Node, value: String, font_size: int = 16, tint: Color = TEXT_MUTED) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent_node.add_child(label)
	return label


func _button(parent_node: Node, value: String, callback: Callable, primary: bool, accent: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 52.0 if primary else 42.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14 if primary else 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_style(button, accent, primary)
	button.pressed.connect(callback)
	parent_node.add_child(button)
	return button


func _panel(parent_node: Node, style: StyleBoxFlat) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	parent_node.add_child(panel)
	return panel


func _panel_style(accent: Color, hero: bool, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_DARK.r, PANEL_DARK.g, PANEL_DARK.b, 0.97 if hero else 0.91)
	style.border_width_left = 2 if hero else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.76 if hero else 0.48)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 15.0 if hero else 13.0
	style.content_margin_top = 14.0 if hero else 12.0
	style.content_margin_right = 15.0 if hero else 13.0
	style.content_margin_bottom = 14.0 if hero else 12.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 7 if hero else 4
	return style


func _wallet_header_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.016, 0.024, 0.965)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.30, 0.92, 0.76, 0.60)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
	style.shadow_size = 5
	return style


func _compact_wallet_chip_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.055, accent.g * 0.055, accent.b * 0.055, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.46)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 5.0
	style.content_margin_top = 3.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 3.0
	return style


func _hero_overlay_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.018, 0.026, 0.90)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.30, 0.92, 0.76, 0.52)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 11.0
	style.content_margin_top = 9.0
	style.content_margin_right = 11.0
	style.content_margin_bottom = 9.0
	style.shadow_color = Color(0, 0, 0, 0.46)
	style.shadow_size = 6
	return style


func _status_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.055, accent.g * 0.055, accent.b * 0.055, 0.74)
	style.border_width_left = 2
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.44)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 10.0
	style.content_margin_top = 5.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 5.0
	return style


func _chip_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.07, accent.g * 0.07, accent.b * 0.07, 0.90)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.44)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 9.0
	style.content_margin_top = 6.0
	style.content_margin_right = 9.0
	style.content_margin_bottom = 6.0
	return style


func _emblem_style(accent: Color, secondary: Color, size_value: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.055, accent.g * 0.055, accent.b * 0.055, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.88)
	var radius := maxi(int(size_value * 0.5), 1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(secondary.r, secondary.g, secondary.b, 0.12)
	style.shadow_size = 5
	return style


func _aura_card_style(accent: Color, featured: bool, current: bool, unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var glow := 0.085 if featured else 0.060
	if current:
		glow += 0.035
	if not unlocked:
		glow *= 0.55
	style.bg_color = Color(accent.r * glow, accent.g * glow, accent.b * glow, 0.96)
	style.border_width_left = 2 if featured or current else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2 if featured else 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.86 if featured or current else 0.54)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 7.0
	style.content_margin_top = 7.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 7.0
	return style


func _aura_overlay_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.014, 0.024, 0.88)
	style.border_width_top = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style


func _equipment_card_style(accent: Color, owned: bool, unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var glow := 0.055 if owned else 0.070
	if not unlocked:
		glow = 0.025
	style.bg_color = Color(accent.r * glow, accent.g * glow, accent.b * glow, 0.965)
	style.border_width_left = 2 if owned else 1
	style.border_width_top = 2
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.70 if unlocked else 0.30)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10.0
	style.content_margin_top = 9.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 9.0
	return style


func _equipment_icon_style(accent: Color, unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var strength := 0.095 if unlocked else 0.035
	style.bg_color = Color(accent.r * strength, accent.g * strength, accent.b * strength, 0.94)
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.48 if unlocked else 0.20)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 5.0
	style.content_margin_top = 3.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 3.0
	return style


func _meditation_altar_style(accent: Color, available: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var strength := 0.105 if available else 0.035
	style.bg_color = Color(accent.r * strength, accent.g * strength, accent.b * strength, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.88 if available else 0.34)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	return style


func _apply_button_style(button: Button, accent: Color, primary: bool) -> void:
	button.add_theme_color_override("font_color", Color(0.94, 0.98, 0.96, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.50, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.54, 0.52, 0.90))
	button.add_theme_stylebox_override("normal", _button_style(accent, primary, 0.18))
	button.add_theme_stylebox_override("hover", _button_style(accent, primary, 0.28))
	button.add_theme_stylebox_override("pressed", _button_style(accent, primary, 0.36))
	button.add_theme_stylebox_override("focus", _button_style(accent, primary, 0.30))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.30, 0.38, 0.37, 1.0), false, 0.10))


func _button_style(accent: Color, primary: bool, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * (0.16 if primary else 0.10), accent.g * (0.16 if primary else 0.10), accent.b * (0.16 if primary else 0.10), 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2 if primary else 1
	style.border_color = Color(accent.r, accent.g, accent.b, clampf(0.55 + alpha, 0.0, 1.0))
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10.0
	style.content_margin_top = 7.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 7.0
	return style


func _apply_filter_style(button: Button, accent: Color, selected: bool) -> void:
	button.add_theme_color_override("font_color", Color(1.0, 0.90, 0.56, 1.0) if selected else Color(0.70, 0.80, 0.76, 1.0))
	button.add_theme_stylebox_override("normal", _filter_style(accent, selected, false))
	button.add_theme_stylebox_override("hover", _filter_style(accent, true, true))
	button.add_theme_stylebox_override("pressed", _filter_style(accent, true, true))
	button.add_theme_stylebox_override("focus", _filter_style(accent, true, true))


func _filter_style(accent: Color, selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fill_alpha := 0.22 if selected else 0.08
	if hovered:
		fill_alpha += 0.05
	style.bg_color = Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, fill_alpha)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2 if selected else 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82 if selected else 0.30)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 5.0
	style.content_margin_top = 6.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 6.0
	return style


func _get_aura_color(cosmetic_id: String) -> Color:
	match cosmetic_id:
		"jade_aura":
			return JADE
		"golden_aura":
			return GOLD
		"astral_aura":
			return VIOLET
		"ascendant_aura":
			return CYAN
		_:
			return Color(0.56, 0.76, 0.70, 1.0)


func _spirit_stone_caption() -> String:
	var sample := tr("%d Spirit Stone") % 1
	if sample.begins_with("1 "):
		sample = sample.substr(2)
	return sample.to_upper()


func _format_count(value: int) -> String:
	var remaining := str(maxi(value, 0))
	var groups: Array[String] = []
	while remaining.length() > 3:
		groups.push_front(remaining.right(3))
		remaining = remaining.left(remaining.length() - 3)
	groups.push_front(remaining)
	return ".".join(groups)
