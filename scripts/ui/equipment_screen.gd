extends Control

## Hero / Equipment Hub
## Presentation layer only. EquipmentManager owns equipment state/save and
## InventoryManager owns item ownership/counts.
## Premium Polish Pass 6: commercial finish — stronger icon presentation, cleaner hero focus and unified modern card language.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const BACKPACK_SCENE: String = "res://scenes/ui/backpack_screen.tscn"
const EquipmentVisualCatalog = preload("res://scripts/ui/equipment_visual_catalog.gd")
const EquipmentSetCatalog = preload("res://scripts/data/equipment_set_catalog.gd")

const SLOT_ORDER: Array[String] = [
	"armament",
	"robe",
	"bracer",
	"pendant",
	"boots"
]

const COMPARISON_KEYS: Array[String] = [
	"max_health_flat",
	"damage_bonus",
	"movement_speed_bonus",
	"experience_bonus",
	"critical_chance_bonus",
	"critical_damage_bonus",
	"pickup_radius_bonus",
	"starting_shield_charges",
	"blood_qi_heal_bonus"
]

@onready var spirit_stone_label: Label = %SpiritStoneLabel
@onready var equipped_count_label: Label = %EquippedCountLabel
@onready var status_label: Label = %StatusLabel
@onready var bonus_summary_label: Label = %BonusSummaryLabel
@onready var stage_title: Label = $Content/HeroLoadoutPanel/HeroStage/StageTitle
@onready var hero_preview_sprite: AnimatedSprite2D = %HeroPreviewSprite
@onready var hero_menu_art: TextureRect = %HeroMenuArt
@onready var hero_ghost_sprite: AnimatedSprite2D = %HeroGhostSprite
@onready var hero_showcase_arch: TextureRect = %HeroShowcaseArch
@onready var cultivation_seal: TextureRect = %CultivationSeal
@onready var hero_showcase_halo: TextureRect = %HeroShowcaseHalo
@onready var hero_qi_particles: TextureRect = %HeroQiParticles
@onready var hero_pedestal: TextureRect = %HeroPedestal
@onready var armament_button: Button = %ArmamentButton
@onready var robe_button: Button = %RobeButton
@onready var bracer_button: Button = %BracerButton
@onready var pendant_button: Button = %PendantButton
@onready var boots_button: Button = %BootsButton
@onready var selected_slot_label: Label = %SelectedSlotLabel
@onready var equipped_item_label: Label = %EquippedItemLabel
@onready var selected_item_icon: TextureRect = %SelectedItemIcon
@onready var item_role_label: Label = %ItemRoleLabel
@onready var selected_stat_label: Label = %SelectedStatLabel
@onready var signature_effect_label: Label = %SignatureEffectLabel
@onready var ascension_status_label: Label = %AscensionStatusLabel
@onready var ascension_preview_label: Label = %AscensionPreviewLabel
@onready var ascend_button: Button = %AscendButton
@onready var ascend_hint_label: Label = %AscendHintLabel
@onready var compare_label: Label = %CompareLabel
@onready var candidate_grid: GridContainer = %CandidateGrid
@onready var action_button: Button = %ActionButton
@onready var action_hint_label: Label = %ActionHintLabel
@onready var backpack_tab_button: Button = %BackpackTabButton
@onready var detail_panel: PanelContainer = %DetailPanel
@onready var inspection_card: PanelContainer = %InspectionCard
@onready var signature_panel: PanelContainer = %SignaturePanel
@onready var ascension_panel: PanelContainer = %AscensionPanel
@onready var detail_close_button: Button = %DetailCloseButton

var selected_slot_id: String = "robe"
var selected_item_id: String = ""
var detail_open: bool = false

func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)
	armament_button.pressed.connect(_on_slot_pressed.bind("armament"))
	robe_button.pressed.connect(_on_slot_pressed.bind("robe"))
	bracer_button.pressed.connect(_on_slot_pressed.bind("bracer"))
	pendant_button.pressed.connect(_on_slot_pressed.bind("pendant"))
	boots_button.pressed.connect(_on_slot_pressed.bind("boots"))
	action_button.pressed.connect(_on_action_pressed)
	ascend_button.pressed.connect(_on_ascend_pressed)
	detail_close_button.pressed.connect(_close_detail)
	backpack_tab_button.pressed.connect(_open_backpack)
	if not EquipmentManager.equipment_changed.is_connected(_on_equipment_changed):
		EquipmentManager.equipment_changed.connect(_on_equipment_changed)
	if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
	if not EquipmentManager.equipment_ascended.is_connected(_on_equipment_ascended):
		EquipmentManager.equipment_ascended.connect(_on_equipment_ascended)
	selected_item_icon.custom_minimum_size = Vector2(90.0, 90.0)
	_setup_hero_showcase()
	bonus_summary_label.clip_text = true
	bonus_summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_refresh_screen()
	detail_panel.visible = detail_open
	DebugLogger.system(str("Hero Equipment Hub aktif!"))


func _setup_hero_showcase() -> void:
	# Keep the legacy AnimatedSprite2D node and idle_down contract for smoke/regression
	# compatibility, but the visible menu focal point is now dedicated high-resolution art.
	if hero_preview_sprite.sprite_frames != null and hero_preview_sprite.sprite_frames.has_animation(&"idle_down"):
		hero_preview_sprite.animation = &"idle_down"
		hero_preview_sprite.stop()
		hero_preview_sprite.frame = 0
	if hero_ghost_sprite.sprite_frames != null and hero_ghost_sprite.sprite_frames.has_animation(&"idle_down"):
		hero_ghost_sprite.animation = &"idle_down"
		hero_ghost_sprite.stop()
		hero_ghost_sprite.frame = 0
	call_deferred("_start_hero_showcase_motion")

func _start_hero_showcase_motion() -> void:
	hero_menu_art.pivot_offset = hero_menu_art.size * 0.5
	hero_showcase_arch.pivot_offset = hero_showcase_arch.size * 0.5
	cultivation_seal.pivot_offset = cultivation_seal.size * 0.5
	hero_showcase_halo.pivot_offset = hero_showcase_halo.size * 0.5
	hero_qi_particles.pivot_offset = hero_qi_particles.size * 0.5
	hero_pedestal.pivot_offset = hero_pedestal.size * 0.5

	var hero_base: Vector2 = hero_menu_art.position
	var particles_base: Vector2 = hero_qi_particles.position

	# Only a subtle breathing/hover loop. The hero should read as an illustration,
	# not as a gameplay actor moving inside the menu.
	var hero_motion: Tween = create_tween().set_loops()
	hero_motion.tween_property(hero_menu_art, "position", hero_base + Vector2(0.0, -2.0), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hero_motion.parallel().tween_property(hero_menu_art, "scale", Vector2(1.008, 1.008), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hero_motion.tween_property(hero_menu_art, "position", hero_base + Vector2(0.0, 1.0), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hero_motion.parallel().tween_property(hero_menu_art, "scale", Vector2.ONE, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var aura_motion: Tween = create_tween().set_loops()
	aura_motion.tween_property(cultivation_seal, "rotation", deg_to_rad(1.0), 4.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	aura_motion.parallel().tween_property(hero_showcase_halo, "rotation", deg_to_rad(-0.8), 4.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	aura_motion.parallel().tween_property(hero_qi_particles, "position", particles_base + Vector2(0.0, -3.0), 4.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	aura_motion.tween_property(cultivation_seal, "rotation", deg_to_rad(-1.0), 4.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	aura_motion.parallel().tween_property(hero_showcase_halo, "rotation", deg_to_rad(0.8), 4.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	aura_motion.parallel().tween_property(hero_qi_particles, "position", particles_base + Vector2(0.0, 2.0), 4.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var pedestal_motion: Tween = create_tween().set_loops()
	pedestal_motion.tween_property(hero_pedestal, "modulate", Color(1.0, 1.0, 1.0, 0.36), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pedestal_motion.tween_property(hero_pedestal, "modulate", Color(1.0, 1.0, 1.0, 0.52), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _refresh_screen() -> void:
	spirit_stone_label.text = "%d" % ProgressionManager.spirit_stone
	var can_modify: bool = EquipmentManager.can_modify_equipment()
	var has_checkpoint: bool = EquipmentManager.has_preserved_active_run_loadout()
	var equipped_count: int = _get_equipped_count()
	equipped_count_label.text = tr("EQUIPPED %d / %d") % [equipped_count, SLOT_ORDER.size()]
	if can_modify:
		if has_checkpoint:
			status_label.text = tr("NEXT RUN LOADOUT  •  CONTINUE KEEPS SAVED LOADOUT")
		else:
			status_label.text = tr("LOADOUT READY  •  SELECT A SLOT TO ATTUNE")
		hero_preview_sprite.modulate = Color.WHITE
		hero_menu_art.modulate = Color.WHITE
	else:
		status_label.text = tr("LOADOUT LOCKED  •  SAVE RECOVERY REQUIRED")
		hero_preview_sprite.modulate = Color(0.78, 0.86, 0.90, 0.92)
		hero_menu_art.modulate = Color(0.74, 0.82, 0.86, 0.90)
	stage_title.text = _build_set_stage_title()
	stage_title.tooltip_text = _build_set_tooltip()
	bonus_summary_label.text = _build_bonus_summary()
	bonus_summary_label.tooltip_text = _build_set_tooltip()
	_refresh_slot_button(armament_button, "armament")
	_refresh_slot_button(robe_button, "robe")
	_refresh_slot_button(bracer_button, "bracer")
	_refresh_slot_button(pendant_button, "pendant")
	_refresh_slot_button(boots_button, "boots")
	_validate_selected_item()
	_rebuild_candidate_grid()
	_refresh_detail_panel(can_modify)
	detail_panel.visible = detail_open

func _refresh_slot_button(button: Button, slot_id: String) -> void:
	var equipped_item_id: String = EquipmentManager.get_equipped_item_id(slot_id)
	var item_name: String = "EMPTY"
	var icon_texture: Texture2D = null
	var rarity_color: Color = Color(0.24, 0.78, 0.70, 1.0)
	var filled: bool = not equipped_item_id.is_empty()
	if filled:
		var item_data: Dictionary = EquipmentManager.get_item_data(equipped_item_id)
		item_name = str(item_data.get("display_name", equipped_item_id))
		icon_texture = _load_item_icon(equipped_item_id)
		rarity_color = EquipmentVisualCatalog.get_rarity_color(str(item_data.get("rarity", "common")))
	_clear_slot_overlays(button)
	button.text = "" if icon_texture != null else EquipmentVisualCatalog.get_slot_title(slot_id)
	button.icon = icon_texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 66)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 12)
	var selected: bool = detail_open and slot_id == selected_slot_id
	button.add_theme_stylebox_override("normal", _make_slot_style(selected, false, rarity_color, filled))
	button.add_theme_stylebox_override("hover", _make_slot_style(selected, true, rarity_color, filled))
	button.add_theme_stylebox_override("pressed", _make_slot_style(true, true, rarity_color, filled))
	button.add_theme_stylebox_override("focus", _make_slot_style(true, true, rarity_color, filled))
	_add_slot_caption(button, EquipmentVisualCatalog.get_slot_title(slot_id), filled, rarity_color)
	button.tooltip_text = ("%s — %s" % [item_name, EquipmentVisualCatalog.get_slot_role(slot_id)] if filled else "Empty %s slot" % EquipmentVisualCatalog.get_slot_title(slot_id).to_lower())

func _validate_selected_item() -> void:
	if selected_item_id.is_empty():
		return
	if EquipmentManager.has_item_definition(selected_item_id):
		return
	selected_item_id = ""
	detail_open = false

func _get_all_equipment_item_ids() -> Array[String]:
	var result: Array[String] = []
	for slot_id: String in SLOT_ORDER:
		for item_id: String in EquipmentManager.get_item_ids_for_slot(slot_id):
			if not result.has(item_id):
				result.append(item_id)
	return result

func _rebuild_candidate_grid() -> void:
	for child: Node in candidate_grid.get_children():
		child.queue_free()
	for item_id: String in _get_all_equipment_item_ids():
		candidate_grid.add_child(_create_candidate_button(item_id))

func _create_candidate_button(item_id: String) -> Button:
	var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
	var slot_id: String = str(item_data.get("slot", ""))
	var owned_count: int = InventoryManager.get_item_count(item_id)
	var equipped: bool = EquipmentManager.get_equipped_item_id(slot_id) == item_id
	var selected: bool = detail_open and item_id == selected_item_id
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(128.0, 122.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = null
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = ""
	var rarity_id: String = str(item_data.get("rarity", "common"))
	var rarity_color: Color = EquipmentVisualCatalog.get_rarity_color(rarity_id)
	_install_card_icon(button, _load_item_icon(item_id), rarity_color, owned_count > 0)
	button.add_theme_stylebox_override("normal", _make_candidate_style(rarity_color, equipped, selected, owned_count > 0, false))
	button.add_theme_stylebox_override("hover", _make_candidate_style(rarity_color, equipped, true, owned_count > 0, true))
	button.add_theme_stylebox_override("pressed", _make_candidate_style(rarity_color, equipped, true, owned_count > 0, true))
	button.add_theme_stylebox_override("focus", _make_candidate_style(rarity_color, equipped, true, owned_count > 0, true))
	_add_rarity_badge(button, rarity_id, rarity_color, owned_count > 0)
	_add_star_badge(button, EquipmentManager.get_item_star(item_id), owned_count > 0)
	if equipped:
		_add_state_badge(button, "E", Color(0.28, 1.0, 0.76, 1.0))
	button.pressed.connect(_on_candidate_pressed.bind(item_id))
	var effective_data: Dictionary = EquipmentManager.get_effective_item_data(item_id)
	button.tooltip_text = "%s\n%s  •  %s\n%s" % [str(item_data.get("display_name", item_id)), _format_stars(EquipmentManager.get_item_star(item_id)), EquipmentVisualCatalog.get_stat_summary(effective_data), EquipmentVisualCatalog.get_signature_effect_description(item_data)]
	return button


func _install_card_icon(parent_button: Button, texture: Texture2D, rarity_color: Color, owned: bool) -> void:
	var glow := PanelContainer.new()
	glow.name = "IconGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.anchor_left = 0.22
	glow.anchor_top = 0.14
	glow.anchor_right = 0.78
	glow.anchor_bottom = 0.72
	glow.add_theme_stylebox_override("panel", _make_icon_glow_style(rarity_color, owned))
	parent_button.add_child(glow)

	var art := TextureRect.new()
	art.name = "ItemArt"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.anchor_left = 0.22
	art.anchor_top = 0.10
	art.anchor_right = 0.78
	art.anchor_bottom = 0.70
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = Color.WHITE if owned else Color(0.62, 0.69, 0.71, 0.78)
	parent_button.add_child(art)

func _make_icon_glow_style(accent: Color, owned: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.34 if owned else 0.16)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.28 if owned else 0.16)
	style.corner_radius_top_left = 64
	style.corner_radius_top_right = 64
	style.corner_radius_bottom_left = 64
	style.corner_radius_bottom_right = 64
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.18 if owned else 0.07)
	style.shadow_size = 9 if owned else 4
	return style

func _make_slot_style(selected: bool, hovered: bool, rarity_color: Color, filled: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var base: Color = Color(0.003, 0.025, 0.038, 0.92)
	var tint: float = 0.26 if filled else 0.05
	style.bg_color = Color(base.r + rarity_color.r * tint, base.g + rarity_color.g * tint * 0.58, base.b + rarity_color.b * tint, 0.95)
	if hovered:
		style.bg_color = style.bg_color.lightened(0.10)
	var border_color: Color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.78 if filled else 0.32)
	if selected:
		border_color = Color(1.0, 0.77, 0.22, 1.0)
	style.border_width_left = 2 if selected else 1
	style.border_width_top = 2 if selected else 1
	style.border_width_right = 2 if selected else 1
	style.border_width_bottom = 3 if selected else 2
	style.border_color = border_color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 6.0
	style.content_margin_top = 6.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.30 if selected else 0.10)
	style.shadow_size = 10 if selected else 4
	return style

func _make_candidate_style(rarity_color: Color, equipped: bool, selected: bool, owned: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var base: Color = Color(0.003, 0.020, 0.034, 0.98)
	var tint_strength: float = 0.40 if owned else 0.055
	style.bg_color = Color(
		base.r + rarity_color.r * tint_strength,
		base.g + rarity_color.g * tint_strength * 0.66,
		base.b + rarity_color.b * tint_strength,
		0.98
	)
	if not owned:
		style.bg_color = Color(0.020, 0.032, 0.042, 0.96)
	if hovered:
		style.bg_color = style.bg_color.lightened(0.10)
	var border_color: Color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.68 if owned else 0.30)
	if equipped:
		border_color = Color(0.18, 1.0, 0.74, 1.0)
	if selected:
		border_color = Color(1.0, 0.76, 0.20, 1.0)
	var border_width: int = 2 if selected or equipped else 1
	style.border_width_left = border_width
	style.border_width_top = 2 if owned else 1
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 7.0
	style.content_margin_top = 9.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 9.0
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.28 if selected or equipped else 0.08)
	style.shadow_size = 9 if selected or equipped else 3
	return style

func _refresh_detail_panel(can_modify: bool) -> void:
	selected_slot_label.text = "%s  •  %s" % [
		tr(EquipmentVisualCatalog.get_slot_title(selected_slot_id)),
		tr(EquipmentVisualCatalog.get_slot_focus(selected_slot_id))
	]
	var equipped_item_id: String = EquipmentManager.get_equipped_item_id(selected_slot_id)
	if equipped_item_id.is_empty():
		equipped_item_label.text = tr("EQUIPPED  •  NONE")
	else:
		var equipped_data: Dictionary = EquipmentManager.get_effective_item_data(equipped_item_id)
		equipped_item_label.text = tr("EQUIPPED  •  %s  •  %s") % [
			str(equipped_data.get("display_name", equipped_item_id)),
			tr(str(equipped_data.get("rarity", "common")).to_upper())
		]

	if selected_item_id.is_empty():
		selected_item_icon.texture = null
		item_role_label.text = tr("NO EQUIPMENT")
		selected_stat_label.text = tr("No equipment definition is available for this slot.")
		signature_effect_label.text = tr("SIGNATURE EFFECT\nNone")
		compare_label.text = tr("LOADOUT IMPACT  •  NONE")
		ascension_status_label.text = tr("ASCENSION  •  NO ITEM")
		ascension_preview_label.text = ""
		ascend_button.text = tr("ASCENSION LOCKED")
		ascend_button.disabled = true
		ascend_hint_label.text = ""
		action_button.text = tr("NO ITEM AVAILABLE")
		action_button.disabled = true
		action_hint_label.text = ""
		return

	var selected_base_data: Dictionary = EquipmentManager.get_item_data(selected_item_id)
	var selected_data: Dictionary = EquipmentManager.get_effective_item_data(selected_item_id)
	var selected_star: int = EquipmentManager.get_item_star(selected_item_id)
	var rarity_id: String = str(selected_data.get("rarity", "common"))
	_apply_detail_rarity_style(EquipmentVisualCatalog.get_rarity_color(rarity_id))
	selected_item_icon.texture = _load_item_icon(selected_item_id)
	item_role_label.text = str(selected_data.get("display_name", selected_item_id))
	var selected_set_id: String = EquipmentSetCatalog.get_set_id_for_item(selected_item_id)
	var selected_set_name: String = EquipmentSetCatalog.get_display_name(selected_set_id)
	selected_stat_label.text = "%s  •  %s  •  %s\nCORE  %s" % [
		tr(rarity_id.to_upper()),
		_format_stars(selected_star),
		tr(selected_set_name) if not selected_set_name.is_empty() else tr(EquipmentVisualCatalog.get_slot_role(selected_slot_id)),
		_get_item_stat_text(selected_data)
	]
	item_role_label.add_theme_color_override("font_color", EquipmentVisualCatalog.get_rarity_color(rarity_id))
	signature_effect_label.text = "%s — %s\n%s" % [
		tr("SIGNATURE"),
		tr(EquipmentVisualCatalog.get_signature_effect_name(selected_base_data)),
		tr(EquipmentVisualCatalog.get_signature_effect_description(selected_base_data))
	]
	compare_label.text = _build_loadout_impact(equipped_item_id, selected_item_id)
	_refresh_ascension_controls(can_modify)

	var is_equipped: bool = equipped_item_id == selected_item_id
	var has_checkpoint: bool = EquipmentManager.has_preserved_active_run_loadout()
	if not can_modify:
		action_button.text = tr("LOADOUT LOCKED")
		action_button.disabled = true
		action_hint_label.text = tr("Resolve save recovery before changing equipment.")
	elif is_equipped:
		action_button.text = tr("UNEQUIP")
		action_button.disabled = false
		action_hint_label.text = (
			tr("Saved for NEXT RUN. Continue keeps the checkpoint loadout.")
			if has_checkpoint
			else tr("Remove this item from the permanent loadout.")
		)
	elif not InventoryManager.owns_item(selected_item_id):
		action_button.text = tr("ITEM NOT OWNED")
		action_button.disabled = true
		action_hint_label.text = tr("Inspect it here; forge or acquire it before equipping.")
	else:
		action_button.text = tr("EQUIP ITEM")
		action_button.disabled = false
		action_hint_label.text = (
			tr("Saved for NEXT RUN. Continue keeps the checkpoint loadout.")
			if has_checkpoint
			else tr("Applies to the next journey and saves permanently.")
		)

func _build_loadout_impact(equipped_item_id: String, inspected_item_id: String) -> String:
	if inspected_item_id.is_empty():
		return tr("LOADOUT IMPACT  •  NONE")
	if equipped_item_id == inspected_item_id:
		return tr("CURRENT LOADOUT  •  EQUIPPED")
	var inspected_data: Dictionary = EquipmentManager.get_effective_item_data(inspected_item_id)
	if equipped_item_id.is_empty():
		return tr("LOADOUT IMPACT  •  EQUIP TO APPLY %s") % _get_item_stat_text(inspected_data).to_upper()
	var equipped_data: Dictionary = EquipmentManager.get_effective_item_data(equipped_item_id)
	var deltas: Array[String] = []
	for stat_key: String in COMPARISON_KEYS:
		var old_value: float = float(equipped_data.get(stat_key, 0.0))
		var new_value: float = float(inspected_data.get(stat_key, 0.0))
		var delta: float = new_value - old_value
		if is_zero_approx(delta):
			continue
		deltas.append(_format_stat_delta(stat_key, delta))
	if deltas.is_empty():
		return tr("COMPARISON  •  NO STAT CHANGE")
	return tr("COMPARISON  •  %s") % "  •  ".join(deltas)

func _format_stat_delta(stat_key: String, delta: float) -> String:
	var prefix: String = "+" if delta > 0.0 else ""
	match stat_key:
		"max_health_flat": return "%s%.0f HP" % [prefix, delta]
		"damage_bonus": return "%s%.1f%% DMG" % [prefix, delta * 100.0]
		"movement_speed_bonus": return "%s%.1f%% MOVE" % [prefix, delta * 100.0]
		"experience_bonus": return "%s%.1f%% EXP" % [prefix, delta * 100.0]
		"critical_chance_bonus": return "%s%.1f%% CRIT" % [prefix, delta * 100.0]
		"critical_damage_bonus": return "%s%.1f%% CRIT DMG" % [prefix, delta * 100.0]
		"pickup_radius_bonus": return "%s%.0f PICKUP" % [prefix, delta]
		"starting_shield_charges": return "%s%.0f SHIELD" % [prefix, delta]
		"blood_qi_heal_bonus": return "%s%.2f BLOOD QI" % [prefix, delta]
		_: return "%s%.2f" % [prefix, delta]

func _refresh_ascension_controls(can_modify: bool) -> void:
	if selected_item_id.is_empty() or not EquipmentManager.has_item_definition(selected_item_id):
		ascension_status_label.text = tr("NO ASCENSION DATA")
		ascension_preview_label.text = ""
		ascend_button.text = tr("ASCENSION LOCKED")
		ascend_button.disabled = true
		ascend_hint_label.text = ""
		return
	var current_star: int = EquipmentManager.get_item_star(selected_item_id)
	var shard_balance: int = InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD)
	if not InventoryManager.owns_item(selected_item_id):
		ascension_status_label.text = "%s  →  ?" % _format_stars(current_star)
		ascension_preview_label.text = tr("Acquire this equipment to unlock ascension.")
		ascend_button.text = tr("ASCENSION LOCKED")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Core passives scale with stars; Signature Effects stay fixed.")
		return
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
	if not can_modify:
		ascend_button.text = tr("ASCENSION LOCKED")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Resolve save recovery before ascending equipment.")
	elif shard_balance < cost:
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Need %d more Refinement Shards.") % (cost - shard_balance)
	else:
		ascend_button.disabled = false
		ascend_hint_label.text = (
			tr("Ascension saves for NEXT RUN; Continue keeps the checkpoint stars.")
			if EquipmentManager.has_preserved_active_run_loadout()
			else tr("Core passive increases. Signature Effect remains unchanged.")
		)

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

func _add_star_badge(parent_button: Button, star: int, owned: bool) -> void:
	var badge: Label = Label.new()
	badge.name = "StarBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.0
	badge.anchor_top = 1.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = 5.0
	badge.offset_top = -25.0
	badge.offset_right = -5.0
	badge.offset_bottom = -4.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_constant_override("outline_size", 2)
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.22, 1.0) if owned else Color(0.46, 0.52, 0.54, 0.72))
	badge.text = _format_stars(star)
	parent_button.add_child(badge)

func _add_state_badge(parent_button: Button, text_value: String, color: Color) -> void:
	var badge: Label = Label.new()
	badge.name = "StateBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.72
	badge.anchor_top = 0.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 0.0
	badge.offset_left = 0.0
	badge.offset_top = 8.0
	badge.offset_right = -9.0
	badge.offset_bottom = 28.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_constant_override("outline_size", 2)
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	badge.add_theme_color_override("font_color", color)
	badge.text = text_value
	parent_button.add_child(badge)

func _clear_slot_overlays(button: Button) -> void:
	for child_name: String in ["SlotCaption", "SlotJewel"]:
		var child: Node = button.get_node_or_null(child_name)
		if child != null: child.free()

func _add_slot_caption(button: Button, slot_title: String, filled: bool, rarity_color: Color) -> void:
	var caption: Label = Label.new()
	caption.name = "SlotCaption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.anchor_left = 0.0; caption.anchor_top = 1.0; caption.anchor_right = 1.0; caption.anchor_bottom = 1.0
	caption.offset_left = 4.0; caption.offset_top = -22.0; caption.offset_right = -4.0; caption.offset_bottom = -3.0
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 9)
	caption.add_theme_constant_override("outline_size", 2)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.86))
	caption.add_theme_color_override("font_color", rarity_color.lightened(0.24) if filled else Color(0.65, 0.82, 0.80, 0.92))
	caption.text = tr(slot_title)
	button.add_child(caption)

func _add_rarity_badge(parent_button: Button, _rarity_id: String, color: Color, owned: bool) -> void:
	var stripe := ColorRect.new()
	stripe.name = "RarityBadge"
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.anchor_left = 0.18
	stripe.anchor_top = 0.0
	stripe.anchor_right = 0.82
	stripe.anchor_bottom = 0.0
	stripe.offset_top = 5.0
	stripe.offset_bottom = 8.0
	stripe.color = Color(color.r, color.g, color.b, 0.95 if owned else 0.25)
	parent_button.add_child(stripe)

func _apply_detail_rarity_style(rarity_color: Color) -> void:
	detail_panel.add_theme_stylebox_override("panel", _make_detail_surface(rarity_color, 0.98, 14))
	inspection_card.add_theme_stylebox_override("panel", _make_detail_surface(rarity_color, 0.88, 8))
	signature_panel.add_theme_stylebox_override("panel", _make_detail_surface(rarity_color, 0.72, 6))
	ascension_panel.add_theme_stylebox_override("panel", _make_detail_surface(Color(0.96, 0.72, 0.20, 1.0), 0.82, 8))

func _make_detail_surface(accent: Color, opacity: float, glow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.003 + accent.r * 0.055, 0.018 + accent.g * 0.035, 0.030 + accent.b * 0.055, opacity)
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	style.corner_radius_top_left = 14; style.corner_radius_top_right = 14; style.corner_radius_bottom_left = 14; style.corner_radius_bottom_right = 14
	style.content_margin_left = 12.0; style.content_margin_top = 9.0; style.content_margin_right = 12.0; style.content_margin_bottom = 9.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
	style.shadow_size = glow
	return style

func _load_item_icon(item_id: String) -> Texture2D:
	var icon_path: String = EquipmentVisualCatalog.get_icon_path(item_id)
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	var icon_resource: Resource = ResourceLoader.load(icon_path)
	if icon_resource is Texture2D:
		return icon_resource as Texture2D
	return null

func _build_bonus_summary() -> String:
	var parts: Array[String] = []
	var hp_bonus: float = EquipmentManager.get_loadout_total_max_health_bonus()
	var damage_bonus: float = (EquipmentManager.get_loadout_damage_multiplier() - 1.0) * 100.0
	var move_bonus: float = (EquipmentManager.get_loadout_movement_speed_multiplier() - 1.0) * 100.0
	var exp_bonus: float = (EquipmentManager.get_loadout_experience_multiplier() - 1.0) * 100.0
	var crit_bonus: float = EquipmentManager.get_loadout_critical_chance_bonus() * 100.0
	if hp_bonus != 0.0: parts.append("+%.0f HP" % hp_bonus)
	if damage_bonus != 0.0: parts.append("+%.0f%% DMG" % damage_bonus)
	if move_bonus != 0.0: parts.append("+%.0f%% MOVE" % move_bonus)
	if exp_bonus != 0.0: parts.append("+%.0f%% EXP" % exp_bonus)
	if crit_bonus != 0.0: parts.append("+%.0f%% CRIT" % crit_bonus)
	return tr("NO ACTIVE LOADOUT BONUSES") if parts.is_empty() else "  •  ".join(parts)


func _build_set_stage_title() -> String:
	var set_state: Dictionary = _get_dominant_set_state()
	var set_id: String = str(set_state.get("set_id", ""))
	var piece_count: int = int(set_state.get("piece_count", 0))
	if set_id.is_empty() or piece_count <= 0:
		return tr("JADE LOADOUT")
	return "%s  •  %d/5" % [
		tr(EquipmentSetCatalog.get_display_name(set_id)),
		piece_count
	]


func _get_equipped_item_ids() -> Array[String]:
	var equipped_ids: Array[String] = []
	for slot_id: String in SLOT_ORDER:
		var item_id: String = EquipmentManager.get_equipped_item_id(slot_id)
		if not item_id.is_empty():
			equipped_ids.append(item_id)
	return equipped_ids


func _get_dominant_set_state() -> Dictionary:
	return EquipmentSetCatalog.get_dominant_set_state(_get_equipped_item_ids())


func _build_set_tooltip() -> String:
	var set_state: Dictionary = _get_dominant_set_state()
	var set_id: String = str(set_state.get("set_id", ""))
	var piece_count: int = int(set_state.get("piece_count", 0))
	if set_id.is_empty() or piece_count <= 0:
		return tr("No equipment set is currently attuned.")

	var equipped_ids: Array[String] = _get_equipped_item_ids()
	var active_names: Array[String] = []
	var missing_names: Array[String] = []

	for item_id: String in EquipmentSetCatalog.get_active_piece_ids(set_id, equipped_ids):
		var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
		active_names.append(str(item_data.get("display_name", item_id)))

	for item_id: String in EquipmentSetCatalog.get_missing_piece_ids(set_id, equipped_ids):
		var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
		missing_names.append(str(item_data.get("display_name", item_id)))

	var active_text: String = ", ".join(active_names) if not active_names.is_empty() else tr("None")
	var missing_text: String = ", ".join(missing_names) if not missing_names.is_empty() else tr("None")
	return "%s  %d/5  •  %s\\n%s: %s\\n%s: %s" % [
		tr(EquipmentSetCatalog.get_display_name(set_id)),
		piece_count,
		tr(EquipmentSetCatalog.get_resonance_label(piece_count)),
		tr("ACTIVE"),
		active_text,
		tr("MISSING"),
		missing_text
	]

func _get_equipped_count() -> int:
	var count: int = 0
	for slot_id: String in SLOT_ORDER:
		if not EquipmentManager.get_equipped_item_id(slot_id).is_empty():
			count += 1
	return count

func _get_item_stat_text(item_data: Dictionary) -> String:
	return EquipmentVisualCatalog.get_stat_summary(item_data)

func _on_slot_pressed(slot_id: String) -> void:
	if not SLOT_ORDER.has(slot_id): return
	selected_slot_id = slot_id
	selected_item_id = EquipmentManager.get_equipped_item_id(slot_id)
	detail_open = not selected_item_id.is_empty()
	_refresh_screen()

func _on_candidate_pressed(item_id: String) -> void:
	if not EquipmentManager.has_item_definition(item_id): return
	var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
	selected_slot_id = str(item_data.get("slot", selected_slot_id))
	selected_item_id = item_id
	detail_open = true
	_refresh_screen()

func _close_detail() -> void:
	detail_open = false
	_refresh_screen()

func _on_action_pressed() -> void:
	if selected_item_id.is_empty(): return
	if not EquipmentManager.can_modify_equipment():
		_refresh_screen()
		return
	var equipped_item_id: String = EquipmentManager.get_equipped_item_id(selected_slot_id)
	if equipped_item_id == selected_item_id:
		EquipmentManager.unequip_slot(selected_slot_id)
	else:
		EquipmentManager.equip_item(selected_item_id)

func _on_ascend_pressed() -> void:
	if selected_item_id.is_empty(): return
	if EquipmentManager.ascend_item(selected_item_id): _refresh_screen()

func _on_equipment_ascended(item_id: String, _old_star: int, _new_star: int) -> void:
	if item_id == selected_item_id: _refresh_screen()

func _on_equipment_changed(_slot_id: String, _item_id: String) -> void:
	_refresh_screen()

func _on_inventory_changed(_item_id: String, _new_count: int) -> void:
	_refresh_screen()

func _open_backpack() -> void:
	if SceneTransitionManager.is_transitioning: return
	if not ResourceLoader.exists(BACKPACK_SCENE):
		push_error("HeroEquipment: Backpack scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(BACKPACK_SCENE, 1)
	if change_error != OK:
		push_error("HeroEquipment: gagal membuka Backpack. Error code: " + str(change_error))

func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning: return
	_return_to_journey()

func _return_to_journey() -> void:
	if SceneTransitionManager.is_transitioning: return
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error("HeroEquipment: Main Menu scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(MAIN_MENU_SCENE, -1)
	if change_error != OK:
		push_error("HeroEquipment: gagal kembali ke Journey. Error code: " + str(change_error))
