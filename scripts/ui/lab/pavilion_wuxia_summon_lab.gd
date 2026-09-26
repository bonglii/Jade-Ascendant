extends "res://scripts/ui/pavilion_screen.gd"

## PAVILION WUXIA SUMMON REDESIGN LAB
## Fresh UI architecture based on the newly approved dark wuxia/xianxia summon design.
## Read-only: no summon, Wish, rewarded-ad, purchase, or save mutation is called.

const EquipmentCatalog = preload("res://scripts/data/equipment_catalog.gd")
const RitualStageLab = preload("res://scripts/ui/lab/pavilion_rateup_ritual_stage_lab.gd")

const PALACE_BACKGROUND_PATH: String = "res://assets/ui/pavilion/redesign/pavilion_summon_palace_bg.png"
const SUMMON_ALTAR_PATH: String = "res://assets/ui/pavilion/redesign/pavilion_summon_altar.png"
const COMPONENT_ROOT: String = "res://assets/ui/pavilion/redesign/components/"
const SUMMON_ONE_BUTTON_PATH: String = COMPONENT_ROOT + "summon_one_button.png"
const SUMMON_TEN_BUTTON_PATH: String = COMPONENT_ROOT + "summon_ten_button.png"
const DROP_RATES_BUTTON_PATH: String = COMPONENT_ROOT + "drop_rates_button.png"
const WATCH_AD_BUTTON_PATH: String = COMPONENT_ROOT + "watch_ad_button.png"
const SUMMON_HISTORY_BUTTON_PATH: String = COMPONENT_ROOT + "summon_history_button.png"
const FEATURED_RATE_UP_FRAME_PATH: String = COMPONENT_ROOT + "featured_rate_up_frame.png"
const FEATURED_RELIC_FRAME_PATH: String = COMPONENT_ROOT + "featured_relic_frame.png"

const BANNER_DEFINITIONS: Dictionary = {
	"nine_heavens_featured": {
		"label": "FEATURED POOL",
		"time_remaining": "13d 16h",
		"set_id": "nine_heavens",
		"featured_items": [
			"nine_heavens_star_sword",
			"sovereign_mantle",
			"tribulation_bracer",
			"cloudtreader_boots",
			"ascendant_heart"
		],
		"default_target": "nine_heavens_star_sword"
	}
}

const ACTIVE_BANNER_ID: String = "nine_heavens_featured"
const GOLD_SOFT: Color = Color(0.96, 0.74, 0.30, 1.0)
const ICE_BLUE: Color = Color(0.45, 0.76, 1.0, 1.0)
const DEEP_NAVY: Color = Color(0.003, 0.016, 0.028, 0.96)
const CARD_NAVY: Color = Color(0.006, 0.024, 0.040, 0.94)
const MUTED_TEXT: Color = Color(0.68, 0.76, 0.78, 1.0)

var active_banner: Dictionary = {}
var featured_items: Array[String] = []
var selected_rate_up_item_id: String = ""

var focal_icon: TextureRect
var focal_name: Label
var featured_row: HBoxContainer
var legendary_bar: ProgressBar
var legendary_value: Label
var legendary_remaining: Label
var banner_pill: Label
var lab_notice: Label
var future_services_anchor: VBoxContainer
var scroll_container: ScrollContainer

func _hide_scroll_pipe() -> void:
	if scroll_container == null:
		return
	var vbar: VScrollBar = scroll_container.get_v_scroll_bar()
	if vbar != null:
		vbar.modulate = Color(1.0, 1.0, 1.0, 0.0)
		vbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbar.custom_minimum_size.x = 0.0
		vbar.size_flags_horizontal = Control.SIZE_SHRINK_END
var palace_background: TextureRect


func _find_wallet_row(root: Node) -> HBoxContainer:
	if root is HBoxContainer:
		var row: HBoxContainer = root as HBoxContainer
		if row.get_child_count() == 4:
			var all_controls: bool = true
			for child in row.get_children():
				if not (child is Control):
					all_controls = false
					break
			if all_controls:
				return row
	for child in root.get_children():
		var found: HBoxContainer = _find_wallet_row(child)
		if found != null:
			return found
	return null

func _fit_wallet_row() -> void:
	if content == null:
		return
	var row: HBoxContainer = _find_wallet_row(content)
	if row == null:
		return
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for child_node in row.get_children():
		if child_node is Control:
			var child: Control = child_node as Control
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			child.custom_minimum_size.x = 0.0
			if child is Container:
				for inner_node in child.get_children():
					if inner_node is Control:
						var inner: Control = inner_node as Control
						inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	_install_palace_background()
	scroll_container = $SafeArea/Scroll
	content = $SafeArea/Scroll/Content
	SceneTransitionManager.set_back_handler(_back)
	_prepare_pavilion_content()
	_build_wallet_header()
	_sync_wallet_balances()
	_fit_wallet_row()
	_install_pavilion_nav_luxury()
	_load_banner(ACTIVE_BANNER_ID)
	_build_redesign()
	_refresh_read_only_state()
	_hide_scroll_pipe()

func _load_banner(banner_id: String) -> void:
	var raw_banner: Variant = BANNER_DEFINITIONS.get(banner_id, {})
	if raw_banner is Dictionary:
		active_banner = (raw_banner as Dictionary).duplicate(true)
	else:
		active_banner = {}

	featured_items.clear()
	var raw_items: Variant = active_banner.get("featured_items", [])
	if raw_items is Array:
		for raw_item_id in raw_items:
			var item_id: String = str(raw_item_id)
			if EquipmentCatalog.ITEMS.has(item_id):
				featured_items.append(item_id)

	if featured_items.is_empty():
		featured_items = EquipmentSetCatalog.get_piece_ids(str(active_banner.get("set_id", "nine_heavens")))

	var preferred_target: String = str(active_banner.get("default_target", ""))
	if preferred_target in featured_items:
		selected_rate_up_item_id = preferred_target
	elif not featured_items.is_empty():
		selected_rate_up_item_id = featured_items[0]

func _build_redesign() -> void:
	content.add_theme_constant_override("separation", 5)
	_build_title_and_banner()
	_build_focal_ritual()
	_build_featured_selector()
	_build_legendary_mandate()
	_build_summon_ctas()
	_build_utility_rows()
	_build_future_services_anchor()
	_build_lab_notice()
	_add_bottom_safe_spacer()

func _build_title_and_banner() -> void:
	var header: VBoxContainer = VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	content.add_child(header)

	var title: Label = _label(header, tr("Pavilion"), 28, Color(1.0, 0.89, 0.66, 1.0))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	_label(header, tr("Equipment Summon"), 13, Color(0.91, 0.88, 0.80, 1.0))

	var banner_panel: PanelContainer = _panel(header, _banner_pill_style())
	banner_panel.custom_minimum_size.y = 30.0
	banner_pill = _label(
		banner_panel,
		"◷  %s  •  %s" % [
			str(active_banner.get("label", "FEATURED POOL")),
			str(active_banner.get("time_remaining", ""))
		],
		12,
		Color(1.0, 0.78, 0.36, 1.0)
	)
	banner_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _build_focal_ritual() -> void:
	var shell: PanelContainer = _panel(content, _ritual_shell_style())
	shell.custom_minimum_size.y = 472.0

	var stage_root: Control = Control.new()
	stage_root.custom_minimum_size.y = 454.0
	stage_root.clip_contents = true
	shell.add_child(stage_root)

	# Generated summon altar asset. It is presentation-only and intentionally
	# cropped through AtlasTexture so the useful altar/dragon portion fills the
	# mobile hero stage without modifying the source PNG.
	var altar: TextureRect = TextureRect.new()
	altar.name = "SummonAltar"
	altar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	altar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	altar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	altar.texture = _load_summon_altar_texture()
	altar.anchor_left = 0.0
	altar.anchor_top = 0.0
	altar.anchor_right = 1.0
	altar.anchor_bottom = 1.0
	altar.modulate = Color(0.92, 0.95, 0.97, 0.88)
	stage_root.add_child(altar)

	var altar_shade: ColorRect = ColorRect.new()
	altar_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	altar_shade.color = Color(0.0, 0.008, 0.014, 0.18)
	stage_root.add_child(altar_shade)
	altar_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var ornament: Control = RitualStageLab.new()
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_root.add_child(ornament)
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	focal_icon = TextureRect.new()
	focal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	focal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	focal_icon.anchor_left = 0.24
	focal_icon.anchor_top = 0.08
	focal_icon.anchor_right = 0.76
	focal_icon.anchor_bottom = 0.64
	focal_icon.modulate = Color(1.0, 1.0, 1.0, 0.86)
	stage_root.add_child(focal_icon)

	var caption_panel: PanelContainer = PanelContainer.new()
	caption_panel.anchor_left = 0.17
	caption_panel.anchor_top = 0.79
	caption_panel.anchor_right = 0.83
	caption_panel.anchor_bottom = 0.92
	caption_panel.add_theme_stylebox_override("panel", _focal_caption_style())
	stage_root.add_child(caption_panel)

	var caption_box: VBoxContainer = VBoxContainer.new()
	caption_box.alignment = BoxContainer.ALIGNMENT_CENTER
	caption_box.add_theme_constant_override("separation", 1)
	caption_panel.add_child(caption_box)
	var rate_label: Label = _label(caption_box, tr("RATE-UP TARGET"), 9, Color(1.0, 0.72, 0.28, 1.0))
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focal_name = _label(caption_box, "", 17, Color(1.0, 0.92, 0.74, 1.0))
	focal_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focal_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_focal_item()

func _build_featured_selector() -> void:
	var shell: PanelContainer = _panel(content, _featured_shell_style())
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	shell.add_child(box)

	var title: Label = _label(box, tr("Featured Equipment"), 18, Color(1.0, 0.88, 0.65, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var helper: Label = _label(box, tr("Tap one of the five relics to make it the Rate-Up target."), 10, MUTED_TEXT)
	helper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	featured_row = HBoxContainer.new()
	featured_row.alignment = BoxContainer.ALIGNMENT_CENTER
	featured_row.add_theme_constant_override("separation", 4)
	box.add_child(featured_row)
	_rebuild_featured_selector()

func _rebuild_featured_selector() -> void:
	if featured_row == null:
		return
	for child in featured_row.get_children():
		featured_row.remove_child(child)
		child.queue_free()

	for item_id in featured_items:
		var selected: bool = item_id == selected_rate_up_item_id
		var card: Control = Control.new()
		card.custom_minimum_size = Vector2(0.0, 134.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		featured_row.add_child(card)

		var frame: TextureRect = TextureRect.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.texture = _load_component_texture(
			FEATURED_RATE_UP_FRAME_PATH if selected else FEATURED_RELIC_FRAME_PATH
		)
		card.add_child(frame)
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Selected target remains fully luminous; the other four relic frames are
		# deliberately restrained so Rate-Up hierarchy reads instantly on mobile.
		frame.modulate = Color(1.0, 1.0, 1.0, 1.0 if selected else 0.58)

		var icon: TextureRect = TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _load_item_texture(item_id)
		icon.anchor_left = 0.19
		icon.anchor_top = 0.15
		icon.anchor_right = 0.81
		icon.anchor_bottom = 0.66 if selected else 0.69
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0 if selected else 0.78)
		card.add_child(icon)

		var name_tint: Color = Color(1.0, 0.95, 0.82, 1.0) if selected else Color(0.90, 0.89, 0.84, 0.92)
		var name_label: Label = _label(card, _compact_item_name(item_id), 10, name_tint)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.add_theme_constant_override("outline_size", 1)
		name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		name_label.anchor_left = 0.06
		name_label.anchor_right = 0.94
		name_label.anchor_top = 0.80 if selected else 0.77
		name_label.anchor_bottom = 0.96 if selected else 0.93

		var hit: Button = Button.new()
		hit.text = ""
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.add_theme_stylebox_override("normal", _transparent_button_style())
		hit.add_theme_stylebox_override("hover", _transparent_button_style())
		hit.add_theme_stylebox_override("pressed", _transparent_button_style())
		hit.add_theme_stylebox_override("focus", _transparent_button_style())
		hit.pressed.connect(_select_rate_up_item.bind(item_id))
		card.add_child(hit)
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _select_rate_up_item(item_id: String) -> void:
	if item_id not in featured_items:
		return
	selected_rate_up_item_id = item_id
	_refresh_focal_item()
	_rebuild_featured_selector()
	_show_lab_notice(tr("Rate-Up target changed locally to %s. Production Wish/save data is untouched.") % _item_display_name(item_id))

func _refresh_focal_item() -> void:
	if focal_icon == null or focal_name == null:
		return
	focal_icon.texture = _load_item_texture(selected_rate_up_item_id)
	focal_name.text = _item_display_name(selected_rate_up_item_id)

func _build_legendary_mandate() -> void:
	var shell: PanelContainer = _panel(content, _mandate_shell_style())
	shell.custom_minimum_size.y = 138.0
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	shell.add_child(box)

	var title_row: HBoxContainer = HBoxContainer.new()
	box.add_child(title_row)
	var title: Label = _label(title_row, tr("Celestial Mandate"), 17, Color(1.0, 0.88, 0.66, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var help: Label = _label(title_row, "?", 13, Color(0.91, 0.91, 0.86, 1.0))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var subtitle: Label = _label(box, tr("Legendary equipment is guaranteed when the mandate reaches its limit."), 10, MUTED_TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var legendary_label: Label = _label(box, tr("LEGENDARY"), 12, GOLD_SOFT)
	legendary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	legendary_bar = ProgressBar.new()
	legendary_bar.min_value = 0.0
	legendary_bar.max_value = 50.0
	legendary_bar.show_percentage = false
	legendary_bar.custom_minimum_size = Vector2(0.0, 12.0)
	legendary_bar.add_theme_stylebox_override("background", _progress_background_style())
	legendary_bar.add_theme_stylebox_override("fill", _progress_fill_style(GOLD_SOFT))
	box.add_child(legendary_bar)

	legendary_value = _label(box, "0 / 50", 17, Color(1.0, 0.91, 0.72, 1.0))
	legendary_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legendary_remaining = _label(box, "", 10, MUTED_TEXT)
	legendary_remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_summon_ctas() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)

	_add_component_button(
		row,
		SUMMON_ONE_BUTTON_PATH,
		"Summon ×1",
		98.0,
		true
	)
	_add_component_button(
		row,
		SUMMON_TEN_BUTTON_PATH,
		"Summon ×10",
		98.0,
		true
	)

func _build_utility_rows() -> void:
	var utilities: HBoxContainer = HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 5)
	content.add_child(utilities)

	_add_component_button(
		utilities,
		DROP_RATES_BUTTON_PATH,
		"Drop Rates & Pity Rules",
		82.0,
		true
	)
	_add_component_button(
		utilities,
		WATCH_AD_BUTTON_PATH,
		"Rewarded Summon Ticket",
		82.0,
		true
	)

	var history_row: HBoxContainer = HBoxContainer.new()
	history_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(history_row)
	var left_spacer: Control = Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_row.add_child(left_spacer)
	_add_component_button(
		history_row,
		SUMMON_HISTORY_BUTTON_PATH,
		"Summon History",
		76.0,
		false,
		0.58
	)
	var right_spacer: Control = Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_row.add_child(right_spacer)

func _add_component_button(
	parent: Container,
	texture_path: String,
	action_name: String,
	height: float,
	expand: bool,
	width_ratio: float = 1.0
) -> Control:
	var holder: Control = Control.new()
	holder.custom_minimum_size.y = height
	if expand:
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		holder.custom_minimum_size.x = maxf(210.0, 390.0 * width_ratio)
	parent.add_child(holder)

	var visual: TextureRect = TextureRect.new()
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual.texture = _load_component_texture(texture_path)
	holder.add_child(visual)
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var hit: Button = Button.new()
	hit.text = ""
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", _transparent_button_style())
	hit.add_theme_stylebox_override("hover", _transparent_button_style())
	hit.add_theme_stylebox_override("pressed", _transparent_button_style())
	hit.add_theme_stylebox_override("focus", _transparent_button_style())
	hit.pressed.connect(_preview_action.bind(action_name))
	holder.add_child(hit)
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return holder

func _load_component_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Pavilion LAB component asset missing: %s" % path)
		return null
	return load(path) as Texture2D

func _transparent_button_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	return style

func _build_future_services_anchor() -> void:
	# Intentionally empty. Future Pavilion service cards are inserted here,
	# before the bottom safe spacer, so the existing summon composition does not
	# need to be rebuilt when Meditation/Aura/Forge/Shop modules are added.
	future_services_anchor = VBoxContainer.new()
	future_services_anchor.name = "FuturePavilionServices"
	future_services_anchor.add_theme_constant_override("separation", 10)
	content.add_child(future_services_anchor)

func _build_lab_notice() -> void:
	lab_notice = _label(content, "", 9, Color(0.66, 0.78, 0.76, 1.0))
	lab_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab_notice.visible = false

func _refresh_read_only_state() -> void:
	_sync_wallet_balances()
	var pity: Dictionary = PavilionManager.get_summon_pity_status()
	var active: bool = bool(pity.get("legendary_active", false))
	var counter: int = int(pity.get("legendary_counter", 0))
	var remaining: int = int(pity.get("legendary_remaining", -1))
	if active:
		legendary_bar.value = counter
		legendary_value.text = "%d / 50" % counter
		legendary_remaining.text = tr("Guaranteed in %d summons") % maxi(remaining, 0)
	else:
		legendary_bar.value = 0.0
		legendary_value.text = tr("LOCKED")
		legendary_remaining.text = tr("Legendary mandate activates when the Legendary pool unlocks.")

func _preview_action(action_name: String) -> void:
	_show_lab_notice(tr("LAB preview only • %s does not call production economy/save logic.") % action_name)

func _show_lab_notice(message: String) -> void:
	if lab_notice == null:
		return
	lab_notice.text = message
	lab_notice.visible = true

func _install_palace_background() -> void:
	if palace_background != null and is_instance_valid(palace_background):
		return
	if not ResourceLoader.exists(PALACE_BACKGROUND_PATH):
		push_warning("Pavilion LAB: palace background asset missing: %s" % PALACE_BACKGROUND_PATH)
		return
	palace_background = TextureRect.new()
	palace_background.name = "PalaceBackgroundAsset"
	palace_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palace_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	palace_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	palace_background.texture = load(PALACE_BACKGROUND_PATH) as Texture2D
	palace_background.modulate = Color(0.74, 0.78, 0.84, 1.0)
	add_child(palace_background)
	palace_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(palace_background, 0)

func _load_summon_altar_texture() -> Texture2D:
	if not ResourceLoader.exists(SUMMON_ALTAR_PATH):
		return null
	var source_texture: Texture2D = load(SUMMON_ALTAR_PATH) as Texture2D
	if source_texture == null:
		return null
	var atlas_texture: AtlasTexture = AtlasTexture.new()
	atlas_texture.atlas = source_texture
	# Keep the dragon guardians and altar while dropping the intentionally empty
	# transparent upper canvas from the generated source asset.
	atlas_texture.region = Rect2(0.0, 330.0, 941.0, 1210.0)
	return atlas_texture

func _add_bottom_safe_spacer() -> void:
	# Scroll itself already ends above the fixed production navbar. Keep only a
	# compact breathing zone so phone gesture/safe-area handling stays clean
	# without recreating the old dead-space problem.
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2.ZERO
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)

func _item_display_name(item_id: String) -> String:
	var raw_data: Variant = EquipmentCatalog.ITEMS.get(item_id, {})
	if raw_data is Dictionary:
		return str((raw_data as Dictionary).get("display_name", item_id.capitalize()))
	return item_id.capitalize()

func _compact_item_name(item_id: String) -> String:
	var full_name: String = _item_display_name(item_id)
	return full_name.replace("Nine Heavens ", "Nine Heavens\n")

func _load_item_texture(item_id: String) -> Texture2D:
	var path: String = EquipmentVisualCatalog.get_icon_path(item_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _banner_pill_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.036, 0.008, 0.90)
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.54)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 12.0
	style.content_margin_top = 7.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 7.0
	return style

func _ritual_shell_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.008, 0.015, 0.24)
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.30)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	style.shadow_size = 10
	return style

func _focal_caption_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.012, 0.022, 0.88)
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.52)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10.0
	style.content_margin_top = 7.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 7.0
	return style

func _featured_shell_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.014, 0.025, 0.87)
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.31)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 8.0
	style.content_margin_top = 10.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 10.0
	return style

func _featured_item_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_NAVY
	var border_alpha: float = 0.96 if selected else 0.30
	if hovered:
		border_alpha = 0.82 if not selected else 1.0
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, border_alpha)
	var border_width: int = 2 if selected else 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 44
	style.corner_radius_top_right = 44
	style.corner_radius_bottom_left = 44
	style.corner_radius_bottom_right = 44
	style.content_margin_left = 7.0
	style.content_margin_top = 7.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.20 if selected else 0.03)
	style.shadow_size = 8 if selected else 2
	return style

func _mandate_shell_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.003, 0.015, 0.030, 0.94)
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.46)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	return style

func _progress_background_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.17, 0.96)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _progress_fill_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = accent
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.25)
	style.shadow_size = 5
	return style

func _summon_one_style(hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.48, 0.76, 0.98) if not hovered else Color(0.30, 0.56, 0.84, 1.0)
	style.border_color = Color(0.72, 0.87, 1.0, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style

func _summon_ten_style(hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.70, 0.28, 0.99) if not hovered else Color(1.0, 0.78, 0.34, 1.0)
	style.border_color = Color(1.0, 0.90, 0.62, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	style.shadow_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.16)
	style.shadow_size = 7
	return style

func _utility_style(accent: Color, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var base_strength: float = 0.040 if not hovered else 0.070
	style.bg_color = Color(accent.r * base_strength, accent.g * base_strength, accent.b * base_strength, 0.96)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.58 if not hovered else 0.86)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style

func _history_style(hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = DEEP_NAVY if not hovered else Color(0.010, 0.034, 0.052, 0.98)
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.34 if not hovered else 0.70)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style
