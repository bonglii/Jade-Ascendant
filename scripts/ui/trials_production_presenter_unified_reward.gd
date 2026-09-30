extends "res://scripts/ui/trials_production_presenter.gd"

## Trials keeps its approved production UI, but explicit claim confirmation
## is now owned by RewardClaimResultPresenter for cross-menu consistency.

var daily_claim_badge: Label = null
var achievement_claim_badge: Label = null
var claim_badge_refresh_queued: bool = false


func setup(new_scene_root: Node) -> void:
	# Let the approved production presenter build the ACTUAL visible Daily /
	# Achievements buttons first. Legacy scene SectionTabs are hidden by the base.
	super(new_scene_root)

	if daily_tab == null or achievement_tab == null:
		push_warning(
			"TrialsProductionPresenter: production tabs unavailable for claim badges."
		)
		return

	daily_claim_badge = _create_claim_badge(
		daily_tab,
		"DailyClaimBadge"
	)
	achievement_claim_badge = _create_claim_badge(
		achievement_tab,
		"AchievementClaimBadge"
	)

	_connect_claim_badge_signals()
	_refresh_claim_badges()


func _create_claim_badge(
	tab_button: Button,
	node_name: String
) -> Label:
	var existing := tab_button.get_node_or_null(node_name) as Label
	if existing != null:
		return existing

	var badge := Label.new()
	badge.name = node_name
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 40
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override(
		"font_color",
		Color(1.0, 0.97, 0.82, 1.0)
	)
	badge.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.92)
	)
	badge.add_theme_constant_override("shadow_offset_y", 1)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.075, 0.055, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.78, 0.26, 1.0)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.48, 0.0, 0.0, 0.52)
	style.shadow_size = 4
	badge.add_theme_stylebox_override("normal", style)

	tab_button.add_child(badge)
	badge.anchor_left = 1.0
	badge.anchor_top = 0.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 0.0
	badge.offset_left = -33.0
	badge.offset_top = -7.0
	badge.offset_right = -5.0
	badge.offset_bottom = 21.0
	badge.visible = false
	return badge


func _connect_claim_badge_signals() -> void:
	if not DailyQuestManager.daily_quest_completed.is_connected(
		_queue_claim_badge_refresh
	):
		DailyQuestManager.daily_quest_completed.connect(
			_queue_claim_badge_refresh
		)
	if not DailyQuestManager.daily_quest_claimed.is_connected(
		_queue_claim_badge_refresh
	):
		DailyQuestManager.daily_quest_claimed.connect(
			_queue_claim_badge_refresh
		)
	if not DailyQuestManager.daily_quests_reset.is_connected(
		_queue_claim_badge_refresh
	):
		DailyQuestManager.daily_quests_reset.connect(
			_queue_claim_badge_refresh
		)

	if not AchievementManager.achievement_unlocked.is_connected(
		_queue_claim_badge_refresh
	):
		AchievementManager.achievement_unlocked.connect(
			_queue_claim_badge_refresh
		)
	if not AchievementManager.achievement_claimed.is_connected(
		_queue_claim_badge_refresh
	):
		AchievementManager.achievement_claimed.connect(
			_queue_claim_badge_refresh
		)


func _queue_claim_badge_refresh(
	_arg1: Variant = null,
	_arg2: Variant = null,
	_arg3: Variant = null
) -> void:
	if claim_badge_refresh_queued:
		return
	claim_badge_refresh_queued = true
	call_deferred("_deferred_claim_badge_refresh")


func _deferred_claim_badge_refresh() -> void:
	claim_badge_refresh_queued = false
	_refresh_claim_badges()


func _refresh_claim_badges() -> void:
	_set_claim_badge(
		daily_claim_badge,
		DailyQuestManager.get_claimable_count(),
		tr("Daily")
	)
	_set_claim_badge(
		achievement_claim_badge,
		AchievementManager.get_claimable_count(),
		tr("Achievements")
	)


func _set_claim_badge(
	badge: Label,
	claimable_count: int,
	section_name: String
) -> void:
	if badge == null or not is_instance_valid(badge):
		return

	badge.visible = claimable_count > 0
	if claimable_count <= 0:
		badge.text = ""
		badge.tooltip_text = ""
		return

	badge.text = "9+" if claimable_count > 9 else str(claimable_count)
	badge.tooltip_text = tr("%s rewards ready: %d") % [
		section_name,
		claimable_count,
	]


func _schedule_reward_result(
	source_title: String,
	amount: int,
	reward_count: int,
	previous_balance: int,
	new_balance: int,
	delay_seconds: float
) -> void:
	var unified_presenter: Node = get_node_or_null(
		"/root/RewardClaimResultPresenter"
	)
	if unified_presenter != null:
		return

	# Safety fallback if the runtime helper is unavailable.
	result_generation += 1
	var generation: int = result_generation
	await get_tree().create_timer(delay_seconds).timeout
	if generation != result_generation:
		return
	if not is_instance_valid(scene_root):
		return
	_show_reward_overlay(
		source_title,
		amount,
		reward_count,
		previous_balance,
		new_balance
	)
