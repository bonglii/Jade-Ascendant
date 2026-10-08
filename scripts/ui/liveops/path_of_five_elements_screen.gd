extends Control

## PATH OF FIVE ELEMENTS — EVENT CONTENT EXPANSION E6
## Presentation/input only. JourneyManager remains progress authority,
## LiveOpsManager owns claims, and RewardManager owns reward delivery.

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")
const JourneyArtCatalog = preload(
	"res://scripts/ui/journey_art_catalog.gd"
)
const EVENT_ID: String = "path_of_five_elements"
const EVENT_ICON: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/event_center_premium.png"
)

const GOLD: Color = Color(0.95, 0.75, 0.31, 1.0)
const JADE: Color = Color(0.34, 0.89, 0.72, 1.0)
const FIRE: Color = Color(0.96, 0.55, 0.28, 1.0)
const SKY: Color = Color(0.58, 0.79, 1.0, 1.0)
const EARTH: Color = Color(0.82, 0.66, 0.32, 1.0)
const MUTED: Color = Color(0.74, 0.84, 0.82, 1.0)

var _live_ops: Node = null
var _content: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_live_ops = get_node_or_null("/root/LiveOpsManager")
	if _live_ops == null:
		push_error("PathOfFiveElementsScreen: LiveOpsManager unavailable.")
		return
	var event: Dictionary = _live_ops.call("get_event", EVENT_ID)
	if event.is_empty():
		push_error("PathOfFiveElementsScreen: event catalog entry missing.")
		return

	var event_background := _load_event_background()
	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("FIVE ELEMENTS EVENT"),
		tr(str(event.get("title", "PATH OF FIVE ELEMENTS"))),
		tr(str(event.get("description", ""))),
		EVENT_ICON,
		JADE,
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

	var trial_ids: Array = _live_ops.call(
		"get_five_elements_trial_ids"
	)
	var unlocked_count: int = int(
		_live_ops.call("get_five_elements_unlocked_count")
	)
	var claimed_count: int = int(
		_live_ops.call("get_five_elements_claimed_count")
	)
	var claimable_count: int = int(
		_live_ops.call("get_five_elements_claimable_count")
	)
	var convergence: Dictionary = _live_ops.call(
		"get_five_elements_convergence"
	)

	_build_elements_dashboard(
		unlocked_count,
		claimed_count,
		claimable_count,
		trial_ids.size(),
		convergence
	)
	_build_elements_route_heading()

	var convergence_focus: bool = (
		bool(convergence.get("unlocked", false))
		and not bool(convergence.get("claimed", false))
	)

	var focus_trial_id: String = ""
	if not convergence_focus:
		focus_trial_id = _choose_element_focus(trial_ids)

	for index: int in trial_ids.size():
		var trial_id: String = str(trial_ids[index])
		_build_element_trial(
			trial_id,
			index,
			trial_ids.size() + 1,
			trial_id == focus_trial_id
		)

	_build_convergence_checkpoint(
		convergence,
		claimed_count,
		trial_ids.size(),
		convergence_focus
	)


func _build_elements_dashboard(
	unlocked_count: int,
	claimed_count: int,
	claimable_count: int,
	total_count: int,
	convergence: Dictionary
) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := LiveOpsUi.make_panel_style(
		Color(0.006, 0.032, 0.030, 0.90),
		Color(JADE.r, JADE.g, JADE.b, 0.86),
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
		tr("ELEMENTAL TRIALS"),
		12,
		JADE
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF

	var metric := LiveOpsUi.add_label(
		heading,
		"%d / %d" % [unlocked_count, total_count],
		22,
		GOLD
	)
	metric.custom_minimum_size = Vector2(64.0, 30.0)
	metric.size_flags_horizontal = Control.SIZE_SHRINK_END
	metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metric.autowrap_mode = TextServer.AUTOWRAP_OFF

	LiveOpsUi.add_progress_meter(
		body,
		unlocked_count,
		total_count,
		JADE
	)

	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 7)
	body.add_child(stats)

	var ready_text := tr("%d REWARD READY") % claimable_count
	if claimable_count != 1:
		ready_text = tr("%d REWARDS READY") % claimable_count

	_build_element_status_pill(
		stats,
		ready_text,
		GOLD,
		claimable_count > 0
	)
	_build_element_status_pill(
		stats,
		tr("%d CLAIMED") % claimed_count,
		JADE,
		false
	)

	if (
		bool(convergence.get("unlocked", false))
		and not bool(convergence.get("claimed", false))
	):
		LiveOpsUi.add_info_strip(
			body,
			tr("FIVE ELEMENTS CONVERGENCE READY"),
			GOLD,
			true
		)


func _build_element_status_pill(
	parent: HBoxContainer,
	text_value: String,
	accent: Color,
	strong: bool
) -> void:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.custom_minimum_size.y = 31.0

	var background := Color(0.004, 0.022, 0.024, 0.94)
	var border_alpha: float = 0.42
	if strong:
		background = Color(0.080, 0.055, 0.010, 0.98)
		border_alpha = 0.88

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


func _build_elements_route_heading() -> void:
	var backing := PanelContainer.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.custom_minimum_size.y = 28.0
	var style := LiveOpsUi.make_panel_style(
		Color(0.004, 0.020, 0.022, 0.78),
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
		tr("ELEMENTAL PATH"),
		12,
		JADE
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF

	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(54.0, 2.0)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color = Color(JADE.r, JADE.g, JADE.b, 0.54)
	row.add_child(rule)


func _choose_element_focus(trial_ids: Array) -> String:
	var ready_id: String = ""
	var best_id: String = ""
	var best_ratio: float = -1.0

	for raw_id: Variant in trial_ids:
		var trial_id: String = str(raw_id)
		var trial: Dictionary = _live_ops.call(
			"get_five_elements_trial",
			trial_id
		)
		if trial.is_empty():
			continue
		if bool(trial.get("claimed", false)):
			continue
		if bool(trial.get("unlocked", false)):
			ready_id = trial_id
			break

		var required_count: int = maxi(
			int(trial.get("required_count", 0)),
			1
		)
		var cleared_count: int = int(
			trial.get("cleared_count", 0)
		)
		var ratio: float = (
			float(cleared_count)
			/ float(required_count)
		)
		if ratio > best_ratio:
			best_ratio = ratio
			best_id = trial_id

	if not ready_id.is_empty():
		return ready_id
	return best_id


func _build_element_trial(
	trial_id: String,
	index: int,
	total_count: int,
	is_focus: bool
) -> void:
	var trial: Dictionary = _live_ops.call(
		"get_five_elements_trial",
		trial_id
	)
	if trial.is_empty():
		return

	var unlocked: bool = bool(trial.get("unlocked", false))
	var claimed: bool = bool(trial.get("claimed", false))
	var cleared_count: int = int(trial.get("cleared_count", 0))
	var required_count: int = int(trial.get("required_count", 0))
	var title_text: String = tr(
		str(trial.get("title", trial_id))
	)
	var accent: Color = _trial_accent(trial_id)

	if claimed:
		_build_compact_element_trial(
			trial_id,
			index,
			total_count,
			title_text,
			accent,
			tr("CLAIMED"),
			"claimed",
			cleared_count,
			required_count
		)
		return

	if not is_focus:
		var compact_state := tr("IN PROGRESS")
		if unlocked:
			compact_state = tr("READY")
		_build_compact_element_trial(
			trial_id,
			index,
			total_count,
			title_text,
			accent,
			compact_state,
			"active",
			cleared_count,
			required_count
		)
		return

	_build_focus_element_trial(
		trial_id,
		trial,
		index,
		total_count,
		title_text,
		accent,
		unlocked,
		cleared_count,
		required_count
	)


func _build_compact_element_trial(
	trial_id: String,
	index: int,
	total_count: int,
	title_text: String,
	accent: Color,
	state_text: String,
	state_id: String,
	cleared_count: int,
	required_count: int
) -> void:
	var chapter_id: int = _element_chapter(trial_id)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	_content.add_child(row)

	_build_element_rail(
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
		Color(0.004, 0.020, 0.022, 0.92),
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

	_add_element_thumbnail(
		content,
		trial_id,
		state_id
	)

	var details := VBoxContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 1)
	content.add_child(details)

	var marker := LiveOpsUi.add_label(
		details,
		_element_label(trial_id),
		9,
		accent
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
	if state_id != "claimed":
		line_text = tr("%s - %d / %d") % [
			state_text,
			cleared_count,
			required_count,
		]
	var state := LiveOpsUi.add_label(
		details,
		line_text,
		10,
		accent
	)
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _build_focus_element_trial(
	trial_id: String,
	trial: Dictionary,
	index: int,
	total_count: int,
	title_text: String,
	accent: Color,
	unlocked: bool,
	cleared_count: int,
	required_count: int
) -> void:
	var chapter_id: int = _element_chapter(trial_id)
	var reward: Dictionary = trial.get("reward", {})

	var state_id := "active"
	var state_text := tr("ACTIVE")
	if unlocked:
		state_id = "ready"
		state_text = tr("READY")

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	_content.add_child(row)

	_build_element_rail(
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

	var background := Color(0.004, 0.030, 0.030, 0.94)
	var edge := accent
	var shadow_size: int = 9
	if unlocked:
		background = Color(0.060, 0.045, 0.008, 0.97)
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

	_build_element_preview(
		body,
		trial_id,
		title_text,
		state_text,
		accent
	)

	var required_keys: Array = trial.get(
		"required_stage_keys",
		[]
	)
	var required_labels := PackedStringArray()
	for raw_key: Variant in required_keys:
		required_labels.append(str(raw_key))

	var required_text := LiveOpsUi.add_label(
		body,
		tr("REQUIRED: %s") % ", ".join(required_labels),
		11,
		MUTED
	)
	required_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	LiveOpsUi.add_progress_meter(
		body,
		cleared_count,
		required_count,
		accent
	)

	LiveOpsUi.add_info_strip(
		body,
		"+  " + _reward_text(reward),
		GOLD,
		unlocked
	)

	var button_text := tr("CLEAR REQUIRED STAGES")
	var callback := Callable()
	var primary := false
	var disabled := true
	if unlocked:
		button_text = tr("CLAIM REWARD")
		callback = Callable(
			self,
			"_claim_trial"
		).bind(trial_id)
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


func _build_convergence_checkpoint(
	convergence: Dictionary,
	claimed_count: int,
	trial_count: int,
	is_focus: bool
) -> void:
	if convergence.is_empty():
		return

	var index: int = trial_count
	var unlocked: bool = bool(
		convergence.get("unlocked", false)
	)
	var claimed: bool = bool(
		convergence.get("claimed", false)
	)
	var title_text: String = tr(
		str(
			convergence.get(
				"title",
				"FIVE ELEMENTS CONVERGENCE"
			)
		)
	)

	if claimed:
		_build_compact_convergence(
			index,
			trial_count + 1,
			title_text,
			tr("CLAIMED"),
			"claimed"
		)
		return

	if not is_focus:
		_build_compact_convergence(
			index,
			trial_count + 1,
			title_text,
			tr("LOCKED"),
			"locked"
		)
		return

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	_content.add_child(row)

	_build_element_rail(
		row,
		5,
		index,
		trial_count + 1,
		GOLD,
		"ready"
	)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := LiveOpsUi.make_panel_style(
		Color(0.070, 0.052, 0.008, 0.97),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.98),
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

	_build_convergence_preview(
		body,
		title_text
	)

	LiveOpsUi.add_progress_meter(
		body,
		claimed_count,
		trial_count,
		GOLD
	)

	LiveOpsUi.add_info_strip(
		body,
		"+  " + _reward_text(
			convergence.get("reward", {})
		),
		GOLD,
		true
	)

	var action := LiveOpsUi.add_action_button(
		body,
		tr("CLAIM CONVERGENCE"),
		Callable(self, "_claim_convergence"),
		true
	)
	action.custom_minimum_size.y = 52.0
	action.disabled = not unlocked


func _build_compact_convergence(
	index: int,
	total_count: int,
	title_text: String,
	state_text: String,
	state_id: String
) -> void:
	var accent := GOLD
	if state_id == "claimed":
		accent = JADE
	elif state_id == "locked":
		accent = Color(GOLD.r, GOLD.g, GOLD.b, 0.46)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	_content.add_child(row)

	_build_element_rail(
		row,
		5,
		index,
		total_count,
		accent,
		state_id
	)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 68.0

	var style := LiveOpsUi.make_panel_style(
		Color(0.018, 0.020, 0.014, 0.92),
		Color(accent.r, accent.g, accent.b, 0.46),
		12
	)
	style.border_width_left = 2
	style.shadow_size = 2
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var details := VBoxContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_theme_constant_override("separation", 2)
	margin.add_child(details)

	var marker := LiveOpsUi.add_label(
		details,
		tr("CONVERGENCE"),
		9,
		accent
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


func _add_element_thumbnail(
	parent: HBoxContainer,
	trial_id: String,
	state_id: String
) -> void:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(74.0, 54.0)

	var accent: Color = _trial_accent(trial_id)
	var style := LiveOpsUi.make_panel_style(
		Color(0.004, 0.016, 0.020, 0.96),
		Color(accent.r, accent.g, accent.b, 0.42),
		8
	)
	style.shadow_size = 0
	frame.add_theme_stylebox_override("panel", style)
	parent.add_child(frame)

	var art_texture := _load_element_art(trial_id)
	if art_texture == null:
		return

	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = art_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if state_id == "claimed":
		art.modulate = Color(0.68, 0.80, 0.74, 0.82)
	else:
		art.modulate = Color(0.58, 0.64, 0.62, 0.72)
	frame.add_child(art)


func _build_element_preview(
	parent: VBoxContainer,
	trial_id: String,
	title_text: String,
	state_text: String,
	accent: Color
) -> void:
	var art_texture := _load_element_art(trial_id)
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

	var caption_shade := ColorRect.new()
	caption_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_shade.color = Color(0.002, 0.014, 0.018, 0.78)
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
		_element_label(trial_id),
		10,
		accent
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
	badge.custom_minimum_size.x = 92.0

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


func _build_convergence_preview(
	parent: VBoxContainer,
	title_text: String
) -> void:
	var path: String = JourneyArtCatalog.get_stage_art_path(
		5,
		5
	)
	if path.is_empty():
		return

	var art_texture := load(path) as Texture2D
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
	shade.color = Color(0.030, 0.020, 0.002, 0.22)
	frame.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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


func _build_element_rail(
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
	var connector_alpha: float = 0.44
	if state_id == "ready":
		connector_alpha = 0.74
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
	seal.texture = _load_element_seal(
		chapter_id,
		state_id
	)
	seal_center.add_child(seal)


func _load_element_seal(
	chapter_id: int,
	state_id: String
) -> Texture2D:
	var seal_state := "CURRENT"
	if state_id == "claimed":
		seal_state = "CLEARED"
	elif state_id == "locked":
		seal_state = "LOCKED"

	var path: String = JourneyArtCatalog.get_node_seal_path(
		chapter_id,
		seal_state
	)
	if path.is_empty():
		return null
	return load(path) as Texture2D


func _load_element_art(trial_id: String) -> Texture2D:
	var chapter_id: int = _element_chapter(trial_id)
	var stage_id: int = _element_stage(trial_id)
	var path: String = JourneyArtCatalog.get_stage_art_path(
		chapter_id,
		stage_id
	)
	if path.is_empty():
		return null
	return load(path) as Texture2D


func _element_chapter(trial_id: String) -> int:
	match trial_id:
		"metal_edge":
			return 2
		"water_flow":
			return 2
		_:
			return 1


func _element_stage(trial_id: String) -> int:
	match trial_id:
		"wood_resonance":
			return 2
		"fire_tempering":
			return 4
		"earth_foundation":
			return 3
		"metal_edge":
			return 4
		"water_flow":
			return 2
		_:
			return 1


func _element_label(trial_id: String) -> String:
	match trial_id:
		"wood_resonance":
			return tr("WOOD")
		"fire_tempering":
			return tr("FIRE")
		"earth_foundation":
			return tr("EARTH")
		"metal_edge":
			return tr("METAL")
		"water_flow":
			return tr("WATER")
		_:
			return tr("ELEMENT")


func _reward_text(reward: Dictionary) -> String:
	var items: Dictionary = reward.get("items", {})
	var stone_count: int = int(reward.get("spirit_stone", 0))
	var shard_count: int = int(items.get("refinement_shard", 0))
	var result: String = "%d %s" % [
		stone_count,
		tr("SPIRIT STONES"),
	]
	if shard_count > 0:
		result += "  |  %d %s" % [
			shard_count,
			tr("REFINEMENT SHARDS"),
		]
	return result


func _trial_accent(trial_id: String) -> Color:
	match trial_id:
		"wood_resonance":
			return JADE
		"fire_tempering":
			return FIRE
		"earth_foundation":
			return EARTH
		"metal_edge":
			return SKY
		"water_flow":
			return Color(0.31, 0.72, 0.95, 1.0)
		_:
			return GOLD


func _load_event_background() -> Texture2D:
	if _live_ops == null:
		return null

	var convergence: Dictionary = _live_ops.call(
		"get_five_elements_convergence"
	)
	if (
		bool(convergence.get("unlocked", false))
		and not bool(convergence.get("claimed", false))
	):
		var convergence_path: String = (
			JourneyArtCatalog.get_realm_vista_path(5)
		)
		if not convergence_path.is_empty():
			return load(convergence_path) as Texture2D

	var trial_ids: Array = _live_ops.call(
		"get_five_elements_trial_ids"
	)
	var focus_id: String = _choose_element_focus(trial_ids)
	var chapter_id: int = 1
	if not focus_id.is_empty():
		chapter_id = _element_chapter(focus_id)

	var path: String = JourneyArtCatalog.get_realm_vista_path(
		chapter_id
	)
	if path.is_empty():
		return null
	return load(path) as Texture2D

func _claim_trial(trial_id: String) -> void:
	if _live_ops != null:
		_live_ops.call("claim_five_elements_trial", trial_id)
		_refresh()


func _claim_convergence() -> void:
	if _live_ops != null:
		_live_ops.call("claim_five_elements_convergence")
		_refresh()


func _back() -> void:
	LiveOpsUi.return_home(self)
