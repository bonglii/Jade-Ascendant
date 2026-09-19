extends Node

const LiveOpsManagerScript = preload(
	"res://scripts/managers/live_ops_manager.gd"
)
const UiIconPolishManagerScript = preload(
	"res://scripts/managers/ui_icon_polish_manager.gd"
)

var continue_game: bool = false
var _lifecycle_checkpoint_in_progress: bool = false


func _ready() -> void:
	# Keep Live Ops outside the autoload registry so the established startup
	# ordering and Phase 0 autoload contract remain unchanged. The deferred
	# bootstrap runs after permanent managers (including PavilionManager) load.
	call_deferred("_bootstrap_runtime_helpers")


func _bootstrap_runtime_helpers() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return

	if tree.root.get_node_or_null("LiveOpsManager") == null:
		var live_ops: Node = LiveOpsManagerScript.new()
		live_ops.name = "LiveOpsManager"
		tree.root.add_child(live_ops)

	if tree.root.get_node_or_null("UiIconPolishManager") == null:
		var icon_polish: Node = UiIconPolishManagerScript.new()
		icon_polish.name = "UiIconPolishManager"
		tree.root.add_child(icon_polish)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		checkpoint_active_run_for_background()


## Android/iOS may suspend the process shortly after the application enters the
## background. Commit the latest active-run snapshot before suspension, but never
## recreate a checkpoint after a terminal result or during another save/transition.
func checkpoint_active_run_for_background() -> bool:
	if _lifecycle_checkpoint_in_progress:
		return false
	if SaveManager.has_pending_transaction():
		return false
	if SceneTransitionManager.is_transitioning:
		return false
	if not JourneyManager.has_active_run():
		return false

	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return false

	var active_scene: Node = tree.current_scene
	var victory_manager: Node = active_scene.get_node_or_null("VictoryManager")
	if (
		victory_manager != null
		and bool(victory_manager.get("victory_processed"))
	):
		return false

	var game_over_manager: Node = active_scene.get_node_or_null("GameOverManager")
	if (
		game_over_manager != null
		and bool(game_over_manager.get("game_over_triggered"))
	):
		return false

	var checkpoint_manager: Node = active_scene.get_node_or_null("CheckPointManager")
	if (
		checkpoint_manager == null
		or not checkpoint_manager.has_method("save_checkpoint")
	):
		return false

	_lifecycle_checkpoint_in_progress = true
	var checkpoint_saved: bool = bool(
		checkpoint_manager.call("save_checkpoint")
	)
	_lifecycle_checkpoint_in_progress = false

	if checkpoint_saved:
		DebugLogger.system(
			"Lifecycle checkpoint saved before application pause."
		)
	return checkpoint_saved


func start_new_game() -> void:
	continue_game = false


func continue_saved_game() -> void:
	continue_game = true


func consume_continue_request() -> bool:
	if continue_game:
		continue_game = false
		return true

	return false
