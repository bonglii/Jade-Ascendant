extends Control

## Jade Pavilion — polished offline preparation hub.
## Gameplay authority remains in PavilionManager / EquipmentManager / InventoryManager.
## This script is presentation-only: it reads manager state and calls existing manager APIs.

const EquipmentVisualCatalog = preload("res://scripts/ui/equipment_visual_catalog.gd")

const SPIRIT_STONE_ICON: String = "res://assets/ui/icons/spirit_stone.svg"
const REFINEMENT_SHARD_ICON: String = "res://assets/ui/equipment/refinement_shard.svg"
const PAVILION_SEAL_ICON: String = "res://assets/ui/pavilion/polish/pavilion_seal.svg"
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
const TEXT_MAIN: Color = Color(0.93, 0.97, 0.95, 1.0)
const TEXT_MUTED: Color = Color(0.62, 0.74, 0.71, 1.0)
const PANEL_DARK: Color = Color(0.002, 0.020, 0.030, 0.94)

var content: VBoxContainer
var stone_balance_label: Label
var shard_balance_label: Label
var status_panel: PanelContainer
var status_label: Label
var chest: Button
var meditation_state_label: Label
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
	_build_meditation_section()
	_build_aura_section()
	_build_forge_section()
	_build_player_trust_section()
	_add_bottom_safe_spacer()


func _build_hero_header() -> void:
	var hero_stage: Control = Control.new()
	hero_stage.custom_minimum_size = Vector2(0.0, 250.0)
	hero_stage.clip_contents = true
	content.add_child(hero_stage)

	var art: TextureRect = TextureRect.new()
	art.texture = load(SANCTUARY_BANNER) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_stage.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title_panel: PanelContainer = PanelContainer.new()
	title_panel.anchor_left = 0.025
	title_panel.anchor_right = 0.975
	title_panel.anchor_top = 1.0
	title_panel.anchor_bottom = 1.0
	title_panel.offset_top = -132.0
	title_panel.offset_bottom = -8.0
	title_panel.add_theme_stylebox_override("panel", _hero_overlay_style())
	hero_stage.add_child(title_panel)

	var hero_box: VBoxContainer = VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 7)
	title_panel.add_child(hero_box)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	hero_box.add_child(title_row)
	_make_icon_emblem(title_row, PAVILION_SEAL_ICON, JADE, GOLD, 58.0)

	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	title_row.add_child(title_box)
	_label(title_box, tr("JADE PAVILION"), 11, JADE)
	_label(title_box, tr("Sanctum of Refinement"), 24, Color(1.0, 0.87, 0.50))
	_label(title_box, tr("Rest, gather your Qi, and prepare for the next trial."), 12, Color(0.74, 0.85, 0.81, 1.0))

	var resource_row: HBoxContainer = HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 8)
	hero_box.add_child(resource_row)
	stone_balance_label = _resource_chip(resource_row, SPIRIT_STONE_ICON, _spirit_stone_caption(), GOLD)
	shard_balance_label = _resource_chip(resource_row, REFINEMENT_SHARD_ICON, tr("Refinement Shard").to_upper(), CYAN)

func _build_status_banner() -> void:
	status_panel = _panel(content, _status_style(JADE_SOFT))
	status_label = _label(status_panel, "", 12, Color(0.70, 0.95, 0.86))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size.y = 22.0

func _build_meditation_section() -> void:
	var meditation: VBoxContainer = _section_card(
		content,
		tr("DAILY RESONANCE"),
		tr("Daily Meditation"),
		tr("A quiet moment grants 20 Spirit Stones once per local day."),
		JADE
	)

	var body: HBoxContainer = HBoxContainer.new()
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

	var copy: VBoxContainer = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	body.add_child(copy)
	meditation_state_label = _state_badge(copy, tr("AVAILABLE"), JADE)
	var reward_line: Label = _label(copy, "+20  •  " + (_spirit_stone_caption()), 16, Color(1.0, 0.86, 0.48))
	reward_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	chest = _button(meditation, tr("MEDITATE  •  +20 SPIRIT STONES"), _meditate, true, JADE)

func _build_aura_section() -> void:
	var cosmetics: VBoxContainer = _section_card(
		content,
		tr("COSMETIC ATTUNEMENT"),
		tr("Cultivation Auras"),
		tr("Realm-clear auras are free. Postgame prestige auras use earned currencies only and never add combat power."),
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
	var forge: VBoxContainer = _section_card(
		content,
		tr("PERMANENT LOADOUT"),
		tr("Equipment Forge"),
		tr("Repeat clears and duplicate equipment provide Refinement Shards for forging."),
		GOLD
	)

	var filter_label: Label = _label(forge, tr("RARITY"), 12, TEXT_MUTED)
	filter_label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.74, 1.0))

	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	forge.add_child(filter_row)
	for rarity: String in RARITIES:
		var button: Button = Button.new()
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
	var panel: PanelContainer = _panel(content, _panel_style(CYAN, false, 9))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var copy: VBoxContainer = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	_label(copy, tr("PLAYER-FIRST EDITION"), 11, Color(CYAN.r, CYAN.g, CYAN.b, 0.90))
	_label(copy, tr("About Jade Ascendant"), 17, Color(1.0, 0.86, 0.48))
	var privacy: Button = _button(row, tr("PRIVACY & SUPPORT"), _open_privacy, false, CYAN)
	privacy.custom_minimum_size = Vector2(154.0, 42.0)

func _refresh() -> void:
	stone_balance_label.text = _format_count(ProgressionManager.spirit_stone)
	shard_balance_label.text = _format_count(
		InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD)
	)

	var meditation_ready: bool = PavilionManager.can_claim_meditation()
	chest.disabled = not meditation_ready
	chest.text = (
		tr("MEDITATE  •  +20 SPIRIT STONES")
		if meditation_ready
		else tr("MEDITATED TODAY")
	)
	meditation_state_label.text = tr("AVAILABLE") if meditation_ready else tr("COMPLETED")
	var meditation_accent: Color = JADE if meditation_ready else Color(0.46, 0.62, 0.58, 1.0)
	meditation_state_label.add_theme_color_override("font_color", Color(meditation_accent.r, meditation_accent.g, meditation_accent.b, 0.98))
	if meditation_state_label.get_parent() is PanelContainer:
		(meditation_state_label.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _chip_style(meditation_accent))
	if meditation_altar_frame != null:
		meditation_altar_frame.add_theme_stylebox_override("panel", _meditation_altar_style(meditation_accent, meditation_ready))
	if meditation_altar_icon != null:
		meditation_altar_icon.modulate = Color(1, 1, 1, 1.0 if meditation_ready else 0.58)
	_apply_button_style(chest, JADE if meditation_ready else Color(0.34, 0.46, 0.43, 1.0), meditation_ready)

	_refresh_status()
	_sync_rarity_buttons()
	_rebuild_auras()
	_rebuild_equipment()


func _refresh_status() -> void:
	if SaveManager.is_progress_read_only():
		_set_status(
			tr("SAVE RECOVERY REQUIRED  •  REOPEN THE GAME BEFORE CHANGING LOADOUT"),
			Color(0.95, 0.43, 0.38)
		)
	elif not EquipmentManager.can_modify_equipment():
		_set_status(
			tr("FORGE SEALED  •  FINISH THE ACTIVE RUN TO MODIFY PERMANENT EQUIPMENT"),
			GOLD
		)
	else:
		_set_status(
			tr("SANCTUM READY  •  PERMANENT PROGRESSION IS SAFE"),
			JADE
		)


func _set_status(value: String, accent: Color) -> void:
	status_label.text = value
	status_label.add_theme_color_override(
		"font_color",
		Color(accent.r, accent.g, accent.b, 0.96)
	)
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
	var definition: Dictionary = PavilionManager.get_cosmetic_data(cosmetic_id)
	var accent: Color = _get_aura_color(cosmetic_id)
	var owned: bool = PavilionManager.is_cosmetic_owned(cosmetic_id)
	var current: bool = PavilionManager.get_cosmetic_id() == cosmetic_id
	var unlocked: bool = PavilionManager.is_cosmetic_unlocked(cosmetic_id)
	var cost: Dictionary = PavilionManager.get_cosmetic_cost(cosmetic_id)
	var stone_cost: int = int(cost.get("spirit_stone", 0))
	var shard_cost: int = int(cost.get("refinement_shard", 0))

	var card_accent: Color = JADE if current else accent
	if not unlocked:
		card_accent = Color(accent.r * 0.60, accent.g * 0.60, accent.b * 0.60, 1.0)
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		_aura_card_style(card_accent, featured, current, unlocked)
	)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)

	# Treat the preview and copy as one visual unit rather than an image sitting
	# above a generic form card.  The lower glass strip keeps names readable on
	# every aura artwork at the 405x860 mobile QA viewport.
	var preview_stage: Control = Control.new()
	preview_stage.custom_minimum_size = Vector2(0.0, 160.0 if featured else 108.0)
	preview_stage.clip_contents = true
	box.add_child(preview_stage)

	var preview: TextureRect = TextureRect.new()
	preview.texture = load(_get_aura_preview_path(cosmetic_id)) as Texture2D
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1, 1, 1, 1.0 if unlocked else 0.50)
	preview_stage.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var overlay: PanelContainer = PanelContainer.new()
	overlay.anchor_left = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_top = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_top = -64.0
	overlay.offset_bottom = 0.0
	overlay.add_theme_stylebox_override("panel", _aura_overlay_style(card_accent))
	preview_stage.add_child(overlay)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	overlay.add_child(title_row)

	var mini_icon: TextureRect = TextureRect.new()
	mini_icon.texture = load(_get_aura_icon_path(cosmetic_id)) as Texture2D
	mini_icon.custom_minimum_size = Vector2(40.0 if featured else 34.0, 40.0 if featured else 34.0)
	mini_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(mini_icon)

	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	title_row.add_child(title_box)
	var name_label: Label = _label(
		title_box,
		tr(str(definition.get("name", cosmetic_id))),
		18 if featured else 14,
		TEXT_MAIN
	)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var state_text: String = ""
	var state_color: Color = TEXT_MUTED
	if current:
		state_text = tr("ATTUNED  ✓")
		state_color = JADE
	elif owned:
		state_text = tr("OWNED  •  ATTUNE")
		state_color = Color(0.56, 0.92, 0.78, 1.0)
	elif not unlocked:
		state_text = tr("LOCKED")
		state_color = Color(0.64, 0.69, 0.68, 1.0)
	else:
		state_text = tr("AVAILABLE")
		state_color = accent
	_label(title_box, state_text, 12, state_color)

	var action: Button = Button.new()
	action.custom_minimum_size.y = 50.0 if featured else 42.0
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.add_theme_font_size_override("font_size", 13 if featured else 12)
	action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_style(action, accent, featured)
	action.pressed.connect(_select_cosmetic.bind(cosmetic_id))
	box.add_child(action)

	if current:
		action.text = tr("ATTUNED  ✓")
		action.disabled = true
	elif not unlocked:
		action.disabled = true
		var required_cosmetic: String = str(definition.get("requires_cosmetic", ""))
		if not PavilionManager.is_cosmetic_stage_unlocked(cosmetic_id):
			action.text = tr("CLEAR %d-%d") % [int(definition.get("chapter", 1)), int(definition.get("stage", 0))]
		elif not required_cosmetic.is_empty() and not PavilionManager.is_cosmetic_owned(required_cosmetic):
			var required_data: Dictionary = PavilionManager.get_cosmetic_data(required_cosmetic)
			action.text = tr("REQUIRES %s") % tr(str(required_data.get("name", required_cosmetic)))
		else:
			action.text = tr("LOCKED")
	elif owned:
		action.text = tr("OWNED  •  ATTUNE")
		action.disabled = SaveManager.is_progress_read_only()
	elif stone_cost <= 0 and shard_cost <= 0:
		action.text = tr("AVAILABLE")
		action.disabled = SaveManager.is_progress_read_only()
	else:
		action.text = tr("%d STONES + %d SHARDS") % [stone_cost, shard_cost]
		action.disabled = (
			SaveManager.is_progress_read_only()
			or ProgressionManager.spirit_stone < stone_cost
			or InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD) < shard_cost
		)
	return card

func _rebuild_equipment() -> void:
	for child: Node in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.queue_free()

	var visible_items: Array[Dictionary] = []
	for item_id: String in EquipmentManager.get_item_ids():
		var data: Dictionary = EquipmentManager.get_item_data(item_id)
		if str(data.get("rarity", "common")) != selected_rarity:
			continue
		visible_items.append({"item_id": item_id, "data": data})

	var row: HBoxContainer
	for index: int in range(visible_items.size()):
		if index % 2 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			equipment_list.add_child(row)
		var entry: Dictionary = visible_items[index]
		var card: PanelContainer = _create_equipment_card(str(entry["item_id"]), entry["data"])
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)

func _create_equipment_card(item_id: String, data: Dictionary) -> PanelContainer:
	var rarity_id: String = str(data.get("rarity", "common"))
	var rarity_color: Color = EquipmentVisualCatalog.get_rarity_color(rarity_id)
	var owned_item: bool = InventoryManager.owns_item(item_id)
	var unlocked_item: bool = PavilionManager.is_item_unlocked(item_id)

	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		_equipment_card_style(rarity_color, owned_item, unlocked_item)
	)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	var rarity_tag: Label = _label(box, tr(rarity_id.capitalize()).to_upper(), 11, rarity_color)
	rarity_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var icon_frame: PanelContainer = PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(0.0, 78.0 if owned_item or not unlocked_item else 84.0)
	icon_frame.add_theme_stylebox_override("panel", _equipment_icon_style(rarity_color, unlocked_item))
	box.add_child(icon_frame)
	var icon: TextureRect = TextureRect.new()
	icon.texture = load(_get_pavilion_equipment_icon_path(item_id)) as Texture2D
	icon.custom_minimum_size = Vector2(68.0, 68.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1, 1, 1, 1.0 if unlocked_item else 0.52)
	icon_frame.add_child(icon)

	var name_label: Label = _label(box, tr(str(data.get("display_name", item_id))), 15, TEXT_MAIN)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var slot_label: Label = _label(
		box,
		tr(EquipmentVisualCatalog.get_slot_title(str(data.get("slot", "")))),
		11,
		Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.94)
	)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stat: Label = _label(box, EquipmentVisualCatalog.get_stat_summary(data), 12, Color(0.78, 0.89, 0.85, 1.0))
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if owned_item:
		var owned_badge: Label = _state_badge(box, tr("OWNED  •  EQUIP FROM HERO"), JADE)
		owned_badge.add_theme_font_size_override("font_size", 11)
		owned_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif not unlocked_item:
		var requirement: Dictionary = PavilionManager.get_item_unlock_requirement(item_id)
		var locked_badge: Label = _state_badge(
			box,
			tr("LOCKED  •  CLEAR %d-%d") % [
				int(requirement.get("chapter_id", 0)),
				int(requirement.get("stage_id", 0))
			],
			Color(0.55, 0.62, 0.61, 1.0)
		)
		locked_badge.add_theme_font_size_override("font_size", 11)
		locked_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var signature_name: String = EquipmentVisualCatalog.get_signature_effect_name(data)
		if signature_name != "NO SIGNATURE EFFECT":
			var signature: Label = _label(box, tr(signature_name), 12, Color(0.82, 0.70, 0.98, 1.0))
			signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			signature.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# Purchase actions share one compact row so a forgeable item does not become
		# dramatically taller than an owned card on mobile.
		var action_row: HBoxContainer = HBoxContainer.new()
		action_row.add_theme_constant_override("separation", 5)
		box.add_child(action_row)
		var stone_price: int = int(data.get("price", 0))
		var shard_price: int = int(data.get("forge_cost", 0))
		var buy: Button = _button(action_row, tr("%d STONES") % stone_price, _buy.bind(item_id, false), false, GOLD)
		var forge_button: Button = _button(action_row, tr("%d SHARDS") % shard_price, _buy.bind(item_id, true), false, CYAN)
		buy.add_theme_font_size_override("font_size", 11)
		forge_button.add_theme_font_size_override("font_size", 11)
		var sealed: bool = not EquipmentManager.can_modify_equipment() or SaveManager.is_progress_read_only()
		buy.disabled = sealed or ProgressionManager.spirit_stone < stone_price
		forge_button.disabled = sealed or InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD) < shard_price
	return card

func _sync_rarity_buttons() -> void:
	for rarity: String in RARITIES:
		var button: Button = rarity_buttons.get(rarity) as Button
		if button == null:
			continue
		var accent: Color = EquipmentVisualCatalog.get_rarity_color(rarity)
		_apply_filter_style(button, accent, rarity == selected_rarity)


func _select_rarity(rarity: String) -> void:
	if not RARITIES.has(rarity):
		return
	selected_rarity = rarity
	_sync_rarity_buttons()
	_rebuild_equipment()


func _meditate() -> void:
	if PavilionManager.claim_meditation():
		_set_status(tr("Meditation complete. +20 Spirit Stones."), JADE)
	else:
		_set_status(tr(PavilionManager.last_error), Color(0.95, 0.48, 0.42))


func _select_cosmetic(cosmetic_id: String) -> void:
	var cost: Dictionary = PavilionManager.get_cosmetic_cost(cosmetic_id)
	var paid: bool = (
		int(cost.get("spirit_stone", 0)) > 0
		or int(cost.get("refinement_shard", 0)) > 0
	)
	var success: bool
	if not PavilionManager.is_cosmetic_owned(cosmetic_id) and paid:
		success = PavilionManager.acquire_cosmetic(cosmetic_id)
		if success:
			_set_status(tr("Aura acquired and attuned."), VIOLET)
		else:
			_set_status(tr(PavilionManager.last_error), Color(0.95, 0.48, 0.42))
	else:
		success = PavilionManager.select_cosmetic(cosmetic_id)
		if success:
			_set_status(tr("Aura attuned."), VIOLET)
		else:
			_set_status(tr(PavilionManager.last_error), Color(0.95, 0.48, 0.42))


func _buy(item_id: String, use_shards: bool) -> void:
	if PavilionManager.acquire_equipment(item_id, use_shards):
		_set_status(tr("Equipment acquired. Open Hero to equip it."), JADE)
	else:
		_set_status(tr(PavilionManager.last_error), Color(0.95, 0.48, 0.42))


func _open_privacy() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		"res://scenes/ui/privacy_screen.tscn",
		1
	)
	if change_error != OK:
		push_error("PavilionScreen: gagal membuka Privacy. Error code: " + str(change_error))


func _back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		"res://scenes/ui/main_menu.tscn",
		-1
	)
	if change_error != OK:
		push_error("PavilionScreen: gagal kembali ke Main Menu. Error code: " + str(change_error))



func _add_bottom_safe_spacer() -> void:
	# The HubNav is anchored above the viewport bottom while Scroll content
	# continues behind it.  Reserve explicit breathing room so the final card
	# can always be scrolled fully above navigation on 405x860 devices.
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 122.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)


func _aura_card_style(
	accent: Color,
	featured: bool,
	current: bool,
	unlocked: bool
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var glow: float = 0.085 if featured else 0.060
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
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.13 if featured else 0.07)
	style.shadow_size = 7 if featured else 4
	return style


func _aura_overlay_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.014, 0.024, 0.88)
	style.border_width_top = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style


func _equipment_card_style(accent: Color, owned: bool, unlocked: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var glow: float = 0.055 if owned else 0.070
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
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.08 if unlocked else 0.02)
	style.shadow_size = 4
	return style


func _equipment_icon_style(accent: Color, unlocked: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var strength: float = 0.095 if unlocked else 0.035
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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var strength: float = 0.105 if available else 0.035
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
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.14 if available else 0.03)
	style.shadow_size = 6
	return style

func _section_card(
	parent_node: Node,
	eyebrow: String,
	title: String,
	description: String,
	accent: Color
) -> VBoxContainer:
	var panel: PanelContainer = _panel(parent_node, _panel_style(accent, false, 12))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	_label(box, eyebrow, 12, Color(accent.r, accent.g, accent.b, 0.96))
	_label(box, title, 23, Color(1.0, 0.86, 0.48))
	_label(box, description, 14, Color(0.76, 0.84, 0.82, 1.0))
	return box


func _resource_chip(
	parent_node: Node,
	icon_path: String,
	caption: String,
	accent: Color
) -> Label:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _chip_style(accent))
	parent_node.add_child(panel)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(30.0, 30.0)
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var copy: VBoxContainer = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", -1)
	row.add_child(copy)
	_label(copy, caption, 10, Color(accent.r, accent.g, accent.b, 0.88))
	return _label(copy, "0", 16, Color(1.0, 0.91, 0.62, 1.0))


func _make_emblem(
	parent_node: Node,
	accent: Color,
	secondary: Color,
	glyph: String,
	size_value: float
) -> void:
	var emblem: PanelContainer = PanelContainer.new()
	emblem.custom_minimum_size = Vector2(size_value, size_value)
	emblem.add_theme_stylebox_override("panel", _emblem_style(accent, secondary, size_value))
	parent_node.add_child(emblem)
	var glyph_label: Label = _label(emblem, glyph, int(size_value * 0.28), Color(1.0, 0.88, 0.48, 1.0))
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _make_icon_emblem(
	parent_node: Node,
	icon_path: String,
	accent: Color,
	secondary: Color,
	size_value: float
) -> void:
	var emblem: PanelContainer = PanelContainer.new()
	emblem.custom_minimum_size = Vector2(size_value, size_value)
	emblem.add_theme_stylebox_override("panel", _emblem_style(accent, secondary, size_value))
	parent_node.add_child(emblem)

	var icon: TextureRect = TextureRect.new()
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
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _chip_style(accent))
	parent_node.add_child(panel)
	var label: Label = _label(panel, value, 10, Color(accent.r, accent.g, accent.b, 0.96))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _label(
	parent_node: Node,
	value: String,
	font_size: int = 16,
	tint: Color = TEXT_MUTED
) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent_node.add_child(label)
	return label


func _button(
	parent_node: Node,
	value: String,
	callback: Callable,
	primary: bool,
	accent: Color
) -> Button:
	var button: Button = Button.new()
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
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	parent_node.add_child(panel)
	return panel


func _panel_style(accent: Color, hero: bool, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(
		PANEL_DARK.r,
		PANEL_DARK.g,
		PANEL_DARK.b,
		0.97 if hero else 0.91
	)
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


func _hero_overlay_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.055, accent.g * 0.055, accent.b * 0.055, 0.74)
	style.border_width_left = 2
	style.border_width_top = 0
	style.border_width_right = 0
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
	var style: StyleBoxFlat = StyleBoxFlat.new()
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


func _soft_icon_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.06, accent.g * 0.06, accent.b * 0.06, 0.88)
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.32)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 6.0
	style.content_margin_top = 4.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 4.0
	return style


func _emblem_style(accent: Color, secondary: Color, size_value: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.055, accent.g * 0.055, accent.b * 0.055, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.88)
	var radius: int = maxi(int(size_value * 0.5), 1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(secondary.r, secondary.g, secondary.b, 0.12)
	style.shadow_size = 5
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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(
		accent.r * (0.16 if primary else 0.10),
		accent.g * (0.16 if primary else 0.10),
		accent.b * (0.16 if primary else 0.10),
		0.96
	)
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
	button.add_theme_color_override(
		"font_color",
		Color(1.0, 0.90, 0.56, 1.0) if selected else Color(0.70, 0.80, 0.76, 1.0)
	)
	button.add_theme_stylebox_override(
		"normal",
		_filter_style(accent, selected, false)
	)
	button.add_theme_stylebox_override(
		"hover",
		_filter_style(accent, true, true)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_filter_style(accent, true, true)
	)
	button.add_theme_stylebox_override(
		"focus",
		_filter_style(accent, true, true)
	)


func _filter_style(accent: Color, selected: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var fill_alpha: float = 0.22 if selected else 0.08
	if hovered:
		fill_alpha += 0.05
	style.bg_color = Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.92)
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
	style.bg_color.a = fill_alpha
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
	var sample: String = tr("%d Spirit Stone") % 1
	if sample.begins_with("1 "):
		sample = sample.substr(2)
	return sample.to_upper()


func _format_count(value: int) -> String:
	var remaining: String = str(maxi(value, 0))
	var groups: Array[String] = []
	while remaining.length() > 3:
		groups.push_front(remaining.right(3))
		remaining = remaining.left(remaining.length() - 3)
	groups.push_front(remaining)
	return ".".join(groups)
