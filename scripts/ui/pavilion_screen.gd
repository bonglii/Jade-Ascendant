extends Control

## Jade Pavilion — Economy Foundation v2 presentation layer.
## Economy authority remains in PavilionManager / EquipmentManager /
## InventoryManager / ProgressionManager. Shipping UI never grants paid currency.
## DEBUG builds may seed a bounded test wallet for summon presentation QA only.

const EquipmentVisualCatalog = preload("res://scripts/ui/equipment_visual_catalog.gd")
const EquipmentSetCatalog = preload("res://scripts/data/equipment_set_catalog.gd")
const SummonStageVisual = preload("res://scripts/ui/pavilion_summon_stage.gd")
const SummonRevealStage = preload("res://scripts/ui/pavilion_summon_reveal_stage.gd")
const PavilionNavOrnament = preload("res://scripts/ui/pavilion_nav_ornament.gd")

const SPIRIT_STONE_ICON: String = "res://assets/ui/icons/spirit_stone.svg"
const REFINEMENT_SHARD_ICON: String = "res://assets/ui/equipment/refinement_shard.svg"
const PAVILION_SEAL_ICON: String = "res://assets/ui/pavilion/polish/pavilion_seal.svg"
const CELESTIAL_JADE_ICON: String = "res://assets/ui/pavilion/polish/celestial_jade.svg"
const PAVILION_JADE_JIAN_ICON: String = "res://assets/ui/pavilion/polish/wanderer_jade_jian.svg"
const SANCTUARY_BANNER: String = "res://assets/ui/pavilion/polish/pavilion_sanctuary_banner.svg"
const MEDITATION_ALTAR: String = "res://assets/ui/pavilion/polish/meditation_altar.svg"
const SLOT_ICON_PATHS: Dictionary = {
	"armament": "res://assets/ui/pavilion/polish/slot_armament.svg",
	"robe": "res://assets/ui/pavilion/polish/slot_robe.svg",
	"bracer": "res://assets/ui/pavilion/polish/slot_bracer.svg",
	"boots": "res://assets/ui/pavilion/polish/slot_boots.svg",
	"pendant": "res://assets/ui/pavilion/polish/slot_pendant.svg"
}

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

const SUMMON_RELIC_SAFE_SHADER_CODE: String = """
shader_type canvas_item;

void fragment() {
    vec4 texel = texture(TEXTURE, UV);
    float left_safe = smoothstep(0.025, 0.095, UV.x);
    float right_safe = smoothstep(0.025, 0.095, 1.0 - UV.x);
    float top_safe = smoothstep(0.105, 0.235, UV.y);
    float bottom_safe = smoothstep(0.035, 0.115, 1.0 - UV.y);
    float safe_alpha = left_safe * right_safe * top_safe * bottom_safe;
    COLOR = texel * COLOR;
    COLOR.a *= safe_alpha;
}
"""

# Temporary QA wallet. This is guarded by OS.is_debug_build(), uses the existing
# idempotent verified-grant path, and therefore cannot seed release builds.
const DEBUG_SUMMON_TEST_JADE_TARGET: int = 100000
const DEBUG_SUMMON_TEST_GRANT_ID: String = "debug_summon_reveal_wallet_v1"

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
var lifetime_label: Label
var ritual_panel: PanelContainer
var ritual_icon: TextureRect
var ritual_icon_frame: PanelContainer
var ritual_pool_preview: HBoxContainer
var ritual_title_label: Label
var ritual_subtitle_label: Label
var pity_rare_track: Dictionary = {}
var pity_epic_track: Dictionary = {}
var pity_legendary_track: Dictionary = {}
var wish_rule_label: Label
var wish_preview_panel: PanelContainer
var wish_preview_icon: TextureRect
var wish_preview_name: Label
var wish_preview_state: Label
var wish_grid: GridContainer
var wish_clear_button: Button
var wish_selector_overlay: ColorRect
var wish_selector_panel: PanelContainer
var wish_summary_label: Label
var wish_open_button: Button
var summon_one_button: Button
var summon_ten_button: Button
var rates_button: Button
var rates_box: VBoxContainer
var summon_result_box: VBoxContainer
var reveal_cards: Array[Control] = []
var rates_visible: bool = false

# Full-screen summon presentation. Economy resolution still happens exclusively
# in PavilionManager; these nodes only reveal the already-resolved result.
var summon_reveal_overlay: ColorRect
var summon_reveal_stage: Control
var summon_reveal_counter: Label
var summon_reveal_rarity: Label
var summon_reveal_focus_panel: PanelContainer
var summon_reveal_icon_frame: PanelContainer
var summon_reveal_icon: TextureRect
var summon_reveal_safe_material: ShaderMaterial
var summon_reveal_name: Label
var summon_reveal_set: Label
var summon_reveal_signature: Label
var summon_reveal_state: Label
var summon_reveal_collection: Label
var summon_reveal_action: Button
var summon_reveal_skip: Button
var summon_reveal_flash: ColorRect
var summon_reveal_omen_label: Label
var summon_reveal_info_group: VBoxContainer
var summon_reveal_busy: bool = false
var summon_reveal_generation: int = 0
var summon_reveal_payload: Dictionary = {}
var summon_reveal_entries: Array = []
var summon_reveal_index: int = -1
var summon_reveal_item_visible: bool = false

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
	_install_pavilion_nav_luxury()
	_build_summon_reveal_overlay()
	if not PavilionManager.pavilion_changed.is_connected(_refresh):
		PavilionManager.pavilion_changed.connect(_refresh)
	_ensure_debug_summon_test_wallet()
	_refresh()


func _install_pavilion_nav_luxury() -> void:
	var hub_nav := get_node_or_null("SafeArea/HubNav") as Control
	if hub_nav == null:
		return
	var old_ornament := hub_nav.get_node_or_null("PavilionLuxuryOrnament")
	if old_ornament != null:
		hub_nav.remove_child(old_ornament)
		old_ornament.queue_free()
	var ornament := PavilionNavOrnament.new()
	ornament.name = "PavilionLuxuryOrnament"
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub_nav.add_child(ornament)
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub_nav.move_child(ornament, 0)


func _ensure_debug_summon_test_wallet() -> void:
	if not OS.is_debug_build():
		return
	var current_jade: int = PavilionManager.get_celestial_jade()
	if current_jade >= DEBUG_SUMMON_TEST_JADE_TARGET:
		return
	var grant_amount: int = DEBUG_SUMMON_TEST_JADE_TARGET - current_jade
	var granted: bool = PavilionManager.apply_verified_economy_grant(
		DEBUG_SUMMON_TEST_GRANT_ID,
		grant_amount,
		0
	)
	if granted:
		DebugLogger.system(
			"DEBUG Pavilion QA wallet seeded: %d Celestial Jade"
			% PavilionManager.get_celestial_jade()
		)
	elif PavilionManager.last_error != "Verified grant already consumed.":
		push_warning(
			"Pavilion DEBUG QA wallet grant skipped: " + PavilionManager.last_error
		)


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
	# Luxury masthead: strong identity, restrained footprint, layered gold/jade trim.
	var hero_stage := Control.new()
	hero_stage.custom_minimum_size = Vector2(0.0, 184.0)
	hero_stage.clip_contents = true
	content.add_child(hero_stage)

	var art := TextureRect.new()
	art.texture = load(SANCTUARY_BANNER) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_stage.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.025, 0.035, 0.28)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_stage.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title_panel := PanelContainer.new()
	title_panel.anchor_left = 0.025
	title_panel.anchor_right = 0.975
	title_panel.anchor_top = 1.0
	title_panel.anchor_bottom = 1.0
	title_panel.offset_top = -116.0
	title_panel.offset_bottom = -8.0
	title_panel.add_theme_stylebox_override("panel", _hero_overlay_style())
	hero_stage.add_child(title_panel)

	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 5)
	title_panel.add_child(hero_box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	hero_box.add_child(title_row)
	_make_icon_emblem(title_row, PAVILION_SEAL_ICON, JADE, GOLD, 54.0)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	title_row.add_child(title_box)
	_label(title_box, tr("JADE PAVILION"), 10, JADE)
	_label(title_box, tr("Sanctum of Refinement"), 22, Color(1.0, 0.88, 0.52))
	_label(title_box, tr("Cultivate, forge, and call equipment from the Celestial Pavilion."), 10, Color(0.73, 0.84, 0.81, 1.0))

	var divider := HBoxContainer.new()
	divider.add_theme_constant_override("separation", 7)
	hero_box.add_child(divider)
	var left_line := ColorRect.new()
	left_line.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.42)
	left_line.custom_minimum_size = Vector2(0.0, 1.0)
	left_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.add_child(left_line)
	var crest := _label(divider, "◇", 12, Color(GOLD.r, GOLD.g, GOLD.b, 0.86))
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var right_line := ColorRect.new()
	right_line.color = Color(JADE.r, JADE.g, JADE.b, 0.38)
	right_line.custom_minimum_size = Vector2(0.0, 1.0)
	right_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.add_child(right_line)


func _build_status_banner() -> void:
	status_panel = _panel(content, _status_style(JADE_SOFT))
	status_label = _label(status_panel, "", 12, Color(0.70, 0.95, 0.86))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size.y = 22.0


func _build_summon_section() -> void:
	var summon_shell := _panel(content, _summon_shell_style(VIOLET))
	var summon := VBoxContainer.new()
	summon.add_theme_constant_override("separation", 10)
	summon_shell.add_child(summon)

	# One premium banner owns the hierarchy. Utility information stays subordinate.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	summon.add_child(header_row)
	var header_copy := VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.add_theme_constant_override("separation", 1)
	header_row.add_child(header_copy)
	_label(header_copy, tr("CELESTIAL ARMORY"), 10, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.94))
	_label(header_copy, tr("Equipment Summon"), 28, Color(1.0, 0.88, 0.50))
	_label(header_copy, tr("Call unlocked equipment. Pity and Wish Fate persist across sessions."), 10, Color(0.69, 0.80, 0.77, 1.0))
	summon_state_label = _state_badge(header_row, tr("LOCKED"), Color(0.48, 0.54, 0.53, 1.0))
	summon_state_label.custom_minimum_size = Vector2(62.0, 0.0)

	# Celestial showcase: the actual unlocked Legendary pool becomes the art.
	ritual_panel = _panel(summon, _featured_armory_style(VIOLET, false))
	ritual_panel.custom_minimum_size = Vector2(0.0, 438.0)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0.0, 416.0)
	stage.clip_contents = true
	ritual_panel.add_child(stage)
	var stage_visual: Control = SummonStageVisual.new()
	stage_visual.name = "SummonStageVisual"
	stage.add_child(stage_visual)
	stage_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stage_margin := MarginContainer.new()
	stage_margin.add_theme_constant_override("margin_left", 18)
	stage_margin.add_theme_constant_override("margin_right", 18)
	stage_margin.add_theme_constant_override("margin_top", 14)
	stage_margin.add_theme_constant_override("margin_bottom", 14)
	stage.add_child(stage_margin)
	stage_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage_box := VBoxContainer.new()
	stage_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_box.add_theme_constant_override("separation", 5)
	stage_margin.add_child(stage_box)

	var invocation_row := HBoxContainer.new()
	invocation_row.alignment = BoxContainer.ALIGNMENT_CENTER
	invocation_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invocation_row.add_theme_constant_override("separation", 8)
	stage_box.add_child(invocation_row)
	var invocation_line_left := ColorRect.new()
	invocation_line_left.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.38)
	invocation_line_left.custom_minimum_size = Vector2(34.0, 1.0)
	invocation_line_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invocation_row.add_child(invocation_line_left)
	var stage_badge := _state_badge(invocation_row, tr("HEAVENLY RELIC INVOCATION"), VIOLET)
	stage_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	stage_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_badge.add_theme_font_size_override("font_size", 9)
	if stage_badge.get_parent() is PanelContainer:
		(stage_badge.get_parent() as PanelContainer).custom_minimum_size = Vector2(174.0, 24.0)
	var invocation_line_right := ColorRect.new()
	invocation_line_right.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.38)
	invocation_line_right.custom_minimum_size = Vector2(34.0, 1.0)
	invocation_line_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invocation_row.add_child(invocation_line_right)

	var relic_center := CenterContainer.new()
	relic_center.custom_minimum_size = Vector2(0.0, 270.0)
	stage_box.add_child(relic_center)
	var relic_stack := VBoxContainer.new()
	relic_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	relic_stack.add_theme_constant_override("separation", 5)
	relic_center.add_child(relic_stack)

	ritual_pool_preview = HBoxContainer.new()
	ritual_pool_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	ritual_pool_preview.add_theme_constant_override("separation", 9)
	relic_stack.add_child(ritual_pool_preview)

	ritual_icon_frame = PanelContainer.new()
	ritual_icon_frame.custom_minimum_size = Vector2(214.0, 214.0)
	ritual_icon_frame.add_theme_stylebox_override("panel", _featured_relic_frame_style(VIOLET, false))
	relic_stack.add_child(ritual_icon_frame)
	ritual_icon = TextureRect.new()
	ritual_icon.texture = load(PAVILION_SEAL_ICON) as Texture2D
	ritual_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ritual_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ritual_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ritual_icon_frame.add_child(ritual_icon)
	ritual_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ritual_icon.offset_left = 18.0
	ritual_icon.offset_top = 18.0
	ritual_icon.offset_right = -18.0
	ritual_icon.offset_bottom = -18.0

	ritual_title_label = _label(stage_box, tr("CELESTIAL ARMORY"), 23, Color(1.0, 0.87, 0.48))
	ritual_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ritual_subtitle_label = _label(stage_box, tr("SELECT A LEGENDARY WISH • OR SUMMON THE OPEN POOL"), 10, TEXT_MUTED)
	ritual_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wish_preview_panel = ritual_panel
	wish_preview_icon = ritual_icon
	wish_preview_name = ritual_title_label
	wish_preview_state = ritual_subtitle_label

	starter_button = _button(summon, tr("CLAIM INITIATE GIFT • 10 PAVILION SEALS"), _claim_starter_seals, true, JADE)

	var fate_row := HBoxContainer.new()
	fate_row.add_theme_constant_override("separation", 8)
	summon.add_child(fate_row)
	var fate_caption := _label(fate_row, tr("FATE CONSTELLATION"), 10, Color(GOLD.r, GOLD.g, GOLD.b, 0.90))
	fate_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var guarantee_caption := _label(fate_row, tr("GUARANTEE TRACKS"), 8, Color(0.50, 0.63, 0.61, 1.0))
	guarantee_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var pity_row := HBoxContainer.new()
	pity_row.add_theme_constant_override("separation", 6)
	pity_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summon.add_child(pity_row)
	pity_rare_track = _create_pity_track(pity_row, tr("RARE+"), EquipmentVisualCatalog.get_rarity_color("rare"))
	pity_epic_track = _create_pity_track(pity_row, tr("EPIC+"), EquipmentVisualCatalog.get_rarity_color("epic"))
	pity_legendary_track = _create_pity_track(pity_row, tr("LEGENDARY"), LEGENDARY_GOLD)
	var rare_card := pity_rare_track.get("card") as PanelContainer
	var epic_card := pity_epic_track.get("card") as PanelContainer
	var legendary_card := pity_legendary_track.get("card") as PanelContainer
	if rare_card != null:
		rare_card.size_flags_stretch_ratio = 0.80
	if epic_card != null:
		epic_card.size_flags_stretch_ratio = 0.88
	if legendary_card != null:
		legendary_card.size_flags_stretch_ratio = 1.32
		legendary_card.custom_minimum_size.y = 80.0

	var wish_panel := _panel(summon, _wish_preview_style(VIOLET, false))
	var wish_summary_row := HBoxContainer.new()
	wish_summary_row.add_theme_constant_override("separation", 9)
	wish_panel.add_child(wish_summary_row)
	var wish_summary_copy := VBoxContainer.new()
	wish_summary_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wish_summary_copy.add_theme_constant_override("separation", 0)
	wish_summary_row.add_child(wish_summary_copy)
	_label(wish_summary_copy, tr("LEGENDARY WISH"), 9, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.90))
	wish_summary_label = _label(wish_summary_copy, tr("NO WISH TARGET"), 13, TEXT_MAIN)
	wish_open_button = _button(wish_summary_row, tr("SET WISH"), _open_wish_selector, false, VIOLET)
	wish_open_button.custom_minimum_size = Vector2(118.0, 44.0)

	# Primary action gets the strongest gold mass and spacing on the page.
	summon_ten_button = _button(summon, tr("SUMMON ×10"), _summon.bind(10), true, GOLD)
	summon_ten_button.custom_minimum_size.y = 94.0
	summon_ten_button.add_theme_font_size_override("font_size", 17)
	_apply_summon_cta_style(summon_ten_button, GOLD, true)

	var secondary_row := HBoxContainer.new()
	secondary_row.add_theme_constant_override("separation", 7)
	summon.add_child(secondary_row)
	summon_one_button = _button(secondary_row, tr("SUMMON ×1"), _summon.bind(1), false, VIOLET)
	summon_one_button.custom_minimum_size.y = 50.0
	summon_one_button.size_flags_stretch_ratio = 0.92
	summon_one_button.add_theme_font_size_override("font_size", 12)
	_apply_summon_cta_style(summon_one_button, VIOLET, false)
	rates_button = _button(secondary_row, tr("DROP RATES & PITY RULES"), _toggle_rates, false, CYAN)
	rates_button.custom_minimum_size.y = 50.0
	rates_button.size_flags_stretch_ratio = 1.08

	var lifetime_row := HBoxContainer.new()
	summon.add_child(lifetime_row)
	var lifetime_caption := _label(lifetime_row, tr("LIFETIME SUMMONS"), 9, Color(0.50, 0.68, 0.66, 1.0))
	lifetime_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lifetime_label = _label(lifetime_row, "0", 10, Color(CYAN.r, CYAN.g, CYAN.b, 0.82))
	lifetime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	rates_box = VBoxContainer.new()
	rates_box.add_theme_constant_override("separation", 5)
	rates_box.visible = false
	summon.add_child(rates_box)
	var billing_note := _label(rates_box, tr("Celestial Jade purchase remains unavailable until verified platform billing is integrated."), 9, Color(0.47, 0.57, 0.56, 1.0))
	billing_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	summon_result_box = VBoxContainer.new()
	summon_result_box.add_theme_constant_override("separation", 8)
	summon_result_box.visible = false
	summon.add_child(summon_result_box)
	_build_wish_selector_overlay()


func _build_wish_selector_overlay() -> void:
	wish_selector_overlay = ColorRect.new()
	wish_selector_overlay.name = "WishSelectorOverlay"
	wish_selector_overlay.color = Color(0.0, 0.0, 0.0, 0.86)
	wish_selector_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	wish_selector_overlay.visible = false
	add_child(wish_selector_overlay)
	wish_selector_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	wish_selector_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	wish_selector_panel = PanelContainer.new()
	wish_selector_panel.custom_minimum_size = Vector2(568.0, 0.0)
	wish_selector_panel.add_theme_stylebox_override("panel", _summon_shell_style(VIOLET))
	center.add_child(wish_selector_panel)
	var modal_margin := MarginContainer.new()
	modal_margin.add_theme_constant_override("margin_left", 10)
	modal_margin.add_theme_constant_override("margin_right", 10)
	modal_margin.add_theme_constant_override("margin_top", 8)
	modal_margin.add_theme_constant_override("margin_bottom", 8)
	wish_selector_panel.add_child(modal_margin)
	var modal_box := VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 9)
	modal_margin.add_child(modal_box)

	var wish_header := HBoxContainer.new()
	modal_box.add_child(wish_header)
	var wish_header_copy := VBoxContainer.new()
	wish_header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wish_header.add_child(wish_header_copy)
	_label(wish_header_copy, tr("CELESTIAL ARMORY"), 10, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.92))
	_label(wish_header_copy, tr("LEGENDARY WISH"), 22, Color(1.0, 0.86, 0.48))
	var close_button := _button(wish_header, "×", _close_wish_selector, false, VIOLET)
	close_button.custom_minimum_size = Vector2(46.0, 42.0)
	close_button.add_theme_font_size_override("font_size", 18)

	wish_rule_label = _label(
		modal_box,
		tr("Choose one unlocked Legendary. Miss once and Wish Fate guarantees the next Legendary target."),
		11,
		TEXT_MUTED
	)

	wish_grid = GridContainer.new()
	wish_grid.columns = 2
	wish_grid.add_theme_constant_override("h_separation", 8)
	wish_grid.add_theme_constant_override("v_separation", 8)
	modal_box.add_child(wish_grid)

	wish_clear_button = _button(modal_box, tr("CLEAR"), _select_wish_target.bind(""), false, VIOLET)
	wish_clear_button.visible = false


func _open_wish_selector() -> void:
	if wish_selector_overlay == null:
		return
	wish_selector_overlay.visible = true
	wish_selector_overlay.move_to_front()


func _close_wish_selector() -> void:
	if wish_selector_overlay != null:
		wish_selector_overlay.visible = false


func _build_summon_reveal_overlay() -> void:
	summon_reveal_overlay = ColorRect.new()
	summon_reveal_overlay.name = "SummonRevealOverlay"
	summon_reveal_overlay.color = Color(0.0, 0.0, 0.0, 0.985)
	summon_reveal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	summon_reveal_overlay.visible = false
	add_child(summon_reveal_overlay)
	summon_reveal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	summon_reveal_stage = SummonRevealStage.new()
	summon_reveal_stage.name = "SummonRevealStage"
	summon_reveal_overlay.add_child(summon_reveal_stage)
	summon_reveal_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	summon_reveal_flash = ColorRect.new()
	summon_reveal_flash.color = Color(1.0, 0.82, 0.36, 0.0)
	summon_reveal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summon_reveal_overlay.add_child(summon_reveal_flash)
	summon_reveal_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var safe_margin := MarginContainer.new()
	safe_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	safe_margin.add_theme_constant_override("margin_left", 26)
	safe_margin.add_theme_constant_override("margin_right", 26)
	safe_margin.add_theme_constant_override("margin_top", 34)
	safe_margin.add_theme_constant_override("margin_bottom", 34)
	summon_reveal_overlay.add_child(safe_margin)
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var reveal_box := VBoxContainer.new()
	reveal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	reveal_box.add_theme_constant_override("separation", 10)
	safe_margin.add_child(reveal_box)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	reveal_box.add_child(top_row)
	var top_copy := VBoxContainer.new()
	top_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_copy.add_theme_constant_override("separation", 1)
	top_row.add_child(top_copy)
	_label(top_copy, tr("CELESTIAL SUMMON"), 11, JADE)
	_label(top_copy, tr("THE ARMORY STIRS"), 24, Color(1.0, 0.87, 0.50))
	summon_reveal_omen_label = _label(top_copy, tr("AWAITING HEAVENLY SIGN"), 10, Color(0.66, 0.78, 0.75, 1.0))
	summon_reveal_counter = _label(top_row, "", 12, TEXT_MUTED)
	summon_reveal_counter.custom_minimum_size = Vector2(116.0, 0.0)
	summon_reveal_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summon_reveal_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	summon_reveal_focus_panel = PanelContainer.new()
	summon_reveal_focus_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summon_reveal_focus_panel.custom_minimum_size = Vector2(0.0, 736.0)
	summon_reveal_focus_panel.add_theme_stylebox_override("panel", _summon_reveal_focus_style(VIOLET, false))
	reveal_box.add_child(summon_reveal_focus_panel)

	var artifact_margin := MarginContainer.new()
	artifact_margin.add_theme_constant_override("margin_left", 18)
	artifact_margin.add_theme_constant_override("margin_right", 18)
	artifact_margin.add_theme_constant_override("margin_top", 18)
	artifact_margin.add_theme_constant_override("margin_bottom", 18)
	summon_reveal_focus_panel.add_child(artifact_margin)

	var artifact_box := VBoxContainer.new()
	artifact_box.alignment = BoxContainer.ALIGNMENT_CENTER
	artifact_box.add_theme_constant_override("separation", 9)
	artifact_margin.add_child(artifact_box)

	summon_reveal_rarity = _state_badge(artifact_box, tr("SEALED RELIC"), VIOLET)
	summon_reveal_rarity.add_theme_font_size_override("font_size", 11)

	var icon_center := CenterContainer.new()
	icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_center.custom_minimum_size = Vector2(0.0, 418.0)
	artifact_box.add_child(icon_center)
	summon_reveal_icon_frame = PanelContainer.new()
	summon_reveal_icon_frame.custom_minimum_size = Vector2(352.0, 352.0)
	summon_reveal_icon_frame.add_theme_stylebox_override("panel", _summon_reveal_icon_style(VIOLET, false))
	icon_center.add_child(summon_reveal_icon_frame)
	summon_reveal_icon = TextureRect.new()
	summon_reveal_icon.texture = load(PAVILION_SEAL_ICON) as Texture2D
	summon_reveal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	summon_reveal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	summon_reveal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summon_reveal_safe_material = _make_summon_relic_safe_material()
	summon_reveal_icon.material = null
	summon_reveal_icon_frame.add_child(summon_reveal_icon)
	summon_reveal_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summon_reveal_icon.offset_left = 24.0
	summon_reveal_icon.offset_top = 24.0
	summon_reveal_icon.offset_right = -24.0
	summon_reveal_icon.offset_bottom = -24.0

	summon_reveal_info_group = VBoxContainer.new()
	summon_reveal_info_group.add_theme_constant_override("separation", 7)
	artifact_box.add_child(summon_reveal_info_group)
	summon_reveal_name = _label(summon_reveal_info_group, tr("CELESTIAL SEAL"), 29, Color(1.0, 0.87, 0.50))
	summon_reveal_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summon_reveal_set = _label(summon_reveal_info_group, tr("REVEAL THE EQUIPMENT WITHIN"), 12, TEXT_MUTED)
	summon_reveal_set.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summon_reveal_signature = _label(summon_reveal_info_group, "", 11, Color(0.72, 0.80, 0.78, 1.0))
	summon_reveal_signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summon_reveal_signature.visible = false
	summon_reveal_state = _state_badge(summon_reveal_info_group, tr("READY TO REVEAL"), JADE)
	summon_reveal_state.add_theme_font_size_override("font_size", 11)
	summon_reveal_collection = _label(summon_reveal_info_group, _collection_progress_text(), 11, Color(CYAN.r, CYAN.g, CYAN.b, 0.90))
	summon_reveal_collection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 9)
	reveal_box.add_child(action_row)
	summon_reveal_skip = _button(action_row, tr("SKIP TO RESULTS"), _finish_summon_reveal.bind(true), false, CYAN)
	summon_reveal_skip.custom_minimum_size = Vector2(174.0, 58.0)
	summon_reveal_action = _button(action_row, tr("REVEAL"), _advance_summon_reveal, true, GOLD)
	summon_reveal_action.custom_minimum_size.y = 70.0
	summon_reveal_action.size_flags_stretch_ratio = 1.58
	_apply_summon_cta_style(summon_reveal_action, GOLD, true)


func _reset_summon_reveal_visual() -> void:
	if summon_reveal_overlay == null:
		return
	summon_reveal_index = -1
	summon_reveal_item_visible = false
	summon_reveal_busy = false
	summon_reveal_generation += 1
	summon_reveal_rarity.text = tr("SEALED RELIC")
	summon_reveal_rarity.add_theme_color_override("font_color", VIOLET)
	if summon_reveal_rarity.get_parent() is PanelContainer:
		(summon_reveal_rarity.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _chip_style(VIOLET))
	summon_reveal_icon.texture = load(PAVILION_SEAL_ICON) as Texture2D
	summon_reveal_icon.material = null
	summon_reveal_icon.modulate = Color.WHITE
	summon_reveal_icon.scale = Vector2.ONE
	summon_reveal_icon_frame.add_theme_stylebox_override("panel", _summon_reveal_icon_style(VIOLET, false))
	if summon_reveal_focus_panel != null:
		summon_reveal_focus_panel.add_theme_stylebox_override("panel", _summon_reveal_focus_style(VIOLET, false))
	summon_reveal_name.text = tr("CELESTIAL SEAL")
	summon_reveal_name.add_theme_color_override("font_color", Color(1.0, 0.87, 0.50))
	summon_reveal_set.text = tr("REVEAL THE EQUIPMENT WITHIN")
	summon_reveal_set.add_theme_color_override("font_color", TEXT_MUTED)
	summon_reveal_signature.text = ""
	summon_reveal_signature.visible = false
	summon_reveal_state.text = tr("READY TO REVEAL")
	summon_reveal_state.add_theme_color_override("font_color", JADE)
	if summon_reveal_state.get_parent() is PanelContainer:
		(summon_reveal_state.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _chip_style(JADE))
	summon_reveal_collection.text = _collection_progress_text()
	summon_reveal_action.text = tr("REVEAL")
	summon_reveal_action.disabled = false
	summon_reveal_skip.visible = summon_reveal_entries.size() > 1
	if summon_reveal_omen_label != null:
		summon_reveal_omen_label.text = tr("AWAITING HEAVENLY SIGN")
		summon_reveal_omen_label.add_theme_color_override("font_color", Color(0.66, 0.78, 0.75, 1.0))
	if summon_reveal_flash != null:
		summon_reveal_flash.color = Color(1.0, 0.82, 0.36, 0.0)
	if summon_reveal_info_group != null:
		summon_reveal_info_group.modulate = Color.WHITE
	if summon_reveal_stage != null and summon_reveal_stage.has_method("configure"):
		summon_reveal_stage.call("configure", VIOLET, "common", false)


func _start_summon_reveal(result: Dictionary) -> void:
	if summon_reveal_overlay == null:
		return
	summon_reveal_payload = result.duplicate(true)
	summon_reveal_entries = result.get("results", []).duplicate(true)
	if summon_reveal_entries.is_empty():
		return
	_reset_summon_reveal_visual()
	summon_reveal_counter.text = tr("PULL %d OF %d") % [1, summon_reveal_entries.size()]
	summon_reveal_overlay.visible = true
	summon_reveal_overlay.move_to_front()
	AudioManager.play_sfx("summon_charge")


func _advance_summon_reveal() -> void:
	if summon_reveal_busy:
		return
	if summon_reveal_entries.is_empty():
		_finish_summon_reveal(false)
		return
	var next_index: int = 0 if summon_reveal_index < 0 else summon_reveal_index + 1
	if next_index >= summon_reveal_entries.size():
		_finish_summon_reveal(false)
		return
	_begin_summon_reveal_sequence(next_index)


func _begin_summon_reveal_sequence(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= summon_reveal_entries.size():
		return
	summon_reveal_busy = true
	summon_reveal_action.disabled = true
	summon_reveal_generation += 1
	var sequence_generation: int = summon_reveal_generation
	_prepare_summon_omen(entry_index)
	var raw_entry = summon_reveal_entries[entry_index]
	var rarity: String = "common"
	if raw_entry is Dictionary:
		rarity = str((raw_entry as Dictionary).get("rarity", "common"))
	var omen_duration: float = _reveal_omen_duration(rarity)
	await get_tree().create_timer(omen_duration).timeout
	if sequence_generation != summon_reveal_generation:
		return
	if summon_reveal_overlay == null or not summon_reveal_overlay.visible:
		return
	summon_reveal_index = entry_index
	_show_summon_reveal_entry(entry_index)
	summon_reveal_busy = false
	summon_reveal_action.disabled = false


func _prepare_summon_omen(entry_index: int) -> void:
	var raw_entry = summon_reveal_entries[entry_index]
	if not raw_entry is Dictionary:
		return
	var entry: Dictionary = raw_entry
	var rarity: String = str(entry.get("rarity", "common"))
	var item_id: String = str(entry.get("item_id", ""))
	var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
	var slot_id: String = str(item_data.get("slot", ""))
	var accent: Color = EquipmentVisualCatalog.get_rarity_color(rarity)
	var legendary: bool = rarity == "legendary"
	summon_reveal_counter.text = tr("PULL %d OF %d") % [entry_index + 1, summon_reveal_entries.size()]
	summon_reveal_rarity.text = tr("CELESTIAL OMEN")
	var sealed_accent := Color(0.58, 0.64, 0.72, 1.0)
	summon_reveal_rarity.add_theme_color_override("font_color", Color(0.82, 0.86, 0.88, 1.0))
	if summon_reveal_rarity.get_parent() is PanelContainer:
		(summon_reveal_rarity.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _chip_style(sealed_accent))
	summon_reveal_icon.texture = load(_get_summon_slot_icon_path(slot_id)) as Texture2D
	summon_reveal_icon.material = null
	summon_reveal_icon.modulate = Color(1.0, 1.0, 1.0, 0.82)
	summon_reveal_icon_frame.add_theme_stylebox_override("panel", _summon_reveal_icon_style(sealed_accent, false))
	if summon_reveal_focus_panel != null:
		summon_reveal_focus_panel.add_theme_stylebox_override("panel", _summon_reveal_focus_style(sealed_accent, false))
	summon_reveal_name.text = tr(_get_summon_slot_reveal_title(slot_id))
	summon_reveal_set.text = tr(_get_summon_slot_reveal_subtitle(slot_id))
	summon_reveal_signature.visible = false
	summon_reveal_state.text = tr("FATE IS BEING READ")
	summon_reveal_state.add_theme_color_override("font_color", accent)
	if summon_reveal_state.get_parent() is PanelContainer:
		(summon_reveal_state.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _chip_style(accent))
	if summon_reveal_omen_label != null:
		summon_reveal_omen_label.text = _rarity_omen_text(rarity)
		summon_reveal_omen_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.98))
	if summon_reveal_stage != null and summon_reveal_stage.has_method("prepare_omen"):
		summon_reveal_stage.call("prepare_omen", rarity)
	var omen_duration: float = _reveal_omen_duration(rarity)
	if legendary:
		if AudioManager.has_method("duck_music"):
			AudioManager.call("duck_music", omen_duration + 0.42, -34.0)
		AudioManager.play_sfx("summon_legendary_omen")
	elif rarity == "epic":
		if AudioManager.has_method("duck_music"):
			AudioManager.call("duck_music", omen_duration + 0.18, -19.0)
		AudioManager.play_sfx("summon_charge")
	else:
		AudioManager.play_sfx("summon_charge")
	if SettingsManager.reduced_effects:
		return
	summon_reveal_icon.pivot_offset = summon_reveal_icon.size * 0.5
	summon_reveal_icon.scale = Vector2(0.92, 0.92)
	var omen_tween := create_tween().set_parallel(true)
	omen_tween.tween_property(summon_reveal_icon, "scale", Vector2(1.035, 1.035), _reveal_omen_duration(rarity)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	omen_tween.tween_property(summon_reveal_icon, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)


func _reveal_omen_duration(rarity: String) -> float:
	match rarity:
		"legendary":
			return 1.55
		"epic":
			return 0.78
		"rare":
			return 0.42
		_:
			return 0.20


func _rarity_omen_text(rarity: String) -> String:
	match rarity:
		"legendary":
			return tr("THE HEAVENS TURN GOLD")
		"epic":
			return tr("PURPLE HEAVENS RESONATE")
		"rare":
			return tr("AZURE STARS ANSWER")
		_:
			return tr("JADE QI GATHERS")


func _show_summon_reveal_entry(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= summon_reveal_entries.size():
		return
	var raw_entry = summon_reveal_entries[entry_index]
	if not raw_entry is Dictionary:
		return
	var entry: Dictionary = raw_entry
	var item_id: String = str(entry.get("item_id", ""))
	var data: Dictionary = EquipmentManager.get_item_data(item_id)
	var rarity: String = str(entry.get("rarity", data.get("rarity", "common")))
	var accent: Color = EquipmentVisualCatalog.get_rarity_color(rarity)
	var legendary: bool = rarity == "legendary"
	var is_duplicate: bool = bool(entry.get("duplicate", false))
	var set_id: String = EquipmentSetCatalog.get_set_id_for_item(item_id)
	var set_display_name: String = EquipmentSetCatalog.get_display_name(set_id)
	var set_identity: String = EquipmentSetCatalog.get_identity(set_id)

	summon_reveal_item_visible = true
	summon_reveal_counter.text = tr("PULL %d OF %d") % [entry_index + 1, summon_reveal_entries.size()]
	summon_reveal_rarity.text = tr(rarity.capitalize()).to_upper()
	summon_reveal_rarity.add_theme_color_override("font_color", accent)
	if summon_reveal_rarity.get_parent() is PanelContainer:
		(summon_reveal_rarity.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _chip_style(accent))
	summon_reveal_icon.texture = load(_get_pavilion_equipment_icon_path(item_id)) as Texture2D
	summon_reveal_icon.material = summon_reveal_safe_material
	summon_reveal_icon.modulate = Color.WHITE
	summon_reveal_icon_frame.add_theme_stylebox_override("panel", _summon_reveal_icon_style(accent, legendary))
	if summon_reveal_focus_panel != null:
		summon_reveal_focus_panel.add_theme_stylebox_override("panel", _summon_reveal_focus_style(accent, legendary))
	summon_reveal_name.text = tr(str(data.get("display_name", item_id)))
	summon_reveal_name.add_theme_color_override("font_color", Color(1.0, 0.84, 0.40, 1.0) if legendary else TEXT_MAIN)
	if not set_display_name.is_empty():
		summon_reveal_set.text = tr("SET • %s") % tr(set_display_name)
		if not set_identity.is_empty():
			summon_reveal_set.text += "\n" + tr(set_identity)
	else:
		summon_reveal_set.text = tr(str(data.get("slot", "equipment")).capitalize()).to_upper()
	summon_reveal_set.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.92))

	var signature_name: String = str(data.get("signature_effect_name", ""))
	var signature_description: String = str(data.get("signature_effect_description", ""))
	if not signature_name.is_empty():
		summon_reveal_signature.text = tr("SIGNATURE • %s") % tr(signature_name)
		if not signature_description.is_empty():
			summon_reveal_signature.text += "\n" + tr(signature_description)
		summon_reveal_signature.visible = true
	else:
		summon_reveal_signature.visible = false

	if is_duplicate:
		var shard_gain: int = int(entry.get("duplicate_shards", 0))
		summon_reveal_state.text = tr("DUPLICATE TRANSMUTED • +%d SHARDS") % shard_gain
		summon_reveal_state.add_theme_color_override("font_color", CYAN)
		if summon_reveal_state.get_parent() is PanelContainer:
			(summon_reveal_state.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _chip_style(CYAN))
	else:
		summon_reveal_state.text = tr("NEW DISCOVERY • ADDED TO COLLECTION")
		summon_reveal_state.add_theme_color_override("font_color", JADE)
		if summon_reveal_state.get_parent() is PanelContainer:
			(summon_reveal_state.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _chip_style(JADE))

	summon_reveal_collection.text = _collection_progress_text()
	if summon_reveal_omen_label != null:
		summon_reveal_omen_label.text = tr("CELESTIAL RELIC REVEALED") if not legendary else tr("HEAVENLY RELIC DESCENDS")
		summon_reveal_omen_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.98))
	if entry_index >= summon_reveal_entries.size() - 1:
		summon_reveal_action.text = tr("VIEW SUMMON RESULTS")
		summon_reveal_skip.visible = false
	else:
		summon_reveal_action.text = tr("NEXT REVEAL • %d/%d") % [entry_index + 2, summon_reveal_entries.size()]
		summon_reveal_skip.visible = summon_reveal_entries.size() > 1

	if summon_reveal_stage != null:
		if summon_reveal_stage.has_method("configure"):
			summon_reveal_stage.call("configure", accent, rarity, true)
		if summon_reveal_stage.has_method("trigger_reveal"):
			summon_reveal_stage.call("trigger_reveal")
	_flash_summon_reveal(accent, legendary)
	_play_reveal_item_feedback(rarity, is_duplicate)
	_animate_summon_reveal_item(rarity)


func _animate_summon_reveal_item(rarity: String) -> void:
	var legendary: bool = rarity == "legendary"
	if summon_reveal_icon == null:
		return
	if SettingsManager.reduced_effects:
		summon_reveal_icon.scale = Vector2.ONE
		summon_reveal_icon.modulate = Color.WHITE
		if summon_reveal_info_group != null:
			summon_reveal_info_group.modulate = Color.WHITE
		return
	summon_reveal_icon.pivot_offset = summon_reveal_icon.size * 0.5
	summon_reveal_icon.scale = Vector2(0.42, 0.42) if legendary else Vector2(0.60, 0.60)
	summon_reveal_icon.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if summon_reveal_info_group != null:
		summon_reveal_info_group.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var peak_scale := Vector2(1.20, 1.20) if legendary else (Vector2(1.10, 1.10) if rarity == "epic" else Vector2(1.06, 1.06))
	var reveal_duration: float = 0.52 if legendary else (0.34 if rarity == "epic" else 0.24)
	var reveal_tween := create_tween().set_parallel(true)
	reveal_tween.tween_property(summon_reveal_icon, "scale", peak_scale, reveal_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(summon_reveal_icon, "modulate", Color.WHITE, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var settle := create_tween()
	settle.tween_interval(reveal_duration)
	settle.tween_property(summon_reveal_icon, "scale", Vector2.ONE, 0.34 if legendary else 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if summon_reveal_info_group != null:
		settle.tween_interval(0.04 if legendary else 0.0)
		settle.tween_property(summon_reveal_info_group, "modulate", Color.WHITE, 0.28 if legendary else 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_reveal_item_feedback(rarity: String, is_duplicate: bool) -> void:
	var outcome_cue: String = "summon_duplicate" if is_duplicate else "summon_new"
	var outcome_delay: float = 0.08
	match rarity:
		"legendary":
			AudioManager.play_sfx("summon_legendary_reveal")
			outcome_delay = 0.46
		"epic":
			AudioManager.play_sfx("summon_epic")
			outcome_delay = 0.22
		"rare":
			AudioManager.play_sfx("summon_rare")
			outcome_delay = 0.12
		_:
			AudioManager.play_sfx("equip")
	var outcome_timer := get_tree().create_timer(outcome_delay)
	outcome_timer.timeout.connect(AudioManager.play_sfx.bind(outcome_cue), CONNECT_ONE_SHOT)


func _flash_summon_reveal(accent: Color, legendary: bool) -> void:
	if summon_reveal_flash == null or SettingsManager.reduced_effects:
		return
	var flash_alpha: float = 0.34 if legendary else 0.18
	summon_reveal_flash.color = Color(accent.r, accent.g, accent.b, flash_alpha)
	var flash_tween := create_tween()
	flash_tween.tween_property(
		summon_reveal_flash,
		"color",
		Color(accent.r, accent.g, accent.b, 0.0),
		0.48 if legendary else 0.30
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _finish_summon_reveal(_skipped: bool = false) -> void:
	summon_reveal_generation += 1
	summon_reveal_busy = false
	if summon_reveal_action != null:
		summon_reveal_action.disabled = false
	if summon_reveal_overlay != null:
		summon_reveal_overlay.visible = false
	if not summon_reveal_payload.is_empty():
		_play_summon_ritual_feedback(summon_reveal_payload)
	summon_reveal_payload.clear()
	summon_reveal_entries.clear()
	summon_reveal_index = -1
	summon_reveal_item_visible = false


func _collection_progress_text() -> String:
	var item_ids: Array[String] = EquipmentManager.get_item_ids()
	var owned_count: int = 0
	for item_id: String in item_ids:
		if InventoryManager.owns_item(item_id):
			owned_count += 1
	return tr("COLLECTION • %d / %d") % [owned_count, item_ids.size()]


func _build_meditation_section() -> void:
	var meditation := _section_card(
		content,
		tr("DAILY RESONANCE"),
		tr("Daily Meditation"),
		tr("A quiet moment grants 20 Spirit Stones once per local day."),
		JADE
	)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	meditation.add_child(body)
	meditation_altar_frame = PanelContainer.new()
	meditation_altar_frame.custom_minimum_size = Vector2(118.0, 118.0)
	meditation_altar_frame.add_theme_stylebox_override("panel", _meditation_altar_style(JADE, true))
	body.add_child(meditation_altar_frame)
	meditation_altar_icon = TextureRect.new()
	meditation_altar_icon.texture = load(MEDITATION_ALTAR) as Texture2D
	meditation_altar_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	meditation_altar_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	meditation_altar_frame.add_child(meditation_altar_icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 5)
	body.add_child(copy)
	meditation_state_label = _state_badge(copy, tr("AVAILABLE"), JADE)
	var reward_label := _label(copy, "+20  •  " + _spirit_stone_caption(), 17, Color(1.0, 0.88, 0.50))
	reward_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	reward_label.add_theme_constant_override("shadow_offset_x", 1)
	reward_label.add_theme_constant_override("shadow_offset_y", 1)
	cadence_label = _label(copy, "", 9, Color(0.69, 0.83, 0.79, 1.0))
	chest = _button(copy, tr("MEDITATE • +20 SPIRIT STONES"), _meditate, true, JADE)
	chest.custom_minimum_size.y = 48.0


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
	var panel := _panel(content, _sanctum_section_style(CYAN, 10))
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
	# Healthy state is the default and should not consume visual hierarchy.
	# Status chrome only appears when the player actually needs information.
	if SaveManager.is_progress_read_only():
		_set_status(tr("SAVE RECOVERY REQUIRED • REOPEN THE GAME BEFORE CHANGING ECONOMY STATE"), Color(0.95, 0.43, 0.38))
	elif not EquipmentManager.can_modify_equipment():
		_set_status(tr("FORGE SEALED DURING ACTIVE GAMEPLAY • SUMMON OWNERSHIP REMAINS PERMANENT"), GOLD)
	else:
		status_panel.visible = false

func _refresh_summon_panel() -> void:
	var unlocked: bool = PavilionManager.is_summon_unlocked()
	var read_only: bool = SaveManager.is_progress_read_only()
	if unlocked:
		summon_state_label.visible = false
		starter_button.visible = not PavilionManager.has_claimed_starter_seals()
		starter_button.disabled = not PavilionManager.can_claim_starter_seals()
		ritual_icon.modulate = Color.WHITE
	else:
		summon_state_label.visible = true
		summon_state_label.text = tr("LOCKED")
		summon_state_label.add_theme_color_override("font_color", Color(0.64, 0.69, 0.68, 1.0))
		starter_button.visible = false
		ritual_icon.texture = load(PAVILION_SEAL_ICON) as Texture2D
		ritual_title_label.text = tr("CELESTIAL ARMORY SEALED")
		ritual_subtitle_label.text = tr("CLEAR CHAPTER 1-5 TO AWAKEN THE ARMORY")
		ritual_title_label.add_theme_color_override("font_color", Color(0.70, 0.72, 0.70, 1.0))
		ritual_subtitle_label.add_theme_color_override("font_color", Color(0.52, 0.58, 0.57, 1.0))
		ritual_panel.add_theme_stylebox_override("panel", _featured_armory_style(Color(0.38, 0.44, 0.44, 1.0), false))
		ritual_icon.modulate = Color(0.62, 0.66, 0.66, 0.72)

	lifetime_label.text = _format_count(PavilionManager.get_lifetime_pulls())
	var pity: Dictionary = PavilionManager.get_summon_pity_status()
	_update_pity_track(
		pity_rare_track,
		int(pity.get("rare_plus_counter", 0)),
		10,
		int(pity.get("rare_plus_remaining", 10)),
		true,
		EquipmentVisualCatalog.get_rarity_color("rare")
	)
	_update_pity_track(
		pity_epic_track,
		int(pity.get("epic_plus_counter", 0)),
		30,
		int(pity.get("epic_plus_remaining", 30)),
		true,
		EquipmentVisualCatalog.get_rarity_color("epic")
	)
	_update_pity_track(
		pity_legendary_track,
		int(pity.get("legendary_counter", 0)),
		50,
		int(pity.get("legendary_remaining", 50)),
		bool(pity.get("legendary_active", false)),
		LEGENDARY_GOLD
	)

	if wish_rule_label != null:
		if PavilionManager.is_wish_fate_guaranteed():
			wish_rule_label.text = tr("WISH FATE ACTIVE • NEXT LEGENDARY IS GUARANTEED TO MATCH YOUR TARGET")
			wish_rule_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.34, 1.0))
		else:
			wish_rule_label.text = tr("Choose one unlocked Legendary. Miss once and Wish Fate guarantees the next Legendary target.")
			wish_rule_label.add_theme_color_override("font_color", TEXT_MUTED)
	_sync_wish_options()
	_rebuild_drop_rates()
	summon_one_button.text = _summon_button_text(1)
	summon_ten_button.text = _summon_button_text(10)
	summon_one_button.disabled = read_only or not unlocked or not PavilionManager.can_summon(1)
	summon_ten_button.disabled = read_only or not unlocked or not PavilionManager.can_summon(10)


func _sync_wish_options() -> void:
	for child: Node in ritual_pool_preview.get_children():
		ritual_pool_preview.remove_child(child)
		child.queue_free()
	for child: Node in wish_grid.get_children():
		wish_grid.remove_child(child)
		child.queue_free()

	var options: Array[String] = PavilionManager.get_wish_target_options()
	var current: String = PavilionManager.get_wish_target_item_id()
	var read_only: bool = SaveManager.is_progress_read_only()
	var fate_active: bool = PavilionManager.is_wish_fate_guaranteed()
	var unlocked: bool = PavilionManager.is_summon_unlocked()

	if current.is_empty():
		wish_preview_icon.texture = load(PAVILION_SEAL_ICON) as Texture2D
		wish_preview_name.text = tr("CELESTIAL ARMORY") if unlocked else tr("CELESTIAL ARMORY SEALED")
		wish_preview_state.text = tr("NO WISH TARGET • ALL UNLOCKED EQUIPMENT SHARE THE POOL") if unlocked else tr("CLEAR CHAPTER 1-5 TO AWAKEN THE ARMORY")
		wish_preview_state.add_theme_color_override("font_color", TEXT_MUTED)
		wish_preview_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48) if unlocked else Color(0.70, 0.72, 0.70, 1.0))
		wish_preview_panel.add_theme_stylebox_override("panel", _featured_armory_style(VIOLET if unlocked else Color(0.38, 0.44, 0.44, 1.0), unlocked))
		wish_summary_label.text = tr("NO WISH TARGET") if unlocked else tr("CELESTIAL ARMORY SEALED")
		wish_summary_label.add_theme_color_override("font_color", TEXT_MAIN if unlocked else Color(0.62, 0.68, 0.67, 1.0))
		wish_open_button.text = tr("SET WISH")

		# In open-pool mode, actual unlocked Legendary art becomes the banner artwork.
		# This communicates desirable content without implying a rate-up target.
		if unlocked and not options.is_empty():
			ritual_icon_frame.visible = false
			ritual_pool_preview.visible = true
			var preview_ids: Array = options.slice(0, mini(options.size(), 4))
			for preview_index: int in range(preview_ids.size()):
				var item_id: String = str(preview_ids[preview_index])
				var is_centerpiece: bool = (preview_ids.size() >= 4 and preview_index in [1, 2]) or (preview_ids.size() < 4 and preview_index == int(float(preview_ids.size()) / 2.0))
				var relic_size: float = 92.0 if is_centerpiece else 66.0
				var relic_frame := PanelContainer.new()
				relic_frame.custom_minimum_size = Vector2(relic_size, relic_size)
				relic_frame.add_theme_stylebox_override("panel", _featured_relic_frame_style(LEGENDARY_GOLD, is_centerpiece))
				ritual_pool_preview.add_child(relic_frame)
				var relic_icon := TextureRect.new()
				relic_icon.texture = load(_get_pavilion_equipment_icon_path(item_id)) as Texture2D
				relic_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				relic_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				relic_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				relic_frame.add_child(relic_icon)
		else:
			ritual_pool_preview.visible = false
			ritual_icon_frame.visible = true
			ritual_icon_frame.add_theme_stylebox_override("panel", _featured_relic_frame_style(VIOLET, false))
	else:
		var current_data: Dictionary = EquipmentManager.get_item_data(current)
		wish_preview_icon.texture = load(_get_pavilion_equipment_icon_path(current)) as Texture2D
		wish_preview_name.text = tr(str(current_data.get("display_name", current)))
		wish_preview_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
		wish_summary_label.text = tr(str(current_data.get("display_name", current)))
		wish_summary_label.add_theme_color_override("font_color", GOLD)
		wish_open_button.text = tr("LEGENDARY WISH")
		ritual_pool_preview.visible = false
		ritual_icon_frame.visible = true
		if fate_active:
			wish_preview_state.text = tr("FATE GUARANTEED • NEXT LEGENDARY IS THIS TARGET")
			wish_preview_state.add_theme_color_override("font_color", GOLD)
			wish_preview_panel.add_theme_stylebox_override("panel", _featured_armory_style(GOLD, true))
			ritual_icon_frame.add_theme_stylebox_override("panel", _featured_relic_frame_style(GOLD, true))
		else:
			wish_preview_state.text = tr("WISH TARGET • 50% LEGENDARY PREFERENCE")
			wish_preview_state.add_theme_color_override("font_color", Color(0.84, 0.72, 0.98, 1.0))
			wish_preview_panel.add_theme_stylebox_override("panel", _featured_armory_style(VIOLET, true))
			ritual_icon_frame.add_theme_stylebox_override("panel", _featured_relic_frame_style(VIOLET, true))

	var visual := ritual_panel.get_node_or_null("SummonStageVisual")
	if visual == null and ritual_panel.get_child_count() > 0:
		var stage_root := ritual_panel.get_child(0)
		if stage_root != null:
			visual = stage_root.get_node_or_null("SummonStageVisual")
	if visual != null and visual.has_method("configure"):
		visual.call("configure", GOLD if fate_active else VIOLET, GOLD, unlocked, fate_active)

	wish_clear_button.visible = not current.is_empty()
	wish_clear_button.disabled = read_only
	wish_open_button.disabled = read_only or options.is_empty()
	if options.is_empty():
		wish_grid.columns = 1
		var locked_label := _label(
			wish_grid,
			tr("LEGENDARY WISH TARGETS APPEAR AS YOUR JOURNEY UNLOCKS THEM"),
			11,
			Color(0.62, 0.68, 0.67, 1.0)
		)
		locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return

	wish_grid.columns = 2
	for item_id: String in options:
		var data: Dictionary = EquipmentManager.get_item_data(item_id)
		var selected: bool = item_id == current
		var card := _create_wish_target_card(
			item_id,
			tr(str(data.get("display_name", item_id))),
			selected,
			read_only
		)
		wish_grid.add_child(card)


func _create_wish_target_card(item_id: String, display_name: String, selected: bool, disabled: bool) -> PanelContainer:
	var accent: Color = GOLD if selected else VIOLET
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 92.0)
	card.add_theme_stylebox_override("panel", _wish_target_card_style(accent, selected))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(64.0, 64.0)
	icon_frame.add_theme_stylebox_override("panel", _featured_relic_frame_style(accent, selected))
	row.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.texture = load(_get_pavilion_equipment_icon_path(item_id)) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(copy)
	var name_label := _label(copy, display_name, 11, TEXT_MAIN)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var state_label := _label(copy, tr("SELECTED") if selected else tr("SET WISH"), 9, GOLD if selected else Color(0.76, 0.66, 0.94, 1.0))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var hit_area := Button.new()
	hit_area.flat = true
	hit_area.text = ""
	hit_area.disabled = disabled
	hit_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit_area.pressed.connect(_select_wish_target.bind(item_id))
	card.add_child(hit_area)
	return card


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
	var billing_disclosure := _label(
		rates_box,
		tr("Celestial Jade purchase remains unavailable until verified platform billing is integrated."),
		9,
		Color(0.47, 0.57, 0.56, 1.0)
	)
	billing_disclosure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rates_box.visible = rates_visible
	rates_button.text = tr("HIDE DROP RATES") if rates_visible else tr("DROP RATES & PITY RULES")


func _summon_button_text(pull_count: int) -> String:
	var cost := PavilionManager.get_summon_cost(pull_count)
	var seal_cost := int(cost.get("pavilion_seal", 0))
	var jade_cost := int(cost.get("celestial_jade", 0))
	var action: String = tr("SUMMON ×%d") % pull_count
	if seal_cost > 0 and PavilionManager.get_pavilion_seals() >= seal_cost:
		return action + "\n" + (tr("%d PAVILION SEAL%s") % [seal_cost, "" if seal_cost == 1 else "S"])
	var cost_line: String = tr("%d CELESTIAL JADE") % jade_cost
	if pull_count == 10:
		cost_line += tr(" • SAVE 10%")
	return action + "\n" + cost_line


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
	_start_summon_reveal(result)
	var payment_method: String = str(result.get("payment_method", ""))
	var payment_amount: int = int(result.get("payment_amount", 0))
	var payment_copy: String = tr("%d Celestial Jade") % payment_amount
	if payment_method == PavilionManager.PAYMENT_SEAL:
		payment_copy = tr("%d Pavilion Seal%s") % [payment_amount, "" if payment_amount == 1 else "s"]
	var message: String = tr("Summon complete • %s") % payment_copy
	var shards_gained: int = int(result.get("refinement_shards_gained", 0))
	if shards_gained > 0:
		message += tr(" • +%d Refinement Shards") % shards_gained
	_set_status(message, GOLD)


func _render_summon_result(result: Dictionary) -> void:
	for child: Node in summon_result_box.get_children():
		summon_result_box.remove_child(child)
		child.queue_free()
	reveal_cards.clear()
	summon_result_box.visible = true
	var pull_count: int = int(result.get("pull_count", 0))
	var entries: Array = result.get("results", [])
	var new_count: int = 0
	var duplicate_count: int = 0
	var highest_rank: int = -1
	var legendary_names: Array[String] = []
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		var scan_entry: Dictionary = raw_entry
		var rarity: String = str(scan_entry.get("rarity", "common"))
		highest_rank = maxi(highest_rank, RARITIES.find(rarity))
		if bool(scan_entry.get("duplicate", false)):
			duplicate_count += 1
		else:
			new_count += 1
		if rarity == "legendary":
			var legendary_id: String = str(scan_entry.get("item_id", ""))
			var legendary_data: Dictionary = EquipmentManager.get_item_data(legendary_id)
			legendary_names.append(tr(str(legendary_data.get("display_name", legendary_id))))

	var reveal_panel := _panel(summon_result_box, _summon_reveal_style(LEGENDARY_GOLD if highest_rank >= RARITIES.find("legendary") else VIOLET, highest_rank >= RARITIES.find("legendary")))
	var reveal_box := VBoxContainer.new()
	reveal_box.add_theme_constant_override("separation", 5)
	reveal_panel.add_child(reveal_box)
	var heading := _label(reveal_box, tr("SUMMON REVEAL"), 12, Color(1.0, 0.86, 0.48))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var summary := _label(
		reveal_box,
		tr("NEW %d • DUPLICATES %d • +%d SHARDS") % [
			new_count,
			duplicate_count,
			int(result.get("refinement_shards_gained", 0))
		],
		11,
		Color(0.76, 0.86, 0.83, 1.0)
	)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var collection_summary := _label(reveal_box, _collection_progress_text(), 10, Color(CYAN.r, CYAN.g, CYAN.b, 0.88))
	collection_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not legendary_names.is_empty():
		var legendary_banner := _state_badge(reveal_box, tr("CELESTIAL LEGENDARY REVEAL"), LEGENDARY_GOLD)
		legendary_banner.add_theme_font_size_override("font_size", 12)
		var legendary_text: String = ""
		for legendary_name: String in legendary_names:
			if not legendary_text.is_empty():
				legendary_text += " • "
			legendary_text += legendary_name
		var legendary_copy := _label(reveal_box, legendary_text, 14, Color(1.0, 0.86, 0.46, 1.0))
		legendary_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var result_grid := GridContainer.new()
	result_grid.columns = 1 if pull_count == 1 else 2
	result_grid.add_theme_constant_override("h_separation", 9)
	result_grid.add_theme_constant_override("v_separation", 9)
	summon_result_box.add_child(result_grid)
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var item_id: String = str(entry.get("item_id", ""))
		var data: Dictionary = EquipmentManager.get_item_data(item_id)
		var rarity: String = str(entry.get("rarity", data.get("rarity", "common")))
		var accent: Color = EquipmentVisualCatalog.get_rarity_color(rarity)
		var is_duplicate: bool = bool(entry.get("duplicate", false))
		var legendary: bool = rarity == "legendary"
		var card := _panel(result_grid, _summon_result_card_style(accent, legendary, is_duplicate))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		card.add_child(box)
		var icon_frame := PanelContainer.new()
		icon_frame.custom_minimum_size = Vector2(0.0, 104.0 if pull_count == 1 else 82.0)
		icon_frame.add_theme_stylebox_override("panel", _equipment_icon_style(accent, true))
		box.add_child(icon_frame)
		var icon := TextureRect.new()
		icon.texture = load(_get_pavilion_equipment_icon_path(item_id)) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_frame.add_child(icon)
		var name_label := _label(box, tr(str(data.get("display_name", item_id))), 13 if pull_count == 1 else 12, TEXT_MAIN)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rarity_label := _label(box, tr(rarity.capitalize()).to_upper(), 10, accent)
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var set_id: String = EquipmentSetCatalog.get_set_id_for_item(item_id)
		var set_display_name: String = EquipmentSetCatalog.get_display_name(set_id)
		if not set_display_name.is_empty():
			var set_label := _label(box, tr(set_display_name), 9, Color(accent.r, accent.g, accent.b, 0.78))
			set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if is_duplicate:
			var duplicate_label := _label(box, tr("DUPLICATE → +%d SHARDS") % int(entry.get("duplicate_shards", 0)), 10, CYAN)
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
		card.modulate = Color(1.0, 1.0, 1.0, 0.0)
		reveal_cards.append(card)
	call_deferred("_animate_reveal_cards")


func _toggle_rates() -> void:
	rates_visible = not rates_visible
	_rebuild_drop_rates()


func _select_wish_target(item_id: String) -> void:
	if PavilionManager.set_wish_target(item_id):
		if item_id.is_empty():
			_set_status(tr("Legendary Wish cleared."), VIOLET)
		else:
			var data: Dictionary = EquipmentManager.get_item_data(item_id)
			_set_status(tr("Legendary Wish set • %s") % tr(str(data.get("display_name", item_id))), VIOLET)
		_close_wish_selector()
	else:
		_set_status(tr(PavilionManager.last_error), Color(0.95, 0.48, 0.42))


func _create_pity_track(parent_node: Node, caption: String, accent: Color) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 64.0)
	card.add_theme_stylebox_override("panel", _pity_tile_style(accent, false))
	parent_node.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	var caption_label := _label(box, caption, 9, Color(accent.r, accent.g, accent.b, 0.92))
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var value_label := _label(box, "—", 16, TEXT_MAIN)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var remaining_label := _label(box, tr("GUARANTEE"), 8, TEXT_MUTED)
	remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var track := Control.new()
	track.custom_minimum_size = Vector2(0.0, 4.0)
	track.clip_contents = true
	box.add_child(track)
	var background := ColorRect.new()
	background.color = Color(0.025, 0.050, 0.055, 0.96)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fill := ColorRect.new()
	fill.color = Color(accent.r, accent.g, accent.b, 0.92)
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	return {"fill": fill, "value_label": value_label, "remaining_label": remaining_label, "card": card}


func _update_pity_track(
	track: Dictionary,
	counter: int,
	limit: int,
	remaining: int,
	active: bool,
	accent: Color
) -> void:
	var fill: ColorRect = track.get("fill") as ColorRect
	var value_label: Label = track.get("value_label") as Label
	var remaining_label: Label = track.get("remaining_label") as Label
	var card: PanelContainer = track.get("card") as PanelContainer
	if fill == null or value_label == null or remaining_label == null or card == null:
		return
	if not active:
		fill.anchor_right = 0.0
		value_label.text = tr("PAUSED")
		remaining_label.text = tr("UNLOCK LEGENDARY")
		value_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.67, 1.0))
		remaining_label.add_theme_color_override("font_color", Color(0.50, 0.58, 0.56, 1.0))
		card.add_theme_stylebox_override("panel", _pity_tile_style(Color(0.38, 0.44, 0.44, 1.0), false))
		return
	var safe_limit: int = maxi(limit, 1)
	fill.anchor_right = clampf(float(counter) / float(safe_limit), 0.0, 1.0)
	fill.color = Color(accent.r, accent.g, accent.b, 0.92)
	value_label.text = "%d / %d" % [counter, safe_limit]
	remaining_label.text = tr("GUARANTEED IN %d") % maxi(remaining, 0)
	value_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.98))
	remaining_label.add_theme_color_override("font_color", TEXT_MUTED)
	card.add_theme_stylebox_override("panel", _pity_tile_style(accent, remaining <= maxi(int(round(float(safe_limit) * 0.20)), 1)))


func _play_summon_ritual_feedback(result: Dictionary) -> void:
	var highest_rank: int = -1
	for raw_entry in result.get("results", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		highest_rank = maxi(highest_rank, RARITIES.find(str(entry.get("rarity", "common"))))
	var reveal_sfx: String = ""
	if highest_rank >= RARITIES.find("legendary"):
		ritual_title_label.text = tr("HEAVENLY RESONANCE • LEGENDARY")
		ritual_title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.40, 1.0))
		ritual_subtitle_label.text = tr("A CELESTIAL RELIC ANSWERED YOUR CALL")
		ritual_panel.add_theme_stylebox_override("panel", _featured_armory_style(LEGENDARY_GOLD, true))
		reveal_sfx = "victory"
	elif highest_rank >= RARITIES.find("epic"):
		ritual_title_label.text = tr("CELESTIAL RESONANCE • EPIC")
		ritual_title_label.add_theme_color_override("font_color", Color(0.84, 0.72, 1.0, 1.0))
		ritual_subtitle_label.text = tr("THE ARMORY RESONATES WITH RARE QI")
		ritual_panel.add_theme_stylebox_override("panel", _featured_armory_style(VIOLET, true))
		reveal_sfx = "level"
	else:
		ritual_title_label.text = tr("CELESTIAL RESONANCE ANSWERED")
		ritual_title_label.add_theme_color_override("font_color", Color(0.76, 0.94, 0.88, 1.0))
		ritual_subtitle_label.text = tr("THE ARMORY HAS ANSWERED")
		ritual_panel.add_theme_stylebox_override("panel", _featured_armory_style(JADE, true))
	if SettingsManager.reduced_effects or ritual_icon == null:
		if not reveal_sfx.is_empty():
			AudioManager.play_sfx(reveal_sfx)
		return
	ritual_icon.pivot_offset = ritual_icon.size * 0.5
	ritual_icon.scale = Vector2(0.78, 0.78)
	ritual_icon.modulate = Color(1.0, 1.0, 1.0, 0.15)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ritual_icon, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ritual_icon, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var settle := create_tween()
	settle.tween_interval(0.18)
	settle.tween_property(ritual_icon, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not reveal_sfx.is_empty():
		settle.tween_callback(AudioManager.play_sfx.bind(reveal_sfx))



func _animate_reveal_cards() -> void:
	if reveal_cards.is_empty():
		return
	if SettingsManager.reduced_effects:
		for card: Control in reveal_cards:
			if is_instance_valid(card):
				card.modulate = Color.WHITE
		return
	var tween := create_tween()
	for card: Control in reveal_cards:
		if not is_instance_valid(card):
			continue
		tween.tween_property(card, "modulate", Color.WHITE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_status(value: String, accent: Color) -> void:
	status_panel.visible = true
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
	if summon_reveal_overlay != null and summon_reveal_overlay.visible:
		_finish_summon_reveal(true)
		return
	if wish_selector_overlay != null and wish_selector_overlay.visible:
		_close_wish_selector()
		return
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
	var panel := _panel(parent_node, _sanctum_section_style(accent, 14))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	var ornament := HBoxContainer.new()
	ornament.add_theme_constant_override("separation", 7)
	box.add_child(ornament)
	var ornament_line := ColorRect.new()
	ornament_line.color = Color(accent.r, accent.g, accent.b, 0.56)
	ornament_line.custom_minimum_size = Vector2(30.0, 1.0)
	ornament_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ornament.add_child(ornament_line)
	var eyebrow_label := _label(ornament, eyebrow, 10, Color(accent.r, accent.g, accent.b, 0.96))
	eyebrow_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var diamond := _label(ornament, "◇", 11, Color(GOLD.r, GOLD.g, GOLD.b, 0.76))
	diamond.size_flags_horizontal = Control.SIZE_SHRINK_END

	var title_label := _label(box, title, 22, Color(1.0, 0.88, 0.52))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.58))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	_label(box, description, 12, Color(0.72, 0.83, 0.80, 1.0))
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


func _make_summon_relic_safe_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SUMMON_RELIC_SAFE_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _get_pavilion_equipment_icon_path(item_id: String) -> String:
	return EquipmentVisualCatalog.get_icon_path(item_id)

func _get_summon_slot_icon_path(slot_id: String) -> String:
	return str(SLOT_ICON_PATHS.get(slot_id, PAVILION_SEAL_ICON))


func _get_summon_slot_reveal_title(slot_id: String) -> String:
	match slot_id:
		"armament":
			return "SEALED ARMAMENT"
		"robe":
			return "SEALED ROBE"
		"bracer":
			return "SEALED BRACER"
		"boots":
			return "SEALED BOOTS"
		"pendant":
			return "SEALED PENDANT"
		_:
			return "CELESTIAL SEAL"


func _get_summon_slot_reveal_subtitle(slot_id: String) -> String:
	match slot_id:
		"armament":
			return "A WEAPON SPIRIT WAITS WITHIN"
		"robe":
			return "A PROTECTIVE GARMENT WAITS WITHIN"
		"bracer":
			return "A MARTIAL RELIC WAITS WITHIN"
		"boots":
			return "A SWIFT FOOTWORK RELIC WAITS WITHIN"
		"pendant":
			return "A SPIRIT TALISMAN WAITS WITHIN"
		_:
			return "REVEAL THE EQUIPMENT WITHIN"


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


func _sanctum_section_style(accent: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0015, 0.010, 0.018, 0.965)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.54)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14.0
	style.content_margin_top = 13.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 13.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.095)
	style.shadow_size = 9
	return style


func _wallet_header_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.001, 0.012, 0.021, 0.985)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.border_color = Color(0.91, 0.73, 0.28, 0.72)
	style.corner_radius_top_left = 13
	style.corner_radius_top_right = 13
	style.corner_radius_bottom_left = 13
	style.corner_radius_bottom_right = 13
	style.shadow_color = Color(0.12, 0.84, 0.69, 0.12)
	style.shadow_size = 9
	return style

func _compact_wallet_chip_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.075, accent.g * 0.075, accent.b * 0.075, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.60)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 5.0
	style.content_margin_top = 3.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 3.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.08)
	style.shadow_size = 3
	return style

func _hero_overlay_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.001, 0.014, 0.023, 0.94)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.88, 0.72, 0.30, 0.62)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 9.0
	style.shadow_color = Color(0.02, 0.20, 0.17, 0.34)
	style.shadow_size = 9
	return style


func _summon_ritual_style(accent: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var strength: float = 0.105 if active else 0.045
	style.bg_color = Color(accent.r * strength, accent.g * strength, accent.b * strength, 0.96)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82 if active else 0.34)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 12.0
	style.content_margin_top = 11.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 11.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.12 if active else 0.04)
	style.shadow_size = 8 if active else 3
	return style


func _summon_shell_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0005, 0.0045, 0.012, 0.78)
	style.border_width_left = 0
	style.border_width_top = 1
	style.border_width_right = 0
	style.border_width_bottom = 2
	style.border_color = Color(0.94, 0.74, 0.30, 0.58)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 10.0
	style.content_margin_top = 17.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 17.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.10)
	style.shadow_size = 18
	return style

func _featured_armory_style(accent: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var strength: float = 0.115 if active else 0.052
	style.bg_color = Color(accent.r * strength, accent.g * strength, accent.b * strength, 0.994)
	style.border_width_left = 1
	style.border_width_top = 2
	style.border_width_right = 1
	style.border_width_bottom = 4
	style.border_color = Color(1.0, 0.77, 0.27, 0.98 if active else 0.68)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.content_margin_left = 2.0
	style.content_margin_top = 2.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 2.0
	style.shadow_color = Color(1.0, 0.70, 0.18, 0.20 if active else 0.11)
	style.shadow_size = 24 if active else 15
	return style

func _featured_relic_frame_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.075, accent.g * 0.075, accent.b * 0.075, 0.965)
	style.border_width_left = 3 if selected else 2
	style.border_width_top = 3 if selected else 2
	style.border_width_right = 3 if selected else 2
	style.border_width_bottom = 3 if selected else 2
	style.border_color = Color(1.0, 0.76, 0.28, 0.98 if selected else 0.76)
	var radius: int = 92 if selected else 42
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 7.0
	style.content_margin_top = 7.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.36 if selected else 0.14)
	style.shadow_size = 16 if selected else 7
	return style


func _pity_tile_style(accent: Color, near_guarantee: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * (0.095 if near_guarantee else 0.036), accent.g * (0.095 if near_guarantee else 0.036), accent.b * (0.095 if near_guarantee else 0.036), 0.88)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.92 if near_guarantee else 0.48)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 7.0
	style.content_margin_top = 7.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.13 if near_guarantee else 0.02)
	style.shadow_size = 8 if near_guarantee else 2
	return style

func _wish_target_card_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * (0.105 if selected else 0.045), accent.g * (0.105 if selected else 0.045), accent.b * (0.105 if selected else 0.045), 0.96)
	style.border_width_left = 2 if selected else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2 if selected else 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.86 if selected else 0.40)
	style.corner_radius_top_left = 11
	style.corner_radius_top_right = 11
	style.corner_radius_bottom_left = 11
	style.corner_radius_bottom_right = 11
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	return style


func _ensure_button_ornaments(button: Button, accent: Color, primary: bool, ceremonial: bool) -> void:
	if button == null:
		return
	var existing := button.get_node_or_null("Ornaments")
	if existing != null:
		button.remove_child(existing)
		existing.queue_free()
	var overlay := Control.new()
	overlay.name = "Ornaments"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var line_width: float = 12.0 if primary else 10.0
	var diamond_size: int = 12 if ceremonial else 10
	var ornament_color := Color(1.0, 0.84, 0.42, 0.95) if ceremonial or primary else Color(accent.r, accent.g, accent.b, 0.88)
	for side in ["left", "right"]:
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = Vector2(24.0 if ceremonial or primary else 20.0, 18.0)
		holder.anchor_top = 0.5
		holder.anchor_bottom = 0.5
		holder.offset_top = -9.0
		holder.offset_bottom = 9.0
		if side == "left":
			holder.anchor_left = 0.0
			holder.anchor_right = 0.0
			holder.offset_left = 8.0
			holder.offset_right = holder.offset_left + holder.custom_minimum_size.x
		else:
			holder.anchor_left = 1.0
			holder.anchor_right = 1.0
			holder.offset_right = -8.0
			holder.offset_left = holder.offset_right - holder.custom_minimum_size.x
		overlay.add_child(holder)
		var line := ColorRect.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.color = Color(ornament_color.r, ornament_color.g, ornament_color.b, 0.70)
		line.custom_minimum_size = Vector2(line_width, 1.0)
		line.anchor_top = 0.5
		line.anchor_bottom = 0.5
		line.offset_top = -0.5
		line.offset_bottom = 0.5
		if side == "left":
			line.anchor_left = 0.0
			line.anchor_right = 0.0
			line.offset_left = 0.0
			line.offset_right = line_width
		else:
			line.anchor_left = 1.0
			line.anchor_right = 1.0
			line.offset_left = -line_width
			line.offset_right = 0.0
		holder.add_child(line)
		var jewel := Label.new()
		jewel.text = "◈"
		jewel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		jewel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		jewel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		jewel.add_theme_font_size_override("font_size", diamond_size)
		jewel.add_theme_color_override("font_color", ornament_color)
		jewel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if side == "left":
			jewel.offset_left = line_width - 2.0
		else:
			jewel.offset_right = -(line_width - 2.0)
		holder.add_child(jewel)


func _apply_summon_cta_style(button: Button, accent: Color, primary: bool) -> void:
	button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82, 1.0) if primary else Color(0.94, 0.92, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.48, 1.0))
	button.add_theme_color_override(
		"font_disabled_color",
		Color(0.72, 0.64, 0.42, 0.86) if primary else Color(0.48, 0.50, 0.56, 0.86)
	)
	button.add_theme_stylebox_override("normal", _summon_cta_style(accent, primary, false, false))
	button.add_theme_stylebox_override("hover", _summon_cta_style(accent, primary, true, false))
	button.add_theme_stylebox_override("pressed", _summon_cta_style(accent, primary, true, true))
	button.add_theme_stylebox_override("focus", _summon_cta_style(accent, primary, true, false))
	var disabled_style: StyleBoxFlat = _summon_cta_style(
		Color(0.55, 0.42, 0.18, 1.0) if primary else Color(0.28, 0.30, 0.36, 1.0),
		primary,
		false,
		false
	)
	button.add_theme_stylebox_override("disabled", disabled_style)
	_ensure_button_ornaments(button, accent, primary, true)


func _summon_cta_style(accent: Color, primary: bool, hovered: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var strength: float = 0.27 if primary else 0.12
	if hovered:
		strength += 0.07
	if pressed:
		strength += 0.04
	style.bg_color = Color(accent.r * strength, accent.g * strength, accent.b * strength, 0.995)
	style.border_width_left = 2 if primary else 1
	style.border_width_top = 2 if primary else 1
	style.border_width_right = 2 if primary else 1
	style.border_width_bottom = 4 if primary else 2
	style.border_color = Color(1.0, 0.79, 0.31, 0.99) if primary else Color(accent.r, accent.g, accent.b, 0.72)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 22.0 if primary else 18.0
	style.content_margin_top = 10.0
	style.content_margin_right = 22.0 if primary else 18.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.32 if primary else 0.08)
	style.shadow_size = 16 if primary else 5
	return style


func _wish_panel_style(accent: Color) -> StyleBoxFlat:
	var style := _panel_style(accent, false, 11)
	style.bg_color = Color(0.012, 0.008, 0.026, 0.94)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.58)
	return style


func _wish_preview_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * (0.070 if selected else 0.025), accent.g * (0.070 if selected else 0.025), accent.b * (0.070 if selected else 0.025), 0.76)
	style.border_width_left = 0
	style.border_width_top = 1
	style.border_width_right = 0
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.68 if selected else 0.28)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 9.0
	style.content_margin_top = 8.0
	style.content_margin_right = 9.0
	style.content_margin_bottom = 8.0
	return style

func _summon_reveal_focus_style(accent: Color, legendary: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var strength: float = 0.105 if legendary else 0.036
	style.bg_color = Color(accent.r * strength, accent.g * strength, accent.b * strength, 0.80)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.77, 0.28, 0.88) if legendary else Color(accent.r, accent.g, accent.b, 0.42)
	style.corner_radius_top_left = 26
	style.corner_radius_top_right = 26
	style.corner_radius_bottom_left = 26
	style.corner_radius_bottom_right = 26
	style.content_margin_left = 12.0
	style.content_margin_top = 12.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.42 if legendary else 0.08)
	style.shadow_size = 30 if legendary else 8
	return style

func _summon_reveal_icon_style(accent: Color, legendary: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.075, accent.g * 0.075, accent.b * 0.075, 0.91)
	style.border_width_left = 4 if legendary else 2
	style.border_width_top = 4 if legendary else 2
	style.border_width_right = 4 if legendary else 2
	style.border_width_bottom = 4 if legendary else 2
	style.border_color = Color(1.0, 0.77, 0.28, 1.0) if legendary else Color(accent.r, accent.g, accent.b, 0.82)
	var radius: int = 148
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 9.0
	style.content_margin_top = 9.0
	style.content_margin_right = 9.0
	style.content_margin_bottom = 9.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.48 if legendary else 0.16)
	style.shadow_size = 24 if legendary else 10
	return style


func _summon_reveal_style(accent: Color, legendary: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * (0.12 if legendary else 0.07), accent.g * (0.12 if legendary else 0.07), accent.b * (0.12 if legendary else 0.07), 0.96)
	style.border_width_left = 2
	style.border_width_top = 2 if legendary else 1
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.90 if legendary else 0.62)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 10.0
	style.content_margin_top = 9.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 9.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.20 if legendary else 0.08)
	style.shadow_size = 12 if legendary else 5
	return style


func _summon_result_card_style(accent: Color, legendary: bool, is_duplicate: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var strength: float = 0.12 if legendary else (0.055 if is_duplicate else 0.085)
	style.bg_color = Color(accent.r * strength, accent.g * strength, accent.b * strength, 0.97)
	style.border_width_left = 2 if legendary else 1
	style.border_width_top = 2 if legendary else 1
	style.border_width_right = 2 if legendary else 1
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.94 if legendary else 0.62)
	style.corner_radius_top_left = 11
	style.corner_radius_top_right = 11
	style.corner_radius_bottom_left = 11
	style.corner_radius_bottom_right = 11
	style.content_margin_left = 7.0
	style.content_margin_top = 7.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.22 if legendary else 0.04)
	style.shadow_size = 10 if legendary else 3
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
	_ensure_button_ornaments(button, accent, primary, false)


func _button_style(accent: Color, primary: bool, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * (0.16 if primary else 0.10), accent.g * (0.16 if primary else 0.10), accent.b * (0.16 if primary else 0.10), 0.96)
	style.border_width_left = 2 if primary else 1
	style.border_width_top = 1
	style.border_width_right = 2 if primary else 1
	style.border_width_bottom = 2 if primary else 1
	style.border_color = Color(accent.r, accent.g, accent.b, clampf(0.55 + alpha, 0.0, 1.0))
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 18.0 if primary else 16.0
	style.content_margin_top = 7.0
	style.content_margin_right = 18.0 if primary else 16.0
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
