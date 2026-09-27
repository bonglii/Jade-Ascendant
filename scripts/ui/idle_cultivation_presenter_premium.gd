extends "res://scripts/ui/idle_cultivation_presenter.gd"

## SPIRIT MEDITATION — PREMIUM PRODUCTION PRESENTER
## Presentation/UX only.
##
## IdleCultivationManager, RewardManager, SaveManager, and
## MonetizationManager remain authoritative.

const PREMIUM_MAIN_MENU_SCENE: String = (
	"res://scenes/ui/main_menu.tscn"
)
const MOBILE_SCROLL_DEADZONE: int = 6

const CLAIM_BLUE_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/claim_blue.png"
)
const CLAIM_GOLD_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/claim_gold.png"
)
const REWARD_SPIRIT_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/reward_spirit.png"
)
const REWARD_HERO_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/reward_hero_exp.png"
)
const REWARD_SHARD_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/reward_shard.png"
)
const SPIRIT_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)
const SHARD_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/refinement_shard_premium.png"
)
const HERO_EXP_ICON: Texture2D = preload(
	"res://assets/ui/equipment/polish/ascension_emblem.svg"
)

const GOLD_BRIGHT: Color = Color(1.0, 0.88, 0.54, 1.0)
const JADE_SOFT: Color = Color(0.47, 0.98, 0.87, 1.0)
const TEXT: Color = Color(0.95, 0.99, 0.97, 1.0)
const MUTED: Color = Color(0.71, 0.82, 0.79, 1.0)

var _premium_scroll: ScrollContainer = null
var _premium_body: VBoxContainer = null
var _yield_note_label: Label = null
var _spirit_reward_value: Label = null
var _hero_reward_value: Label = null
var _shard_reward_value: Label = null
var _claim_press_scroll_y: int = 0
var _rewarded_press_scroll_y: int = 0
var _cached_hero_texture: Texture2D = null


func is_premium_meditation_presenter() -> bool:
	return true


func _attach_to_home_if_needed() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var scene: Node = tree.current_scene
	if scene.scene_file_path != PREMIUM_MAIN_MENU_SCENE:
		_attached_home_id = 0
		_shortcut = null
		_badge = null
		_popup = null
		_result_popup = null
		_result_panel = null
		return

	if not bool(manager.call("is_unlocked")):
		return

	var scene_id: int = int(scene.get_instance_id())
	if _attached_home_id != scene_id:
		_attached_home_id = scene_id
		_shortcut = null
		_badge = null

	# HomeProductionPresenter owns the visible Home shortcut.
	# This presenter still owns the existing offline auto-open behavior.
	_maybe_auto_open()


func _open_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		return

	var scene: Node = get_tree().current_scene
	if (
		scene == null
		or scene.scene_file_path != PREMIUM_MAIN_MENU_SCENE
	):
		return

	_claim_message = ""

	_popup = Control.new()
	_popup.name = "SpiritMeditationPremiumPopup"
	_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	_popup.z_index = 120
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	scene.add_child(_popup)
	_popup.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	scrim.color = Color(0.0, 0.0, 0.0, 0.64)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	_popup.add_child(scrim)

	_modal_panel = PanelContainer.new()
	_modal_panel.anchor_left = 0.045
	_modal_panel.anchor_top = 0.5
	_modal_panel.anchor_right = 0.955
	_modal_panel.anchor_bottom = 0.5
	_modal_panel.offset_top = 0.0
	_modal_panel.offset_bottom = 0.0
	_modal_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_panel.add_theme_stylebox_override(
		"panel",
		_premium_panel_style(
			Color(0.002, 0.020, 0.028, 0.992),
			Color(0.98, 0.78, 0.32, 0.94),
			20,
			18
		)
	)
	_popup.add_child(_modal_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_modal_panel.add_child(margin)

	_premium_scroll = ScrollContainer.new()
	_premium_scroll.name = "MeditationPopupScroll"
	_premium_scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	_premium_scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	_premium_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	_premium_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	_premium_scroll.scroll_deadzone = (
		MOBILE_SCROLL_DEADZONE
	)
	_premium_scroll.follow_focus = false
	_premium_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_child(_premium_scroll)

	_premium_body = VBoxContainer.new()
	_premium_body.name = "MeditationPopupBody"
	_premium_body.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	_premium_body.add_theme_constant_override(
		"separation",
		8
	)
	_premium_scroll.add_child(_premium_body)

	_build_premium_header(_premium_body)
	_build_premium_hero(_premium_body)
	_build_premium_status(_premium_body)
	_build_premium_rewards(_premium_body)
	_build_premium_claim_row(_premium_body)

	_hint_label = Label.new()
	_hint_label.visible = false
	_hint_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_hint_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	_hint_label.add_theme_font_size_override(
		"font_size",
		12
	)
	_hint_label.add_theme_color_override(
		"font_color",
		MUTED
	)
	_premium_body.add_child(_hint_label)

	_modal_panel.modulate.a = 0.0
	var intro_tween: Tween = _modal_panel.create_tween()
	intro_tween.tween_property(
		_modal_panel,
		"modulate:a",
		1.0,
		0.12
	)

	SceneTransitionManager.set_back_handler(
		Callable(self, "_close_popup")
	)
	_refresh_popup()
	call_deferred("_fit_modal_to_content")


func _build_premium_header(
	parent: VBoxContainer
) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override(
		"separation",
		8
	)
	parent.add_child(header)

	var left_spacer := Control.new()
	left_spacer.custom_minimum_size = Vector2(
		42.0,
		42.0
	)
	header.add_child(left_spacer)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title_box.add_theme_constant_override(
		"separation",
		-1
	)
	header.add_child(title_box)

	var title := Label.new()
	title.text = tr("SPIRIT MEDITATION")
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		30
	)
	title.add_theme_color_override(
		"font_color",
		GOLD_BRIGHT
	)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = tr(
		"Refine Qi  •  Accumulate Resources  •  Even While Away"
	)
	subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	subtitle.add_theme_font_size_override(
		"font_size",
		14
	)
	subtitle.add_theme_color_override(
		"font_color",
		Color(0.83, 0.91, 0.88, 1.0)
	)
	title_box.add_child(subtitle)

	var close := Button.new()
	close.custom_minimum_size = Vector2(
		42.0,
		42.0
	)
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_filter = Control.MOUSE_FILTER_PASS
	close.action_mode = (
		BaseButton.ACTION_MODE_BUTTON_RELEASE
	)
	close.keep_pressed_outside = false
	close.add_theme_font_size_override(
		"font_size",
		24
	)
	close.add_theme_color_override(
		"font_color",
		GOLD_BRIGHT
	)
	close.add_theme_stylebox_override(
		"normal",
		_premium_panel_style(
			Color(0.002, 0.035, 0.045, 0.96),
			Color(0.96, 0.77, 0.32, 0.82),
			21,
			6
		)
	)
	close.pressed.connect(_close_popup)
	header.add_child(close)


func _build_premium_hero(
	parent: VBoxContainer
) -> void:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(
		0.0,
		334.0
	)
	frame.clip_contents = true
	frame.add_theme_stylebox_override(
		"panel",
		_premium_panel_style(
			Color(0.0, 0.018, 0.026, 0.96),
			Color(0.31, 0.89, 0.77, 0.62),
			18,
			8
		)
	)
	parent.add_child(frame)

	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	art.texture = _load_premium_hero_texture()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	shade.color = Color(0.0, 0.012, 0.018, 0.035)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(shade)

	var sanctum := Label.new()
	sanctum.anchor_left = 0.0
	sanctum.anchor_top = 1.0
	sanctum.anchor_right = 1.0
	sanctum.anchor_bottom = 1.0
	sanctum.offset_top = -32.0
	sanctum.offset_bottom = -7.0
	sanctum.text = tr("INNER SEA SANCTUM")
	sanctum.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	sanctum.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	sanctum.add_theme_font_size_override(
		"font_size",
		13
	)
	sanctum.add_theme_color_override(
		"font_color",
		Color(1.0, 0.90, 0.61, 0.95)
	)
	sanctum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(sanctum)


func _build_premium_status(
	parent: VBoxContainer
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		8
	)
	parent.add_child(row)

	var time_card: PanelContainer = (
		_premium_status_card(
			"ACCUMULATED TIME",
			GOLD_BRIGHT
		)
	)
	row.add_child(time_card)
	_time_label = (
		time_card.get_node("Body/Value") as Label
	)
	var time_note: Label = (
		time_card.get_node("Body/Note") as Label
	)
	if time_note != null:
		time_note.text = tr("12H OFFLINE CAP")

	var yield_card: PanelContainer = (
		_premium_status_card(
			"CURRENT SPIRITUAL YIELD",
			JADE_SOFT
		)
	)
	row.add_child(yield_card)
	_rate_label = (
		yield_card.get_node("Body/Value") as Label
	)
	_yield_note_label = (
		yield_card.get_node("Body/Note") as Label
	)


func _premium_status_card(
	heading_text: String,
	accent: Color
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	panel.custom_minimum_size = Vector2(
		0.0,
		92.0
	)
	panel.add_theme_stylebox_override(
		"panel",
		_premium_panel_style(
			Color(0.002, 0.032, 0.043, 0.97),
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.52
			),
			13,
			4
		)
	)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override(
		"separation",
		0
	)
	panel.add_child(body)

	var heading := Label.new()
	heading.text = tr(heading_text)
	heading.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	heading.add_theme_font_size_override(
		"font_size",
		12
	)
	heading.add_theme_color_override(
		"font_color",
		accent
	)
	body.add_child(heading)

	var value := Label.new()
	value.name = "Value"
	value.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	value.add_theme_font_size_override(
		"font_size",
		20
	)
	value.add_theme_color_override(
		"font_color",
		TEXT
	)
	body.add_child(value)

	var note := Label.new()
	note.name = "Note"
	note.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	note.add_theme_font_size_override(
		"font_size",
		11
	)
	note.add_theme_color_override(
		"font_color",
		MUTED
	)
	body.add_child(note)
	return panel


func _build_premium_rewards(
	parent: VBoxContainer
) -> void:
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override(
		"panel",
		_premium_panel_style(
			Color(0.005, 0.027, 0.034, 0.94),
			Color(0.95, 0.73, 0.27, 0.54),
			15,
			5
		)
	)
	parent.add_child(shell)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		4
	)
	shell.add_child(box)

	var heading := Label.new()
	heading.text = tr("ESTIMATED REWARDS")
	heading.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	heading.add_theme_font_size_override(
		"font_size",
		15
	)
	heading.add_theme_color_override(
		"font_color",
		GOLD_BRIGHT
	)
	box.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		5
	)
	box.add_child(row)

	var spirit_card: PanelContainer = (
		_premium_reward_card(
			REWARD_SPIRIT_FRAME,
			SPIRIT_ICON,
			"SPIRIT STONE"
		)
	)
	row.add_child(spirit_card)
	_spirit_reward_value = (
		spirit_card.get_node("Body/Value") as Label
	)

	var hero_card: PanelContainer = (
		_premium_reward_card(
			REWARD_HERO_FRAME,
			HERO_EXP_ICON,
			"HERO EXP"
		)
	)
	row.add_child(hero_card)
	_hero_reward_value = (
		hero_card.get_node("Body/Value") as Label
	)

	var shard_card: PanelContainer = (
		_premium_reward_card(
			REWARD_SHARD_FRAME,
			SHARD_ICON,
			"REFINEMENT"
		)
	)
	row.add_child(shard_card)
	_shard_reward_value = (
		shard_card.get_node("Body/Value") as Label
	)


func _premium_reward_card(
	frame_texture: Texture2D,
	icon_texture: Texture2D,
	label_text: String
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	panel.custom_minimum_size = Vector2(
		0.0,
		116.0
	)

	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override(
		"panel",
		transparent
	)

	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	frame.texture = frame_texture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override(
		"separation",
		-1
	)
	panel.add_child(body)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(
		44.0,
		44.0
	)
	icon.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER
	)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(icon)

	var value := Label.new()
	value.name = "Value"
	value.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	value.add_theme_font_size_override(
		"font_size",
		19
	)
	value.add_theme_color_override(
		"font_color",
		GOLD_BRIGHT
	)
	body.add_child(value)

	var name_label := Label.new()
	name_label.text = tr(label_text)
	name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	name_label.add_theme_font_size_override(
		"font_size",
		12
	)
	name_label.add_theme_color_override(
		"font_color",
		Color(0.83, 0.91, 0.88, 1.0)
	)
	body.add_child(name_label)
	return panel


func _build_premium_claim_row(
	parent: VBoxContainer
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		8
	)
	parent.add_child(row)

	_claim_button = _premium_cta(
		CLAIM_BLUE_FRAME,
		tr("CLAIM 1×"),
		Color(0.94, 0.99, 1.0, 1.0)
	)
	_claim_button.button_down.connect(
		_on_claim_button_down
	)
	_claim_button.pressed.connect(
		_on_safe_claim_pressed
	)
	row.add_child(_claim_button)

	_rewarded_button = _premium_cta(
		CLAIM_GOLD_FRAME,
		tr("WATCH AD  •  CLAIM 2×"),
		Color(0.19, 0.10, 0.015, 1.0)
	)
	_rewarded_button.button_down.connect(
		_on_rewarded_button_down
	)
	_rewarded_button.pressed.connect(
		_on_safe_rewarded_pressed
	)
	row.add_child(_rewarded_button)


func _premium_cta(
	frame_texture: Texture2D,
	text_value: String,
	font_color: Color
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(
		0.0,
		66.0
	)
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.action_mode = (
		BaseButton.ACTION_MODE_BUTTON_RELEASE
	)
	button.keep_pressed_outside = false
	button.add_theme_font_size_override(
		"font_size",
		17
	)
	button.add_theme_color_override(
		"font_color",
		font_color
	)
	button.add_theme_color_override(
		"font_hover_color",
		font_color
	)
	button.add_theme_color_override(
		"font_pressed_color",
		font_color
	)

	for state_name: String in [
		"normal",
		"hover",
		"pressed",
		"focus",
		"disabled",
	]:
		var transparent := StyleBoxFlat.new()
		transparent.bg_color = Color.TRANSPARENT
		button.add_theme_stylebox_override(
			state_name,
			transparent
		)

	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	frame.texture = frame_texture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.show_behind_parent = true
	button.add_child(frame)
	return button


func _on_claim_button_down() -> void:
	_claim_press_scroll_y = (
		_premium_scroll.scroll_vertical
		if _premium_scroll != null
		else 0
	)


func _on_rewarded_button_down() -> void:
	_rewarded_press_scroll_y = (
		_premium_scroll.scroll_vertical
		if _premium_scroll != null
		else 0
	)


func _on_safe_claim_pressed() -> void:
	if _gesture_became_scroll(
		_claim_press_scroll_y
	):
		return
	_on_claim_pressed()


func _on_safe_rewarded_pressed() -> void:
	if _gesture_became_scroll(
		_rewarded_press_scroll_y
	):
		return
	_on_rewarded_claim_pressed()


func _gesture_became_scroll(
	start_scroll_y: int
) -> bool:
	if _premium_scroll == null:
		return false
	return absi(
		_premium_scroll.scroll_vertical
		- start_scroll_y
	) >= MOBILE_SCROLL_DEADZONE


func _refresh_popup() -> void:
	if _popup == null or not is_instance_valid(_popup):
		return

	var seconds: int = int(
		manager.call("get_claimable_seconds")
	)
	var tier: int = int(
		manager.call("get_progress_tier")
	)
	var rates: Dictionary = manager.call(
		"get_rates_for_tier",
		tier
	)
	var preview: Dictionary = manager.call(
		"get_claim_preview"
	)

	var raw_reward: Variant = preview.get(
		"reward_data",
		{}
	)
	var reward: Dictionary = {}
	if raw_reward is Dictionary:
		reward = (
			raw_reward as Dictionary
		).duplicate(true)

	if _time_label != null:
		_time_label.text = (
			_format_clock_duration(seconds)
		)

	if _rate_label != null:
		_rate_label.text = "%d STONE / H" % int(
			rates.get(
				"spirit_stone_per_hour",
				0
			)
		)

	if _yield_note_label != null:
		_yield_note_label.text = (
			"%d HERO EXP / H"
			% int(
				rates.get(
					"hero_exp_per_hour",
					0
				)
			)
		)

	var spirit_amount: int = maxi(
		int(
			reward.get(
				RewardManager.REWARD_KEY_SPIRIT_STONE,
				0
			)
		),
		0
	)
	var hero_amount: int = maxi(
		int(
			reward.get(
				RewardManager.REWARD_KEY_HERO_EXP,
				0
			)
		),
		0
	)
	var shard_amount: int = 0
	var raw_items: Variant = reward.get(
		RewardManager.REWARD_KEY_ITEMS,
		{}
	)
	if raw_items is Dictionary:
		shard_amount = maxi(
			int(
				(raw_items as Dictionary).get(
					InventoryManager.REFINEMENT_SHARD,
					0
				)
			),
			0
		)

	if _spirit_reward_value != null:
		_spirit_reward_value.text = str(
			spirit_amount
		)
	if _hero_reward_value != null:
		_hero_reward_value.text = str(
			hero_amount
		)
	if _shard_reward_value != null:
		_shard_reward_value.text = str(
			shard_amount
		)

	if _hint_label != null:
		_hint_label.visible = (
			not _claim_message.is_empty()
		)
		_hint_label.text = _claim_message

	var is_ready: bool = (
		int(
			preview.get(
				"claim_units",
				0
			)
		) > 0
	)
	var rewarded_pending: bool = bool(
		manager.call(
			"has_pending_rewarded_double_claim"
		)
	)
	var request_active: bool = (
		MonetizationManager.is_rewarded_request_active(
			RewardedBridge.PLACEMENT_ID
		)
	)
	var save_locked: bool = (
		SaveManager.is_progress_read_only()
	)

	if _claim_button != null:
		_claim_button.disabled = (
			not is_ready
			or save_locked
			or rewarded_pending
			or request_active
		)
		_claim_button.text = (
			tr("CLAIM 1×")
			if is_ready
			else tr("GATHERING QI")
		)

	if _rewarded_button != null:
		_rewarded_button.disabled = true

		if not is_ready:
			_rewarded_button.text = tr(
				"2× AFTER 10M"
			)
		elif save_locked:
			_rewarded_button.text = tr(
				"2× AD UNAVAILABLE"
			)
		elif rewarded_pending or request_active:
			_rewarded_button.text = tr(
				"AD PLAYING..."
			)
		else:
			var policy: Dictionary = (
				MonetizationManager.get_rewarded_policy_status(
					RewardedBridge.PLACEMENT_ID
				)
			)
			var placement_claims: int = int(
				policy.get(
					"placement_claims",
					0
				)
			)
			var daily_limit: int = int(
				policy.get(
					"daily_limit",
					1
				)
			)
			var cooldown_remaining: int = int(
				policy.get(
					"cooldown_remaining_seconds",
					0
				)
			)

			if placement_claims >= daily_limit:
				_rewarded_button.text = tr(
					"2× CLAIMED TODAY"
				)
			elif cooldown_remaining > 0:
				_rewarded_button.text = (
					tr("2× AD • %dS")
					% cooldown_remaining
				)
			elif bool(
				policy.get(
					"available",
					false
				)
			):
				_rewarded_button.text = tr(
					"WATCH AD  •  CLAIM 2×"
				)
				_rewarded_button.disabled = false
			else:
				var runtime: Dictionary = (
					MonetizationManager.get_provider_runtime_status()
				)
				var provider_state: String = str(
					runtime.get(
						"state",
						""
					)
				)
				if provider_state in [
					"consent_updating",
					"consent_form_loading",
					"consent_form_showing",
					"ads_initializing",
					"ads_initialized",
					"rewarded_loading",
				]:
					_rewarded_button.text = tr(
						"2× AD • PREPARING"
					)
				else:
					_rewarded_button.text = tr(
						"2× AD UNAVAILABLE"
					)

	call_deferred("_fit_modal_to_content")


func _fit_modal_to_content() -> void:
	if (
		_modal_panel == null
		or not is_instance_valid(_modal_panel)
		or _premium_scroll == null
		or _premium_body == null
	):
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var desired_height: float = ceilf(
		_premium_body.get_combined_minimum_size().y
		+ 22.0
	)
	var available_height: float = maxf(
		get_viewport().get_visible_rect().size.y
		- 178.0,
		420.0
	)
	var final_height: float = minf(
		desired_height,
		available_height
	)
	var half_height: float = final_height * 0.5

	_modal_panel.offset_top = -half_height
	_modal_panel.offset_bottom = half_height

	var needs_scroll: bool = (
		desired_height
		> available_height + 1.0
	)
	if needs_scroll:
		_premium_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_SHOW_NEVER
			if (
				OS.has_feature("android")
				or OS.has_feature("ios")
			)
			else ScrollContainer.SCROLL_MODE_AUTO
		)
		_make_premium_scroll_tree_touch_safe(
			_premium_body
		)
	else:
		_premium_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_DISABLED
		)


func _make_premium_scroll_tree_touch_safe(
	root: Node
) -> void:
	for child: Node in root.get_children():
		if child is Button:
			var button := child as Button
			button.mouse_filter = (
				Control.MOUSE_FILTER_PASS
			)
			button.action_mode = (
				BaseButton.ACTION_MODE_BUTTON_RELEASE
			)
			button.keep_pressed_outside = false
		elif (
			child is Label
			or child is TextureRect
		):
			(child as Control).mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
		elif child is Control:
			var control := child as Control
			if (
				control.mouse_filter
				== Control.MOUSE_FILTER_STOP
			):
				control.mouse_filter = (
					Control.MOUSE_FILTER_PASS
				)

		_make_premium_scroll_tree_touch_safe(child)


func _format_clock_duration(
	seconds: int
) -> String:
	var safe_seconds: int = maxi(
		seconds,
		0
	)
	var hours: int = floori(
		float(safe_seconds) / 3600.0
	)
	var minutes: int = floori(
		float(safe_seconds % 3600) / 60.0
	)
	var remaining_seconds: int = safe_seconds % 60
	return "%02d:%02d:%02d" % [
		hours,
		minutes,
		remaining_seconds,
	]


func _load_premium_hero_texture() -> Texture2D:
	if _cached_hero_texture != null:
		return _cached_hero_texture

	var image_path: String = (
		"res://assets/ui/meditation/premium_popup/"
		+ "meditation_hero_sanctum.png"
	)

	# Load through Godot's imported resource pipeline so the texture is
	# packaged correctly in exported Android/iOS builds.
	var loaded_resource: Resource = ResourceLoader.load(
		image_path,
		"Texture2D",
		ResourceLoader.CACHE_MODE_REUSE
	)
	if loaded_resource is not Texture2D:
		return MEDITATION_ICON

	_cached_hero_texture = loaded_resource as Texture2D
	return _cached_hero_texture


func _show_claim_result(
	reward_data: Dictionary
) -> void:
	var unified_presenter: Node = get_node_or_null(
		"/root/RewardClaimResultPresenter"
	)
	if unified_presenter != null:
		return

	# Safety fallback for unusual boot contexts.
	super._show_claim_result(reward_data)



func _close_popup() -> void:
	super._close_popup()
	_premium_scroll = null
	_premium_body = null
	_yield_note_label = null
	_spirit_reward_value = null
	_hero_reward_value = null
	_shard_reward_value = null


func _premium_panel_style(
	background: Color,
	border: Color,
	radius: int,
	shadow_size: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.58
	)
	style.shadow_size = shadow_size
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style
