extends Control

## Jade Pavilion — premium offline preparation hub.
## Gameplay authority remains in PavilionManager / EquipmentManager / InventoryManager.

const EquipmentVisualCatalog = preload("res://scripts/ui/equipment_visual_catalog.gd")

var content: VBoxContainer
var balance: Label
var status: Label
var chest: Button
var equipment_list: GridContainer
var rarity_filter: OptionButton
var cosmetic_buttons: Dictionary = {}

func _ready() -> void:
	content = $SafeArea/Scroll/Content
	SceneTransitionManager.set_back_handler(_back)
	_configure_backdrop()
	_build_screen()
	PavilionManager.pavilion_changed.connect(_refresh)
	_refresh()

func _configure_backdrop() -> void:
	var backdrop: Control = $Backdrop
	if backdrop != null and backdrop.has_method("apply_profile"):
		backdrop.call("apply_profile", {
			"sky_top": Color(0.002, 0.014, 0.026, 1.0),
			"sky_bottom": Color(0.008, 0.055, 0.062, 1.0),
			"mountain_far": Color(0.020, 0.105, 0.104, 0.82),
			"mountain_near": Color(0.006, 0.050, 0.055, 0.96),
			"mist": Color(0.25, 0.86, 0.75, 0.09),
			"moon": Color(0.98, 0.82, 0.42, 0.08),
			"accent": Color(0.30, 0.94, 0.80, 1.0),
			"gold": Color(0.98, 0.79, 0.34, 1.0)
		})

func _build_screen() -> void:
	for child: Node in content.get_children():
		child.queue_free()

	var hero: PanelContainer = _panel(content, _panel_style(Color(0.30, 0.94, 0.80), true))
	var hero_box: VBoxContainer = VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 3)
	hero.add_child(hero_box)
	_label(hero_box, tr("JADE PAVILION"), 10, Color(0.34, 0.94, 0.80))
	_label(hero_box, tr("Sanctum of Refinement"), 25, Color(1.0, 0.84, 0.43))
	_label(hero_box, tr("Meditate • Attune aura • Forge permanent equipment"), 11, Color(0.66, 0.76, 0.73))
	balance = _label(hero_box, "", 16, Color(0.96, 0.81, 0.42))

	status = _label(content, "", 12, Color(0.58, 0.92, 0.78))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var meditation: VBoxContainer = _card(
		content,
		tr("DAILY RESONANCE"),
		tr("Meditation"),
		tr("A quiet breath grants 20 Spirit Stones once per local day."),
		Color(0.36, 0.90, 0.78)
	)
	chest = _button(meditation, tr("MEDITATE  •  +20 SPIRIT STONES"), _meditate, true)

	var cosmetics: VBoxContainer = _card(
		content,
		tr("COSMETIC ATTUNEMENT"),
		tr("Cultivation Auras"),
		tr("Realm-clear auras are free. Postgame prestige auras use earned currencies only and never add combat power."),
		Color(0.70, 0.55, 0.96)
	)
	var aura_grid: GridContainer = GridContainer.new()
	aura_grid.columns = 2
	aura_grid.add_theme_constant_override("h_separation", 8)
	aura_grid.add_theme_constant_override("v_separation", 8)
	cosmetics.add_child(aura_grid)
	for raw_id in PavilionManager.COSMETICS:
		var cosmetic_id: String = str(raw_id)
		cosmetic_buttons[cosmetic_id] = _button(aura_grid, "", _select_cosmetic.bind(cosmetic_id), false)

	var forge: VBoxContainer = _card(
		content,
		tr("PERMANENT LOADOUT"),
		tr("Equipment Forge"),
		tr("Repeat clears and duplicate equipment provide Refinement Shards for forging."),
		Color(0.98, 0.79, 0.34)
	)
	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	forge.add_child(filter_row)
	var filter_label: Label = _label(filter_row, tr("RARITY"), 10, Color(0.56, 0.72, 0.69))
	filter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_filter = OptionButton.new()
	rarity_filter.custom_minimum_size = Vector2(176.0, 42.0)
	for rarity: String in ["common", "rare", "epic", "legendary"]:
		rarity_filter.add_item(tr(rarity.capitalize()))
	filter_row.add_child(rarity_filter)
	rarity_filter.item_selected.connect(_on_rarity_selected)

	equipment_list = GridContainer.new()
	equipment_list.columns = 2
	equipment_list.add_theme_constant_override("h_separation", 8)
	equipment_list.add_theme_constant_override("v_separation", 8)
	forge.add_child(equipment_list)

	var about: VBoxContainer = _card(
		content,
		tr("PLAYER-FIRST EDITION"),
		tr("Offline by Design"),
		tr("All equipment is earned through play. This build has no ads, account requirement, or real-money purchases."),
		Color(0.38, 0.76, 0.96)
	)
	_button(about, tr("PRIVACY & SUPPORT"), _open_privacy, false)

func _refresh() -> void:
	balance.text = tr("%d Spirit Stones  •  %d Refinement Shards") % [
		ProgressionManager.spirit_stone,
		InventoryManager.get_item_count("refinement_shard")
	]
	chest.disabled = not PavilionManager.can_claim_meditation()
	chest.text = tr("MEDITATED TODAY") if chest.disabled else tr("MEDITATE  •  +20 SPIRIT STONES")
	for raw_id in cosmetic_buttons:
		_refresh_cosmetic_button(str(raw_id))
	_rebuild_equipment()
	if SaveManager.is_progress_read_only():
		status.text = tr("SAVE RECOVERY REQUIRED  •  REOPEN THE GAME BEFORE CHANGING LOADOUT")
	elif not EquipmentManager.can_modify_equipment():
		status.text = tr("FORGE SEALED  •  FINISH THE ACTIVE RUN TO MODIFY PERMANENT EQUIPMENT")
	else:
		status.text = tr("SANCTUM READY  •  PERMANENT PROGRESSION IS SAFE")

func _rebuild_equipment() -> void:
	for child: Node in equipment_list.get_children():
		child.queue_free()
	var rarity: String = ["common", "rare", "epic", "legendary"][rarity_filter.selected]
	for item_id: String in EquipmentManager.get_item_ids():
		var data: Dictionary = EquipmentManager.get_item_data(item_id)
		if str(data["rarity"]) != rarity:
			continue
		equipment_list.add_child(_create_equipment_card(item_id, data))

func _create_equipment_card(item_id: String, data: Dictionary) -> PanelContainer:
	var rarity_color: Color = EquipmentVisualCatalog.get_rarity_color(str(data.get("rarity", "common")))
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 188.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(rarity_color, false))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	var icon: TextureRect = TextureRect.new()
	icon.texture = load(EquipmentVisualCatalog.get_icon_path(item_id)) as Texture2D
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	var name_label: Label = _label(box, tr(str(data["display_name"])), 13, Color(0.92, 0.95, 0.93))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var meta: Label = _label(
		box,
		"%s  •  %s" % [
			tr(str(data["rarity"]).capitalize()).to_upper(),
			tr(EquipmentVisualCatalog.get_slot_title(str(data["slot"])))
		],
		9,
		rarity_color
	)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stat: Label = _label(box, EquipmentVisualCatalog.get_stat_summary(data), 10, Color(0.68, 0.80, 0.77))
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if data.has("signature_effect_description"):
		var signature: Label = _label(box, tr(str(data["signature_effect_description"])), 9, Color(0.72, 0.66, 0.92))
		signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if InventoryManager.owns_item(item_id):
		var owned: Label = _label(box, tr("OWNED  •  EQUIP FROM HERO"), 9, Color(0.42, 0.92, 0.75))
		owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif not PavilionManager.is_item_unlocked(item_id):
		var requirement: Dictionary = PavilionManager.get_item_unlock_requirement(item_id)
		var required_chapter := int(requirement.get("chapter_id", 0))
		var required_stage := int(requirement.get("stage_id", 0))
		var locked: Label = _label(
			box,
			tr("LOCKED  •  CLEAR %d-%d") % [required_chapter, required_stage],
			9,
			Color(0.54, 0.61, 0.61)
		)
		locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var buy: Button = _button(box, tr("%d STONES") % int(data["price"]), _buy.bind(item_id, false), false)
		var forge: Button = _button(box, tr("%d SHARDS") % int(data["forge_cost"]), _buy.bind(item_id, true), false)
		var sealed: bool = not EquipmentManager.can_modify_equipment() or SaveManager.is_progress_read_only()
		buy.disabled = sealed or ProgressionManager.spirit_stone < int(data["price"])
		forge.disabled = sealed or InventoryManager.get_item_count("refinement_shard") < int(data["forge_cost"])
	return card

func _meditate() -> void:
	status.text = tr("Meditation complete. +20 Spirit Stones.") if PavilionManager.claim_meditation() else tr(PavilionManager.last_error)
	_refresh()

func _refresh_cosmetic_button(cosmetic_id: String) -> void:
	var button: Button = cosmetic_buttons[cosmetic_id]
	var definition: Dictionary = PavilionManager.get_cosmetic_data(cosmetic_id)
	var unlocked: bool = PavilionManager.is_cosmetic_unlocked(cosmetic_id)
	var owned: bool = PavilionManager.is_cosmetic_owned(cosmetic_id)
	var current: bool = PavilionManager.get_cosmetic_id() == cosmetic_id
	var cost: Dictionary = PavilionManager.get_cosmetic_cost(cosmetic_id)
	var stone_cost: int = int(cost.get("spirit_stone", 0))
	var shard_cost: int = int(cost.get("refinement_shard", 0))
	button.text = tr(str(definition.get("name", cosmetic_id)))
	button.disabled = false
	if not unlocked:
		var required_cosmetic: String = str(definition.get("requires_cosmetic", ""))
		if not PavilionManager.is_cosmetic_stage_unlocked(cosmetic_id):
			button.text += "\n" + (tr("CLEAR %d-%d") % [int(definition.get("chapter", 1)), int(definition.get("stage", 0))])
		elif not required_cosmetic.is_empty() and not PavilionManager.is_cosmetic_owned(required_cosmetic):
			var required_data: Dictionary = PavilionManager.get_cosmetic_data(required_cosmetic)
			button.text += "\n" + (tr("REQUIRES %s") % tr(str(required_data.get("name", required_cosmetic))))
		button.disabled = true
	elif owned:
		button.text += "\n" + (tr("ATTUNED  ✓") if current else tr("OWNED  •  ATTUNE"))
	else:
		button.text += "\n" + (tr("%d STONES + %d SHARDS") % [stone_cost, shard_cost])
		button.disabled = (
			SaveManager.is_progress_read_only()
			or ProgressionManager.spirit_stone < stone_cost
			or InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD) < shard_cost
		)

func _select_cosmetic(cosmetic_id: String) -> void:
	var cost: Dictionary = PavilionManager.get_cosmetic_cost(cosmetic_id)
	var paid: bool = int(cost.get("spirit_stone", 0)) > 0 or int(cost.get("refinement_shard", 0)) > 0
	var success: bool = false
	if not PavilionManager.is_cosmetic_owned(cosmetic_id) and paid:
		success = PavilionManager.acquire_cosmetic(cosmetic_id)
		status.text = tr("Aura acquired and attuned.") if success else tr(PavilionManager.last_error)
	else:
		success = PavilionManager.select_cosmetic(cosmetic_id)
		status.text = tr("Aura attuned.") if success else tr(PavilionManager.last_error)
	_refresh()

func _buy(item_id: String, use_shards: bool) -> void:
	if PavilionManager.acquire_equipment(item_id, use_shards):
		status.text = tr("Equipment acquired. Open Hero to equip it.")
	else:
		status.text = PavilionManager.last_error
	_refresh()

func _on_rarity_selected(_index: int) -> void:
	_rebuild_equipment()

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

func _label(parent_node: Node, value: String, font_size: int = 16, tint: Color = Color(0.78, 0.85, 0.8)) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent_node.add_child(label)
	return label

func _button(parent_node: Node, value: String, callback: Callable, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = value
	button.custom_minimum_size.y = 40.0 if not primary else 46.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11 if not primary else 13)
	button.theme_type_variation = &"JadePrimaryButton" if primary else &"JadeSecondaryButton"
	button.pressed.connect(callback)
	parent_node.add_child(button)
	return button

func _card(parent_node: Node, eyebrow: String, title: String, description: String, accent: Color) -> VBoxContainer:
	var panel: PanelContainer = _panel(parent_node, _panel_style(accent, false))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_label(box, eyebrow, 10, Color(accent.r, accent.g, accent.b, 0.92))
	_label(box, title, 20, Color(0.98, 0.84, 0.45))
	_label(box, description, 12, Color(0.67, 0.77, 0.74))
	return box

func _panel(parent_node: Node, style: StyleBoxFlat) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	parent_node.add_child(panel)
	return panel

func _panel_style(accent: Color, hero: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.024, 0.036, 0.88 if not hero else 0.94)
	style.border_width_left = 2 if hero else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.52 if not hero else 0.74)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 4
	return style
