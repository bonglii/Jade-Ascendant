extends Control

## CELESTIAL BOSS HUNT — EVENT CONTENT EXPANSION E3
## Presentation/input only. LiveOpsManager owns progress validation, optional
## rewarded request state, permanent claim markers, and RewardManager delivery.

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")
const JourneyArtCatalog = preload(
	"res://scripts/ui/journey_art_catalog.gd"
)
const EVENT_ID: String = "celestial_boss_hunt"
const EVENT_ICON: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/event_center_premium.png"
)

const GOLD: Color = Color(0.95, 0.75, 0.31, 1.0)
const JADE: Color = Color(0.34, 0.89, 0.72, 1.0)
const EMBER: Color = Color(0.96, 0.55, 0.28, 1.0)
const MUTED: Color = Color(0.74, 0.84, 0.82, 1.0)

var _live_ops: Node = null
var _content: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_live_ops = get_node_or_null("/root/LiveOpsManager")
	if _live_ops == null:
		push_error("CelestialBossHuntScreen: LiveOpsManager unavailable.")
		return
	var event: Dictionary = _live_ops.call("get_event", EVENT_ID)
	if event.is_empty():
		push_error("CelestialBossHuntScreen: event catalog entry missing.")
		return
	var event_background := _load_event_background()
	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("BOSS HUNT EVENT"),
		tr(str(event.get("title", "CELESTIAL BOSS HUNT"))),
		tr(str(event.get("description", ""))),
		EVENT_ICON,
		EMBER,
		event_background
	)
	_content = shell.get("content") as VBoxContainer
	var back_button: Button = shell.get("back_button") as Button
	if not bool(get_meta("liveops_popup", false)) and is_instance_valid(back_button):
		back_button.pressed.connect(_back)
	var callback := Callable(self, "_on_live_ops_changed")
	if _live_ops.has_signal("live_ops_changed") and not _live_ops.is_connected("live_ops_changed", callback):
		_live_ops.connect("live_ops_changed", callback)
	SceneTransitionManager.set_back_handler(_back)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree() and is_instance_valid(_content):
		call_deferred("_refresh")


func _on_live_ops_changed() -> void:
	if is_inside_tree() and is_instance_valid(_content):
		_refresh()


func _refresh() -> void:
	if _live_ops == null or not is_instance_valid(_content):
		return

	LiveOpsUi.clear_container(_content)

	var milestone_ids: Array = _live_ops.call(
		"get_boss_hunt_milestone_ids"
	)
	var unlocked_count: int = int(
		_live_ops.call("get_boss_hunt_unlocked_count")
	)
	var claimed_count: int = int(
		_live_ops.call("get_boss_hunt_claimed_count")
	)
	var claimable_count: int = int(
		_live_ops.call("get_boss_hunt_claimable_count")
	)
	var policy: Dictionary = _live_ops.call(
		"get_boss_hunt_rewarded_policy_status"
	)
	var pending_id: String = str(
		policy.get("pending_milestone_id", "")
	)

	_build_bounty_dashboard(
		unlocked_count,
		claimed_count,
		claimable_count,
		milestone_ids.size(),
		policy,
		pending_id
	)
	_build_bounty_route_heading()

	for index: int in milestone_ids.size():
		_build_bounty_checkpoint(
			str(milestone_ids[index]),
			index,
			milestone_ids.size(),
			pending_id
		)


func _build_bounty_dashboard(
	unlocked_count: int,
	claimed_count: int,
	claimable_count: int,
	total_count: int,
	policy: Dictionary,
	pending_id: String
) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := LiveOpsUi.make_panel_style(
		Color(0.060, 0.025, 0.010, 0.91),
		Color(EMBER.r, EMBER.g, EMBER.b, 0.86),
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
		tr("SOVEREIGN BOUNTIES"),
		12,
		EMBER
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var metric := LiveOpsUi.add_label(
		heading,
		"%d / %d" % [unlocked_count, total_count],
		22,
		GOLD
	)
	metric.custom_minimum_size = Vector2(64.0, 30.0)
	metric.size_flags_horizontal = Control.SIZE_SHRINK_END
	metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metric.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	metric.autowrap_mode = TextServer.AUTOWRAP_OFF

	LiveOpsUi.add_progress_meter(
		body,
		unlocked_count,
		total_count,
		EMBER
	)

	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 7)
	body.add_child(stats)

	var ready_text := tr("%d REWARD READY") % claimable_count
	if claimable_count != 1:
		ready_text = tr("%d REWARDS READY") % claimable_count

	_build_bounty_status_pill(
		stats,
		ready_text,
		GOLD,
		claimable_count > 0
	)
	_build_bounty_status_pill(
		stats,
		tr("%d CLAIMED") % claimed_count,
		JADE,
		false
	)

	var boost_text: String = tr("2X BOOST UNAVAILABLE")
	if not pending_id.is_empty():
		boost_text = tr("2X BOOST IN PROGRESS")
	elif int(policy.get("placement_claims", 0)) >= int(
		policy.get("daily_limit", 1)
	):
		boost_text = tr("2X BOOST USED TODAY")
	elif bool(policy.get("available", false)):
		boost_text = tr("2X BOOST AVAILABLE TODAY")

	LiveOpsUi.add_info_strip(
		body,
		boost_text,
		EMBER,
		bool(policy.get("available", false))
			and pending_id.is_empty()
	)
	var note := LiveOpsUi.add_label(
		body,
		tr("NORMAL CLAIM ALWAYS REMAINS AVAILABLE"),
		10,
		MUTED
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _build_bounty_status_pill(
	parent: HBoxContainer,
	text_value: String,
	accent: Color,
	strong: bool
) -> void:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.custom_minimum_size.y = 31.0

	var background := Color(0.010, 0.018, 0.020, 0.94)
	var border_alpha: float = 0.42
	if strong:
		background = Color(0.105, 0.055, 0.010, 0.98)
		border_alpha = 0.90

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


func _build_bounty_route_heading() -> void:
	var backing := PanelContainer.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.custom_minimum_size.y = 28.0
	backing.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := LiveOpsUi.make_panel_style(
		Color(0.010, 0.016, 0.018, 0.70),
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
		tr("CELESTIAL BOUNTY ROUTE"),
		12,
		EMBER
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF

	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(54.0, 2.0)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color = Color(EMBER.r, EMBER.g, EMBER.b, 0.52)
	row.add_child(rule)


func _build_bounty_checkpoint(
	milestone_id: String,
	index: int,
	total_count: int,
	pending_id: String
) -> void:
	var milestone: Dictionary = _live_ops.call(
		"get_boss_hunt_milestone",
		milestone_id
	)
	if milestone.is_empty():
		return

	var unlocked: bool = bool(milestone.get("unlocked", false))
	var claimed: bool = bool(milestone.get("claimed", false))
	var chapter_id: int = int(milestone.get("chapter_id", 1))
	var title_text: String = tr(
		str(milestone.get("title", milestone_id))
	)

	if claimed:
		_build_compact_boss_checkpoint(
			chapter_id,
			index,
			total_count,
			title_text,
			"claimed"
		)
		return

	if not unlocked:
		_build_compact_boss_checkpoint(
			chapter_id,
			index,
			total_count,
			title_text,
			"locked"
		)
		return

	_build_ready_boss_checkpoint(
		milestone_id,
		milestone,
		chapter_id,
		index,
		total_count,
		title_text,
		pending_id
	)


func _build_compact_boss_checkpoint(
	chapter_id: int,
	index: int,
	total_count: int,
	title_text: String,
	state_id: String
) -> void:
	var accent := Color(JADE.r, JADE.g, JADE.b, 0.68)
	var state_text := tr("CLAIMED")
	if state_id == "locked":
		accent = Color(0.46, 0.52, 0.50, 0.64)
		state_text = tr("LOCKED")

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	_content.add_child(row)

	_build_bounty_rail(
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
	panel.custom_minimum_size.y = 76.0

	var style := LiveOpsUi.make_panel_style(
		Color(0.006, 0.018, 0.020, 0.92),
		Color(accent.r, accent.g, accent.b, 0.48),
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

	_add_boss_thumbnail(
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
		tr("REALM %d") % chapter_id,
		9,
		Color(EMBER.r, EMBER.g, EMBER.b, 0.72)
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

	var state := LiveOpsUi.add_label(
		details,
		state_text,
		10,
		accent
	)
	state.autowrap_mode = TextServer.AUTOWRAP_OFF

	_queue_bounty_intro(row, index)


func _build_ready_boss_checkpoint(
	milestone_id: String,
	milestone: Dictionary,
	chapter_id: int,
	index: int,
	total_count: int,
	title_text: String,
	pending_id: String
) -> void:
	var reward: Dictionary = milestone.get("reward", {})
	var items: Dictionary = reward.get("items", {})
	var stone_count: int = int(reward.get("spirit_stone", 0))
	var shard_count: int = int(items.get("refinement_shard", 0))
	var pending: bool = not pending_id.is_empty()
	var pending_this: bool = pending_id == milestone_id

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	_content.add_child(row)

	_build_bounty_rail(
		row,
		chapter_id,
		index,
		total_count,
		EMBER,
		"ready"
	)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := LiveOpsUi.make_panel_style(
		Color(0.080, 0.032, 0.006, 0.94),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.96),
		15
	)
	style.border_width_left = 4
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_size = 15
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

	var state_text := tr("READY")
	if pending_this:
		state_text = tr("BOOSTING")

	_build_boss_stage_preview(
		body,
		chapter_id,
		title_text,
		state_text
	)

	var description := LiveOpsUi.add_label(
		body,
		tr(str(milestone.get("description", ""))),
		12,
		Color(0.88, 0.86, 0.80, 1.0)
	)
	description.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.76)
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
		true
	)

	var normal_button := LiveOpsUi.add_action_button(
		body,
		tr("CLAIM REWARD"),
		Callable(self, "_claim_normal").bind(milestone_id),
		true
	)
	normal_button.custom_minimum_size.y = 54.0
	normal_button.disabled = pending

	var double_button := LiveOpsUi.add_action_button(
		body,
		tr("CLAIM 2X - OPTIONAL AD"),
		Callable(self, "_claim_double").bind(milestone_id),
		false
	)
	double_button.custom_minimum_size.y = 50.0
	double_button.disabled = (
		pending
		or not bool(
			_live_ops.call(
				"is_boss_hunt_double_available",
				milestone_id
			)
		)
	)
	_style_double_claim_button(double_button)
	_queue_bounty_intro(row, index)


func _add_boss_thumbnail(
	parent: HBoxContainer,
	chapter_id: int,
	state_id: String
) -> void:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(80.0, 60.0)

	var accent := Color(JADE.r, JADE.g, JADE.b, 0.46)
	if state_id == "locked":
		accent = Color(0.42, 0.48, 0.46, 0.36)

	var style := LiveOpsUi.make_panel_style(
		Color(0.004, 0.014, 0.018, 0.96),
		accent,
		8
	)
	style.shadow_size = 0
	frame.add_theme_stylebox_override("panel", style)
	parent.add_child(frame)

	var art_path: String = JourneyArtCatalog.get_stage_art_path(
		chapter_id,
		5
	)
	if art_path.is_empty():
		return

	var art_texture := load(art_path) as Texture2D
	if art_texture == null:
		return

	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = art_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if state_id == "claimed":
		art.modulate = Color(0.68, 0.76, 0.72, 0.80)
	else:
		art.modulate = Color(0.42, 0.46, 0.44, 0.58)
	frame.add_child(art)


func _build_boss_stage_preview(
	parent: VBoxContainer,
	chapter_id: int,
	title_text: String,
	state_text: String
) -> void:
	var art_path: String = JourneyArtCatalog.get_stage_art_path(
		chapter_id,
		5
	)
	if art_path.is_empty():
		return

	var art_texture := load(art_path) as Texture2D
	if art_texture == null:
		return

	var frame := Control.new()
	frame.custom_minimum_size.y = 142.0
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

	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(0.035, 0.008, 0.002, 0.12)
	frame.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var caption_shade := ColorRect.new()
	caption_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_shade.color = Color(0.018, 0.006, 0.002, 0.78)
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
	top_row.add_theme_constant_override("separation", 6)
	frame.add_child(top_row)

	var marker := LiveOpsUi.add_label(
		top_row,
		tr("REALM %d") % chapter_id,
		10,
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
		EMBER,
		true
	)
	badge.custom_minimum_size.x = 86.0

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
	title.add_theme_constant_override("shadow_offset_y", 2)
	caption.add_child(title)


func _build_bounty_rail(
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
			EMBER.r,
			EMBER.g,
			EMBER.b,
			connector_alpha
		)
	else:
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
	seal.texture = _load_boss_seal(chapter_id, state_id)
	seal_center.add_child(seal)


func _load_boss_seal(
	chapter_id: int,
	state_id: String
) -> Texture2D:
	var seal_state := "LOCKED"
	if state_id == "ready":
		seal_state = "BOSS"
	elif state_id == "claimed":
		seal_state = "CLEARED"

	var path: String = JourneyArtCatalog.get_node_seal_path(
		chapter_id,
		seal_state
	)
	if path.is_empty():
		return null
	return load(path) as Texture2D


func _style_double_claim_button(button: Button) -> void:
	button.add_theme_color_override(
		"font_color",
		Color(1.0, 0.68, 0.42, 1.0)
	)
	button.add_theme_color_override(
		"font_hover_color",
		GOLD
	)
	button.add_theme_stylebox_override(
		"normal",
		LiveOpsUi.make_button_style(
			Color(0.055, 0.020, 0.008, 0.96),
			Color(EMBER.r, EMBER.g, EMBER.b, 0.76)
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		LiveOpsUi.make_button_style(
			Color(0.095, 0.034, 0.010, 1.0),
			Color(EMBER.r, EMBER.g, EMBER.b, 1.0)
		)
	)


func _queue_bounty_intro(
	row: Control,
	index: int
) -> void:
	row.modulate = Color(1.0, 1.0, 1.0, 0.0)
	call_deferred("_play_bounty_intro", row, index)


func _play_bounty_intro(
	row: Control,
	index: int
) -> void:
	if not is_instance_valid(row):
		return

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if index > 0:
		tween.tween_interval(0.035 * float(index))
	tween.tween_property(
		row,
		"modulate",
		Color(1.0, 1.0, 1.0, 1.0),
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _load_event_background() -> Texture2D:
	if _live_ops == null:
		return null

	var chapter_id: int = 1
	var milestone_ids: Array = _live_ops.call(
		"get_boss_hunt_milestone_ids"
	)

	for raw_id: Variant in milestone_ids:
		var milestone: Dictionary = _live_ops.call(
			"get_boss_hunt_milestone",
			str(raw_id)
		)
		if milestone.is_empty():
			continue

		if bool(milestone.get("unlocked", false)):
			chapter_id = int(
				milestone.get("chapter_id", chapter_id)
			)
			if not bool(milestone.get("claimed", false)):
				break

	var path: String = JourneyArtCatalog.get_realm_vista_path(
		chapter_id
	)
	if path.is_empty():
		return null
	return load(path) as Texture2D

func _claim_normal(milestone_id: String) -> void:
	if _live_ops != null:
		_live_ops.call("claim_boss_hunt_milestone", milestone_id)
		_refresh()


func _claim_double(milestone_id: String) -> void:
	if _live_ops != null:
		_live_ops.call("request_boss_hunt_double_claim", milestone_id)
		_refresh()


func _back() -> void:
	LiveOpsUi.return_home(self)
