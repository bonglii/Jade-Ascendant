extends Control

const LiveOpsUi = preload(
	"res://scripts/ui/liveops/live_ops_ui.gd"
)

const ICON_SEVEN_DAY: Texture2D = preload(
	"res://assets/ui/liveops/seven_day.png"
)
const ICON_REWARD_CHEST: Texture2D = preload(
	"res://assets/ui/pavilion/icons/reward_chest.png"
)

var content: VBoxContainer
var live_ops: Node


func _ready() -> void:
	live_ops = get_node_or_null("/root/LiveOpsManager")
	if live_ops == null:
		push_error(
			"NewPlayerEventScreen: LiveOpsManager tidak tersedia."
		)
		return

	SceneTransitionManager.set_back_handler(_back)

	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("NEW CULTIVATOR EVENT"),
		tr("Seven Days of Ascension"),
		tr(
			"Seven active days. No calendar punishment. "
			+ "Your progress waits for you."
		),
		ICON_SEVEN_DAY
	)
	content = shell["content"] as VBoxContainer
	(shell["back_button"] as Button).pressed.connect(_back)
	_refresh()


func _refresh() -> void:
	LiveOpsUi.clear_container(content)

	var active_days: int = live_ops.get_active_login_day_count()
	var summary := LiveOpsUi.make_card(
		content,
		Color(0.96, 0.78, 0.34, 1.0)
	)
	var active_label := LiveOpsUi.add_label(
		summary,
		tr("ACTIVE DAY %d / %d") % [
			active_days,
			live_ops.LOGIN_DAY_COUNT,
		],
		18,
		Color(0.98, 0.82, 0.42, 1.0)
	)
	active_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	active_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	if live_ops.is_new_player_event_complete():
		var done_label := LiveOpsUi.add_label(
			summary,
			tr("ALL SEVEN DAYS COMPLETE"),
			14,
			Color(0.36, 0.92, 0.78, 1.0)
		)
		done_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)

	for day: int in range(1, live_ops.LOGIN_DAY_COUNT + 1):
		_add_day_tile(grid, day)


func _add_day_tile(parent: GridContainer, day: int) -> void:
	var unlocked: bool = live_ops.is_login_day_unlocked(day)
	var claimed: bool = live_ops.is_login_day_claimed(day)
	var is_final_day: bool = day == live_ops.LOGIN_DAY_COUNT

	var accent := Color(0.27, 0.74, 0.66, 1.0)
	if is_final_day:
		accent = Color(0.98, 0.76, 0.30, 1.0)
	elif unlocked and not claimed:
		accent = Color(0.90, 0.72, 0.30, 1.0)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 190.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		LiveOpsUi.make_panel_style(
			Color(0.002, 0.024, 0.034, 0.97),
			Color(accent.r, accent.g, accent.b, 0.52),
			12
		)
	)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var day_label := LiveOpsUi.add_label(
		box,
		tr("DAY %d") % day,
		15,
		Color(0.98, 0.84, 0.48, 1.0)
	)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	var reward_icon := TextureRect.new()
	reward_icon.custom_minimum_size = Vector2(
		56.0 if is_final_day else 48.0,
		56.0 if is_final_day else 48.0
	)
	reward_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reward_icon.texture = ICON_REWARD_CHEST
	reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reward_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_icon.modulate = (
		Color.WHITE
		if unlocked
		else Color(0.55, 0.60, 0.58, 0.72)
	)
	box.add_child(reward_icon)

	var reward: Dictionary = live_ops.get_login_reward(day)
	var reward_label := LiveOpsUi.add_label(
		box,
		RewardManager.get_reward_summary(reward),
		11,
		Color(0.84, 0.90, 0.76, 1.0)
	)
	reward_label.custom_minimum_size = Vector2(0.0, 38.0)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var action_text: String
	var callback := Callable()
	var is_disabled := false

	if claimed:
		action_text = tr("CLAIMED")
		is_disabled = true
	elif unlocked:
		action_text = tr("CLAIM REWARD")
		callback = func() -> void: _claim_day(day)
	else:
		action_text = tr("DAY %d") % day
		is_disabled = true

	var action := LiveOpsUi.add_action_button(
		box,
		action_text,
		callback,
		unlocked and not claimed
	)
	action.custom_minimum_size.y = 38.0
	action.add_theme_font_size_override("font_size", 12)
	action.disabled = is_disabled


func _claim_day(day: int) -> void:
	if live_ops.claim_login_day(day):
		_refresh()


func _back() -> void:
	LiveOpsUi.return_home(self)
