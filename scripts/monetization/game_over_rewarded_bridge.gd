extends Node

## Verified rewarded-ad boundary for in-run revive.
## The provider callback never mutates gameplay directly; it is forwarded only
## to the currently defeated run's GameOverManager.
const PLACEMENT_ID: String = "game_over_revive"


func _ready() -> void:
	var manager: Variant = get_parent()
	if not manager.verified_rewarded_completed.is_connected(
		_on_verified_rewarded_completed
	):
		manager.verified_rewarded_completed.connect(
			_on_verified_rewarded_completed
		)
	if not manager.rewarded_request_finished.is_connected(
		_on_rewarded_request_finished
	):
		manager.rewarded_request_finished.connect(
			_on_rewarded_request_finished
		)


func _get_game_over_manager() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("GameOverManager")


func _on_verified_rewarded_completed(
	placement: String,
	grant_id: String
) -> void:
	if placement != PLACEMENT_ID:
		return
	var game_over_manager: Node = _get_game_over_manager()
	if game_over_manager == null:
		_publish(false, "Game Over manager is unavailable.")
		return
	var result: Dictionary = game_over_manager.call(
		"apply_verified_rewarded_revive",
		grant_id
	)
	var success: bool = bool(result.get("success", false))
	var message: String = (
		"Revived • 60% HP • 2.5s protection"
		if success
		else str(result.get("error", "Rewarded revive failed."))
	)
	_publish(success, message)


func _on_rewarded_request_finished(
	placement: String,
	status: String
) -> void:
	if placement != PLACEMENT_ID or status == "completed":
		return
	var game_over_manager: Node = _get_game_over_manager()
	if game_over_manager != null:
		game_over_manager.call("cancel_pending_rewarded_revive")


func _publish(success: bool, message: String) -> void:
	var manager: Variant = get_parent()
	manager.call(
		"publish_reward_delivery_result",
		PLACEMENT_ID,
		success,
		1 if success else 0,
		message
	)
