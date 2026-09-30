extends Node

## Menu/Pavilion prewarm pass 2 — featured relic art staged before entering.
## No UI nodes are created and no gameplay/monetization/save state is touched.
## Existing SceneTransitionManager still owns transitions.
## The prewarm starts only AFTER an initial hub menu becomes interactive.

const PAVILION_SCENE: String = "res://scenes/ui/pavilion_screen.tscn"
const MENU_SCENES: PackedStringArray = [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/cultivation_menu.tscn",
	"res://scenes/ui/equipment_screen.tscn",
	"res://scenes/ui/daily_quest_screen.tscn",
	"res://scenes/ui/achievement_screen.tscn",
]

# Assets directly requested during Pavilion's visible, above-fold build.
# Keep the set small: a full inventory/summoning cache wastes Android RAM.
# Never pre-request the PackedScene: doing so could race the existing menu
# transition manager's own threaded load for that SAME resource path.
const PRIORITY_RESOURCES: PackedStringArray = [
	"res://assets/ui/pavilion/redesign/pavilion_summon_palace_bg.png",
	"res://assets/ui/pavilion/redesign/pavilion_summon_altar.png",
	"res://assets/ui/pavilion/redesign/components/featured_rate_up_frame.png",
	"res://assets/ui/pavilion/redesign/components/featured_relic_frame.png",
	"res://assets/ui/pavilion/redesign/components/summon_one_button.png",
	"res://assets/ui/pavilion/redesign/components/summon_ten_button.png",
	# Five authored Legendary featured cards are rendered above the fold.
	"res://assets/ui/equipment/final/nine_heavens_star_sword.png",
	"res://assets/ui/equipment/final/sovereign_mantle.png",
	"res://assets/ui/equipment/final/tribulation_bracer.png",
	"res://assets/ui/equipment/final/cloudtreader_boots.png",
	"res://assets/ui/equipment/final/ascendant_heart.png",
]

# Deferred, below-the-fold resources — useful but not critical to the first
# paint. Spread processing across frames instead of opening everything at once.
const SECONDARY_RESOURCES: PackedStringArray = [
	"res://assets/ui/pavilion/redesign/components/drop_rates_button.png",
	"res://assets/ui/pavilion/redesign/components/watch_ad_button.png",
	"res://assets/ui/pavilion/redesign/components/summon_history_button.png",
	"res://assets/ui/hero/lin_yue_menu_showcase_v2.png",
]

const IDLE_DELAY_SECONDS: float = 0.18

var _warm_cache: Dictionary = {}
var _prewarm_started: bool = false
var _prewarm_completed: bool = false
var _generation: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Optional parameter accepts either a zero- or one-argument Godot signal.
	var callback: Callable = Callable(self, "_on_scene_changed")
	if not get_tree().scene_changed.is_connected(callback):
		get_tree().scene_changed.connect(callback)
	_on_scene_changed.call_deferred()


func _exit_tree() -> void:
	_generation += 1
	if get_tree() != null:
		var callback: Callable = Callable(self, "_on_scene_changed")
		if get_tree().scene_changed.is_connected(callback):
			get_tree().scene_changed.disconnect(callback)
	_warm_cache.clear()


func _on_scene_changed(_scene: Node = null) -> void:
	var current_scene: Node = get_tree().current_scene
	if not is_instance_valid(current_scene):
		return
	var scene_path: String = current_scene.scene_file_path

	# Free optional menu textures before a memory-intensive gameplay run.
	if scene_path.begins_with("res://scenes/levels/"):
		_generation += 1
		_prewarm_started = false
		_prewarm_completed = false
		_warm_cache.clear()
		return

	if scene_path == PAVILION_SCENE:
		return
	if scene_path not in MENU_SCENES:
		return
	if _prewarm_started or _prewarm_completed:
		return

	_prewarm_started = true
	_generation += 1
	_start_prewarm.call_deferred(_generation)


func _start_prewarm(generation_id: int) -> void:
	# Do not compete with the initial home screen or its opening animation.
	await get_tree().create_timer(IDLE_DELAY_SECONDS, true).timeout
	if not _is_current_run(generation_id):
		return
	var started_at: int = Time.get_ticks_msec()

	for path_value: String in PRIORITY_RESOURCES:
		await _await_idle_navigation(generation_id)
		if not _is_current_run(generation_id):
			return
		await _prewarm_texture(path_value, generation_id)
		if not _is_current_run(generation_id):
			return
		await get_tree().process_frame

	# Less-important assets load only after the Pavilion first-fold art.
	for path_value: String in SECONDARY_RESOURCES:
		await _await_idle_navigation(generation_id)
		if not _is_current_run(generation_id):
			return
		await _prewarm_texture(path_value, generation_id)
		if not _is_current_run(generation_id):
			return
		await get_tree().process_frame

	_prewarm_completed = true
	_prewarm_started = false
	DebugLogger.system(
		"Menu idle prewarm | %d optional textures | %d ms"
		% [_warm_cache.size(), Time.get_ticks_msec() - started_at]
	)


func _await_idle_navigation(generation_id: int) -> void:
	# A prewarm may finish a pending resource but must not launch another
	# during scene transitions, Pavilion first paint, or gameplay selection.
	while _is_current_run(generation_id) and not _hub_is_idle():
		await get_tree().create_timer(0.12, true).timeout


func _hub_is_idle() -> bool:
	if SceneTransitionManager.is_transitioning:
		return false
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene):
		return false
	return scene.scene_file_path in MENU_SCENES


func _prewarm_texture(path_value: String, generation_id: int) -> void:
	if not _is_current_run(generation_id):
		return
	if path_value.is_empty() or not ResourceLoader.exists(path_value):
		return
	if _warm_cache.has(path_value):
		return

	if ResourceLoader.has_cached(path_value):
		var existing: Texture2D = ResourceLoader.load(
			path_value, "Texture2D", ResourceLoader.CACHE_MODE_REUSE
		) as Texture2D
		if existing != null:
			_warm_cache[path_value] = existing
		return

	var request_error: Error = ResourceLoader.load_threaded_request(
		path_value,
		"Texture2D",
		false,
		ResourceLoader.CACHE_MODE_REUSE
	)
	if request_error != OK:
		# A different screen can be requesting this asset simultaneously.
		# Never block the main thread trying to seize that request.
		return

	while _is_current_run(generation_id):
		var load_status: int = ResourceLoader.load_threaded_get_status(path_value)
		if load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			continue
		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			var warmed: Texture2D = ResourceLoader.load_threaded_get(
				path_value
			) as Texture2D
			if warmed != null and _is_current_run(generation_id):
				_warm_cache[path_value] = warmed
		return


func _is_current_run(generation_id: int) -> bool:
	return is_inside_tree() and generation_id == _generation
