extends Control

## JADE VALLEY PILGRIMAGE — EVENT CONTENT EXPANSION E2
## Presentation/input only. LiveOpsManager owns unlock checks, permanent claim
## markers and RewardManager delivery. JourneyManager remains the progress owner.

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")
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
		EVENT_ICON
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

	var summary := LiveOpsUi.make_card(_content, GOLD)
	LiveOpsUi.add_label(
		summary,
		tr("VERDANT MILESTONES"),
		18,
		GOLD
	)
	LiveOpsUi.add_label(
		summary,
		tr("PROGRESS %d / %d") % [
			unlocked_count,
			milestone_ids.size(),
		],
		14,
		JADE
	)
	if bool(_live_ops.call("is_pilgrimage_complete")):
		LiveOpsUi.add_label(
			summary,
			tr("ALL PILGRIMAGE OFFERINGS CLAIMED"),
			13,
			MUTED
		)
	elif claimable_count > 0:
		LiveOpsUi.add_label(
			summary,
			tr("%d REWARDS READY") % claimable_count,
			13,
			JADE
		)
	else:
		LiveOpsUi.add_label(
			summary,
			tr("IN PROGRESS"),
			13,
			MUTED
		)

	for raw_id: Variant in milestone_ids:
		_build_milestone_card(str(raw_id), claimed_count)


func _build_milestone_card(
	milestone_id: String,
	_claimed_count: int
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

	var accent: Color = GOLD if unlocked and not claimed else JADE
	var card := LiveOpsUi.make_card(_content, accent)
	LiveOpsUi.add_label(
		card,
		tr(str(milestone.get("title", milestone_id))),
		17,
		accent
	)
	LiveOpsUi.add_label(
		card,
		tr(str(milestone.get("description", ""))),
		13,
		MUTED
	)

	var reward_text: String = "%d %s" % [
		stone_count,
		tr("SPIRIT STONES"),
	]
	if shard_count > 0:
		reward_text += "  •  %d %s" % [
			shard_count,
			tr("REFINEMENT SHARDS"),
		]
	LiveOpsUi.add_label(
		card,
		reward_text,
		13,
		GOLD
	)

	var button_text: String = tr("IN PROGRESS")
	var callback := Callable()
	var primary: bool = false
	var disabled: bool = true
	if claimed:
		button_text = tr("CLAIMED")
	elif unlocked:
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
		card,
		button_text,
		callback,
		primary
	)
	action.disabled = disabled


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
