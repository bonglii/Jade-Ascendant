extends Control

## Hero / Backpack presentation.
## InventoryManager remains the authority for ownership/counts.
## Premium Polish Pass 6: commercial finish — codex progress, premium item focus and unified collectible card language.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const EQUIPMENT_SCENE: String = "res://scenes/ui/equipment_screen.tscn"
const PAVILION_SCENE: String = "res://scenes/ui/pavilion_screen.tscn"
const EquipmentVisualCatalog = preload("res://scripts/ui/equipment_visual_catalog.gd")

const FILTER_ALL: String = "all"
const FILTER_EQUIPMENT: String = "equipment"
const FILTER_MATERIAL: String = "material"
const FILTER_EQUIPPED: String = "equipped"
const SORT_RARITY: String = "rarity"
const SORT_SLOT: String = "slot"
const SORT_NAME: String = "name"

@onready var spirit_stone_label: Label = %SpiritStoneLabel
@onready var summary_label: Label = %SummaryLabel
@onready var equipped_summary_label: Label = %EquippedSummaryLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var empty_label: Label = %EmptyLabel
@onready var equipment_tab_button: Button = %EquipmentTabButton
@onready var all_filter_button: Button = %AllFilterButton
@onready var equipment_filter_button: Button = %EquipmentFilterButton
@onready var material_filter_button: Button = %MaterialFilterButton
@onready var equipped_filter_button: Button = %EquippedFilterButton
@onready var sort_button: Button = %SortButton
@onready var selected_item_icon: TextureRect = %SelectedItemIcon
@onready var selected_item_name_label: Label = %SelectedItemNameLabel
@onready var selected_meta_label: Label = %SelectedMetaLabel
@onready var selected_stats_label: Label = %SelectedStatsLabel
@onready var selected_effect_label: Label = %SelectedEffectLabel
@onready var ascension_status_label: Label = %AscensionStatusLabel
@onready var ascension_preview_label: Label = %AscensionPreviewLabel
@onready var ascend_button: Button = %AscendButton
@onready var ascend_hint_label: Label = %AscendHintLabel
@onready var selected_action_button: Button = %SelectedActionButton
@onready var selected_hint_label: Label = %SelectedHintLabel
@onready var detail_panel: PanelContainer = %DetailPanel
@onready var item_info_card: PanelContainer = %ItemInfoCard
@onready var signature_panel: PanelContainer = %SignaturePanel
@onready var ascension_panel: PanelContainer = %AscensionPanel
@onready var collection_progress_label: Label = %CollectionProgressLabel
@onready var collection_progress_bar: ProgressBar = %CollectionProgressBar
@onready var detail_close_button: Button = %DetailCloseButton

var active_filter: String = FILTER_ALL
var sort_mode: String = SORT_RARITY
var selected_item_id: String = ""
var detail_open: bool = false

func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)
	equipment_tab_button.pressed.connect(_open_equipment)
	all_filter_button.pressed.connect(_set_filter.bind(FILTER_ALL))
	equipment_filter_button.pressed.connect(_set_filter.bind(FILTER_EQUIPMENT))
	material_filter_button.pressed.connect(_set_filter.bind(FILTER_MATERIAL))
	equipped_filter_button.pressed.connect(_set_filter.bind(FILTER_EQUIPPED))
	sort_button.pressed.connect(_cycle_sort)
	selected_action_button.pressed.connect(_on_selected_action_pressed)
	ascend_button.pressed.connect(_on_ascend_pressed)
	detail_close_button.pressed.connect(_close_detail)
	if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
	if not EquipmentManager.equipment_changed.is_connected(_on_equipment_changed):
		EquipmentManager.equipment_changed.connect(_on_equipment_changed)
	if not EquipmentManager.equipment_ascended.is_connected(_on_equipment_ascended):
		EquipmentManager.equipment_ascended.connect(_on_equipment_ascended)
	_refresh_screen()
	detail_panel.visible = detail_open
	DebugLogger.system(str("Hero Backpack Hub aktif!"))

func _refresh_screen() -> void:
	spirit_stone_label.text = "%d" % ProgressionManager.spirit_stone
	var unique_count: int = InventoryManager.get_unique_item_count()
	var total_count: int = InventoryManager.get_total_item_count()
	summary_label.text = tr("OWNED %d UNIQUE  •  %d TOTAL") % [unique_count, total_count]
	equipped_summary_label.text = tr("EQUIPPED %d / %d") % [_get_equipped_count(), EquipmentManager.get_slot_ids().size()]
	var owned_equipment: int = _get_owned_equipment_count()
	var total_equipment: int = _get_total_equipment_count()
	collection_progress_label.text = tr("RELIC CODEX  %d / %d") % [owned_equipment, total_equipment]
	collection_progress_bar.max_value = maxf(float(total_equipment), 1.0)
	collection_progress_bar.value = float(owned_equipment)
	_refresh_filter_buttons()
	var visible_items: Array[String] = _get_visible_item_ids()
	_validate_selected_item(visible_items)
	_rebuild_item_grid(visible_items)
	_refresh_detail_panel()
	detail_panel.visible = detail_open

func _refresh_filter_buttons() -> void:
	_apply_filter_style(all_filter_button, active_filter == FILTER_ALL)
	_apply_filter_style(equipment_filter_button, active_filter == FILTER_EQUIPMENT)
	_apply_filter_style(material_filter_button, active_filter == FILTER_MATERIAL)
	_apply_filter_style(equipped_filter_button, active_filter == FILTER_EQUIPPED)
	sort_button.text = tr("SORT  •  %s") % tr(sort_mode.to_upper())

func _apply_filter_style(button: Button, selected: bool) -> void:
	button.theme_type_variation = &"JadePrimaryButton" if selected else &"JadeSecondaryButton"
	button.add_theme_font_size_override("font_size", 12)

func _get_visible_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	for item_id: String in InventoryManager.get_owned_item_ids():
		var item_type: String = InventoryManager.get_item_type(item_id)
		match active_filter:
			FILTER_EQUIPMENT:
				if item_type != InventoryManager.ITEM_TYPE_EQUIPMENT: continue
			FILTER_MATERIAL:
				if item_type != InventoryManager.ITEM_TYPE_MATERIAL: continue
			FILTER_EQUIPPED:
				if not _is_equipped(item_id): continue
		item_ids.append(item_id)
	item_ids.sort_custom(_sort_item_ids)
	return item_ids

func _sort_item_ids(a: String, b: String) -> bool:
	var data_a: Dictionary = InventoryManager.get_item_data(a)
	var data_b: Dictionary = InventoryManager.get_item_data(b)
	match sort_mode:
		SORT_NAME:
			return str(data_a.get("display_name", a)).nocasecmp_to(str(data_b.get("display_name", b))) < 0
		SORT_SLOT:
			var slot_a: int = EquipmentVisualCatalog.get_slot_sort_order(str(data_a.get("slot", "zz")))
			var slot_b: int = EquipmentVisualCatalog.get_slot_sort_order(str(data_b.get("slot", "zz")))
			if slot_a != slot_b: return slot_a < slot_b
			return str(data_a.get("display_name", a)).nocasecmp_to(str(data_b.get("display_name", b))) < 0
		_:
			var rarity_a: int = EquipmentVisualCatalog.get_rarity_rank(str(data_a.get("rarity", "common")))
			var rarity_b: int = EquipmentVisualCatalog.get_rarity_rank(str(data_b.get("rarity", "common")))
			if rarity_a != rarity_b: return rarity_a > rarity_b
			return str(data_a.get("display_name", a)).nocasecmp_to(str(data_b.get("display_name", b))) < 0

func _validate_selected_item(visible_items: Array[String]) -> void:
	if selected_item_id in visible_items: return
	selected_item_id = ""
	detail_open = false

func _rebuild_item_grid(visible_items: Array[String]) -> void:
	for child: Node in item_grid.get_children(): child.queue_free()
	empty_label.visible = visible_items.is_empty()
	for item_id: String in visible_items:
		item_grid.add_child(_create_item_tile(item_id))

func _create_item_tile(item_id: String) -> Button:
	var item_data: Dictionary = InventoryManager.get_item_data(item_id)
	var item_type: String = InventoryManager.get_item_type(item_id)
	var equipped: bool = _is_equipped(item_id)
	var selected: bool = detail_open and selected_item_id == item_id
	var tile: Button = Button.new()
	tile.custom_minimum_size = Vector2(102.0, 108.0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.icon = null
	tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var count: int = InventoryManager.get_item_count(item_id)
	tile.text = ""
	var rarity_id: String = str(item_data.get("rarity", "common"))
	var rarity_color: Color = EquipmentVisualCatalog.get_rarity_color(rarity_id)
	if item_type == InventoryManager.ITEM_TYPE_MATERIAL:
		rarity_color = Color(0.35, 0.82, 1.0, 1.0)
	_install_card_icon(tile, _load_item_icon(item_id), rarity_color, true)
	if item_type == InventoryManager.ITEM_TYPE_EQUIPMENT:
		_add_rarity_badge(tile, rarity_id, rarity_color)
		_add_star_badge(tile, EquipmentManager.get_item_star(item_id))
	else:
		_add_count_badge(tile, count)
	if equipped: _add_state_badge(tile, "E", Color(0.24, 1.0, 0.76, 1.0))
	tile.add_theme_stylebox_override("normal", _make_tile_style(rarity_color, equipped, selected, false))
	tile.add_theme_stylebox_override("hover", _make_tile_style(rarity_color, equipped, true, true))
	tile.add_theme_stylebox_override("pressed", _make_tile_style(rarity_color, equipped, true, true))
	tile.add_theme_stylebox_override("focus", _make_tile_style(rarity_color, equipped, true, true))
	tile.add_theme_color_override("font_color", Color(1.0, 0.91, 0.61, 1.0))
	var tooltip_detail: String = str(item_data.get("description", ""))
	if item_type == InventoryManager.ITEM_TYPE_EQUIPMENT: tooltip_detail = "%s  •  %s" % [_format_stars(EquipmentManager.get_item_star(item_id)), EquipmentVisualCatalog.get_stat_summary(EquipmentManager.get_effective_item_data(item_id))]
	tile.tooltip_text = "%s\n%s" % [str(item_data.get("display_name", item_id)), tooltip_detail]
	tile.pressed.connect(_on_item_pressed.bind(item_id))
	return tile


func _install_card_icon(parent_button: Button, texture: Texture2D, rarity_color: Color, owned: bool) -> void:
	var glow := PanelContainer.new()
	glow.name = "IconGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.anchor_left = 0.20
	glow.anchor_top = 0.14
	glow.anchor_right = 0.80
	glow.anchor_bottom = 0.72
	glow.add_theme_stylebox_override("panel", _make_icon_glow_style(rarity_color, owned))
	parent_button.add_child(glow)

	var art := TextureRect.new()
	art.name = "ItemArt"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.anchor_left = 0.20
	art.anchor_top = 0.10
	art.anchor_right = 0.80
	art.anchor_bottom = 0.70
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent_button.add_child(art)

func _make_icon_glow_style(accent: Color, owned: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.34 if owned else 0.10)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.28 if owned else 0.10)
	style.corner_radius_top_left = 64
	style.corner_radius_top_right = 64
	style.corner_radius_bottom_left = 64
	style.corner_radius_bottom_right = 64
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.18 if owned else 0.04)
	style.shadow_size = 8 if owned else 2
	return style

func _make_tile_style(rarity_color: Color, equipped: bool, selected: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var base: Color = Color(0.003, 0.020, 0.034, 0.98)
	var tint: float = 0.40
	style.bg_color = Color(base.r + rarity_color.r * tint, base.g + rarity_color.g * tint * 0.64, base.b + rarity_color.b * tint, 0.98)
	if hovered:
		style.bg_color = style.bg_color.lightened(0.10)
	var border_color: Color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.68)
	if equipped:
		border_color = Color(0.18, 1.0, 0.74, 1.0)
	if selected:
		border_color = Color(1.0, 0.76, 0.20, 1.0)
	style.border_width_left = 2 if selected or equipped else 1
	style.border_width_top = 2 if selected or equipped else 1
	style.border_width_right = 2 if selected or equipped else 1
	style.border_width_bottom = 3 if selected or equipped else 2
	style.border_color = border_color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 5.0
	style.content_margin_top = 7.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.30 if selected or equipped else 0.09)
	style.shadow_size = 10 if selected or equipped else 3
	return style

func _apply_detail_density(item_type: String) -> void:
	# Compact bottom-sheet sizing keeps information close to the selected relic.
	# Materials need less vertical space because they have no Ascension block.
	detail_panel.anchor_top = 0.61 if item_type == InventoryManager.ITEM_TYPE_MATERIAL else 0.535
	detail_panel.anchor_bottom = 0.875

func _refresh_detail_panel() -> void:
	if selected_item_id.is_empty():
		detail_panel.anchor_top = 0.535
		detail_panel.anchor_bottom = 0.875
		selected_item_icon.texture = null
		selected_item_name_label.text = tr("NO ITEM SELECTED")
		selected_meta_label.text = tr("Choose an item from the backpack grid.")
		selected_stats_label.text = ""
		selected_effect_label.text = ""
		ascension_status_label.visible = false
		ascension_preview_label.visible = false
		ascend_button.visible = false
		ascend_hint_label.visible = false
		selected_action_button.text = tr("NO ACTION")
		selected_action_button.disabled = true
		selected_hint_label.text = ""
		return

	var item_data: Dictionary = InventoryManager.get_item_data(selected_item_id)
	var item_type: String = InventoryManager.get_item_type(selected_item_id)
	_apply_detail_density(item_type)
	selected_item_icon.texture = _load_item_icon(selected_item_id)
	selected_item_name_label.text = str(item_data.get("display_name", selected_item_id))
	var detail_rarity_color: Color = EquipmentVisualCatalog.get_rarity_color(str(item_data.get("rarity", "common")))
	selected_item_name_label.add_theme_color_override("font_color", detail_rarity_color)
	_apply_detail_rarity_style(detail_rarity_color)
	if item_type == InventoryManager.ITEM_TYPE_MATERIAL:
		ascension_panel.visible = false
		ascension_status_label.visible = false
		ascension_preview_label.visible = false
		ascend_button.visible = false
		ascend_hint_label.visible = false
		selected_meta_label.text = tr("REFINEMENT MATERIAL  •  OWNED x%d") % InventoryManager.get_item_count(selected_item_id)
		selected_stats_label.text = tr(str(item_data.get("description", "Use this material to forge or ascend equipment.")))
		selected_effect_label.text = tr("PAVILION RESOURCE")
		selected_action_button.text = tr("OPEN JADE PAVILION")
		selected_action_button.disabled = false
		selected_hint_label.text = tr("Use Refinement Shards to forge or ascend equipment.")
		return

	ascension_panel.visible = true
	var slot_id: String = str(item_data.get("slot", ""))
	var equipped: bool = EquipmentManager.get_equipped_item_id(slot_id) == selected_item_id
	var current_star: int = EquipmentManager.get_item_star(selected_item_id)
	var effective_data: Dictionary = EquipmentManager.get_effective_item_data(selected_item_id)
	selected_meta_label.text = "%s  •  %s  •  x%d\n%s" % [
		tr(str(item_data.get("rarity", "common")).to_upper()),
		tr(EquipmentVisualCatalog.get_slot_title(slot_id)),
		InventoryManager.get_item_count(selected_item_id),
		_format_stars(current_star)
	]
	selected_stats_label.text = tr("CORE PASSIVE  •  %s") % EquipmentVisualCatalog.get_stat_summary(effective_data)
	selected_effect_label.text = "%s — %s\n%s" % [
		tr("SIGNATURE"),
		EquipmentVisualCatalog.get_signature_effect_name(item_data),
		EquipmentVisualCatalog.get_signature_effect_description(item_data)
	]
	_refresh_ascension_controls()
	if not EquipmentManager.can_modify_equipment():
		selected_action_button.text = tr("LOADOUT SEALED")
		selected_action_button.disabled = true
		selected_hint_label.text = tr("Finish or clear the active run before changing equipment.")
	elif equipped:
		selected_action_button.text = tr("UNEQUIP")
		selected_action_button.disabled = false
		selected_hint_label.text = tr("Remove this item from the permanent loadout.")
	else:
		selected_action_button.text = tr("EQUIP %s") % tr(EquipmentVisualCatalog.get_slot_title(slot_id))
		selected_action_button.disabled = false
		selected_hint_label.text = tr("Equip directly without leaving the backpack.")

func _refresh_ascension_controls() -> void:
	ascension_status_label.visible = true
	ascension_preview_label.visible = true
	ascend_button.visible = true
	ascend_hint_label.visible = true
	var current_star: int = EquipmentManager.get_item_star(selected_item_id)
	var shard_balance: int = InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD)
	if current_star >= EquipmentManager.MAX_ASCENSION_STAR:
		ascension_status_label.text = "%s  •  MAX" % _format_stars(current_star)
		ascension_preview_label.text = tr("CELESTIAL LIMIT REACHED\nCore passive +20% from 1★")
		ascend_button.text = tr("MAX ASCENSION")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("This relic has reached 5★ resonance.")
		return
	var target_star: int = current_star + 1
	var cost: int = EquipmentManager.get_ascension_cost(selected_item_id)
	ascension_status_label.text = "%s  →  %s\nSHARDS  %d / %d" % [_format_stars(current_star), _format_stars(target_star), shard_balance, cost]
	ascension_preview_label.text = tr("NEXT CORE PASSIVE\n%s") % _build_ascension_stat_preview(selected_item_id, target_star)
	ascend_button.text = tr("ASCEND TO %d★  •  %d SHARDS") % [target_star, cost]
	if not EquipmentManager.can_modify_equipment():
		ascend_button.text = tr("ASCENSION SEALED")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Finish or clear the active run before ascending equipment.")
	elif shard_balance < cost:
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Need %d more Refinement Shards.") % (cost - shard_balance)
	else:
		ascend_button.disabled = false
		ascend_hint_label.text = tr("Core passive increases. Signature Effect remains unchanged.")

func _build_ascension_stat_preview(item_id: String, target_star: int) -> String:
	var base_data: Dictionary = EquipmentManager.get_item_data(item_id)
	var current_data: Dictionary = EquipmentManager.get_effective_item_data(item_id)
	var target_multiplier: float = float(EquipmentManager.ASCENSION_CORE_MULTIPLIERS.get(target_star, 1.0))
	var transitions: Array[String] = []
	for stat_key: String in EquipmentManager.ASCENSION_SCALABLE_STATS:
		if not base_data.has(stat_key): continue
		var current_value: float = float(current_data.get(stat_key, 0.0))
		var target_value: float = float(base_data.get(stat_key, 0.0)) * target_multiplier
		transitions.append(_format_stat_transition(stat_key, current_value, target_value))
	if transitions.is_empty(): return tr("CORE PASSIVE UNCHANGED")
	return "  •  ".join(transitions)

func _format_stat_transition(stat_key: String, current_value: float, target_value: float) -> String:
	match stat_key:
		"max_health_flat": return "%.1f → %.1f HP" % [current_value, target_value]
		"damage_bonus": return "%.1f%% → %.1f%% DMG" % [current_value * 100.0, target_value * 100.0]
		"movement_speed_bonus": return "%.1f%% → %.1f%% MOVE" % [current_value * 100.0, target_value * 100.0]
		"experience_bonus": return "%.1f%% → %.1f%% EXP" % [current_value * 100.0, target_value * 100.0]
		"critical_chance_bonus": return "%.1f%% → %.1f%% CRIT" % [current_value * 100.0, target_value * 100.0]
		_: return "%.2f → %.2f" % [current_value, target_value]

func _format_stars(star: int) -> String:
	var clamped_star: int = clampi(star, 0, EquipmentManager.MAX_ASCENSION_STAR)
	var result: String = ""
	for index: int in range(EquipmentManager.MAX_ASCENSION_STAR):
		result += "★" if index < clamped_star else "☆"
	return result

func _add_star_badge(parent_button: Button, star: int) -> void:
	var badge: Label = Label.new()
	badge.name = "StarBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.0
	badge.anchor_top = 1.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = 4.0
	badge.offset_top = -26.0
	badge.offset_right = -4.0
	badge.offset_bottom = -4.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_constant_override("outline_size", 2)
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.84))
	badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.22, 1.0))
	badge.text = _format_stars(star)
	parent_button.add_child(badge)


func _add_count_badge(parent_button: Button, count: int) -> void:
	var badge := Label.new()
	badge.name = "CountBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.54
	badge.anchor_top = 0.70
	badge.anchor_right = 0.94
	badge.anchor_bottom = 0.94
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_constant_override("outline_size", 3)
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
	badge.add_theme_color_override("font_color", Color(0.78, 0.93, 1.0, 1.0))
	badge.text = "×%d" % count
	parent_button.add_child(badge)

func _add_state_badge(parent_button: Button, text_value: String, color: Color) -> void:
	var badge: Label = Label.new()
	badge.name = "StateBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.76
	badge.anchor_top = 0.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 0.0
	badge.offset_top = 8.0
	badge.offset_right = -9.0
	badge.offset_bottom = 28.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_constant_override("outline_size", 2)
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	badge.add_theme_color_override("font_color", color)
	badge.text = text_value
	parent_button.add_child(badge)

func _add_rarity_badge(parent_button: Button, _rarity_id: String, color: Color) -> void:
	var stripe := ColorRect.new()
	stripe.name = "RarityBadge"
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.anchor_left = 0.18
	stripe.anchor_top = 0.0
	stripe.anchor_right = 0.82
	stripe.anchor_bottom = 0.0
	stripe.offset_top = 4.0
	stripe.offset_bottom = 7.0
	stripe.color = Color(color.r, color.g, color.b, 0.96)
	parent_button.add_child(stripe)

func _apply_detail_rarity_style(rarity_color: Color) -> void:
	detail_panel.add_theme_stylebox_override("panel", _make_detail_surface(rarity_color, 0.985, 12))
	item_info_card.add_theme_stylebox_override("panel", _make_detail_surface(rarity_color, 0.90, 7))
	signature_panel.add_theme_stylebox_override("panel", _make_detail_surface(rarity_color, 0.74, 6))
	ascension_panel.add_theme_stylebox_override("panel", _make_detail_surface(Color(0.96, 0.72, 0.20, 1.0), 0.82, 8))

func _make_detail_surface(accent: Color, opacity: float, glow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.003 + accent.r * 0.055, 0.018 + accent.g * 0.035, 0.030 + accent.b * 0.055, opacity)
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	style.corner_radius_top_left = 14; style.corner_radius_top_right = 14; style.corner_radius_bottom_left = 14; style.corner_radius_bottom_right = 14
	style.content_margin_left = 12.0; style.content_margin_top = 9.0; style.content_margin_right = 12.0; style.content_margin_bottom = 9.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.22); style.shadow_size = glow
	return style

func _get_total_equipment_count() -> int:
	var total := 0
	for slot_id: String in EquipmentManager.get_slot_ids(): total += EquipmentManager.get_item_ids_for_slot(slot_id).size()
	return total

func _get_owned_equipment_count() -> int:
	var total := 0
	for item_id: String in InventoryManager.get_owned_item_ids():
		if InventoryManager.get_item_type(item_id) == InventoryManager.ITEM_TYPE_EQUIPMENT: total += 1
	return total

func _set_filter(filter_id: String) -> void:
	if filter_id not in [FILTER_ALL, FILTER_EQUIPMENT, FILTER_MATERIAL, FILTER_EQUIPPED]: return
	active_filter = filter_id
	_refresh_screen()

func _cycle_sort() -> void:
	match sort_mode:
		SORT_RARITY: sort_mode = SORT_SLOT
		SORT_SLOT: sort_mode = SORT_NAME
		_: sort_mode = SORT_RARITY
	_refresh_screen()

func _on_item_pressed(item_id: String) -> void:
	if not InventoryManager.owns_item(item_id): return
	selected_item_id = item_id
	detail_open = true
	_refresh_screen()

func _close_detail() -> void:
	detail_open = false
	_refresh_screen()

func _on_selected_action_pressed() -> void:
	if selected_item_id.is_empty(): return
	var item_type: String = InventoryManager.get_item_type(selected_item_id)
	if item_type == InventoryManager.ITEM_TYPE_MATERIAL:
		_open_pavilion()
		return
	if item_type != InventoryManager.ITEM_TYPE_EQUIPMENT: return
	if not EquipmentManager.can_modify_equipment():
		_refresh_screen()
		return
	var item_data: Dictionary = EquipmentManager.get_item_data(selected_item_id)
	ascension_panel.visible = true
	var slot_id: String = str(item_data.get("slot", ""))
	if EquipmentManager.get_equipped_item_id(slot_id) == selected_item_id:
		EquipmentManager.unequip_slot(slot_id)
	else:
		EquipmentManager.equip_item(selected_item_id)

func _load_item_icon(item_id: String) -> Texture2D:
	var icon_path: String = EquipmentVisualCatalog.get_icon_path(item_id)
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path): return null
	var icon_resource: Resource = ResourceLoader.load(icon_path)
	if icon_resource is Texture2D: return icon_resource as Texture2D
	return null

func _get_equipped_count() -> int:
	var count: int = 0
	for slot_id: String in EquipmentManager.get_slot_ids():
		if not EquipmentManager.get_equipped_item_id(slot_id).is_empty(): count += 1
	return count

func _is_equipped(item_id: String) -> bool:
	for slot_id: String in EquipmentManager.get_slot_ids():
		if EquipmentManager.get_equipped_item_id(slot_id) == item_id: return true
	return false

func _on_ascend_pressed() -> void:
	if selected_item_id.is_empty(): return
	if InventoryManager.get_item_type(selected_item_id) != InventoryManager.ITEM_TYPE_EQUIPMENT: return
	if EquipmentManager.ascend_item(selected_item_id): _refresh_screen()

func _on_equipment_ascended(item_id: String, _old_star: int, _new_star: int) -> void:
	if item_id == selected_item_id: _refresh_screen()

func _on_inventory_changed(_item_id: String, _new_count: int) -> void:
	_refresh_screen()

func _on_equipment_changed(_slot_id: String, _item_id: String) -> void:
	_refresh_screen()

func _open_equipment() -> void:
	if SceneTransitionManager.is_transitioning: return
	if not ResourceLoader.exists(EQUIPMENT_SCENE):
		push_error("HeroBackpack: Equipment scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(EQUIPMENT_SCENE, -1)
	if change_error != OK:
		push_error("HeroBackpack: gagal membuka Equipment. Error code: " + str(change_error))

func _open_pavilion() -> void:
	if SceneTransitionManager.is_transitioning: return
	if not ResourceLoader.exists(PAVILION_SCENE):
		push_error("HeroBackpack: Pavilion scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(PAVILION_SCENE, 1)
	if change_error != OK:
		push_error("HeroBackpack: gagal membuka Pavilion. Error code: " + str(change_error))

func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning: return
	_return_to_journey()

func _return_to_journey() -> void:
	if SceneTransitionManager.is_transitioning: return
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error("HeroBackpack: Main Menu scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(MAIN_MENU_SCENE, -1)
	if change_error != OK:
		push_error("HeroBackpack: gagal kembali ke Journey. Error code: " + str(change_error))
