extends Control

## JADE VALLEY PILGRIMAGE — EVENT CONTENT EXPANSION E2
## Presentation/input only. LiveOpsManager owns unlock checks, permanent claim
## markers and RewardManager delivery. JourneyManager remains the progress owner.

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")
const JourneyArtCatalog = preload(
	"res://scripts/ui/journey_art_catalog.gd"
)
const EVENT_ID: String = "jade_valley_pilgrimage"
const EVENT_ICON: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/event_center_premium.png"
)

const GOLD: Color = Color(0.95, 0.75, 0.31, 1.0)
const JADE: Color = Color(0.34, 0.89, 0.72, 1.0)
const MUTED: Color = Color(0.74, 0.84, 0.82, 1.0)

var _live_ops: Node = null
var _content: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_live_ops = get_node_or_null("/root/LiveOpsManager")
	if _live_ops == null:
		push_error(
			"JadeValleyPilgrimageScreen: LiveOpsManager unavailable."
		)
		return

	var event: Dictionary = _live_ops.call(
		"get_event",
		EVENT_ID
	)
	if event.is_empty():
		push_error(
			"JadeValleyPilgrimageScreen: event catalog entry missing."
		)
		return

	var event_background := _load_event_background()
	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("JOURNEY EVENT"),
		tr(str(event.get("title", "JADE VALLEY PILGRIMAGE"))),
		tr(
			str(
				event.get(
					"description",
					"Clear key trials across Verdant Qi Valley and claim pilgrimage offerings."
				)
			)
		),
		EVENT_ICON,
		GOLD,
		event_background
	)
	_content = shell.get("content") as VBoxContainer
	var back_button: Button = shell.get("back_button") as Button
	if (
		not bool(get_meta("liveops_popup", false))
		and is_instance_valid(back_button)
	):
		back_button.pressed.connect(_back)

	var callback := Callable(self, "_on_live_ops_changed")
	if (
		_live_ops.has_signal("live_ops_changed")
		and not _live_ops.is_connected("live_ops_changed", callback)
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
		"get_pilgrimage_milestone_ids"
	)
	var unlocked_count: int = int(
		_live_ops.call("get_pilgrimage_unlocked_count")
	)
	var claimed_count: int = int(
		_live_ops.call("get_pilgrimage_claimed_count")
	)
	var claimable_count: int = int(
		_live_ops.call("get_pilgrimage_claimable_count")
	)
	var complete: bool = bool(
		_live_ops.call("is_pilgrimage_complete")
	)

	_build_journey_dashboard(
		unlocked_count,
		claimed_count,
		claimable_count,
		milestone_ids.size(),
		complete
	)
	_build_route_heading()

	for index: int in milestone_ids.size():
		_build_route_checkpoint(
			str(milestone_ids[index]),
			index,
			milestone_ids.size()
		)

func _build_journey_dashboard(
	unlocked_count: int,
	claimed_count: int,
	claimable_count: int,
	total_count: int,
	complete: bool
) -> void:
	var panel := PanelContainer.new()
	panel.name = "PilgrimageDashboard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel_border: Color = Color(GOLD.r, GOLD.g, GOLD.b, 0.74)
	if claimable_count > 0:
		panel_border = Color(GOLD.r, GOLD.g, GOLD.b, 0.96)

	var style := LiveOpsUi.make_panel_style(
		Color(0.014, 0.030, 0.030, 0.995),
		panel_border,
		15
	)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
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

	var eyebrow := LiveOpsUi.add_label(
		heading,
		tr("VERDANT MILESTONES"),
		12,
		JADE
	)
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eyebrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	eyebrow.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var metric := LiveOpsUi.add_label(
		heading,
		"%d / %d" % [unlocked_count, total_count],
		22,
		GOLD
	)
	metric.custom_minimum_size = Vector2(64.0, 30.0)
	metric.size_flags_horizontal = Control.SIZE_SHRINK_END
	metric.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metric.autowrap_mode = TextServer.AUTOWRAP_OFF
	metric.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	LiveOpsUi.add_progress_meter(
		body,
		unlocked_count,
		total_count,
		GOLD
	)

	var status_row := HBoxContainer.new()
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_theme_constant_override("separation", 7)
	body.add_child(status_row)

	var ready_text := tr("%d REWARD READY") % claimable_count
	if claimable_count != 1:
		ready_text = tr("%d REWARDS READY") % claimable_count

	_build_dashboard_status_pill(
		status_row,
		ready_text,
		GOLD,
		claimable_count > 0
	)
	_build_dashboard_status_pill(
		status_row,
		tr("%d CLAIMED") % claimed_count,
		JADE,
		false
	)

	if complete and claimable_count <= 0:
		var complete_label := LiveOpsUi.add_label(
			body,
			tr("PILGRIMAGE COMPLETE"),
			11,
			JADE
		)
		complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_dashboard_status_pill(
	parent: HBoxContainer,
	text_value: String,
	accent: Color,
	strong: bool
) -> void:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.custom_minimum_size.y = 31.0

	var background := Color(0.002, 0.022, 0.026, 0.98)
	var border_alpha: float = 0.42
	if strong:
		background = Color(0.094, 0.058, 0.010, 0.99)
		border_alpha = 0.84

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

func _build_stat_tile(
	parent: Container,
	value_text: String,
	label_text: String,
	accent: Color,
	strong: bool
) -> void:
	var tile := PanelContainer.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var background := Color(0.002, 0.024, 0.029, 0.98)
	if strong:
		background = Color(0.095, 0.060, 0.012, 0.99)
	var style := LiveOpsUi.make_panel_style(
		background,
		Color(accent.r, accent.g, accent.b, 0.48),
		10
	)
	style.shadow_size = 0
	tile.add_theme_stylebox_override("panel", style)
	parent.add_child(tile)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	tile.add_child(box)

	var value := Label.new()
	value.text = value_text
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.custom_minimum_size.y = 28.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", accent)
	box.add_child(value)

	var label := Label.new()
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size.y = 23.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override(
		"font_color",
		Color(0.74, 0.84, 0.82, 1.0)
	)
	box.add_child(label)


func _build_route_heading() -> void:
	var section := VBoxContainer.new()
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.custom_minimum_size.y = 38.0
	section.add_theme_constant_override("separation", 5)
	_content.add_child(section)

	var title := LiveOpsUi.add_label(
		section,
		tr("PILGRIMAGE ROUTE"),
		14,
		GOLD
	)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.y = 22.0
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 2.0
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.46)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(rule)

func _build_route_checkpoint(
	milestone_id: String,
	index: int,
	total_count: int
) -> void:
	var milestone: Dictionary = _live_ops.call(
		"get_pilgrimage_milestone",
		milestone_id
	)
	if milestone.is_empty():
		return

	var unlocked: bool = bool(milestone.get("unlocked", false))
	var claimed: bool = bool(milestone.get("claimed", false))
	var stage_id: int = int(milestone.get("stage_id", 0))
	var reward: Dictionary = milestone.get("reward", {})
	var items: Dictionary = reward.get("items", {})
	var stone_count: int = int(reward.get("spirit_stone", 0))
	var shard_count: int = int(items.get("refinement_shard", 0))
	var title_text: String = tr(
		str(milestone.get("title", milestone_id))
	)

	if claimed:
		_build_claimed_checkpoint(
			stage_id,
			index,
			total_count,
			title_text
		)
		return

	var state_id: String = "locked"
	var state_text: String = tr("LOCKED")
	var accent: Color = Color(0.32, 0.54, 0.51, 1.0)
	if unlocked:
		state_id = "ready"
		state_text = tr("READY")
		accent = GOLD

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)

	_build_timeline_rail(
		row,
		index,
		total_count,
		accent,
		state_id
	)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var background := Color(0.003, 0.025, 0.031, 0.99)
	var shadow_size: int = 5
	if state_id == "ready":
		background = Color(0.090, 0.054, 0.008, 0.995)
		shadow_size = 16

	var style := LiveOpsUi.make_panel_style(
		background,
		Color(accent.r, accent.g, accent.b, 0.92),
		15
	)
	style.border_width_left = 4
	if state_id == "ready":
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

	_build_checkpoint_stage_preview(
		body,
		stage_id,
		index,
		title_text,
		state_id,
		state_text,
		accent
	)

	var objective := LiveOpsUi.add_label(
		body,
		tr(str(milestone.get("description", ""))),
		12,
		MUTED
	)
	objective.add_theme_color_override(
		"font_color",
		Color(0.82, 0.88, 0.84, 1.0)
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
		state_id == "ready"
	)

	var button_text: String = tr("IN PROGRESS")
	var callback := Callable()
	var primary: bool = false
	var disabled: bool = true

	if unlocked:
		button_text = tr("CLAIM REWARD")
		callback = Callable(
			self,
			"_claim_milestone"
		).bind(milestone_id)
		primary = true
		disabled = false
	else:
		button_text = tr("CLEAR STAGE 1-%d") % stage_id

	var action := LiveOpsUi.add_action_button(
		body,
		button_text,
		callback,
		primary
	)
	action.custom_minimum_size.y = 56.0
	action.disabled = disabled
	_style_checkpoint_action(action, state_id)
	_queue_checkpoint_intro(row, index)


func _build_claimed_checkpoint(
	stage_id: int,
	index: int,
	total_count: int,
	title_text: String
) -> void:
	var accent := Color(JADE.r, JADE.g, JADE.b, 0.66)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)

	_build_timeline_rail(
		row,
		index,
		total_count,
		accent,
		"claimed"
	)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 78.0

	var style := LiveOpsUi.make_panel_style(
		Color(0.002, 0.020, 0.023, 0.96),
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

	var thumb_frame := PanelContainer.new()
	thumb_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_frame.custom_minimum_size = Vector2(78.0, 62.0)
	var thumb_style := LiveOpsUi.make_panel_style(
		Color(0.002, 0.016, 0.020, 0.98),
		Color(accent.r, accent.g, accent.b, 0.38),
		8
	)
	thumb_style.shadow_size = 0
	thumb_frame.add_theme_stylebox_override("panel", thumb_style)
	content.add_child(thumb_frame)

	var art_path: String = JourneyArtCatalog.get_stage_art_path(
		1,
		stage_id
	)
	if not art_path.is_empty():
		var art_texture := load(art_path) as Texture2D
		if art_texture != null:
			var art := TextureRect.new()
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.texture = art_texture
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			art.modulate = Color(0.72, 0.82, 0.78, 0.82)
			thumb_frame.add_child(art)

	var details := VBoxContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	content.add_child(details)

	var marker := LiveOpsUi.add_label(
		details,
		"#%02d" % (index + 1),
		9,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.62)
	)
	marker.autowrap_mode = TextServer.AUTOWRAP_OFF

	var title := LiveOpsUi.add_label(
		details,
		title_text,
		13,
		Color(JADE.r, JADE.g, JADE.b, 0.80)
	)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var state := LiveOpsUi.add_label(
		details,
		tr("CLAIMED"),
		10,
		Color(JADE.r, JADE.g, JADE.b, 0.72)
	)
	state.autowrap_mode = TextServer.AUTOWRAP_OFF

	_queue_checkpoint_intro(row, index)

func _build_timeline_rail(
	parent: HBoxContainer,
	index: int,
	total_count: int,
	accent: Color,
	state_id: String
) -> void:
	var rail := Control.new()
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.custom_minimum_size.x = 46.0
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(rail)

	var connector := ColorRect.new()
	connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var connector_alpha: float = 0.44
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
		connector.offset_top = 22.0
		connector.offset_bottom = 10.0
	elif index == total_count - 1:
		connector.anchor_top = 0.0
		connector.anchor_bottom = 0.0
		connector.offset_top = -10.0
		connector.offset_bottom = 22.0
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
	seal_center.offset_bottom = 44.0
	rail.add_child(seal_center)

	var seal := TextureRect.new()
	seal.custom_minimum_size = Vector2(44.0, 44.0)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	seal.texture = _load_checkpoint_seal(state_id)
	seal_center.add_child(seal)

func _build_checkpoint_stage_preview(
	parent: VBoxContainer,
	stage_id: int,
	index: int,
	title_text: String,
	state_id: String,
	state_text: String,
	accent: Color
) -> void:
	var art_path: String = JourneyArtCatalog.get_stage_art_path(
		1,
		stage_id
	)
	if art_path.is_empty():
		return

	var art_texture := load(art_path) as Texture2D
	if art_texture == null:
		return

	var frame := PanelContainer.new()
	frame.custom_minimum_size.y = 138.0
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := LiveOpsUi.make_panel_style(
		Color(0.002, 0.018, 0.024, 0.99),
		Color(accent.r, accent.g, accent.b, 0.72),
		11
	)
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.shadow_size = 0
	frame.add_theme_stylebox_override("panel", frame_style)
	parent.add_child(frame)

	var stack := Control.new()
	stack.custom_minimum_size.y = 138.0
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stack)

	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = art_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stack.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if state_id == "ready":
		art.modulate = Color(1.0, 1.0, 0.96, 1.0)
	elif state_id == "locked":
		art.modulate = Color(0.40, 0.49, 0.48, 0.66)
	elif state_id == "claimed":
		art.modulate = Color(0.50, 0.62, 0.58, 0.74)

	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(0.002, 0.014, 0.020, 0.14)
	if state_id == "ready":
		veil.color = Color(0.002, 0.014, 0.020, 0.05)
	elif state_id == "claimed":
		veil.color = Color(0.002, 0.014, 0.020, 0.30)
	elif state_id == "locked":
		veil.color = Color(0.002, 0.014, 0.020, 0.26)
	stack.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var caption_shade := ColorRect.new()
	caption_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_shade.color = Color(0.002, 0.016, 0.022, 0.80)
	stack.add_child(caption_shade)
	caption_shade.anchor_left = 0.0
	caption_shade.anchor_top = 1.0
	caption_shade.anchor_right = 1.0
	caption_shade.anchor_bottom = 1.0
	caption_shade.offset_top = -52.0

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(top_row)
	top_row.anchor_left = 0.0
	top_row.anchor_top = 0.0
	top_row.anchor_right = 1.0
	top_row.anchor_bottom = 0.0
	top_row.offset_left = 8.0
	top_row.offset_top = 8.0
	top_row.offset_right = -8.0
	top_row.offset_bottom = 36.0
	top_row.add_theme_constant_override("separation", 6)

	var marker := LiveOpsUi.add_label(
		top_row,
		"#%02d" % (index + 1),
		11,
		GOLD
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
		state_id == "ready"
	)
	badge.custom_minimum_size.x = 112.0

	var caption := MarginContainer.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(caption)
	caption.anchor_left = 0.0
	caption.anchor_top = 1.0
	caption.anchor_right = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_left = 10.0
	caption.offset_top = -48.0
	caption.offset_right = -10.0
	caption.offset_bottom = -6.0

	var title := Label.new()
	title.text = title_text
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 18)
	var title_color: Color = accent
	if state_id == "ready":
		title_color = GOLD
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.92)
	)
	title.add_theme_constant_override("shadow_offset_y", 2)
	caption.add_child(title)

func _load_checkpoint_seal(state_id: String) -> Texture2D:
	var seal_state: String = "LOCKED"
	if state_id == "ready":
		seal_state = "CURRENT"
	elif state_id == "claimed":
		seal_state = "CLEARED"
	var path: String = JourneyArtCatalog.get_node_seal_path(
		1,
		seal_state
	)
	if path.is_empty():
		return null
	return load(path) as Texture2D


func _style_checkpoint_action(
	button: Button,
	state_id: String
) -> void:
	if state_id != "ready":
		return

	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.88, 0.54, 1.0)
	)
	button.add_theme_stylebox_override(
		"normal",
		LiveOpsUi.make_button_style(
			Color(0.105, 0.065, 0.012, 0.99),
			Color(GOLD.r, GOLD.g, GOLD.b, 0.94)
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		LiveOpsUi.make_button_style(
			Color(0.145, 0.090, 0.016, 1.0),
			Color(1.0, 0.86, 0.42, 1.0)
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		LiveOpsUi.make_button_style(
			Color(0.070, 0.042, 0.008, 1.0),
			Color(GOLD.r, GOLD.g, GOLD.b, 0.88)
		)
	)


func _queue_checkpoint_intro(
	row: Control,
	index: int
) -> void:
	row.modulate = Color(1.0, 1.0, 1.0, 0.0)
	call_deferred("_play_checkpoint_intro", row, index)


func _play_checkpoint_intro(
	row: Control,
	index: int
) -> void:
	if not is_instance_valid(row):
		return

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if index > 0:
		tween.tween_interval(0.045 * float(index))
	tween.tween_property(
		row,
		"modulate",
		Color(1.0, 1.0, 1.0, 1.0),
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _load_event_background() -> Texture2D:
	var path: String = JourneyArtCatalog.get_realm_vista_path(1)
	if path.is_empty():
		return null
	return load(path) as Texture2D
func _claim_milestone(milestone_id: String) -> void:
	if _live_ops == null:
		return
	_live_ops.call(
		"claim_pilgrimage_milestone",
		milestone_id
	)
	_refresh()


func _back() -> void:
	LiveOpsUi.return_home(self)
