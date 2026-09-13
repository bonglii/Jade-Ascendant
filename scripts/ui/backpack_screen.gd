extends Control

## Hero / Backpack presentation.
## InventoryManager remains the authority for ownership/counts.

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
	equipped_summary_label.text = tr("EQUIPPED %d / %d") % [
		_get_equipped_count(),
		EquipmentManager.get_slot_ids().size()
	]
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
	button.add_theme_font_size_override("font_size", 10)

func _get_visible_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	for item_id: String in InventoryManager.get_owned_item_ids():
		var item_type: String = InventoryManager.get_item_type(item_id)
		match active_filter:
			FILTER_EQUIPMENT:
				if item_type != InventoryManager.ITEM_TYPE_EQUIPMENT:
					continue
			FILTER_MATERIAL:
				if item_type != InventoryManager.ITEM_TYPE_MATERIAL:
					continue
			FILTER_EQUIPPED:
				if not _is_equipped(item_id):
					continue
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
			if slot_a != slot_b:
				return slot_a < slot_b
			return str(data_a.get("display_name", a)).nocasecmp_to(str(data_b.get("display_name", b))) < 0
		_:
			var rarity_a: int = EquipmentVisualCatalog.get_rarity_rank(str(data_a.get("rarity", "common")))
			var rarity_b: int = EquipmentVisualCatalog.get_rarity_rank(str(data_b.get("rarity", "common")))
			if rarity_a != rarity_b:
				return rarity_a > rarity_b
			return str(data_a.get("display_name", a)).nocasecmp_to(str(data_b.get("display_name", b))) < 0

func _validate_selected_item(visible_items: Array[String]) -> void:
	if selected_item_id in visible_items:
		return
	selected_item_id = ""
	detail_open = false

func _rebuild_item_grid(visible_items: Array[String]) -> void:
	for child: Node in item_grid.get_children():
		child.queue_free()
	empty_label.visible = visible_items.is_empty()
	for item_id: String in visible_items:
		item_grid.add_child(_create_item_tile(item_id))

func _create_item_tile(item_id: String) -> Button:
	var item_data: Dictionary = InventoryManager.get_item_data(item_id)
	var item_type: String = InventoryManager.get_item_type(item_id)
	var equipped: bool = _is_equipped(item_id)
	var selected: bool = detail_open and selected_item_id == item_id
	var tile: Button = Button.new()
	tile.custom_minimum_size = Vector2(98.0, 92.0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.icon = _load_item_icon(item_id)
	tile.expand_icon = true
	tile.add_theme_constant_override("icon_max_width", 50)
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_theme_font_size_override("font_size", 8)
	var count_text: String = "x%d" % InventoryManager.get_item_count(item_id)
	tile.text = count_text
	if item_type == InventoryManager.ITEM_TYPE_EQUIPMENT:
		_add_star_badge(tile, EquipmentManager.get_item_star(item_id))
	var rarity_color: Color = EquipmentVisualCatalog.get_rarity_color(str(item_data.get("rarity", "common")))
	tile.add_theme_stylebox_override("normal", _make_tile_style(rarity_color, equipped, selected))
	tile.add_theme_stylebox_override("hover", _make_tile_style(rarity_color, equipped, true))
	tile.add_theme_stylebox_override("pressed", _make_tile_style(rarity_color, equipped, true))
	tile.add_theme_stylebox_override("focus", _make_tile_style(rarity_color, equipped, true))
	tile.add_theme_color_override("font_color", Color(1.0, 0.90, 0.60, 1.0) if selected else Color(0.72, 0.88, 0.84, 1.0))
	var tooltip_detail: String = str(item_data.get("description", ""))
	if item_type == InventoryManager.ITEM_TYPE_EQUIPMENT:
		tooltip_detail = "%s  •  %s" % [
			_format_stars(EquipmentManager.get_item_star(item_id)),
			EquipmentVisualCatalog.get_stat_summary(EquipmentManager.get_effective_item_data(item_id))
		]
	tile.tooltip_text = "%s\n%s" % [
		str(item_data.get("display_name", item_id)),
		tooltip_detail
	]
	tile.pressed.connect(_on_item_pressed.bind(item_id))
	return tile

func _make_tile_style(rarity_color: Color, equipped: bool, selected: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.024, 0.036, 0.88)
	if selected:
		style.bg_color = Color(0.008, 0.066, 0.070, 0.96)
	var border_width: int = 2 if selected else 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	if selected:
		style.border_color = Color(0.98, 0.80, 0.36, 0.98)
	elif equipped:
		style.border_color = Color(0.34, 0.90, 0.75, 0.92)
	else:
		style.border_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.72)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 1
	return style

func _refresh_detail_panel() -> void:
	if selected_item_id.is_empty():
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
	selected_item_icon.texture = _load_item_icon(selected_item_id)
	selected_item_name_label.text = str(item_data.get("display_name", selected_item_id))
	selected_item_name_label.add_theme_color_override(
		"font_color",
		EquipmentVisualCatalog.get_rarity_color(str(item_data.get("rarity", "common")))
	)
	if item_type == InventoryManager.ITEM_TYPE_MATERIAL:
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

	var slot_id: String = str(item_data.get("slot", ""))
	var equipped: bool = EquipmentManager.get_equipped_item_id(slot_id) == selected_item_id
	var current_star: int = EquipmentManager.get_item_star(selected_item_id)
	var effective_data: Dictionary = EquipmentManager.get_effective_item_data(selected_item_id)
	selected_meta_label.text = "%s  •  %s  •  %s  •  OWNED x%d" % [
		tr(str(item_data.get("rarity", "common")).to_upper()),
		tr(EquipmentVisualCatalog.get_slot_title(slot_id)),
		_format_stars(current_star),
		InventoryManager.get_item_count(selected_item_id)
	]
	selected_stats_label.text = EquipmentVisualCatalog.get_stat_summary(effective_data)
	selected_effect_label.text = "%s  •  %s" % [
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
	ascension_status_label.text = tr("ASCENSION  •  %s  •  REFINEMENT SHARDS %d") % [
		_format_stars(current_star),
		shard_balance
	]
	if current_star >= EquipmentManager.MAX_ASCENSION_STAR:
		ascension_preview_label.text = tr("MAX ASCENSION  •  CORE PASSIVE +20% FROM 1★")
		ascend_button.text = tr("MAX ASCENSION")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("This equipment has reached 5★.")
		return

	var target_star: int = current_star + 1
	var cost: int = EquipmentManager.get_ascension_cost(selected_item_id)
	ascension_preview_label.text = tr("NEXT %d★  •  %s") % [
		target_star,
		_build_ascension_stat_preview(selected_item_id, target_star)
	]
	if not EquipmentManager.can_modify_equipment():
		ascend_button.text = tr("ASCENSION SEALED")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Finish or clear the active run before ascending equipment.")
	elif shard_balance < cost:
		ascend_button.text = tr("ASCEND TO %d★  •  %d SHARDS") % [target_star, cost]
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Need %d more Refinement Shards.") % (cost - shard_balance)
	else:
		ascend_button.text = tr("ASCEND TO %d★  •  %d SHARDS") % [target_star, cost]
		ascend_button.disabled = false
		ascend_hint_label.text = tr("Ascension strengthens core passives only; Signature Effects stay fixed.")

func _build_ascension_stat_preview(item_id: String, target_star: int) -> String:
	var base_data: Dictionary = EquipmentManager.get_item_data(item_id)
	var current_data: Dictionary = EquipmentManager.get_effective_item_data(item_id)
	var target_multiplier: float = float(EquipmentManager.ASCENSION_CORE_MULTIPLIERS.get(target_star, 1.0))
	var transitions: Array[String] = []
	for stat_key: String in EquipmentManager.ASCENSION_SCALABLE_STATS:
		if not base_data.has(stat_key):
			continue
		var current_value: float = float(current_data.get(stat_key, 0.0))
		var target_value: float = float(base_data.get(stat_key, 0.0)) * target_multiplier
		transitions.append(_format_stat_transition(stat_key, current_value, target_value))
	if transitions.is_empty():
		return tr("CORE PASSIVE UNCHANGED")
	return "  •  ".join(transitions)

func _format_stat_transition(stat_key: String, current_value: float, target_value: float) -> String:
	match stat_key:
		"max_health_flat":
			return "%.1f → %.1f HP" % [current_value, target_value]
		"damage_bonus":
			return "%.1f%% → %.1f%% DMG" % [current_value * 100.0, target_value * 100.0]
		"movement_speed_bonus":
			return "%.1f%% → %.1f%% MOVE" % [current_value * 100.0, target_value * 100.0]
		"experience_bonus":
			return "%.1f%% → %.1f%% EXP" % [current_value * 100.0, target_value * 100.0]
		"critical_chance_bonus":
			return "%.1f%% → %.1f%% CRIT" % [current_value * 100.0, target_value * 100.0]
		_:
			return "%.2f → %.2f" % [current_value, target_value]

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
	badge.offset_left = 3.0
	badge.offset_top = -19.0
	badge.offset_right = -3.0
	badge.offset_bottom = -2.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38, 0.96))
	badge.text = _format_stars(star)
	parent_button.add_child(badge)

func _set_filter(filter_id: String) -> void:
	if filter_id not in [FILTER_ALL, FILTER_EQUIPMENT, FILTER_MATERIAL, FILTER_EQUIPPED]:
		return
	active_filter = filter_id
	_refresh_screen()

func _cycle_sort() -> void:
	match sort_mode:
		SORT_RARITY:
			sort_mode = SORT_SLOT
		SORT_SLOT:
			sort_mode = SORT_NAME
		_:
			sort_mode = SORT_RARITY
	_refresh_screen()

func _on_item_pressed(item_id: String) -> void:
	if not InventoryManager.owns_item(item_id):
		return
	selected_item_id = item_id
	detail_open = true
	_refresh_screen()

func _close_detail() -> void:
	detail_open = false
	_refresh_screen()

func _on_selected_action_pressed() -> void:
	if selected_item_id.is_empty():
		return
	var item_type: String = InventoryManager.get_item_type(selected_item_id)
	if item_type == InventoryManager.ITEM_TYPE_MATERIAL:
		_open_pavilion()
		return
	if item_type != InventoryManager.ITEM_TYPE_EQUIPMENT:
		return
	if not EquipmentManager.can_modify_equipment():
		_refresh_screen()
		return
	var item_data: Dictionary = EquipmentManager.get_item_data(selected_item_id)
	var slot_id: String = str(item_data.get("slot", ""))
	if EquipmentManager.get_equipped_item_id(slot_id) == selected_item_id:
		EquipmentManager.unequip_slot(slot_id)
	else:
		EquipmentManager.equip_item(selected_item_id)

func _load_item_icon(item_id: String) -> Texture2D:
	var icon_path: String = EquipmentVisualCatalog.get_icon_path(item_id)
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	var icon_resource: Resource = ResourceLoader.load(icon_path)
	if icon_resource is Texture2D:
		return icon_resource as Texture2D
	return null

func _get_equipped_count() -> int:
	var count: int = 0
	for slot_id: String in EquipmentManager.get_slot_ids():
		if not EquipmentManager.get_equipped_item_id(slot_id).is_empty():
			count += 1
	return count

func _is_equipped(item_id: String) -> bool:
	for slot_id: String in EquipmentManager.get_slot_ids():
		if EquipmentManager.get_equipped_item_id(slot_id) == item_id:
			return true
	return false

func _on_ascend_pressed() -> void:
	if selected_item_id.is_empty():
		return
	if InventoryManager.get_item_type(selected_item_id) != InventoryManager.ITEM_TYPE_EQUIPMENT:
		return
	if EquipmentManager.ascend_item(selected_item_id):
		_refresh_screen()

func _on_equipment_ascended(item_id: String, _old_star: int, _new_star: int) -> void:
	if item_id == selected_item_id:
		_refresh_screen()

func _on_inventory_changed(_item_id: String, _new_count: int) -> void:
	_refresh_screen()

func _on_equipment_changed(_slot_id: String, _item_id: String) -> void:
	_refresh_screen()

func _open_equipment() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(EQUIPMENT_SCENE):
		push_error("HeroBackpack: Equipment scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(EQUIPMENT_SCENE, -1)
	if change_error != OK:
		push_error("HeroBackpack: gagal membuka Equipment. Error code: " + str(change_error))

func _open_pavilion() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(PAVILION_SCENE):
		push_error("HeroBackpack: Pavilion scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(PAVILION_SCENE, 1)
	if change_error != OK:
		push_error("HeroBackpack: gagal membuka Pavilion. Error code: " + str(change_error))

func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	_return_to_journey()

func _return_to_journey() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error("HeroBackpack: Main Menu scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(MAIN_MENU_SCENE, -1)
	if change_error != OK:
		push_error("HeroBackpack: gagal kembali ke Journey. Error code: " + str(change_error))
