extends Control

## HEAVENLY LADDER — EVENT CONTENT EXPANSION E4
## Presentation/input only. JourneyManager remains progress authority,
## LiveOpsManager owns claims, and RewardManager owns reward delivery.

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")
const JourneyArtCatalog = preload(
	"res://scripts/ui/journey_art_catalog.gd"
)
const EVENT_ID: String = "heavenly_ladder"
const EVENT_ICON: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/event_center_premium.png"
)

const GOLD: Color = Color(0.95, 0.75, 0.31, 1.0)
const JADE: Color = Color(0.34, 0.89, 0.72, 1.0)
const SKY: Color = Color(0.58, 0.79, 1.0, 1.0)
const MUTED: Color = Color(0.74, 0.84, 0.82, 1.0)

var _live_ops: Node = null
var _content: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_live_ops = get_node_or_null("/root/LiveOpsManager")
	if _live_ops == null:
		push_error("HeavenlyLadderScreen: LiveOpsManager unavailable.")
		return
	var event: Dictionary = _live_ops.call("get_event", EVENT_ID)
	if event.is_empty():
		push_error("HeavenlyLadderScreen: event catalog entry missing.")
		return
	var event_background := _load_event_background()
	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("LADDER EVENT"),
		tr(str(event.get("title", "HEAVENLY LADDER"))),
		tr(str(event.get("description", ""))),
		EVENT_ICON,
		SKY,
		event_background
	)
	_content = shell.get("content") as VBoxContainer
	var back_button: Button = shell.get("back_button") as Button
	if not bool(get_meta("liveops_popup", false)) and is_instance_valid(back_button):
		back_button.pressed.connect(_back)
	var callback := Callable(self, "_on_live_ops_changed")
	if _live_ops.has_signal("live_ops_changed") and not _live_ops.is_connected(
		"live_ops_changed",
		callback
	):
		_live_ops.connect("live_ops_changed", callback)
	SceneTransitionManager.set_back_handler(_back)
	_refresh()


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_TRANSLATION_CHANGED
		and is_inside_tree()
		and is_instance_valid(_content)
	):
		call_deferred("_refresh")


func _on_live_ops_changed() -> void:
	if is_inside_tree() and is_instance_valid(_content):
		_refresh()


func _refresh() -> void:
	if _live_ops == null or not is_instance_valid(_content):
		return

	LiveOpsUi.clear_container(_content)

	var milestone_ids: Array = _live_ops.call(
		"get_heavenly_ladder_milestone_ids"
	)
	var cleared_count: int = int(
		_live_ops.call("get_heavenly_ladder_cleared_stage_count")
	)
	var total_stages: int = int(
		_live_ops.call("get_heavenly_ladder_total_stage_count")
	)
	var claimed_count: int = int(
		_live_ops.call("get_heavenly_ladder_claimed_count")
	)
	var claimable_count: int = int(
		_live_ops.call("get_heavenly_ladder_claimable_count")
	)

	_build_ladder_dashboard(
		cleared_count,
		total_stages,
		claimed_count,
		claimable_count,
		milestone_ids.size()
	)
	_build_ladder_route_heading()

	var focus_id: String = ""
	for raw_id: Variant in milestone_ids:
		var milestone: Dictionary = _live_ops.call(
			"get_heavenly_ladder_milestone",
			str(raw_id)
		)
		if milestone.is_empty():
			continue
		if not bool(milestone.get("claimed", false)):
			focus_id = str(raw_id)
			break

	for index: int in milestone_ids.size():
		var milestone_id: String = str(milestone_ids[index])
		_build_ladder_checkpoint(
			milestone_id,
			index,
			milestone_ids.size(),
			cleared_count,
			milestone_id == focus_id
		)


func _build_ladder_dashboard(
	cleared_count: int,
	total_stages: int,
	claimed_count: int,
	claimable_count: int,
	milestone_count: int
) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := LiveOpsUi.make_panel_style(
		Color(0.010, 0.030, 0.052, 0.90),
		Color(SKY.r, SKY.g, SKY.b, 0.84),
		15
	)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	_content.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)

	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 8)
	body.add_child(heading)

	var title := LiveOpsUi.add_label(
		heading,
		tr("ASCENSION RUNGS"),
		12,
		SKY
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var metric := LiveOpsUi.add_label(
		heading,
		"%d / %d" % [cleared_count, total_stages],
		21,
		GOLD
	)
	metric.custom_minimum_size = Vector2(76.0, 30.0)
	metric.size_flags_horizontal = Control.SIZE_SHRINK_END
	metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metric.autowrap_mode = TextServer.AUTOWRAP_OFF

	LiveOpsUi.add_progress_meter(
		body,
		cleared_count,
		total_stages,
		SKY
	)

	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 7)
	body.add_child(stats)

	var ready_text := tr("%d REWARD READY") % claimable_count
	if claimable_count != 1:
		ready_text = tr("%d REWARDS READY") % claimable_count

	_build_ladder_status_pill(
		stats,
		ready_text,
		GOLD,
		claimable_count > 0
	)
	_build_ladder_status_pill(
		stats,
		tr("%d / %d CLAIMED") % [
			claimed_count,
			milestone_count,
		],
		JADE,
		false
	)


func _build_ladder_status_pill(
	parent: HBoxContainer,
	text_value: String,
	accent: Color,
	strong: bool
) -> void:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.custom_minimum_size.y = 31.0

	var background := Color(0.004, 0.020, 0.032, 0.94)
	var border_alpha: float = 0.44
	if strong:
		background = Color(0.070, 0.055, 0.014, 0.98)
		border_alpha = 0.86

	var style := LiveOpsUi.make_panel_style(
		background,
		Color(accent.r, accent.g, accent.b, border_alpha),
		9
	)
	style.shadow_size = 0
	pill.add_theme_stylebox_override("panel", style)
	parent.add_child(pill)

	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", accent)
	pill.add_child(label)


func _build_ladder_route_heading() -> void:
	var backing := PanelContainer.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.custom_minimum_size.y = 28.0
	var style := LiveOpsUi.make_panel_style(
		Color(0.004, 0.014, 0.026, 0.78),
		Color(0.0, 0.0, 0.0, 0.0),
		7
	)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.shadow_size = 0
	backing.add_theme_stylebox_override("panel", style)
	_content.add_child(backing)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	backing.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var title := LiveOpsUi.add_label(
		row,
		tr("HEAVENLY ASCENT"),
		12,
		SKY
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF

	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(54.0, 2.0)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color = Color(SKY.r, SKY.g, SKY.b, 0.54)
	row.add_child(rule)


func _build_ladder_checkpoint(
	milestone_id: String,
	index: int,
	total_count: int,
	cleared_count: int,
	is_focus: bool
) -> void:
	var milestone: Dictionary = _live_ops.call(
		"get_heavenly_ladder_milestone",
		milestone_id
	)
	if milestone.is_empty():
		return

	var unlocked: bool = bool(milestone.get("unlocked", false))
	var claimed: bool = bool(milestone.get("claimed", false))
	var required_clears: int = int(
		milestone.get("required_clears", 0)
	)
	var title_text: String = tr(
		str(milestone.get("title", milestone_id))
	)
	var chapter_id: int = _ladder_chapter_for_clears(
		required_clears
	)

	if claimed:
		_build_compact_ladder_checkpoint(
			chapter_id,
			index,
			total_count,
			title_text,
			tr("CLAIMED"),
			"claimed",
			-1,
			-1
		)
		return

	if not is_focus:
		var compact_state_text := tr("LOCKED")
		var compact_state_id := "locked"
		if unlocked:
			compact_state_text = tr("READY")
			compact_state_id = "ready"

		_build_compact_ladder_checkpoint(
			chapter_id,
			index,
			total_count,
			title_text,
			compact_state_text,
			compact_state_id,
			mini(cleared_count, required_clears),
			required_clears
		)
		return

	_build_focus_ladder_checkpoint(
		milestone_id,
		milestone,
		chapter_id,
		index,
		total_count,
		cleared_count,
		required_clears,
		unlocked,
		title_text
	)


func _build_compact_ladder_checkpoint(
	chapter_id: int,
	index: int,
	total_count: int,
	title_text: String,
	state_text: String,
	state_id: String,
	progress_value: int,
	progress_total: int
) -> void:
	var accent := Color(JADE.r, JADE.g, JADE.b, 0.66)
	if state_id == "ready":
		accent = GOLD
	elif state_id == "locked":
		accent = Color(SKY.r, SKY.g, SKY.b, 0.46)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	_content.add_child(row)

	_build_ladder_rail(
		row,
		chapter_id,
		index,
		total_count,
		accent,
		state_id
	)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 70.0

	var style := LiveOpsUi.make_panel_style(
		Color(0.004, 0.017, 0.025, 0.92),
		Color(accent.r, accent.g, accent.b, 0.44),
		12
	)
	style.border_width_left = 2
	style.shadow_size = 2
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)

	_add_ladder_thumbnail(
		content,
		chapter_id,
		state_id
	)

	var details := VBoxContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 1)
	content.add_child(details)

	var marker := LiveOpsUi.add_label(
		details,
		tr("ASCENT %02d") % (index + 1),
		9,
		Color(SKY.r, SKY.g, SKY.b, 0.72)
	)
	marker.autowrap_mode = TextServer.AUTOWRAP_OFF

	var title := LiveOpsUi.add_label(
		details,
		title_text,
		13,
		accent
	)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var line_text: String = state_text
	if progress_total > 0:
		if state_id == "ready":
			line_text = tr("READY - %d / %d") % [
				progress_value,
				progress_total,
			]
		else:
			line_text = tr("PROGRESS %d / %d") % [
				progress_value,
				progress_total,
			]
	var state := LiveOpsUi.add_label(
		details,
		line_text,
		10,
		accent
	)
	state.autowrap_mode = TextServer.AUTOWRAP_OFF


func _build_focus_ladder_checkpoint(
	milestone_id: String,
	milestone: Dictionary,
	chapter_id: int,
	index: int,
	total_count: int,
	cleared_count: int,
	required_clears: int,
	unlocked: bool,
	title_text: String
) -> void:
	var reward: Dictionary = milestone.get("reward", {})
	var items: Dictionary = reward.get("items", {})
	var stone_count: int = int(reward.get("spirit_stone", 0))
	var shard_count: int = int(items.get("refinement_shard", 0))

	var state_id := "active"
	var state_text := tr("ASCENDING")
	var accent := SKY
	if unlocked:
		state_id = "ready"
		state_text = tr("READY")
		accent = GOLD

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	_content.add_child(row)

	_build_ladder_rail(
		row,
		chapter_id,
		index,
		total_count,
		accent,
		state_id
	)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var background := Color(0.010, 0.030, 0.052, 0.94)
	var edge := SKY
	var shadow_size: int = 8
	if unlocked:
		background = Color(0.064, 0.050, 0.012, 0.96)
		edge = GOLD
		shadow_size = 14

	var style := LiveOpsUi.make_panel_style(
		background,
		Color(edge.r, edge.g, edge.b, 0.94),
		15
	)
	style.border_width_left = 4
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_size = shadow_size
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 7)
	margin.add_child(body)

	_build_ladder_stage_preview(
		body,
		chapter_id,
		index,
		title_text,
		state_text,
		accent
	)

	var progress_value: int = mini(
		cleared_count,
		required_clears
	)
	var progress_text := LiveOpsUi.add_label(
		body,
		tr("JOURNEY STAGES %d / %d") % [
			progress_value,
			required_clears,
		],
		11,
		MUTED
	)
	progress_text.autowrap_mode = TextServer.AUTOWRAP_OFF

	LiveOpsUi.add_progress_meter(
		body,
		progress_value,
		required_clears,
		accent
	)

	var reward_text: String = "%d %s" % [
		stone_count,
		tr("SPIRIT STONES"),
	]
	if shard_count > 0:
		reward_text += "  |  %d %s" % [
			shard_count,
			tr("REFINEMENT SHARDS"),
		]

	LiveOpsUi.add_info_strip(
		body,
		"+  " + reward_text,
		GOLD,
		unlocked
	)

	var button_text := tr("CLEAR %d JOURNEY STAGES") % required_clears
	var callback := Callable()
	var primary := false
	var disabled := true
	if unlocked:
		button_text = tr("CLAIM REWARD")
		callback = Callable(self, "_claim").bind(milestone_id)
		primary = true
		disabled = false

	var action := LiveOpsUi.add_action_button(
		body,
		button_text,
		callback,
		primary
	)
	action.custom_minimum_size.y = 52.0
	action.disabled = disabled


func _add_ladder_thumbnail(
	parent: HBoxContainer,
	chapter_id: int,
	state_id: String
) -> void:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(74.0, 54.0)

	var accent := Color(SKY.r, SKY.g, SKY.b, 0.44)
	if state_id == "claimed":
		accent = Color(JADE.r, JADE.g, JADE.b, 0.42)

	var style := LiveOpsUi.make_panel_style(
		Color(0.002, 0.014, 0.024, 0.96),
		accent,
		8
	)
	style.shadow_size = 0
	frame.add_theme_stylebox_override("panel", style)
	parent.add_child(frame)

	var art_texture := _load_ladder_stage_art(chapter_id)
	if art_texture == null:
		return

	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = art_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if state_id == "claimed":
		art.modulate = Color(0.70, 0.80, 0.78, 0.82)
	else:
		art.modulate = Color(0.50, 0.58, 0.62, 0.68)
	frame.add_child(art)


func _build_ladder_stage_preview(
	parent: VBoxContainer,
	chapter_id: int,
	index: int,
	title_text: String,
	state_text: String,
	accent: Color
) -> void:
	var art_texture := _load_ladder_stage_art(chapter_id)
	if art_texture == null:
		return

	var frame := Control.new()
	frame.custom_minimum_size.y = 136.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_contents = true
	parent.add_child(frame)

	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = art_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.002, 0.012, 0.030, 0.14)
	frame.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var caption_shade := ColorRect.new()
	caption_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_shade.color = Color(0.002, 0.010, 0.026, 0.80)
	caption_shade.anchor_left = 0.0
	caption_shade.anchor_top = 1.0
	caption_shade.anchor_right = 1.0
	caption_shade.anchor_bottom = 1.0
	caption_shade.offset_top = -50.0
	frame.add_child(caption_shade)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.anchor_left = 0.0
	top_row.anchor_top = 0.0
	top_row.anchor_right = 1.0
	top_row.anchor_bottom = 0.0
	top_row.offset_left = 8.0
	top_row.offset_top = 8.0
	top_row.offset_right = -8.0
	top_row.offset_bottom = 36.0
	frame.add_child(top_row)

	var marker := LiveOpsUi.add_label(
		top_row,
		tr("ASCENT %02d") % (index + 1),
		10,
		SKY
	)
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var badge := LiveOpsUi.add_state_badge(
		top_row,
		state_text,
		accent,
		state_text == tr("READY")
	)
	badge.custom_minimum_size.x = 88.0

	var caption := MarginContainer.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.anchor_left = 0.0
	caption.anchor_top = 1.0
	caption.anchor_right = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_left = 10.0
	caption.offset_top = -46.0
	caption.offset_right = -10.0
	caption.offset_bottom = -5.0
	frame.add_child(caption)

	var title := Label.new()
	title.text = title_text
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.92)
	)
	caption.add_child(title)


func _build_ladder_rail(
	parent: HBoxContainer,
	chapter_id: int,
	index: int,
	total_count: int,
	accent: Color,
	state_id: String
) -> void:
	var rail := Control.new()
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.custom_minimum_size.x = 44.0
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(rail)

	var connector := ColorRect.new()
	connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var connector_alpha: float = 0.42
	if state_id == "ready":
		connector_alpha = 0.72
	connector.color = Color(
		accent.r,
		accent.g,
		accent.b,
		connector_alpha
	)
	connector.anchor_left = 0.5
	connector.anchor_right = 0.5
	connector.offset_left = -1.5
	connector.offset_right = 1.5

	if total_count <= 1:
		connector.visible = false
	elif index == 0:
		connector.anchor_top = 0.0
		connector.anchor_bottom = 1.0
		connector.offset_top = 21.0
		connector.offset_bottom = 10.0
	elif index == total_count - 1:
		connector.anchor_top = 0.0
		connector.anchor_bottom = 0.0
		connector.offset_top = -10.0
		connector.offset_bottom = 21.0
	else:
		connector.anchor_top = 0.0
		connector.anchor_bottom = 1.0
		connector.offset_top = -10.0
		connector.offset_bottom = 10.0
	rail.add_child(connector)

	var seal_center := CenterContainer.new()
	seal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_center.anchor_left = 0.0
	seal_center.anchor_top = 0.0
	seal_center.anchor_right = 1.0
	seal_center.anchor_bottom = 0.0
	seal_center.offset_bottom = 42.0
	rail.add_child(seal_center)

	var seal := TextureRect.new()
	seal.custom_minimum_size = Vector2(42.0, 42.0)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	seal.texture = _load_ladder_seal(chapter_id, state_id)
	seal_center.add_child(seal)


func _load_ladder_seal(
	chapter_id: int,
	state_id: String
) -> Texture2D:
	var seal_state := "LOCKED"
	if state_id == "ready" or state_id == "active":
		seal_state = "CURRENT"
	elif state_id == "claimed":
		seal_state = "CLEARED"

	var path: String = JourneyArtCatalog.get_node_seal_path(
		chapter_id,
		seal_state
	)
	if path.is_empty():
		return null
	return load(path) as Texture2D


func _load_ladder_stage_art(chapter_id: int) -> Texture2D:
	var path: String = JourneyArtCatalog.get_stage_art_path(
		chapter_id,
		5
	)
	if path.is_empty():
		return null
	return load(path) as Texture2D


func _ladder_chapter_for_clears(required_clears: int) -> int:
	if required_clears <= 5:
		return 1
	if required_clears <= 10:
		return 2
	if required_clears <= 15:
		return 3
	if required_clears <= 20:
		return 4
	return 5


func _load_event_background() -> Texture2D:
	if _live_ops == null:
		return null
	var cleared_count: int = int(
		_live_ops.call("get_heavenly_ladder_cleared_stage_count")
	)
	var chapter_id: int = _ladder_chapter_for_clears(
		maxi(cleared_count + 1, 1)
	)
	var path: String = JourneyArtCatalog.get_realm_vista_path(
		chapter_id
	)
	if path.is_empty():
		return null
	return load(path) as Texture2D

func _claim(milestone_id: String) -> void:
	if _live_ops != null:
		_live_ops.call("claim_heavenly_ladder_milestone", milestone_id)
		_refresh()


func _back() -> void:
	LiveOpsUi.return_home(self)
