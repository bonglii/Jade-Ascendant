extends Control

## Hero / Equipment Hub
## Presentation layer only. EquipmentManager owns equipment state/save and
## InventoryManager owns item ownership/counts.
## Hero Full Redesign: portrait-first loadout board + compact arsenal + scroll-safe relic inspection.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const BACKPACK_SCENE: String = "res://scenes/ui/backpack_screen.tscn"
const EquipmentVisualCatalog = preload("res://scripts/ui/equipment_visual_catalog.gd")
const EquipmentSetCatalog = preload("res://scripts/data/equipment_set_catalog.gd")
const DETAIL_RELIC_BACKDROP: Texture2D = preload("res://assets/ui/equipment/polish/relic_vault_backdrop.svg")

const SLOT_ORDER: Array[String] = [
	"armament",
	"robe",
	"bracer",
	"pendant",
	"boots"
]

const SLOT_PLACEHOLDER_TEXTURES: Dictionary = {
	"armament": preload("res://assets/ui/pavilion/icons/slot_armament.png"),
	"robe": preload("res://assets/ui/pavilion/icons/slot_robe.png"),
	"bracer": preload("res://assets/ui/pavilion/icons/slot_bracer.png"),
	"pendant": preload("res://assets/ui/pavilion/icons/slot_pendant.png"),
	"boots": preload("res://assets/ui/pavilion/icons/slot_boots.png"),
}

const SLOT_CAPTION_TEXTS: Dictionary = {
	"armament": "SENJATA",
	"robe": "JUBAH",
	"bracer": "LENGAN",
	"pendant": "LIONTIN",
	"boots": "SEPATU",
}

const FILTER_ALL: String = "all"
const FILTER_OWNED: String = "owned"
const FILTER_MISSING: String = "missing"
const CANDIDATE_BUILD_BATCH_SIZE: int = 6

const FILTER_ORDER: Array[String] = [
	FILTER_ALL,
	FILTER_OWNED,
	FILTER_MISSING
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
@onready var candidate_scroll: ScrollContainer = %CandidateScroll
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
var active_collection_filter: String = FILTER_OWNED
var collection_filter_buttons: Dictionary = {}
var collection_filter_count_label: Label
var collection_filter_empty_label: Label
var collection_showcase_panel: PanelContainer
var collection_progress_fill: ColorRect
var collection_progress_label: Label
var collection_resonance_label: Label
var collection_identity_label: Label
var collection_next_bonus_label: Label
var detail_resonance_label: Label
var ascension_star_track: HBoxContainer
var detail_rarity_line: ColorRect
var detail_last_visible: bool = false
var candidate_rebuild_generation: int = 0

func _ready() -> void:
	var startup_started_at: int = Time.get_ticks_msec()
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
	selected_item_icon.custom_minimum_size = Vector2(86.0, 86.0)
	selected_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Commercial portrait layout: dense enough to feel like an equipment game,
	# but still large enough for Jade Ascendant item artwork and names.
	candidate_grid.columns = 3
	candidate_grid.add_theme_constant_override("h_separation", 8)
	candidate_grid.add_theme_constant_override("v_separation", 8)
	_setup_hero_showcase()
	_apply_mobile_readability_polish()
	DebugLogger.system(str("Hero Equipment Hub aktif!"))
	_finish_initial_equipment_setup.call_deferred(startup_started_at)


func _apply_mobile_readability_polish() -> void:
	# Scene owns geometry. This script only owns readable text and dynamic content.
	# Keeping one layout authority prevents the anchor/offset conflicts that caused
	# the previous portrait regressions.
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stage_title.add_theme_font_size_override("font_size", 11)
	equipped_count_label.add_theme_font_size_override("font_size", 13)
	equipped_count_label.custom_minimum_size.y = 22.0

	bonus_summary_label.add_theme_font_size_override("font_size", 11)
	bonus_summary_label.clip_text = false
	bonus_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_summary_label.max_lines_visible = 2
	bonus_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bonus_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var detail_font_sizes: Dictionary = {
		selected_slot_label: 12,
		equipped_item_label: 9,
		item_role_label: 15,
		selected_stat_label: 10,
		signature_effect_label: 10,
		ascension_status_label: 10,
		ascension_preview_label: 9,
		action_hint_label: 8,
		ascend_hint_label: 8,
		compare_label: 9,
	}
	for label_variant: Variant in detail_font_sizes.keys():
		var label := label_variant as Label
		if label == null:
			continue
		label.add_theme_font_size_override(
			"font_size",
			int(detail_font_sizes[label_variant])
		)
		label.add_theme_constant_override("line_spacing", 1)
		if label in [
			selected_slot_label,
			equipped_item_label,
			selected_stat_label,
			signature_effect_label,
			ascension_preview_label,
			compare_label
		]:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.clip_text = false

	candidate_grid.columns = 3
	candidate_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidate_grid.custom_minimum_size.x = 0.0
	candidate_grid.add_theme_constant_override("h_separation", 8)
	candidate_grid.add_theme_constant_override("v_separation", 8)


func _finish_initial_equipment_setup(startup_started_at: int) -> void:
	# Let the new scene become visible before constructing collection/detail
	# chrome. Candidate cards are already populated in small frame batches.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_setup_collection_filter()
	_setup_detail_premium_presentation()
	_refresh_screen()
	_audit_runtime_layout.call_deferred()
	DebugLogger.system(str(
		"Hero Equipment staged init selesai | ",
		Time.get_ticks_msec() - startup_started_at,
		" ms"
	))


func _audit_runtime_layout() -> void:
	if not OS.is_debug_build() or not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return

	var hero_stage := stage_title.get_parent() as Control
	if hero_stage == null:
		push_warning("HeroLayoutQA: HeroStage missing.")
		return
	var stage_rect := Rect2(Vector2.ZERO, hero_stage.size)
	var slot_controls: Array[Control] = [robe_button, pendant_button, armament_button, bracer_button, boots_button]
	var reference_slot_size: Vector2 = slot_controls[0].size
	for slot: Control in slot_controls:
		if slot.size.distance_to(reference_slot_size) > 1.0:
			push_warning("HeroLayoutQA: ukuran slot tidak konsisten: %s = %s vs %s" % [slot.name, slot.size, reference_slot_size])
		var short_side: float = maxf(minf(slot.size.x, slot.size.y), 1.0)
		var long_side: float = maxf(slot.size.x, slot.size.y)
		if long_side / short_side > 1.18:
			push_warning("HeroLayoutQA: rasio slot terlalu memanjang: %s = %s" % [slot.name, slot.size])
		var slot_rect := Rect2(slot.position, slot.size)
		if not stage_rect.encloses(slot_rect):
			push_warning("HeroLayoutQA: slot overflow: " + str(slot.name))

	for first_index: int in range(slot_controls.size()):
		for second_index: int in range(first_index + 1, slot_controls.size()):
			var first := slot_controls[first_index]
			var second := slot_controls[second_index]
			if Rect2(first.position, first.size).intersects(Rect2(second.position, second.size)):
				push_warning("HeroLayoutQA: slot overlap: %s / %s" % [first.name, second.name])

	var bonus_panel := bonus_summary_label.get_parent() as Control
	if bonus_panel != null:
		var bonus_rect := Rect2(bonus_panel.position, bonus_panel.size)
		if not stage_rect.encloses(bonus_rect):
			push_warning("HeroLayoutQA: bonus panel overflow.")
		for slot_control: Control in slot_controls:
			if bonus_rect.intersects(Rect2(slot_control.position, slot_control.size)):
				push_warning("HeroLayoutQA: bonus overlaps slot: " + str(slot_control.name))

	if candidate_scroll.size.y < 110.0:
		push_warning("HeroLayoutQA: arsenal scroll viewport terlalu pendek: %.1f" % candidate_scroll.size.y)
	if candidate_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		push_warning("HeroLayoutQA: arsenal vertical scroll disabled.")
	if candidate_grid.columns != 3:
		push_warning("HeroLayoutQA: arsenal portrait harus 3 kolom compact.")
	if candidate_scroll.size.x > 0.0 and candidate_grid.size.x > candidate_scroll.size.x + 2.0:
		push_warning("HeroLayoutQA: candidate grid overflow horizontal: %.1f > %.1f" % [candidate_grid.size.x, candidate_scroll.size.x])
	var detail_scroll := detail_panel.get_node_or_null("DetailScroll") as ScrollContainer
	if detail_scroll == null:
		push_warning("HeroLayoutQA: detail scroll container missing.")
	elif detail_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		push_warning("HeroLayoutQA: detail vertical scroll disabled.")


func _setup_detail_premium_presentation() -> void:
	# Relic-grade presentation: authored vault texture provides depth without
	# increasing information density.
	if detail_panel.get_node_or_null("RelicVaultBackdrop") == null:
		var backdrop := TextureRect.new()
		backdrop.name = "RelicVaultBackdrop"
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.texture = DETAIL_RELIC_BACKDROP
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.modulate = Color(0.52, 0.78, 0.75, 0.13)
		detail_panel.add_child(backdrop)
		detail_panel.move_child(backdrop, 0)

	var detail_scroll := detail_panel.get_node_or_null("DetailScroll") as ScrollContainer
	if detail_scroll != null:
		var detail_bar := detail_scroll.get_v_scroll_bar()
		if detail_bar != null:
			# Keep touch/wheel scrolling but remove the desktop-white scrollbar.
			detail_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
			detail_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			detail_bar.custom_minimum_size.x = 0.0

	var detail_header := selected_slot_label.get_parent() as VBoxContainer
	if detail_header != null and detail_header.get_node_or_null("RelicEyebrow") == null:
		var eyebrow := Label.new()
		eyebrow.name = "RelicEyebrow"
		eyebrow.text = tr("CELESTIAL RELIC INSPECTION")
		eyebrow.add_theme_font_size_override("font_size", 8)
		eyebrow.add_theme_constant_override("letter_spacing", 1)
		eyebrow.add_theme_color_override(
			"font_color",
			Color(0.96, 0.76, 0.32, 0.88)
		)
		detail_header.add_child(eyebrow)
		detail_header.move_child(eyebrow, 0)

	var inspection_text: VBoxContainer = selected_stat_label.get_parent() as VBoxContainer
	if inspection_text != null:
		if inspection_text.get_node_or_null("RarityLine") == null:
			detail_rarity_line = ColorRect.new()
			detail_rarity_line.name = "RarityLine"
			detail_rarity_line.custom_minimum_size = Vector2(0.0, 2.0)
			detail_rarity_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			detail_rarity_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inspection_text.add_child(detail_rarity_line)
			inspection_text.move_child(
				detail_rarity_line,
				item_role_label.get_index() + 1
			)
		detail_resonance_label = Label.new()
		detail_resonance_label.name = "DetailResonanceLabel"
		detail_resonance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_resonance_label.add_theme_font_size_override("font_size", 9)
		detail_resonance_label.add_theme_color_override("font_color", Color(0.70, 0.90, 0.84, 0.96))
		detail_resonance_label.add_theme_constant_override("outline_size", 1)
		detail_resonance_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		inspection_text.add_child(detail_resonance_label)
		inspection_text.move_child(detail_resonance_label, selected_stat_label.get_index() + 1)

	var ascension_text: VBoxContainer = ascension_status_label.get_parent() as VBoxContainer
	if ascension_text != null:
		ascension_star_track = HBoxContainer.new()
		ascension_star_track.name = "AscensionStarTrack"
		ascension_star_track.custom_minimum_size = Vector2(0.0, 18.0)
		ascension_star_track.add_theme_constant_override("separation", 4)
		ascension_text.add_child(ascension_star_track)
		ascension_text.move_child(ascension_star_track, 0)

	_apply_relic_button_ornaments(ascend_button, Color(0.98, 0.74, 0.24, 1.0), true)
	_apply_relic_button_ornaments(action_button, Color(0.22, 0.92, 0.80, 1.0), true)
	_apply_relic_button_ornaments(detail_close_button, Color(0.88, 0.68, 0.28, 1.0), false)


func _apply_relic_button_ornaments(button: Button, accent: Color, strong: bool) -> void:
	if button == null:
		return
	var overlay := Control.new()
	overlay.name = "RelicOrnaments"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ornament_color: Color = Color(accent.r, accent.g, accent.b, 0.92 if strong else 0.72)
	for side: int in [-1, 1]:
		var glyph := Label.new()
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.text = "◆"
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 10 if strong else 8)
		glyph.add_theme_color_override("font_color", ornament_color)
		glyph.anchor_top = 0.5
		glyph.anchor_bottom = 0.5
		glyph.offset_top = -10.0
		glyph.offset_bottom = 10.0
		if side < 0:
			glyph.anchor_left = 0.0
			glyph.anchor_right = 0.0
			glyph.offset_left = 8.0
			glyph.offset_right = 24.0
		else:
			glyph.anchor_left = 1.0
			glyph.anchor_right = 1.0
			glyph.offset_left = -24.0
			glyph.offset_right = -8.0
		overlay.add_child(glyph)


func _set_detail_visibility(should_show: bool) -> void:
	if detail_panel == null:
		return
	if not should_show:
		detail_panel.visible = false
		detail_last_visible = false
		return
	var just_opened: bool = not detail_last_visible
	detail_panel.visible = true
	detail_last_visible = true
	if just_opened:
		_play_detail_open_motion()


func _play_detail_open_motion() -> void:
	if detail_panel == null:
		return
	detail_panel.pivot_offset = detail_panel.size * 0.5
	detail_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	detail_panel.scale = Vector2(0.985, 0.985)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(detail_panel, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(detail_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_detail_resonance(item_id: String) -> void:
	if detail_resonance_label == null:
		return
	if item_id.is_empty():
		detail_resonance_label.text = ""
		return
	var set_id: String = EquipmentSetCatalog.get_set_id_for_item(item_id)
	if set_id.is_empty():
		detail_resonance_label.text = tr(EquipmentVisualCatalog.get_slot_role(selected_slot_id))
		return
	var equipped_ids: Array[String] = _get_equipped_item_ids()
	var piece_count: int = EquipmentSetCatalog.get_piece_count(set_id, equipped_ids)
	var identity: String = EquipmentSetCatalog.get_identity(set_id)
	detail_resonance_label.text = "%s  •  %d/5\n%s" % [
		tr(EquipmentSetCatalog.get_display_name(set_id)),
		piece_count,
		tr(identity)
	]


func _refresh_ascension_star_track(current_star: int, target_star: int = 0) -> void:
	if ascension_star_track == null:
		return
	for child: Node in ascension_star_track.get_children():
		child.queue_free()
	for star_index: int in range(1, EquipmentManager.MAX_ASCENSION_STAR + 1):
		var star := Label.new()
		star.custom_minimum_size = Vector2(24.0, 16.0)
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.text = "★"
		star.add_theme_font_size_override("font_size", 12)
		var color := Color(0.30, 0.42, 0.43, 0.80)
		if star_index <= current_star:
			color = Color(1.0, 0.78, 0.28, 1.0)
		elif target_star > 0 and star_index == target_star:
			color = Color(0.28, 0.96, 0.84, 1.0)
		star.add_theme_color_override("font_color", color)
		star.add_theme_constant_override("outline_size", 2)
		star.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.86))
		ascension_star_track.add_child(star)


func _setup_collection_filter() -> void:
	var collection_vbox: VBoxContainer = candidate_scroll.get_parent() as VBoxContainer
	if collection_vbox == null:
		push_error("HeroEquipment: CollectionVBox tidak ditemukan untuk ownership filter.")
		return

	# Compact collection HUD. The old multi-line block consumed most of the
	# scroll viewport; this keeps progress/resonance visible without sacrificing
	# browsing space.
	collection_showcase_panel = PanelContainer.new()
	collection_showcase_panel.name = "CollectionShowcase"
	collection_showcase_panel.custom_minimum_size = Vector2(0.0, 54.0)
	collection_showcase_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_showcase_panel.add_theme_stylebox_override("panel", _make_collection_showcase_style())
	collection_vbox.add_child(collection_showcase_panel)
	collection_vbox.move_child(collection_showcase_panel, candidate_scroll.get_index())

	var showcase_box := VBoxContainer.new()
	showcase_box.add_theme_constant_override("separation", 3)
	collection_showcase_panel.add_child(showcase_box)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	showcase_box.add_child(header_row)

	var completion_title := Label.new()
	completion_title.text = tr("KOLEKSI")
	completion_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	completion_title.add_theme_font_size_override("font_size", 10)
	completion_title.add_theme_color_override("font_color", Color(0.38, 0.94, 0.82, 0.96))
	header_row.add_child(completion_title)

	collection_progress_label = Label.new()
	collection_progress_label.add_theme_font_size_override("font_size", 11)
	collection_progress_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.46, 1.0))
	collection_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(collection_progress_label)

	var progress_track := Control.new()
	progress_track.custom_minimum_size = Vector2(0.0, 4.0)
	progress_track.clip_contents = true
	showcase_box.add_child(progress_track)
	var progress_background := ColorRect.new()
	progress_background.color = Color(0.03, 0.11, 0.12, 0.96)
	progress_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(progress_background)
	progress_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	collection_progress_fill = ColorRect.new()
	collection_progress_fill.color = Color(0.98, 0.76, 0.26, 0.96)
	collection_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	collection_progress_fill.anchor_left = 0.0
	collection_progress_fill.anchor_top = 0.0
	collection_progress_fill.anchor_right = 0.0
	collection_progress_fill.anchor_bottom = 1.0
	progress_track.add_child(collection_progress_fill)

	collection_resonance_label = Label.new()
	collection_resonance_label.add_theme_font_size_override("font_size", 10)
	collection_resonance_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
	collection_resonance_label.clip_text = true
	collection_resonance_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	collection_resonance_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	showcase_box.add_child(collection_resonance_label)

	# Keep these state labels alive for the existing refresh contract but hide
	# them from the compact HUD. Their information remains available in tooltips
	# and the item detail sheet.
	collection_identity_label = Label.new()
	collection_identity_label.visible = false
	showcase_box.add_child(collection_identity_label)
	collection_next_bonus_label = Label.new()
	collection_next_bonus_label.visible = false
	showcase_box.add_child(collection_next_bonus_label)

	var filter_bar := HBoxContainer.new()
	filter_bar.name = "CollectionFilterBar"
	filter_bar.custom_minimum_size = Vector2(0.0, 38.0)
	filter_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_bar.add_theme_constant_override("separation", 5)
	collection_vbox.add_child(filter_bar)
	collection_vbox.move_child(filter_bar, candidate_scroll.get_index())

	for filter_id: String in FILTER_ORDER:
		var button := Button.new()
		button.name = "Filter_" + filter_id
		button.custom_minimum_size = Vector2(72.0, 36.0)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.text = tr(filter_id.to_upper())
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(_on_collection_filter_pressed.bind(filter_id))
		filter_bar.add_child(button)
		collection_filter_buttons[filter_id] = button

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_bar.add_child(spacer)

	collection_filter_count_label = Label.new()
	collection_filter_count_label.name = "CollectionOwnedCount"
	collection_filter_count_label.custom_minimum_size = Vector2(88.0, 36.0)
	collection_filter_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	collection_filter_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	collection_filter_count_label.add_theme_font_size_override("font_size", 10)
	collection_filter_count_label.add_theme_color_override("font_color", Color(0.70, 0.91, 0.87, 0.96))
	collection_filter_count_label.add_theme_constant_override("outline_size", 2)
	collection_filter_count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	filter_bar.add_child(collection_filter_count_label)

	collection_filter_empty_label = Label.new()
	collection_filter_empty_label.name = "CollectionFilterEmpty"
	collection_filter_empty_label.custom_minimum_size = Vector2(0.0, 42.0)
	collection_filter_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_filter_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	collection_filter_empty_label.add_theme_font_size_override("font_size", 11)
	collection_filter_empty_label.add_theme_color_override("font_color", Color(0.60, 0.79, 0.77, 0.90))
	collection_filter_empty_label.add_theme_constant_override("outline_size", 2)
	collection_filter_empty_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	collection_filter_empty_label.visible = false
	collection_vbox.add_child(collection_filter_empty_label)
	collection_vbox.move_child(collection_filter_empty_label, candidate_scroll.get_index())

	if _get_owned_equipment_count() <= 0:
		active_collection_filter = FILTER_ALL


func _refresh_collection_filter() -> void:
	if collection_filter_buttons.is_empty():
		return

	var all_item_ids: Array[String] = _get_all_equipment_item_ids()
	var owned_count: int = _get_owned_equipment_count()
	var total_count: int = maxi(all_item_ids.size(), 1)
	var completion_ratio: float = clampf(float(owned_count) / float(total_count), 0.0, 1.0)
	collection_filter_count_label.text = ""
	if collection_progress_label != null:
		collection_progress_label.text = "%d / %d  •  %d%%" % [owned_count, all_item_ids.size(), int(round(completion_ratio * 100.0))]
	if collection_progress_fill != null:
		collection_progress_fill.anchor_right = completion_ratio
	_refresh_collection_resonance_summary()

	for filter_id: String in FILTER_ORDER:
		var button: Button = collection_filter_buttons.get(filter_id) as Button
		if button == null:
			continue
		var is_active: bool = filter_id == active_collection_filter
		button.button_pressed = is_active
		button.add_theme_stylebox_override("normal", _make_collection_filter_style(is_active, false))
		button.add_theme_stylebox_override("hover", _make_collection_filter_style(is_active, true))
		button.add_theme_stylebox_override("pressed", _make_collection_filter_style(true, true))
		button.add_theme_stylebox_override("focus", _make_collection_filter_style(true, true))
		var font_color: Color = Color(1.0, 0.84, 0.42, 1.0) if is_active else Color(0.69, 0.86, 0.84, 0.92)
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_hover_color", Color(0.92, 1.0, 0.96, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.45, 1.0))

	var filtered_count: int = _get_filtered_equipment_item_ids().size()
	collection_filter_count_label.text = tr("SHOWING %d") % filtered_count
	var has_results: bool = filtered_count > 0
	candidate_scroll.visible = has_results
	collection_filter_empty_label.visible = not has_results
	if has_results:
		return
	match active_collection_filter:
		FILTER_OWNED:
			collection_filter_empty_label.text = tr("NO OWNED EQUIPMENT YET")
		FILTER_MISSING:
			collection_filter_empty_label.text = tr("COLLECTION COMPLETE")
		_:
			collection_filter_empty_label.text = tr("NO EQUIPMENT FOUND")


func _make_collection_showcase_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.026, 0.038, 0.97)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.96, 0.76, 0.28, 0.58)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 11.0
	style.content_margin_top = 8.0
	style.content_margin_right = 11.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0.18, 0.86, 0.76, 0.10)
	style.shadow_size = 6
	return style


func _refresh_collection_resonance_summary() -> void:
	if collection_resonance_label == null or collection_identity_label == null or collection_next_bonus_label == null:
		return
	var state: Dictionary = _get_dominant_set_state()
	var set_id: String = str(state.get("set_id", ""))
	var piece_count: int = int(state.get("piece_count", 0))
	if set_id.is_empty() or piece_count <= 0:
		collection_resonance_label.text = tr("LOADOUT RESONANCE") + "  •  —"
		collection_identity_label.text = tr("No equipment set is currently attuned.")
		collection_next_bonus_label.text = "2P  •  " + tr("Equip matching set pieces to awaken resonance.")
		return
	collection_resonance_label.text = "%s  •  %s  %d/5" % [tr("LOADOUT RESONANCE"), tr(EquipmentSetCatalog.get_display_name(set_id)), piece_count]
	collection_identity_label.text = tr(EquipmentSetCatalog.get_identity(set_id))
	var next_tier: int = 0
	for tier: int in [2, 3, 4, 5]:
		if piece_count < tier:
			next_tier = tier
			break
	if next_tier <= 0:
		collection_next_bonus_label.text = tr(EquipmentSetCatalog.get_resonance_label(piece_count))
	else:
		collection_next_bonus_label.text = "%dP  •  %s" % [next_tier, tr(EquipmentSetCatalog.get_tier_description(set_id, next_tier))]


func _make_collection_filter_style(active: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.020, 0.145, 0.135, 0.98)
		if active
		else Color(0.003, 0.030, 0.044, 0.94)
	)
	if hovered:
		style.bg_color = style.bg_color.lightened(0.08)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = (
		Color(0.96, 0.75, 0.27, 0.92)
		if active
		else Color(0.24, 0.70, 0.63, 0.46)
	)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 8.0
	style.content_margin_top = 4.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(0.12, 0.85, 0.77, 0.16 if active else 0.06)
	style.shadow_size = 5 if active else 2
	return style


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
	equipped_count_label.text = tr("TERPASANG %d / %d") % [equipped_count, SLOT_ORDER.size()]
	if can_modify:
		if has_checkpoint:
			status_label.text = tr("RUN BERIKUTNYA")
		else:
			status_label.text = tr("SIAP  •  PILIH SLOT")
		hero_preview_sprite.modulate = Color.WHITE
		hero_menu_art.modulate = Color.WHITE
	else:
		status_label.text = tr("LOADOUT TERKUNCI")
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
	_refresh_collection_filter()
	_rebuild_candidate_grid()
	_refresh_detail_panel(can_modify)
	_set_detail_visibility(detail_open)

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
	if icon_texture == null:
		icon_texture = SLOT_PLACEHOLDER_TEXTURES.get(slot_id) as Texture2D

	_clear_slot_overlays(button)
	button.text = ""
	button.icon = null
	button.expand_icon = false
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 10)
	_add_slot_icon(button, icon_texture, filled)
	var selected: bool = detail_open and slot_id == selected_slot_id
	button.add_theme_stylebox_override("normal", _make_slot_style(selected, false, rarity_color, filled))
	button.add_theme_stylebox_override("hover", _make_slot_style(selected, true, rarity_color, filled))
	button.add_theme_stylebox_override("pressed", _make_slot_style(true, true, rarity_color, filled))
	button.add_theme_stylebox_override("focus", _make_slot_style(true, true, rarity_color, filled))
	_add_slot_caption(button, _get_slot_caption_text(slot_id), filled, rarity_color)
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

func _get_owned_equipment_count() -> int:
	var owned_count: int = 0
	for item_id: String in _get_all_equipment_item_ids():
		if InventoryManager.owns_item(item_id):
			owned_count += 1
	return owned_count

func _item_matches_collection_filter(item_id: String, filter_id: String) -> bool:
	var owned: bool = InventoryManager.owns_item(item_id)
	match filter_id:
		FILTER_OWNED:
			return owned
		FILTER_MISSING:
			return not owned
		_:
			return true

func _get_filtered_equipment_item_ids() -> Array[String]:
	var filtered_ids: Array[String] = []
	for item_id: String in _get_all_equipment_item_ids():
		if _item_matches_collection_filter(item_id, active_collection_filter):
			filtered_ids.append(item_id)
	return filtered_ids

func _rebuild_candidate_grid() -> void:
	candidate_rebuild_generation += 1
	var rebuild_generation: int = candidate_rebuild_generation
	for child: Node in candidate_grid.get_children():
		candidate_grid.remove_child(child)
		child.queue_free()
	var item_ids: Array[String] = _get_filtered_equipment_item_ids()
	_populate_candidate_grid_batched.call_deferred(item_ids, rebuild_generation)


func _populate_candidate_grid_batched(
	item_ids: Array[String],
	rebuild_generation: int
) -> void:
	for item_index: int in range(item_ids.size()):
		if rebuild_generation != candidate_rebuild_generation or not is_inside_tree():
			return
		candidate_grid.add_child(_create_candidate_button(item_ids[item_index]))
		if (item_index + 1) % CANDIDATE_BUILD_BATCH_SIZE == 0:
			await get_tree().process_frame

func _create_candidate_button(item_id: String) -> Button:
	var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
	var slot_id: String = str(item_data.get("slot", ""))
	var owned_count: int = InventoryManager.get_item_count(item_id)
	var equipped: bool = EquipmentManager.get_equipped_item_id(slot_id) == item_id
	var selected: bool = detail_open and item_id == selected_item_id
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(168.0, 156.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = null
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = ""
	var rarity_id: String = str(item_data.get("rarity", "common"))
	var rarity_color: Color = EquipmentVisualCatalog.get_rarity_color(rarity_id)
	_install_card_icon(button, _load_item_icon(item_id), rarity_color, owned_count > 0)
	_add_candidate_card_copy(button, item_id, item_data, rarity_id, owned_count > 0)
	button.add_theme_stylebox_override("normal", _make_candidate_style(rarity_color, equipped, selected, owned_count > 0, false))
	button.add_theme_stylebox_override("hover", _make_candidate_style(rarity_color, equipped, true, owned_count > 0, true))
	button.add_theme_stylebox_override("pressed", _make_candidate_style(rarity_color, equipped, true, owned_count > 0, true))
	button.add_theme_stylebox_override("focus", _make_candidate_style(rarity_color, equipped, true, owned_count > 0, true))
	_add_rarity_badge(button, rarity_id, rarity_color, owned_count > 0)
	_add_star_badge(button, EquipmentManager.get_item_star(item_id), owned_count > 0)
	if equipped:
		_add_state_badge(button, tr("EQUIPPED"), Color(0.28, 1.0, 0.76, 1.0))
	button.pressed.connect(_on_candidate_pressed.bind(item_id))
	var effective_data: Dictionary = EquipmentManager.get_effective_item_data(item_id)
	button.tooltip_text = "%s\n%s  •  %s\n%s" % [str(item_data.get("display_name", item_id)), _format_stars(EquipmentManager.get_item_star(item_id)), EquipmentVisualCatalog.get_stat_summary(effective_data), EquipmentVisualCatalog.get_signature_effect_description(item_data)]
	return button


func _install_card_icon(parent_button: Button, texture: Texture2D, rarity_color: Color, owned: bool) -> void:
	var glow := PanelContainer.new()
	glow.name = "IconGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.anchor_left = 0.15
	glow.anchor_top = 0.08
	glow.anchor_right = 0.85
	glow.anchor_bottom = 0.62
	glow.add_theme_stylebox_override("panel", _make_icon_glow_style(rarity_color, owned))
	parent_button.add_child(glow)

	var art := TextureRect.new()
	art.name = "ItemArt"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.anchor_left = 0.13
	art.anchor_top = 0.055
	art.anchor_right = 0.87
	art.anchor_bottom = 0.61
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = Color.WHITE if owned else Color(0.62, 0.69, 0.71, 0.78)
	parent_button.add_child(art)

func _add_candidate_card_copy(
	parent_button: Button,
	item_id: String,
	item_data: Dictionary,
	rarity_id: String,
	owned: bool
) -> void:
	var rarity_color: Color = EquipmentVisualCatalog.get_rarity_color(rarity_id)
	var name_label := Label.new()
	name_label.name = "ItemName"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.anchor_left = 0.05
	name_label.anchor_top = 0.60
	name_label.anchor_right = 0.95
	name_label.anchor_bottom = 0.84
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	name_label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.95, 1.0) if owned else Color(0.54, 0.60, 0.61, 0.88))
	name_label.text = tr(str(item_data.get("display_name", item_id)))
	parent_button.add_child(name_label)

	var set_id: String = EquipmentSetCatalog.get_set_id_for_item(item_id)
	var meta_label := Label.new()
	meta_label.name = "ItemMeta"
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.anchor_left = 0.05
	meta_label.anchor_top = 0.84
	meta_label.anchor_right = 0.95
	meta_label.anchor_bottom = 0.97
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_label.clip_text = true
	meta_label.add_theme_font_size_override("font_size", 8)
	meta_label.add_theme_constant_override("outline_size", 1)
	meta_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	meta_label.add_theme_color_override("font_color", Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.96 if owned else 0.52))
	var set_display_name: String = EquipmentSetCatalog.get_display_name(set_id)
	meta_label.text = tr(rarity_id.to_upper())
	if not set_display_name.is_empty():
		meta_label.text += "  •  " + tr(set_display_name)
	parent_button.add_child(meta_label)


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
	var tint: float = 0.035 if filled else 0.020
	style.bg_color = Color(base.r + rarity_color.r * tint, base.g + rarity_color.g * tint * 0.58, base.b + rarity_color.b * tint, 0.95)
	if hovered:
		style.bg_color = style.bg_color.lightened(0.10)
	var border_color: Color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.78 if filled else 0.32)
	if selected:
		border_color = Color(1.0, 0.77, 0.22, 1.0)
	style.border_width_left = 2 if selected else 1
	style.border_width_top = 2 if selected else 1
	style.border_width_right = 2 if selected else 1
	style.border_width_bottom = 2 if selected else 1
	style.border_color = border_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 5.0
	style.content_margin_top = 4.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 6.0
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.26 if selected else 0.07)
	style.shadow_size = 8 if selected else 3
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
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 10.0
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
		_refresh_detail_resonance("")
		_refresh_ascension_star_track(0)
		return

	var selected_base_data: Dictionary = EquipmentManager.get_item_data(selected_item_id)
	var selected_data: Dictionary = EquipmentManager.get_effective_item_data(selected_item_id)
	var selected_star: int = EquipmentManager.get_item_star(selected_item_id)
	var rarity_id: String = str(selected_data.get("rarity", "common"))
	_apply_detail_rarity_style(EquipmentVisualCatalog.get_rarity_color(rarity_id))
	selected_item_icon.texture = _load_item_icon(selected_item_id)
	item_role_label.text = str(selected_data.get("display_name", selected_item_id))
	selected_stat_label.text = "%s  •  %s\nCORE  •  %s" % [
		tr(rarity_id.to_upper()),
		_format_stars(selected_star),
		_get_item_stat_text(selected_data)
	]
	_refresh_detail_resonance(selected_item_id)
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
		_refresh_ascension_star_track(0)
		return
	var current_star: int = EquipmentManager.get_item_star(selected_item_id)
	var shard_balance: int = InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD)
	if not InventoryManager.owns_item(selected_item_id):
		ascension_status_label.text = "%s  →  ?" % _format_stars(current_star)
		ascension_preview_label.text = tr("Acquire this equipment to unlock ascension.")
		ascend_button.text = tr("ASCENSION LOCKED")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Core passives scale with stars; Signature Effects stay fixed.")
		_refresh_ascension_star_track(current_star)
		return
	if current_star >= EquipmentManager.MAX_ASCENSION_STAR:
		ascension_status_label.text = "%s  •  MAX" % _format_stars(current_star)
		ascension_preview_label.text = tr("CELESTIAL LIMIT REACHED\nCore passive +20% from 1★")
		ascend_button.text = tr("MAX ASCENSION")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("This relic has reached 5★ resonance.")
		_refresh_ascension_star_track(current_star)
		return
	var target_star: int = current_star + 1
	var cost: int = EquipmentManager.get_ascension_cost(selected_item_id)
	ascension_status_label.text = "%s  →  %s\nSHARDS  %d / %d" % [_format_stars(current_star), _format_stars(target_star), shard_balance, cost]
	ascension_preview_label.text = tr("NEXT CORE PASSIVE\n%s") % _build_ascension_stat_preview(selected_item_id, target_star)
	_refresh_ascension_star_track(current_star, target_star)
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
	badge.anchor_left = 0.04
	badge.anchor_top = 0.0
	badge.anchor_right = 0.62
	badge.anchor_bottom = 0.0
	badge.offset_left = 0.0
	badge.offset_top = 7.0
	badge.offset_right = 0.0
	badge.offset_bottom = 27.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 7)
	badge.add_theme_constant_override("outline_size", 2)
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.22, 1.0) if owned else Color(0.46, 0.52, 0.54, 0.72))
	badge.text = _format_stars(star)
	parent_button.add_child(badge)

func _add_state_badge(parent_button: Button, text_value: String, color: Color) -> void:
	var badge: Label = Label.new()
	badge.name = "StateBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.58
	badge.anchor_top = 0.0
	badge.anchor_right = 0.96
	badge.anchor_bottom = 0.0
	badge.offset_left = 0.0
	badge.offset_top = 7.0
	badge.offset_right = 0.0
	badge.offset_bottom = 27.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_constant_override("outline_size", 2)
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	badge.add_theme_color_override("font_color", color)
	badge.text = text_value
	parent_button.add_child(badge)

func _clear_slot_overlays(button: Button) -> void:
	for child_name: String in ["SlotIcon", "SlotCaption", "SlotJewel"]:
		var child: Node = button.get_node_or_null(child_name)
		if child != null: child.free()

func _get_slot_caption_text(slot_id: String) -> String:
	return tr(str(SLOT_CAPTION_TEXTS.get(
		slot_id,
		EquipmentVisualCatalog.get_slot_title(slot_id)
	)))

func _add_slot_icon(button: Button, texture: Texture2D, filled: bool) -> void:
	var icon := TextureRect.new()
	icon.name = "SlotIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_left = 0.18
	icon.anchor_top = 0.08
	icon.anchor_right = 0.82
	icon.anchor_bottom = 0.68
	icon.offset_left = 0.0
	icon.offset_top = 0.0
	icon.offset_right = 0.0
	icon.offset_bottom = 0.0
	icon.modulate = Color.WHITE if filled else Color(0.84, 0.96, 0.92, 0.88)
	button.add_child(icon)

func _add_slot_caption(button: Button, slot_title: String, filled: bool, rarity_color: Color) -> void:
	var caption: Label = Label.new()
	caption.name = "SlotCaption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.anchor_left = 0.06
	caption.anchor_top = 0.70
	caption.anchor_right = 0.94
	caption.anchor_bottom = 0.94
	caption.offset_left = 0.0
	caption.offset_top = 0.0
	caption.offset_right = 0.0
	caption.offset_bottom = 0.0
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.max_lines_visible = 1
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.clip_text = false
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_constant_override("outline_size", 2)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.86))
	caption.add_theme_color_override("font_color", rarity_color.lightened(0.24) if filled else Color(0.76, 0.90, 0.87, 0.98))
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
	detail_panel.add_theme_stylebox_override(
		"panel",
		_make_detail_surface(rarity_color, 0.985, 18)
	)
	inspection_card.add_theme_stylebox_override(
		"panel",
		_make_detail_surface(rarity_color, 0.90, 10)
	)
	signature_panel.add_theme_stylebox_override(
		"panel",
		_make_detail_surface(
			rarity_color.lerp(Color(0.22, 0.92, 0.82, 1.0), 0.46),
			0.78,
			7
		)
	)
	ascension_panel.add_theme_stylebox_override(
		"panel",
		_make_detail_surface(Color(0.96, 0.72, 0.20, 1.0), 0.86, 10)
	)
	if detail_rarity_line != null:
		detail_rarity_line.color = Color(
			rarity_color.r,
			rarity_color.g,
			rarity_color.b,
			0.92
		)

func _make_detail_surface(accent: Color, opacity: float, glow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.003 + accent.r * 0.055, 0.018 + accent.g * 0.035, 0.030 + accent.b * 0.055, opacity)
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	style.corner_radius_top_left = 14; style.corner_radius_top_right = 14; style.corner_radius_bottom_left = 14; style.corner_radius_bottom_right = 14
	style.content_margin_left = 11.0; style.content_margin_top = 7.0; style.content_margin_right = 11.0; style.content_margin_bottom = 7.0
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
	return tr("TANPA BONUS AKTIF") if parts.is_empty() else "  •  ".join(parts)


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
	var tier_lines: Array[String] = []
	for tier: int in [2, 3, 4, 5]:
		var tier_description: String = EquipmentSetCatalog.get_tier_description(set_id, tier)
		if tier_description.is_empty():
			continue
		var state_prefix: String = "ACTIVE" if piece_count >= tier else "LOCKED"
		tier_lines.append("%s  •  %dP  •  %s" % [
			tr(state_prefix),
			tier,
			tr(tier_description)
		])
	var identity: String = EquipmentSetCatalog.get_identity(set_id)
	var bonus_text: String = "\\n".join(tier_lines)
	return "%s  %d/5  •  %s\\n%s\\n\\n%s\\n\\n%s: %s\\n%s: %s" % [
		tr(EquipmentSetCatalog.get_display_name(set_id)),
		piece_count,
		tr(EquipmentSetCatalog.get_resonance_label(piece_count)),
		tr(identity),
		bonus_text,
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

func _on_collection_filter_pressed(filter_id: String) -> void:
	if not FILTER_ORDER.has(filter_id):
		return
	active_collection_filter = filter_id
	if (
		not selected_item_id.is_empty()
		and not _item_matches_collection_filter(selected_item_id, active_collection_filter)
	):
		selected_item_id = ""
		detail_open = false
	_refresh_screen()

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
	call_deferred("_play_item_inspection_pulse")

func _play_item_inspection_pulse() -> void:
	if selected_item_icon == null or not detail_open:
		return
	selected_item_icon.pivot_offset = selected_item_icon.size * 0.5
	selected_item_icon.scale = Vector2(0.94, 0.94)
	selected_item_icon.modulate = Color(1.0, 1.0, 1.0, 0.72)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(selected_item_icon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(selected_item_icon, "modulate", Color.WHITE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
