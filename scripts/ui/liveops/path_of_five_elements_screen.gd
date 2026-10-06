extends Control

## PATH OF FIVE ELEMENTS — EVENT CONTENT EXPANSION E6
## Presentation/input only. JourneyManager remains progress authority,
## LiveOpsManager owns claims, and RewardManager owns reward delivery.

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")
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

	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("FIVE ELEMENTS EVENT"),
		tr(str(event.get("title", "PATH OF FIVE ELEMENTS"))),
		tr(str(event.get("description", ""))),
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
	var trial_ids: Array = _live_ops.call("get_five_elements_trial_ids")
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

	var summary := LiveOpsUi.make_card(_content, JADE)
	LiveOpsUi.add_label(summary, tr("ELEMENTAL TRIALS"), 18, GOLD)
	LiveOpsUi.add_label(
		summary,
		tr("PROGRESS %d / %d") % [unlocked_count, trial_ids.size()],
		14,
		JADE
	)
	if bool(_live_ops.call("is_five_elements_complete")):
		LiveOpsUi.add_label(
			summary,
			tr("ALL ELEMENTAL REWARDS CLAIMED"),
			13,
			MUTED
		)
	elif (
		bool(convergence.get("unlocked", false))
		and not bool(convergence.get("claimed", false))
	):
		LiveOpsUi.add_label(summary, tr("CONVERGENCE READY"), 13, GOLD)
	elif claimable_count > 0:
		LiveOpsUi.add_label(
			summary,
			tr("%d REWARDS READY") % claimable_count,
			13,
			JADE
		)
	else:
		LiveOpsUi.add_label(summary, tr("IN PROGRESS"), 13, MUTED)

	for raw_id: Variant in trial_ids:
		_build_trial_card(str(raw_id))

	_build_convergence_card(convergence, claimed_count, trial_ids.size())


func _build_trial_card(trial_id: String) -> void:
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
	var required_keys: Array = trial.get("required_stage_keys", [])
	var required_labels := PackedStringArray()
	for raw_key: Variant in required_keys:
		required_labels.append(str(raw_key))
	var reward: Dictionary = trial.get("reward", {})
	var accent: Color = _trial_accent(trial_id)

	var card := LiveOpsUi.make_card(_content, accent)
	LiveOpsUi.add_label(
		card,
		tr(str(trial.get("title", trial_id))),
		17,
		accent
	)
	LiveOpsUi.add_label(
		card,
		tr("REQUIRED STAGES: %s") % ", ".join(required_labels),
		13,
		MUTED
	)
	LiveOpsUi.add_label(
		card,
		tr("PROGRESS %d / %d") % [cleared_count, required_count],
		13,
		JADE
	)
	LiveOpsUi.add_label(card, _reward_text(reward), 13, GOLD)

	if claimed:
		var claimed_button := LiveOpsUi.add_action_button(
			card,
			tr("CLAIMED"),
			Callable(),
			false
		)
		claimed_button.disabled = true
		return

	if not unlocked:
		var locked_button := LiveOpsUi.add_action_button(
			card,
			tr("CLEAR REQUIRED STAGES"),
			Callable(),
			false
		)
		locked_button.disabled = true
		return

	LiveOpsUi.add_action_button(
		card,
		tr("CLAIM REWARD"),
		Callable(self, "_claim_trial").bind(trial_id),
		true
	)


func _build_convergence_card(
	convergence: Dictionary,
	claimed_count: int,
	trial_count: int
) -> void:
	if convergence.is_empty():
		return

	var unlocked: bool = bool(convergence.get("unlocked", false))
	var claimed: bool = bool(convergence.get("claimed", false))
	var card := LiveOpsUi.make_card(_content, GOLD)
	LiveOpsUi.add_label(
		card,
		tr(str(convergence.get("title", "FIVE ELEMENTS CONVERGENCE"))),
		18,
		GOLD
	)
	LiveOpsUi.add_label(
		card,
		tr("PROGRESS %d / %d") % [claimed_count, trial_count],
		13,
		JADE
	)
	LiveOpsUi.add_label(
		card,
		_reward_text(convergence.get("reward", {})),
		13,
		GOLD
	)

	if claimed:
		var claimed_button := LiveOpsUi.add_action_button(
			card,
			tr("CLAIMED"),
			Callable(),
			false
		)
		claimed_button.disabled = true
		return

	if not unlocked:
		var locked_button := LiveOpsUi.add_action_button(
			card,
			tr("CLAIM ALL FIVE ELEMENTS FIRST"),
			Callable(),
			false
		)
		locked_button.disabled = true
		return

	LiveOpsUi.add_action_button(
		card,
		tr("CLAIM CONVERGENCE"),
		Callable(self, "_claim_convergence"),
		true
	)


func _reward_text(reward: Dictionary) -> String:
	var items: Dictionary = reward.get("items", {})
	var stone_count: int = int(reward.get("spirit_stone", 0))
	var shard_count: int = int(items.get("refinement_shard", 0))
	var result: String = "%d %s" % [stone_count, tr("SPIRIT STONES")]
	if shard_count > 0:
		result += "  •  %d %s" % [
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
