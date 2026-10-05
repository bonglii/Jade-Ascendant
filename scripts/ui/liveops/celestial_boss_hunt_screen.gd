extends Control

## CELESTIAL BOSS HUNT — EVENT CONTENT EXPANSION E3
## Presentation/input only. LiveOpsManager owns progress validation, optional
## rewarded request state, permanent claim markers, and RewardManager delivery.

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")
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
	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("BOSS HUNT EVENT"),
		tr(str(event.get("title", "CELESTIAL BOSS HUNT"))),
		tr(str(event.get("description", ""))),
		EVENT_ICON
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
	var milestone_ids: Array = _live_ops.call("get_boss_hunt_milestone_ids")
	var unlocked_count: int = int(_live_ops.call("get_boss_hunt_unlocked_count"))
	var claimed_count: int = int(_live_ops.call("get_boss_hunt_claimed_count"))
	var claimable_count: int = int(_live_ops.call("get_boss_hunt_claimable_count"))
	var policy: Dictionary = _live_ops.call("get_boss_hunt_rewarded_policy_status")
	var pending_id: String = str(policy.get("pending_milestone_id", ""))

	var summary := LiveOpsUi.make_card(_content, EMBER)
	LiveOpsUi.add_label(summary, tr("SOVEREIGN BOUNTIES"), 18, GOLD)
	LiveOpsUi.add_label(summary, tr("PROGRESS %d / %d") % [unlocked_count, milestone_ids.size()], 14, JADE)
	if claimed_count == milestone_ids.size() and not milestone_ids.is_empty():
		LiveOpsUi.add_label(summary, tr("ALL BOSS BOUNTIES CLAIMED"), 13, MUTED)
	elif claimable_count > 0:
		LiveOpsUi.add_label(summary, tr("%d REWARDS READY") % claimable_count, 13, JADE)
	else:
		LiveOpsUi.add_label(summary, tr("IN PROGRESS"), 13, MUTED)

	var boost_text: String = tr("2× BOOST UNAVAILABLE")
	if not pending_id.is_empty():
		boost_text = tr("2× BOOST IN PROGRESS")
	elif int(policy.get("placement_claims", 0)) >= int(policy.get("daily_limit", 1)):
		boost_text = tr("2× BOOST USED TODAY")
	elif bool(policy.get("available", false)):
		boost_text = tr("2× BOOST AVAILABLE TODAY")
	LiveOpsUi.add_label(summary, boost_text, 13, EMBER)
	LiveOpsUi.add_label(summary, tr("NORMAL CLAIM ALWAYS REMAINS AVAILABLE"), 12, MUTED)

	for raw_id: Variant in milestone_ids:
		_build_milestone_card(str(raw_id), pending_id)


func _build_milestone_card(milestone_id: String, pending_id: String) -> void:
	var milestone: Dictionary = _live_ops.call("get_boss_hunt_milestone", milestone_id)
	if milestone.is_empty():
		return
	var unlocked: bool = bool(milestone.get("unlocked", false))
	var claimed: bool = bool(milestone.get("claimed", false))
	var chapter_id: int = int(milestone.get("chapter_id", 0))
	var reward: Dictionary = milestone.get("reward", {})
	var items: Dictionary = reward.get("items", {})
	var stone_count: int = int(reward.get("spirit_stone", 0))
	var shard_count: int = int(items.get("refinement_shard", 0))
	var pending: bool = not pending_id.is_empty()
	var accent: Color = EMBER if unlocked and not claimed else JADE

	var card := LiveOpsUi.make_card(_content, accent)
	LiveOpsUi.add_label(card, tr(str(milestone.get("title", milestone_id))), 17, accent)
	LiveOpsUi.add_label(card, tr(str(milestone.get("description", ""))), 13, MUTED)
	var reward_text: String = "%d %s" % [stone_count, tr("SPIRIT STONES")]
	if shard_count > 0:
		reward_text += "  •  %d %s" % [shard_count, tr("REFINEMENT SHARDS")]
	LiveOpsUi.add_label(card, reward_text, 13, GOLD)

	if claimed:
		var claimed_button := LiveOpsUi.add_action_button(card, tr("CLAIMED"), Callable(), false)
		claimed_button.disabled = true
		return
	if not unlocked:
		var locked_button := LiveOpsUi.add_action_button(card, tr("CLEAR STAGE %d-5") % chapter_id, Callable(), false)
		locked_button.disabled = true
		return

	var normal_button := LiveOpsUi.add_action_button(
		card,
		tr("CLAIM REWARD"),
		Callable(self, "_claim_normal").bind(milestone_id),
		true
	)
	normal_button.disabled = pending
	var double_button := LiveOpsUi.add_action_button(
		card,
		tr("CLAIM 2× • OPTIONAL AD"),
		Callable(self, "_claim_double").bind(milestone_id),
		false
	)
	double_button.disabled = pending or not bool(_live_ops.call("is_boss_hunt_double_available", milestone_id))


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
