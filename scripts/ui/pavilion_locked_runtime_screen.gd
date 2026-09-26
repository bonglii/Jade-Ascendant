extends "res://scripts/ui/pavilion_runtime_screen_vfx.gd"

## Locked Pavilion production composition.
## The approved LAB visual is promoted here while PavilionManager remains the
## sole authority for summon resolution, pity, Wish Fate, payment, inventory,
## duplicate conversion, rewarded grants, and save state.

const RitualStage = preload("res://scripts/ui/pavilion_rateup_ritual_stage.gd")

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

const DAILY_MEDITATION_ORBIT_PATH: String = "res://assets/ui/pavilion/services/daily_meditation_orbit.svg"
const AURA_CARD_FRAME_PATH: String = "res://assets/ui/pavilion/services/aura_card_frame.svg"
const FORGE_EMBLEM_PATH: String = "res://assets/ui/pavilion/services/forge_emblem.svg"

const FEATURED_SET_ID: String = "nine_heavens"
const GOLD_SOFT: Color = Color(0.96, 0.74, 0.30, 1.0)
const DEEP_NAVY: Color = Color(0.003, 0.016, 0.028, 0.96)
const MUTED_TEXT: Color = Color(0.68, 0.76, 0.78, 1.0)

var session_summon_history: Array = []

var locked_root: VBoxContainer
var palace_background: TextureRect
var featured_items: Array[String] = []
var selected_rate_up_item_id: String = ""
var focal_icon: TextureRect
var focal_name: Label
var featured_row: HBoxContainer
var legendary_bar: ProgressBar
var legendary_value: Label
var legendary_remaining: Label
var locked_watch_ad_button: Button
var summon_controls_stack: VBoxContainer
var locked_watch_ad_visual: TextureRect
var locked_rates_overlay: ColorRect
var locked_history_overlay: ColorRect
var scroll_container: ScrollContainer
var compact_forge_host: VBoxContainer
var compact_forge_details: VBoxContainer
var compact_forge_toggle: Button
var compact_forge_expanded: bool = false


func _build_wallet_header() -> void:
	# SharedHubResourceBarManager owns the one global resource bar. Do not build
	# a Pavilion-only duplicate underneath it.
	wallet_header = null
	stone_balance_label = null
	shard_balance_label = null
	jade_balance_label = null
	seal_balance_label = null
	var pavilion_scroll := $SafeArea/Scroll as ScrollContainer
	if pavilion_scroll != null:
		pavilion_scroll.offset_top = 78.0


func _build_hero_header() -> void:
	_install_palace_background()
	# Approved production lock has no legacy Sanctum masthead.


func _build_status_banner() -> void:
	status_panel = _panel(content, _status_style(JADE_SOFT))
	status_label = _label(status_panel, "", 12, Color(0.72, 0.88, 0.82, 1.0))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_panel.visible = false


func _build_summon_section() -> void:
	scroll_container = $SafeArea/Scroll
	_hide_scroll_pipe()
	_load_featured_items()

	locked_root = VBoxContainer.new()
	locked_root.name = "LockedSummonProduction"
	locked_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	locked_root.add_theme_constant_override("separation", 5)
	content.add_child(locked_root)

	_build_title_and_banner()
	_build_focal_ritual()
	_build_featured_selector()
	_build_legendary_mandate()
	_build_summon_ctas()
	_build_utility_rows()

	starter_button = _button(
		locked_root,
		tr("CLAIM INITIATE GIFT • +10 PAVILION SEALS"),
		_claim_starter_seals,
		false,
		JADE
	)
	starter_button.custom_minimum_size.y = 38.0
	starter_button.visible = false


func _build_meditation_section() -> void:
	# Preserve all existing Pavilion services and rewarded-ad initialization.
	super()
	# The approved summon layout already owns the Watch Ad CTA, so keep the old
	# rewarded service card alive for state/signals but remove duplicate chrome.
	if rewarded_seal_panel != null:
		rewarded_seal_panel.visible = false

	# Mobile lower-section pass: keep the meditation card compact while making
	# its small copy readable on a real phone.
	if meditation_altar_frame != null:
		meditation_altar_frame.custom_minimum_size = Vector2(104.0, 104.0)
		var meditation_body := meditation_altar_frame.get_parent() as HBoxContainer
		if meditation_body != null:
			meditation_body.add_theme_constant_override("separation", 10)
	if cadence_label != null:
		cadence_label.add_theme_font_size_override("font_size", 13)
		cadence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if chest != null:
		chest.add_theme_font_size_override("font_size", 15)
		chest.custom_minimum_size.y = 46.0
	if meditation_altar_icon != null and ResourceLoader.exists(DAILY_MEDITATION_ORBIT_PATH):
		meditation_altar_icon.texture = load(DAILY_MEDITATION_ORBIT_PATH) as Texture2D
		meditation_altar_icon.modulate = Color.WHITE


func _apply_first_frame_polish() -> void:
	# Do not inject the legacy runtime icons into the approved image-backed CTAs.
	_hide_scroll_pipe()


func _enforce_mobile_readability(root: Node) -> void:
	# Preserve the exact locked typography inside the approved summon block.
	# Everything below it gets a slightly larger phone-readable floor.
	if root == null or _is_inside_locked_root(root):
		return
	if root is Label:
		var label := root as Label
		if label.get_theme_font_size("font_size") < 13:
			label.add_theme_font_size_override("font_size", 13)
	elif root is Button:
		var button := root as Button
		if button.get_theme_font_size("font_size") < 14:
			button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override(
			"font_disabled_color",
			Color(0.64, 0.73, 0.70, 0.98)
		)

	for child: Node in root.get_children():
		_enforce_mobile_readability(child)


func _is_inside_locked_root(node: Node) -> bool:
	if locked_root == null or node == null:
		return false
	var current: Node = node
	while current != null:
		if current == locked_root:
			return true
		current = current.get_parent()
	return false


# -----------------------------------------------------------------------------
# MOBILE LOWER-PAVILION POLISH
# The approved summon composition above stays locked. These overrides only tune
# the service cards that follow it inside the same production scroll container.
# -----------------------------------------------------------------------------

func _section_card(
	parent_node: Node,
	eyebrow: String,
	title: String,
	description: String,
	accent: Color
) -> VBoxContainer:
	var box: VBoxContainer = super(parent_node, eyebrow, title, description, accent)
	box.add_theme_constant_override("separation", 6)

	var panel := box.get_parent() as PanelContainer
	if panel != null:
		var compact_style: StyleBoxFlat = _sanctum_section_style(accent, 12)
		compact_style.content_margin_left = 11.0
		compact_style.content_margin_top = 10.0
		compact_style.content_margin_right = 11.0
		compact_style.content_margin_bottom = 10.0
		panel.add_theme_stylebox_override("panel", compact_style)

	if box.get_child_count() >= 3:
		var ornament := box.get_child(0) as HBoxContainer
		if ornament != null:
			ornament.add_theme_constant_override("separation", 6)
			for ornament_child: Node in ornament.get_children():
				if ornament_child is Label:
					var ornament_label := ornament_child as Label
					if ornament_label.get_theme_font_size("font_size") < 12:
						ornament_label.add_theme_font_size_override("font_size", 12)

		var title_label := box.get_child(1) as Label
		if title_label != null:
			title_label.add_theme_font_size_override("font_size", 23)

		var description_label := box.get_child(2) as Label
		if description_label != null:
			description_label.add_theme_font_size_override("font_size", 14)
			description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	return box


func _build_aura_section() -> void:
	super()
	if aura_grid != null:
		aura_grid.columns = 2
		aura_grid.add_theme_constant_override("h_separation", 6)
		aura_grid.add_theme_constant_override("v_separation", 6)
	if aura_featured != null:
		aura_featured.add_theme_constant_override("separation", 5)


func _create_aura_card(
	cosmetic_id: String,
	featured: bool = false
) -> PanelContainer:
	var card: PanelContainer = super(cosmetic_id, featured)
	if card == null or card.get_child_count() <= 0:
		return card

	var box := card.get_child(0) as VBoxContainer
	if box == null:
		return card
	box.add_theme_constant_override("separation", 5)

	if box.get_child_count() > 0:
		var preview_stage := box.get_child(0) as Control
		if preview_stage != null:
			preview_stage.custom_minimum_size.y = 118.0 if featured else 94.0
			for preview_child: Node in preview_stage.get_children():
				if preview_child is PanelContainer:
					var overlay := preview_child as PanelContainer
					overlay.offset_top = -58.0
					if overlay.get_child_count() > 0:
						var title_row := overlay.get_child(0) as HBoxContainer
						if title_row != null:
							title_row.add_theme_constant_override("separation", 6)
							for title_child: Node in title_row.get_children():
								if title_child is TextureRect:
									(title_child as TextureRect).custom_minimum_size = (
										Vector2(34.0, 34.0)
										if featured
										else Vector2(30.0, 30.0)
									)
								elif title_child is VBoxContainer:
									for copy_child: Node in title_child.get_children():
										if copy_child is Label:
											var copy_label := copy_child as Label
											copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		if ResourceLoader.exists(AURA_CARD_FRAME_PATH):
			var aura_frame := TextureRect.new()
			aura_frame.name = "PremiumAuraFrame"
			aura_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			aura_frame.texture = load(AURA_CARD_FRAME_PATH) as Texture2D
			aura_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			aura_frame.stretch_mode = TextureRect.STRETCH_SCALE
			preview_stage.add_child(aura_frame)
			aura_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			# Keep labels/action overlay above the ornamental frame.
			if preview_stage.get_child_count() > 1:
				preview_stage.move_child(aura_frame, 1)

	if box.get_child_count() > 1:
		var action := box.get_child(box.get_child_count() - 1) as Button
		if action != null:
			action.custom_minimum_size.y = 46.0
			action.add_theme_font_size_override("font_size", 14)

	_enforce_mobile_readability(card)
	return card


func _build_forge_section() -> void:
	var forge := _section_card(
		content,
		tr("DETERMINISTIC SAFETY NET"),
		tr("Equipment Forge"),
		tr("Target a specific relic when you prefer a deterministic path over summoning."),
		GOLD
	)

	var compact_row := HBoxContainer.new()
	compact_row.add_theme_constant_override("separation", 10)
	forge.add_child(compact_row)

	var emblem_shell := PanelContainer.new()
	emblem_shell.custom_minimum_size = Vector2(76.0, 76.0)
	emblem_shell.add_theme_stylebox_override(
		"panel",
		_equipment_icon_style(GOLD, true)
	)
	compact_row.add_child(emblem_shell)
	var emblem := TextureRect.new()
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(FORGE_EMBLEM_PATH):
		emblem.texture = load(FORGE_EMBLEM_PATH) as Texture2D
	emblem_shell.add_child(emblem)

	var compact_copy := VBoxContainer.new()
	compact_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_copy.add_theme_constant_override("separation", 3)
	compact_row.add_child(compact_copy)
	var compact_title := _label(
		compact_copy,
		tr("Choose the relic. Forge only when you need certainty."),
		15,
		Color(1.0, 0.88, 0.54, 1.0)
	)
	compact_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var compact_hint := _label(
		compact_copy,
		tr("Common/Rare can use Spirit Stones. Higher rarities use Refinement Shards."),
		13,
		TEXT_MUTED
	)
	compact_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	compact_forge_toggle = _button(
		forge,
		tr("OPEN FORGE"),
		_toggle_compact_forge,
		false,
		GOLD
	)
	compact_forge_toggle.custom_minimum_size.y = 46.0
	compact_forge_toggle.add_theme_font_size_override("font_size", 14)

	compact_forge_details = VBoxContainer.new()
	compact_forge_details.add_theme_constant_override("separation", 7)
	compact_forge_details.visible = false
	forge.add_child(compact_forge_details)

	_label(compact_forge_details, tr("RARITY"), 13, TEXT_MUTED)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 5)
	compact_forge_details.add_child(filter_row)
	for rarity: String in RARITIES:
		var rarity_button := Button.new()
		rarity_button.text = tr(rarity.capitalize()).to_upper()
		rarity_button.custom_minimum_size = Vector2(0.0, 44.0)
		rarity_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rarity_button.add_theme_font_size_override("font_size", 13)
		rarity_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		rarity_button.pressed.connect(_select_rarity.bind(rarity))
		filter_row.add_child(rarity_button)
		rarity_buttons[rarity] = rarity_button

	equipment_list = VBoxContainer.new()
	equipment_list.add_theme_constant_override("separation", 6)
	compact_forge_details.add_child(equipment_list)
	compact_forge_host = forge


func _toggle_compact_forge() -> void:
	if compact_forge_details == null:
		return
	compact_forge_expanded = not compact_forge_expanded
	compact_forge_details.visible = compact_forge_expanded
	if compact_forge_toggle != null:
		compact_forge_toggle.text = (
			tr("CLOSE FORGE")
			if compact_forge_expanded
			else tr("OPEN FORGE")
		)
	if compact_forge_expanded:
		_sync_rarity_buttons()
		_rebuild_equipment()


func _create_equipment_card(
	item_id: String,
	data: Dictionary
) -> PanelContainer:
	var card: PanelContainer = super(item_id, data)
	if card == null or card.get_child_count() <= 0:
		return card

	var box := card.get_child(0) as VBoxContainer
	if box == null:
		return card
	box.add_theme_constant_override("separation", 4)

	for child: Node in box.get_children():
		if child is PanelContainer:
			var icon_frame := child as PanelContainer
			if icon_frame.custom_minimum_size.y >= 80.0:
				icon_frame.custom_minimum_size.y = 72.0
				for icon_child: Node in icon_frame.get_children():
					if icon_child is TextureRect:
						(icon_child as TextureRect).custom_minimum_size = Vector2(60.0, 60.0)
		elif child is Label:
			var label := child as Label
			if label.get_theme_font_size("font_size") >= 15:
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				label.custom_minimum_size.y = 34.0
		elif child is HBoxContainer:
			(child as HBoxContainer).add_theme_constant_override("separation", 4)
			for action_child: Node in child.get_children():
				if action_child is Button:
					var action_button := action_child as Button
					action_button.custom_minimum_size.y = 40.0
					action_button.add_theme_font_size_override("font_size", 14)
		elif child is Button:
			var single_action := child as Button
			single_action.custom_minimum_size.y = 40.0
			single_action.add_theme_font_size_override("font_size", 14)

	_enforce_mobile_readability(card)
	return card


func _build_player_trust_section() -> void:
	super()
	if content == null or content.get_child_count() <= 0:
		return
	var panel := content.get_child(content.get_child_count() - 1) as PanelContainer
	if panel == null or panel.get_child_count() <= 0:
		return
	var row := panel.get_child(0) as HBoxContainer
	if row != null:
		row.add_theme_constant_override("separation", 6)
		for row_child: Node in row.get_children():
			if row_child is VBoxContainer:
				for copy_child: Node in row_child.get_children():
					if copy_child is Label:
						(copy_child as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			elif row_child is Button:
				var privacy_button := row_child as Button
				privacy_button.custom_minimum_size = Vector2(132.0, 46.0)
				privacy_button.add_theme_font_size_override("font_size", 14)
	_enforce_mobile_readability(panel)


func _add_bottom_safe_spacer() -> void:
	# The ScrollContainer already stops above the fixed navbar. Keep only a small
	# breathing zone instead of the old 122 px blank block.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 20.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)


func _refresh_summon_panel() -> void:
	if locked_root == null:
		return
	_sync_wallet_balances()

	var unlocked: bool = PavilionManager.is_summon_unlocked()
	var read_only: bool = SaveManager.is_progress_read_only()
	var live_target: String = PavilionManager.get_wish_target_item_id()
	selected_rate_up_item_id = live_target if live_target in featured_items else ""
	_refresh_focal_item()
	_rebuild_featured_selector()

	var pity: Dictionary = PavilionManager.get_summon_pity_status()
	var legendary_limit: int = int(EconomyCatalog.PITY_LIMITS.get("legendary", 50))
	var legendary_active: bool = bool(pity.get("legendary_active", false))
	var counter: int = int(pity.get("legendary_counter", 0))
	var remaining: int = int(pity.get("legendary_remaining", -1))
	legendary_bar.max_value = legendary_limit
	if legendary_active:
		legendary_bar.value = counter
		legendary_value.text = "%d / %d" % [counter, legendary_limit]
		legendary_remaining.text = tr("Guaranteed in %d summons") % maxi(remaining, 0)
		if PavilionManager.is_wish_fate_guaranteed():
			legendary_remaining.text += tr(" • RATE-UP GUARANTEED")
	else:
		legendary_bar.value = 0.0
		legendary_value.text = tr("LOCKED")
		legendary_remaining.text = tr("Legendary mandate activates when the Legendary pool unlocks.")

	if summon_one_button != null:
		summon_one_button.disabled = (
			not unlocked
			or read_only
			or not PavilionManager.can_summon(EconomyCatalog.SINGLE_PULL_COUNT)
		)
	if summon_ten_button != null:
		summon_ten_button.disabled = (
			not unlocked
			or read_only
			or not PavilionManager.can_summon(EconomyCatalog.TEN_PULL_COUNT)
		)
	if starter_button != null:
		starter_button.visible = PavilionManager.can_claim_starter_seals()
		starter_button.disabled = read_only or not PavilionManager.can_claim_starter_seals()

	if not unlocked:
		_set_status(tr("Clear Chapter 1-5 to open the Celestial Pavilion."), GOLD)
	elif not read_only and status_panel != null and status_label != null:
		# Healthy state remains visually quiet.
		status_panel.visible = false


func _refresh_rewarded_seal_section() -> void:
	super()
	if rewarded_seal_panel != null:
		rewarded_seal_panel.visible = false
	if locked_watch_ad_button != null:
		var ad_ready: bool = rewarded_seal_button != null and not rewarded_seal_button.disabled
		locked_watch_ad_button.disabled = not ad_ready
		if locked_watch_ad_visual != null:
			locked_watch_ad_visual.modulate = Color.WHITE if ad_ready else Color(0.62, 0.64, 0.66, 0.78)


func _summon(pull_count: int) -> void:	
	var result: Dictionary = PavilionManager.summon_equipment(pull_count)
	if not bool(result.get("success", false)):
		_set_status(
			tr(str(result.get("error", PavilionManager.last_error))),
			Color(0.95, 0.48, 0.42)
		)
		return
	_record_session_history(result)
	_start_summon_reveal(result)
	_sync_wallet_balances()
	_refresh_summon_panel()


func _play_summon_ritual_feedback(_result: Dictionary) -> void:
	# Premium cinematic/result presentation already owns the payoff. Suppress the
	# legacy ritual-card feedback because that card is intentionally not built.
	pass


func _on_reward_delivery_finished(
	placement: String,
	success: bool,
	amount: int,
	message: String
) -> void:
	super(placement, success, amount, message)
	if placement != RewardedBridge.PLACEMENT_ID:
		return
	_sync_wallet_balances()
	if success:
		_set_status(tr("Reward granted • +%d Pavilion Seal.") % amount, JADE)
	else:
		_set_status(tr("Reward could not be granted. Please try again later."), Color(0.95, 0.48, 0.42))


func _on_rewarded_request_finished(placement: String, status: String) -> void:
	super(placement, status)
	if placement != RewardedBridge.PLACEMENT_ID:
		return
	_refresh_rewarded_seal_section()


func _load_featured_items() -> void:
	featured_items.clear()
	var set_items: Array[String] = EquipmentSetCatalog.get_piece_ids(FEATURED_SET_ID)
	for item_id: String in set_items:
		var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
		if str(item_data.get("rarity", "")) == "legendary":
			featured_items.append(item_id)
	if featured_items.is_empty():
		var fallback: Array[String] = PavilionManager.get_wish_target_options()
		for item_id: String in fallback:
			featured_items.append(item_id)
			if featured_items.size() >= 5:
				break


func _build_title_and_banner() -> void:
	var header: VBoxContainer = VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	locked_root.add_child(header)

	var title: Label = _label(header, tr("Pavilion"), 28, Color(1.0, 0.89, 0.66, 1.0))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	_label(header, tr("Equipment Summon"), 13, Color(0.91, 0.88, 0.80, 1.0))

	var banner_panel: PanelContainer = _panel(header, _banner_pill_style())
	banner_panel.custom_minimum_size.y = 30.0
	var banner: Label = _label(
		banner_panel,
		tr("◷  FEATURED POOL  •  ACTIVE"),
		12,
		Color(1.0, 0.78, 0.36, 1.0)
	)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_focal_ritual() -> void:
	var shell: PanelContainer = _panel(locked_root, _ritual_shell_style())
	shell.custom_minimum_size.y = 472.0
	var stage_root: Control = Control.new()
	stage_root.custom_minimum_size.y = 454.0
	stage_root.clip_contents = true
	shell.add_child(stage_root)

	var altar: TextureRect = TextureRect.new()
	altar.name = "SummonAltar"
	altar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	altar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	altar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	altar.texture = _load_summon_altar_texture()
	altar.anchor_right = 1.0
	altar.anchor_bottom = 1.0
	altar.modulate = Color(0.92, 0.95, 0.97, 0.88)
	stage_root.add_child(altar)

	var altar_shade: ColorRect = ColorRect.new()
	altar_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	altar_shade.color = Color(0.0, 0.008, 0.014, 0.18)
	stage_root.add_child(altar_shade)
	altar_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var ornament: Control = RitualStage.new()
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
	var shell: PanelContainer = _panel(locked_root, _featured_shell_style())
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
	for child: Node in featured_row.get_children():
		featured_row.remove_child(child)
		child.queue_free()

	var available_targets: Array[String] = PavilionManager.get_wish_target_options()
	for item_id: String in featured_items:
		var selected: bool = item_id == selected_rate_up_item_id
		var available: bool = item_id in available_targets
		var card: Control = Control.new()
		card.custom_minimum_size = Vector2(0.0, 134.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		featured_row.add_child(card)

		var frame: TextureRect = TextureRect.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.texture = _load_component_texture(
			FEATURED_RATE_UP_FRAME_PATH if selected else FEATURED_RELIC_FRAME_PATH
		)
		frame.modulate = (
			Color.WHITE
			if selected
			else Color(1.0, 1.0, 1.0, 0.58 if available else 0.34)
		)
		card.add_child(frame)
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var icon: TextureRect = TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _load_item_texture(item_id)
		icon.anchor_left = 0.19
		icon.anchor_top = 0.15
		icon.anchor_right = 0.81
		icon.anchor_bottom = 0.66 if selected else 0.69
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0 if selected else (0.78 if available else 0.42))
		card.add_child(icon)

		var name_tint: Color = Color(1.0, 0.95, 0.82, 1.0) if selected else Color(0.90, 0.89, 0.84, 0.92 if available else 0.52)
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

		var hit: Button = _transparent_hit_button()
		hit.pressed.connect(_select_rate_up_item.bind(item_id))
		card.add_child(hit)
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _select_rate_up_item(item_id: String) -> void:
	if item_id not in featured_items:
		return
	if SaveManager.is_progress_read_only():
		_set_status(tr("Restart the game to recover the pending save before changing Rate-Up."), Color(0.95, 0.48, 0.42))
		return
	if item_id not in PavilionManager.get_wish_target_options():
		_set_status(tr("This Legendary relic is not unlocked for the current summon pool yet."), GOLD)
		return
	if not PavilionManager.set_wish_target(item_id):
		_set_status(tr(PavilionManager.last_error), Color(0.95, 0.48, 0.42))
		return
	selected_rate_up_item_id = item_id
	_refresh_focal_item()
	_rebuild_featured_selector()


func _refresh_focal_item() -> void:
	if focal_icon == null or focal_name == null:
		return
	var display_id: String = selected_rate_up_item_id
	if display_id.is_empty() and not featured_items.is_empty():
		display_id = featured_items[0]
	focal_icon.texture = _load_item_texture(display_id)
	focal_name.text = _item_display_name(display_id)


func _build_legendary_mandate() -> void:
	var shell: PanelContainer = _panel(locked_root, _mandate_shell_style())
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
	legendary_bar.max_value = float(EconomyCatalog.PITY_LIMITS.get("legendary", 50))
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
	# Keep the approved button artwork and hit-area sizes unchanged. Only compact
	# the vertical distance between the summon, utility, and history rows.
	summon_controls_stack = VBoxContainer.new()
	summon_controls_stack.name = "SummonControlsStack"
	summon_controls_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summon_controls_stack.add_theme_constant_override("separation", -34)
	locked_root.add_child(summon_controls_stack)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	summon_controls_stack.add_child(row)
	summon_one_button = _add_component_button(row, SUMMON_ONE_BUTTON_PATH, 98.0, true)
	summon_one_button.pressed.connect(_summon.bind(EconomyCatalog.SINGLE_PULL_COUNT))
	summon_ten_button = _add_component_button(row, SUMMON_TEN_BUTTON_PATH, 98.0, true)
	summon_ten_button.pressed.connect(_summon.bind(EconomyCatalog.TEN_PULL_COUNT))


func _build_utility_rows() -> void:
	var controls_parent: Container = (
		summon_controls_stack
		if summon_controls_stack != null
		else locked_root
	)

	var utilities: HBoxContainer = HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 5)
	controls_parent.add_child(utilities)
	rates_button = _add_component_button(utilities, DROP_RATES_BUTTON_PATH, 82.0, true)
	rates_button.pressed.connect(_show_drop_rates_overlay)
	locked_watch_ad_button = _add_component_button(utilities, WATCH_AD_BUTTON_PATH, 82.0, true)
	locked_watch_ad_visual = locked_watch_ad_button.get_meta("visual") as TextureRect
	locked_watch_ad_button.pressed.connect(_request_locked_rewarded_ad)

	var history_row: HBoxContainer = HBoxContainer.new()
	history_row.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_parent.add_child(history_row)
	var left_spacer: Control = Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_row.add_child(left_spacer)
	var history_button: Button = _add_component_button(history_row, SUMMON_HISTORY_BUTTON_PATH, 76.0, false, 0.58)
	history_button.pressed.connect(_show_history_overlay)
	var right_spacer: Control = Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_row.add_child(right_spacer)


func _add_component_button(
	parent: Container,
	texture_path: String,
	height: float,
	expand: bool,
	width_ratio: float = 1.0
) -> Button:
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

	var hit: Button = _transparent_hit_button()
	hit.set_meta("visual", visual)
	holder.add_child(hit)
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return hit


func _transparent_hit_button() -> Button:
	var hit: Button = Button.new()
	hit.text = ""
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent: StyleBoxFlat = _transparent_button_style()
	hit.add_theme_stylebox_override("normal", transparent)
	hit.add_theme_stylebox_override("hover", transparent)
	hit.add_theme_stylebox_override("pressed", transparent)
	hit.add_theme_stylebox_override("focus", transparent)
	return hit


func _request_locked_rewarded_ad() -> void:
	if rewarded_seal_button == null:
		_set_status(tr("Reward service is still preparing."), MUTED_TEXT)
		return
	_request_rewarded_seal()
	_refresh_rewarded_seal_section()


func _show_drop_rates_overlay() -> void:
	if locked_rates_overlay != null and is_instance_valid(locked_rates_overlay):
		locked_rates_overlay.queue_free()
	locked_rates_overlay = _build_modal_overlay(tr("DROP RATES & PITY RULES"))
	var box: VBoxContainer = locked_rates_overlay.get_meta("content") as VBoxContainer
	var rates: Array[Dictionary] = PavilionManager.get_effective_drop_rate_disclosure()
	for entry: Dictionary in rates:
		var rarity: String = str(entry.get("rarity", "common")).to_upper()
		var percent: float = float(entry.get("percent", 0.0))
		var line: Label = _label(box, "%s  •  %.2f%%" % [rarity, percent], 15, EquipmentVisualCatalog.get_rarity_color(rarity.to_lower()))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pity: Dictionary = PavilionManager.get_summon_pity_status()
	_label(box, tr("Legendary Mandate: guaranteed at %d pulls.") % int(EconomyCatalog.PITY_LIMITS.get("legendary", 50)), 12, MUTED_TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bool(pity.get("legendary_active", false)):
		_label(box, tr("Current Legendary counter: %d • %d remaining") % [int(pity.get("legendary_counter", 0)), int(pity.get("legendary_remaining", 0))], 12, GOLD_SOFT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(box, tr("Rate-Up uses the saved Wish target and Wish Fate rules."), 12, MUTED_TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var close_button: Button = _button(box, tr("CLOSE"), _close_rates_overlay, false, JADE)
	close_button.custom_minimum_size.y = 42.0


func _close_rates_overlay() -> void:
	if locked_rates_overlay != null and is_instance_valid(locked_rates_overlay):
		locked_rates_overlay.queue_free()
	locked_rates_overlay = null


func _show_history_overlay() -> void:
	if locked_history_overlay != null and is_instance_valid(locked_history_overlay):
		locked_history_overlay.queue_free()
	locked_history_overlay = _build_modal_overlay(tr("SUMMON HISTORY • THIS PAVILION VISIT"))
	var box: VBoxContainer = locked_history_overlay.get_meta("content") as VBoxContainer
	if session_summon_history.is_empty():
		var empty_label: Label = _label(box, tr("No summons recorded during this Pavilion visit yet."), 13, MUTED_TEXT)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var shown: int = mini(session_summon_history.size(), 20)
		for index: int in range(shown):
			var entry: Dictionary = session_summon_history[index]
			var rarity: String = str(entry.get("rarity", "common"))
			var state_text: String = tr("DUPLICATE") if bool(entry.get("duplicate", false)) else tr("NEW")
			var row_label: Label = _label(
				box,
				"%s  •  %s  •  %s" % [
					str(entry.get("name", "")),
					rarity.to_upper(),
					state_text
				],
				12,
				EquipmentVisualCatalog.get_rarity_color(rarity)
			)
			row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note: Label = _label(box, tr("History is visit-only; the frozen production save schema is unchanged."), 10, MUTED_TEXT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close_button: Button = _button(box, tr("CLOSE"), _close_history_overlay, false, JADE)
	close_button.custom_minimum_size.y = 42.0


func _close_history_overlay() -> void:
	if locked_history_overlay != null and is_instance_valid(locked_history_overlay):
		locked_history_overlay.queue_free()
	locked_history_overlay = null


func _build_modal_overlay(title_text: String) -> ColorRect:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.008, 0.014, 0.93)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 90
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.move_to_front()

	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.08
	panel.anchor_top = 0.18
	panel.anchor_right = 0.92
	panel.anchor_bottom = 0.82
	panel.add_theme_stylebox_override("panel", _mandate_shell_style())
	overlay.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title: Label = _label(box, title_text, 20, Color(1.0, 0.88, 0.66, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.set_meta("content", box)
	return overlay


func _record_session_history(result: Dictionary) -> void:
	for raw_entry: Variant in result.get("results", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var item_id: String = str(entry.get("item_id", ""))
		var data: Dictionary = EquipmentManager.get_item_data(item_id)
		session_summon_history.push_front({
			"item_id": item_id,
			"name": tr(str(data.get("display_name", item_id))),
			"rarity": str(entry.get("rarity", data.get("rarity", "common"))),
			"duplicate": bool(entry.get("duplicate", false)),
		})
	while session_summon_history.size() > 40:
		session_summon_history.pop_back()


func _hide_scroll_pipe() -> void:
	if scroll_container == null:
		scroll_container = $SafeArea/Scroll
	if scroll_container == null:
		return
	var vbar: VScrollBar = scroll_container.get_v_scroll_bar()
	if vbar != null:
		vbar.modulate = Color(1.0, 1.0, 1.0, 0.0)
		vbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbar.custom_minimum_size.x = 0.0
		vbar.size_flags_horizontal = Control.SIZE_SHRINK_END


func _install_palace_background() -> void:
	if palace_background != null and is_instance_valid(palace_background):
		return
	var legacy_backdrop: Control = get_node_or_null("Backdrop") as Control
	if legacy_backdrop != null:
		legacy_backdrop.visible = false
	if not ResourceLoader.exists(PALACE_BACKGROUND_PATH):
		push_warning("Pavilion production background missing: %s" % PALACE_BACKGROUND_PATH)
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
	atlas_texture.region = Rect2(0.0, 330.0, 941.0, 1210.0)
	return atlas_texture


func _load_component_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Pavilion production component missing: %s" % path)
		return null
	return load(path) as Texture2D


func _load_item_texture(item_id: String) -> Texture2D:
	var path: String = EquipmentVisualCatalog.get_icon_path(item_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _item_display_name(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	var data: Dictionary = EquipmentManager.get_item_data(item_id)
	return tr(str(data.get("display_name", item_id.capitalize())))


func _compact_item_name(item_id: String) -> String:
	return _item_display_name(item_id).replace("Nine Heavens ", "Nine Heavens\n")


func _transparent_button_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	return style


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
