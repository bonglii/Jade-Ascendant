extends Node

## Home claim-ready notification badges.
##
## Presentation only:
## - DailyQuestManager owns daily completion/claim state.
## - AchievementManager owns achievement unlock/claim state.
## - this script only reflects get_claimable_count() on the Home quick actions.

const BADGE_SIZE: float = 25.0
const BADGE_MARGIN_RIGHT: float = 7.0
const BADGE_MARGIN_TOP: float = 5.0

var daily_button: Button = null
var achievement_button: Button = null
var daily_badge: Label = null
var achievement_badge: Label = null


func _ready() -> void:
	# HomeProductionOverlay is readied before MainMenu. Defer so MainMenu's own
	# first _refresh_home() has already finished before badges normalize labels.
	call_deferred("_initialize_badges")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		call_deferred("_refresh_badges")


func _initialize_badges() -> void:
	var overlay := get_parent()
	if overlay == null:
		return
	var home_ui := overlay.get_parent()
	if home_ui == null:
		return

	daily_button = home_ui.get_node_or_null(
		"HomeActions/QuickActions/DailyQuickButton"
	) as Button
	achievement_button = home_ui.get_node_or_null(
		"HomeActions/QuickActions/AchievementQuickButton"
	) as Button

	if daily_button == null or achievement_button == null:
		push_warning(
			"HomeClaimNotificationBadges: Home quick-action buttons not found."
		)
		return

	daily_badge = _create_badge(daily_button, "DailyClaimBadge")
	achievement_badge = _create_badge(
		achievement_button,
		"AchievementClaimBadge"
	)

	_connect_manager_signals()
	_refresh_badges()


func _create_badge(button: Button, node_name: String) -> Label:
	var existing := button.get_node_or_null(node_name) as Label
	if existing != null:
		return existing

	var badge := Label.new()
	badge.name = node_name
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 20
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override(
		"font_color",
		Color(1.0, 0.96, 0.82, 1.0)
	)
	badge.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.90)
	)
	badge.add_theme_constant_override("shadow_offset_y", 1)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.10, 0.08, 0.99)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.78, 0.30, 1.0)
	style.corner_radius_top_left = 13
	style.corner_radius_top_right = 13
	style.corner_radius_bottom_left = 13
	style.corner_radius_bottom_right = 13
	style.shadow_color = Color(0.45, 0.02, 0.01, 0.42)
	style.shadow_size = 4
	badge.add_theme_stylebox_override("normal", style)

	button.add_child(badge)
	badge.anchor_left = 1.0
	badge.anchor_top = 0.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 0.0
	badge.offset_left = -BADGE_MARGIN_RIGHT - BADGE_SIZE
	badge.offset_top = BADGE_MARGIN_TOP
	badge.offset_right = -BADGE_MARGIN_RIGHT
	badge.offset_bottom = BADGE_MARGIN_TOP + BADGE_SIZE
	badge.visible = false
	return badge


func _connect_manager_signals() -> void:
	if not AchievementManager.achievement_unlocked.is_connected(
		_on_achievement_unlocked
	):
		AchievementManager.achievement_unlocked.connect(
			_on_achievement_unlocked
		)
	if not AchievementManager.achievement_claimed.is_connected(
		_on_achievement_claimed
	):
		AchievementManager.achievement_claimed.connect(
			_on_achievement_claimed
		)

	if not DailyQuestManager.daily_quest_completed.is_connected(
		_on_daily_quest_completed
	):
		DailyQuestManager.daily_quest_completed.connect(
			_on_daily_quest_completed
		)
	if not DailyQuestManager.daily_quest_claimed.is_connected(
		_on_daily_quest_claimed
	):
		DailyQuestManager.daily_quest_claimed.connect(
			_on_daily_quest_claimed
		)
	if not DailyQuestManager.daily_quests_reset.is_connected(
		_on_daily_quests_reset
	):
		DailyQuestManager.daily_quests_reset.connect(
			_on_daily_quests_reset
		)


func _refresh_badges() -> void:
	if daily_button != null:
		daily_button.text = tr("DAILY TRIALS")
	if achievement_button != null:
		achievement_button.text = tr("ACHIEVEMENTS")

	_refresh_badge(
		daily_badge,
		DailyQuestManager.get_claimable_count(),
		tr("Daily Quest")
	)
	_refresh_badge(
		achievement_badge,
		AchievementManager.get_claimable_count(),
		tr("Achievement")
	)


func _refresh_badge(
	badge: Label,
	claimable_count: int,
	label_name: String
) -> void:
	if badge == null:
		return

	badge.visible = claimable_count > 0
	if claimable_count <= 0:
		badge.text = ""
		badge.tooltip_text = ""
		return

	badge.text = "9+" if claimable_count > 9 else str(claimable_count)
	badge.tooltip_text = (
		"%s: %d reward%s ready to claim"
		% [
			label_name,
			claimable_count,
			"" if claimable_count == 1 else "s",
		]
	)


func _on_achievement_unlocked(_achievement_id: String) -> void:
	_refresh_badges()


func _on_achievement_claimed(
	_achievement_id: String,
	_spirit_stone_reward: int
) -> void:
	_refresh_badges()


func _on_daily_quest_completed(_quest_id: String) -> void:
	_refresh_badges()


func _on_daily_quest_claimed(
	_quest_id: String,
	_spirit_stone_reward: int
) -> void:
	_refresh_badges()


func _on_daily_quests_reset(_date_key: String) -> void:
	_refresh_badges()
