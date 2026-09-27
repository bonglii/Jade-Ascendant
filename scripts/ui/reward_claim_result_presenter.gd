extends Node

## UNIVERSAL REWARD CLAIM RESULT PRESENTER
## Presentation-only.
##
## Standardizes explicit reward-claim confirmation across Meditation,
## Trials, 7-Day Login, Mail, and Hero Milestones.
##
## RewardManager / source managers remain authoritative for grant, save,
## duplicate protection, inventory, progression, and economy.

const CLAIM_BUFFER_SECONDS: float = 0.14
const DELIVERY_SETTLE_SECONDS: float = 0.78
const MOBILE_SCROLL_DEADZONE: int = 6

const CLAIM_BLUE_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/claim_blue.png"
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
const GENERIC_REWARD_ICON: Texture2D = preload(
	"res://assets/ui/pavilion/icons/reward_chest.png"
)

const GOLD: Color = Color(0.96, 0.76, 0.32, 1.0)
const GOLD_BRIGHT: Color = Color(1.0, 0.88, 0.54, 1.0)
const JADE: Color = Color(0.29, 0.91, 0.76, 1.0)
const JADE_SOFT: Color = Color(0.47, 0.98, 0.87, 1.0)
const TEXT: Color = Color(0.95, 0.99, 0.97, 1.0)
const MUTED: Color = Color(0.71, 0.82, 0.79, 1.0)

var _pending_entries: Array[Dictionary] = []
var _pending_elapsed: float = 0.0
var _result_queue: Array[Dictionary] = []
var _queue_elapsed: float = 0.0

var _popup: Control = null
var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _body: VBoxContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if (
		is_instance_valid(RewardManager)
		and not RewardManager.reward_granted.is_connected(
			_on_reward_granted
		)
	):
		RewardManager.reward_granted.connect(
			_on_reward_granted
		)


func _process(delta: float) -> void:
	if not _pending_entries.is_empty():
		_pending_elapsed += delta
		if _pending_elapsed >= CLAIM_BUFFER_SECONDS:
			_flush_pending_claims()

	if _popup != null and is_instance_valid(_popup):
		return
	if _result_queue.is_empty():
		_queue_elapsed = 0.0
		return

	_queue_elapsed += delta
	if _queue_elapsed < DELIVERY_SETTLE_SECONDS:
		return
	_queue_elapsed = 0.0
	_show_next_result()


func _on_reward_granted(
	source_type: String,
	source_id: String,
	reward_data: Dictionary
) -> void:
	if not _is_explicit_claim_source(
		source_type,
		source_id
	):
		return

	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var applied_reward: Dictionary = _get_applied_reward(
		source_type,
		source_id,
		reward_data
	)

	_pending_entries.append({
		"scene_id": int(scene.get_instance_id()),
		"source_label": _get_source_label(
			source_type,
			source_id
		),
		"reward_data": applied_reward,
	})
	_pending_elapsed = 0.0


func show_claimed_reward(
	source_label: String,
	reward_data: Dictionary
) -> void:
	# Public hook for future explicit claim systems that do not route through
	# RewardManager (for example a future verified store-delivery summary).
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	_pending_entries.append({
		"scene_id": int(scene.get_instance_id()),
		"source_label": source_label,
		"reward_data": reward_data.duplicate(true),
	})
	_pending_elapsed = 0.0


func _is_explicit_claim_source(
	source_type: String,
	source_id: String
) -> bool:
	if source_type in [
		RewardManager.SOURCE_DAILY_QUEST,
		RewardManager.SOURCE_ACHIEVEMENT,
		RewardManager.SOURCE_HERO_MILESTONE,
		RewardManager.SOURCE_IDLE_CULTIVATION,
	]:
		return true

	if source_type == RewardManager.SOURCE_PAVILION:
		return (
			source_id.begins_with("live_ops_login_day_")
			or source_id.begins_with("live_ops_mail_")
		)

	return false


func _get_source_label(
	source_type: String,
	source_id: String
) -> String:
	if source_type == RewardManager.SOURCE_IDLE_CULTIVATION:
		return tr("SPIRIT MEDITATION")
	if source_type == RewardManager.SOURCE_DAILY_QUEST:
		return tr("DAILY TRIALS")
	if source_type == RewardManager.SOURCE_ACHIEVEMENT:
		return tr("ACHIEVEMENT")
	if source_type == RewardManager.SOURCE_HERO_MILESTONE:
		return tr("HERO MILESTONE")
	if source_type == RewardManager.SOURCE_PAVILION:
		if source_id.begins_with("live_ops_login_day_"):
			return tr("7-DAY LOGIN")
		if source_id.begins_with("live_ops_mail_"):
			return tr("MAIL ATTACHMENT")
	return tr("REWARD")


func _get_applied_reward(
	source_type: String,
	source_id: String,
	fallback_reward: Dictionary
) -> Dictionary:
	var result: Dictionary = RewardManager.get_last_grant_result()
	if (
		bool(result.get("success", false))
		and str(result.get("source_type", "")) == source_type
		and str(result.get("source_id", "")) == source_id
	):
		var raw_applied: Variant = result.get(
			"applied_reward_data",
			{}
		)
		if raw_applied is Dictionary:
			return (
				raw_applied as Dictionary
			).duplicate(true)

	return fallback_reward.duplicate(true)


func _flush_pending_claims() -> void:
	if _pending_entries.is_empty():
		return

	var first_entry: Dictionary = _pending_entries[0]
	var scene_id: int = int(
		first_entry.get("scene_id", 0)
	)
	var source_label: String = str(
		first_entry.get(
			"source_label",
			tr("REWARD")
		)
	)
	var merged_reward: Dictionary = (
		RewardManager.create_reward_data()
	)
	var claim_count: int = 0

	for entry: Dictionary in _pending_entries:
		if int(entry.get("scene_id", 0)) != scene_id:
			continue

		var raw_reward: Variant = entry.get(
			"reward_data",
			{}
		)
		if raw_reward is Dictionary:
			merged_reward = _merge_rewards(
				merged_reward,
				raw_reward as Dictionary
			)
			claim_count += 1

		var entry_source: String = str(
			entry.get("source_label", "")
		)
		if (
			not entry_source.is_empty()
			and entry_source != source_label
		):
			source_label = tr("MULTIPLE REWARDS")

	_result_queue.append({
		"scene_id": scene_id,
		"source_label": source_label,
		"reward_data": merged_reward,
		"claim_count": claim_count,
	})

	_pending_entries.clear()
	_pending_elapsed = 0.0
	_queue_elapsed = 0.0


func _merge_rewards(
	current: Dictionary,
	addition: Dictionary
) -> Dictionary:
	var spirit_total: int = maxi(
		int(current.get(
			RewardManager.REWARD_KEY_SPIRIT_STONE,
			0
		)),
		0
	) + maxi(
		int(addition.get(
			RewardManager.REWARD_KEY_SPIRIT_STONE,
			0
		)),
		0
	)

	var hero_total: int = maxi(
		int(current.get(
			RewardManager.REWARD_KEY_HERO_EXP,
			0
		)),
		0
	) + maxi(
		int(addition.get(
			RewardManager.REWARD_KEY_HERO_EXP,
			0
		)),
		0
	)

	var merged_items: Dictionary = {}
	var current_items_raw: Variant = current.get(
		RewardManager.REWARD_KEY_ITEMS,
		{}
	)
	if current_items_raw is Dictionary:
		for raw_id: Variant in (
			current_items_raw as Dictionary
		).keys():
			var item_id: String = str(raw_id)
			merged_items[item_id] = maxi(
				int(
					(current_items_raw as Dictionary).get(
						raw_id,
						0
					)
				),
				0
			)

	var added_items_raw: Variant = addition.get(
		RewardManager.REWARD_KEY_ITEMS,
		{}
	)
	if added_items_raw is Dictionary:
		for raw_id: Variant in (
			added_items_raw as Dictionary
		).keys():
			var item_id: String = str(raw_id)
			merged_items[item_id] = (
				int(merged_items.get(item_id, 0))
				+ maxi(
					int(
						(added_items_raw as Dictionary).get(
							raw_id,
							0
						)
					),
					0
				)
			)

	return RewardManager.create_reward_data(
		spirit_total,
		merged_items,
		hero_total
	)


func _show_next_result() -> void:
	if _result_queue.is_empty():
		return

	var result: Dictionary = _result_queue.pop_front()
	var scene: Node = get_tree().current_scene
	if scene == null:
		_show_next_result()
		return

	var expected_scene_id: int = int(
		result.get("scene_id", 0)
	)
	if int(scene.get_instance_id()) != expected_scene_id:
		_show_next_result()
		return

	var reward_data_raw: Variant = result.get(
		"reward_data",
		{}
	)
	var reward_data: Dictionary = {}
	if reward_data_raw is Dictionary:
		reward_data = (
			reward_data_raw as Dictionary
		).duplicate(true)

	_build_result_popup(
		scene,
		str(
			result.get(
				"source_label",
				tr("REWARD")
			)
		),
		reward_data,
		maxi(
			int(result.get("claim_count", 1)),
			1
		)
	)


func _build_result_popup(
	scene: Node,
	source_label: String,
	reward_data: Dictionary,
	claim_count: int
) -> void:
	_close_popup()

	_popup = Control.new()
	_popup.name = "UnifiedRewardClaimPopup"
	_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	_popup.z_index = 220
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	scene.add_child(_popup)
	_popup.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	scrim.color = Color(0.0, 0.0, 0.0, 0.62)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	_popup.add_child(scrim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.10
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.90
	_panel.anchor_bottom = 0.5
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.002, 0.023, 0.030, 0.995),
			Color(0.97, 0.77, 0.31, 0.92),
			20,
			18
		)
	)
	_popup.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		14
	)
	margin.add_theme_constant_override(
		"margin_top",
		12
	)
	margin.add_theme_constant_override(
		"margin_right",
		14
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		12
	)
	_panel.add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	_scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	_scroll.scroll_deadzone = MOBILE_SCROLL_DEADZONE
	_scroll.follow_focus = false
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_child(_scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	_body.add_theme_constant_override(
		"separation",
		8
	)
	_scroll.add_child(_body)

	var eyebrow := Label.new()
	eyebrow.text = source_label
	eyebrow.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	eyebrow.add_theme_font_size_override(
		"font_size",
		13
	)
	eyebrow.add_theme_color_override(
		"font_color",
		JADE_SOFT
	)
	_body.add_child(eyebrow)

	var title := Label.new()
	title.text = (
		tr("REWARDS CLAIMED")
		if claim_count > 1
		else tr("REWARD CLAIMED")
	)
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		27
	)
	title.add_theme_color_override(
		"font_color",
		GOLD_BRIGHT
	)
	_body.add_child(title)

	var divider := HSeparator.new()
	divider.add_theme_constant_override(
		"separation",
		3
	)
	_body.add_child(divider)

	var heading := Label.new()
	heading.text = tr("REWARDS RECEIVED")
	heading.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	heading.add_theme_font_size_override(
		"font_size",
		14
	)
	heading.add_theme_color_override(
		"font_color",
		Color(0.78, 0.90, 0.86, 1.0)
	)
	_body.add_child(heading)

	var reward_grid := GridContainer.new()
	reward_grid.columns = 3
	reward_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	reward_grid.add_theme_constant_override(
		"h_separation",
		6
	)
	reward_grid.add_theme_constant_override(
		"v_separation",
		6
	)
	_body.add_child(reward_grid)

	_add_reward_cards(
		reward_grid,
		reward_data
	)

	var saved := Label.new()
	saved.text = tr(
		"Reward secured and saved to your progression."
	)
	saved.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	saved.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	saved.add_theme_font_size_override(
		"font_size",
		12
	)
	saved.add_theme_color_override(
		"font_color",
		MUTED
	)
	_body.add_child(saved)

	var continue_button := _premium_continue_button()
	continue_button.pressed.connect(_close_popup)
	_body.add_child(continue_button)

	SceneTransitionManager.set_back_handler(
		Callable(self, "_close_popup")
	)

	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	_panel.pivot_offset = Vector2(
		_panel.size.x * 0.5,
		_panel.size.y * 0.5
	)
	var tween: Tween = _panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		_panel,
		"modulate:a",
		1.0,
		0.14
	)
	tween.tween_property(
		_panel,
		"scale",
		Vector2.ONE,
		0.18
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	call_deferred("_fit_popup_to_content")


func _add_reward_cards(
	grid: GridContainer,
	reward_data: Dictionary
) -> void:
	var card_count: int = 0

	var spirit_amount: int = maxi(
		int(reward_data.get(
			RewardManager.REWARD_KEY_SPIRIT_STONE,
			0
		)),
		0
	)
	if spirit_amount > 0:
		grid.add_child(
			_reward_card(
				REWARD_SPIRIT_FRAME,
				SPIRIT_ICON,
				tr("SPIRIT STONE"),
				spirit_amount,
				GOLD_BRIGHT
			)
		)
		card_count += 1

	var hero_amount: int = maxi(
		int(reward_data.get(
			RewardManager.REWARD_KEY_HERO_EXP,
			0
		)),
		0
	)
	if hero_amount > 0:
		grid.add_child(
			_reward_card(
				REWARD_HERO_FRAME,
				HERO_EXP_ICON,
				tr("HERO EXP"),
				hero_amount,
				JADE_SOFT
			)
		)
		card_count += 1

	var raw_items: Variant = reward_data.get(
		RewardManager.REWARD_KEY_ITEMS,
		{}
	)
	if raw_items is Dictionary:
		var item_ids: Array[String] = []
		for raw_item_id: Variant in (
			raw_items as Dictionary
		).keys():
			item_ids.append(str(raw_item_id))
		item_ids.sort()

		for item_id: String in item_ids:
			var amount: int = maxi(
				int(
					(raw_items as Dictionary).get(
						item_id,
						0
					)
				),
				0
			)
			if amount <= 0:
				continue

			var display_name: String = item_id
			var icon_texture: Texture2D = (
				GENERIC_REWARD_ICON
			)
			var frame_texture: Texture2D = (
				REWARD_SHARD_FRAME
			)
			var accent: Color = Color(
				0.72,
				0.86,
				1.0,
				1.0
			)

			if item_id == InventoryManager.REFINEMENT_SHARD:
				display_name = tr(
					"REFINEMENT SHARD"
				)
				icon_texture = SHARD_ICON
				accent = Color(
					0.68,
					0.86,
					1.0,
					1.0
				)
			elif InventoryManager.is_known_item(item_id):
				var item_data: Dictionary = (
					InventoryManager.get_item_data(item_id)
				)
				display_name = tr(
					str(
						item_data.get(
							"display_name",
							item_id
						)
					)
				).to_upper()

			grid.add_child(
				_reward_card(
					frame_texture,
					icon_texture,
					display_name,
					amount,
					accent
				)
			)
			card_count += 1

	if card_count <= 0:
		var empty := Label.new()
		empty.text = tr("REWARD SECURED")
		empty.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		empty.add_theme_font_size_override(
			"font_size",
			16
		)
		empty.add_theme_color_override(
			"font_color",
			TEXT
		)
		grid.add_child(empty)


func _reward_card(
	frame_texture: Texture2D,
	icon_texture: Texture2D,
	label_text: String,
	amount: int,
	accent: Color
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	panel.custom_minimum_size = Vector2(
		0.0,
		122.0
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
	frame.offset_left = -2.0
	frame.offset_top = -8.0
	frame.offset_right = 2.0
	frame.offset_bottom = 4.0
	frame.texture = frame_texture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)

	var content_margin := MarginContainer.new()
	content_margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	content_margin.add_theme_constant_override(
		"margin_left",
		8
	)
	content_margin.add_theme_constant_override(
		"margin_top",
		4
	)
	content_margin.add_theme_constant_override(
		"margin_right",
		8
	)
	content_margin.add_theme_constant_override(
		"margin_bottom",
		8
	)
	panel.add_child(content_margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	body.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override(
		"separation",
		-1
	)
	content_margin.add_child(body)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(
		46.0,
		46.0
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
	value.text = "+%d" % maxi(amount, 0)
	value.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	value.add_theme_font_size_override(
		"font_size",
		21
	)
	value.add_theme_color_override(
		"font_color",
		accent
	)
	body.add_child(value)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	name_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	name_label.add_theme_font_size_override(
		"font_size",
		12
	)
	name_label.add_theme_color_override(
		"font_color",
		Color(0.84, 0.92, 0.89, 1.0)
	)
	body.add_child(name_label)
	return panel


func _premium_continue_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(
		0.0,
		62.0
	)
	button.text = tr("CONTINUE")
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.action_mode = (
		BaseButton.ACTION_MODE_BUTTON_RELEASE
	)
	button.keep_pressed_outside = false
	button.add_theme_font_size_override(
		"font_size",
		18
	)
	button.add_theme_color_override(
		"font_color",
		Color(0.94, 0.99, 1.0, 1.0)
	)

	for state_name: String in [
		"normal",
		"hover",
		"pressed",
		"focus",
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
	frame.texture = CLAIM_BLUE_FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.show_behind_parent = true
	button.add_child(frame)
	return button


func _fit_popup_to_content() -> void:
	if (
		_panel == null
		or not is_instance_valid(_panel)
		or _scroll == null
		or _body == null
	):
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var desired_height: float = ceilf(
		_body.get_combined_minimum_size().y
		+ 24.0
	)
	var available_height: float = maxf(
		get_viewport().get_visible_rect().size.y
		- 180.0,
		420.0
	)
	var final_height: float = minf(
		desired_height,
		available_height
	)
	var half_height: float = final_height * 0.5

	_panel.offset_top = -half_height
	_panel.offset_bottom = half_height
	_panel.pivot_offset = Vector2(
		_panel.size.x * 0.5,
		final_height * 0.5
	)

	var needs_scroll: bool = (
		desired_height > available_height + 1.0
	)
	if needs_scroll:
		_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_SHOW_NEVER
			if (
				OS.has_feature("android")
				or OS.has_feature("ios")
			)
			else ScrollContainer.SCROLL_MODE_AUTO
		)
		_make_scroll_tree_touch_safe(_body)
	else:
		_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_DISABLED
		)


func _make_scroll_tree_touch_safe(
	root: Node
) -> void:
	for child: Node in root.get_children():
		if child is Button:
			var button := child as Button
			button.mouse_filter = Control.MOUSE_FILTER_PASS
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

		_make_scroll_tree_touch_safe(child)


func _on_scrim_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
	) or (
		event is InputEventScreenTouch
		and (event as InputEventScreenTouch).pressed
	):
		_close_popup()


func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()

	_popup = null
	_panel = null
	_scroll = null
	_body = null

	var scene: Node = get_tree().current_scene
	if (
		scene != null
		and scene.has_method("handle_system_back")
	):
		SceneTransitionManager.set_back_handler(
			Callable(scene, "handle_system_back")
		)
	else:
		SceneTransitionManager.set_back_handler(
			Callable()
		)

	_queue_elapsed = 0.0


func _panel_style(
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
