extends Control

## HEAVENLY LADDER — EVENT CONTENT EXPANSION E4
## Presentation/input only. JourneyManager remains progress authority,
## LiveOpsManager owns claims, and RewardManager owns reward delivery.

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")
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
	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("LADDER EVENT"),
		tr(str(event.get("title", "HEAVENLY LADDER"))),
		tr(str(event.get("description", ""))),
		EVENT_ICON
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

	var summary := LiveOpsUi.make_card(_content, SKY)
	LiveOpsUi.add_label(summary, tr("ASCENSION RUNGS"), 18, GOLD)
	LiveOpsUi.add_label(
		summary,
		tr("PROGRESS %d / %d") % [cleared_count, total_stages],
		14,
		JADE
	)
	if claimed_count == milestone_ids.size() and not milestone_ids.is_empty():
		LiveOpsUi.add_label(summary, tr("ALL LADDER REWARDS CLAIMED"), 13, MUTED)
	elif claimable_count > 0:
		LiveOpsUi.add_label(
			summary,
			tr("%d REWARDS READY") % claimable_count,
			13,
			JADE
		)
	else:
		LiveOpsUi.add_label(summary, tr("IN PROGRESS"), 13, MUTED)

	for raw_id: Variant in milestone_ids:
		_build_milestone_card(str(raw_id))


func _build_milestone_card(milestone_id: String) -> void:
	var milestone: Dictionary = _live_ops.call(
		"get_heavenly_ladder_milestone",
		milestone_id
	)
	if milestone.is_empty():
		return
	var unlocked: bool = bool(milestone.get("unlocked", false))
	var claimed: bool = bool(milestone.get("claimed", false))
	var required_clears: int = int(milestone.get("required_clears", 0))
	var reward: Dictionary = milestone.get("reward", {})
	var items: Dictionary = reward.get("items", {})
	var stone_count: int = int(reward.get("spirit_stone", 0))
	var shard_count: int = int(items.get("refinement_shard", 0))
	var accent: Color = SKY if unlocked and not claimed else JADE

	var card := LiveOpsUi.make_card(_content, accent)
	LiveOpsUi.add_label(card, tr(str(milestone.get("title", milestone_id))), 17, accent)
	LiveOpsUi.add_label(
		card,
		tr("CLEAR %d JOURNEY STAGES") % required_clears,
		13,
		MUTED
	)
	var reward_text: String = "%d %s" % [stone_count, tr("SPIRIT STONES")]
	if shard_count > 0:
		reward_text += "  •  %d %s" % [shard_count, tr("REFINEMENT SHARDS")]
	LiveOpsUi.add_label(card, reward_text, 13, GOLD)

	if claimed:
		var claimed_button := LiveOpsUi.add_action_button(
			card, tr("CLAIMED"), Callable(), false
		)
		claimed_button.disabled = true
		return
	if not unlocked:
		var locked_button := LiveOpsUi.add_action_button(
			card,
			tr("CLEAR %d JOURNEY STAGES") % required_clears,
			Callable(),
			false
		)
		locked_button.disabled = true
		return

	LiveOpsUi.add_action_button(
		card,
		tr("CLAIM REWARD"),
		Callable(self, "_claim").bind(milestone_id),
		true
	)


func _claim(milestone_id: String) -> void:
	if _live_ops != null:
		_live_ops.call("claim_heavenly_ladder_milestone", milestone_id)
		_refresh()


func _back() -> void:
	LiveOpsUi.return_home(self)
