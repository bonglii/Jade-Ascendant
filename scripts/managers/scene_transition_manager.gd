extends CanvasLayer

signal transition_started(scene_path: String)
signal transition_completed(scene_path: String)
signal transition_failed(scene_path: String, error_code: int)

## Scene Transition Manager
## Heavy/gameplay scene changes keep the threaded Celestial Gate presentation.
## Menu-to-menu changes use a lightweight jade veil without moving the scene root.
## Keeping the root Control fixed prevents portrait UI from appearing stretched
## or pulled during transitions on edge-to-edge Android displays.

const LOADING_SCREEN_SCENE: PackedScene = preload(
	"res://scenes/system/loading_screen.tscn"
)

const MENU_OUT_DURATION: float = 0.10
const MENU_IN_DURATION: float = 0.16
const MENU_REDUCED_OUT_DURATION: float = 0.05
const MENU_REDUCED_IN_DURATION: float = 0.08
const MENU_VEIL_COLOR: Color = Color(0.004, 0.055, 0.052, 0.72)

var is_transitioning: bool = false
var target_scene_path: String = ""
var minimum_display_time: float = 0.45
var transition_started_at: int = 0
var loading_screen: Variant = null
var completing_transition: bool = false
var previous_tree_paused: bool = false
var back_handler: Callable = Callable()
var menu_overlay: ColorRect = null

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	var root_window: Window = get_tree().root
	if not root_window.go_back_requested.is_connected(
		_on_go_back_requested
	):
		root_window.go_back_requested.connect(_on_go_back_requested)
	DebugLogger.system(str("SceneTransitionManager aktif!"))

func set_back_handler(handler: Callable) -> void:
	back_handler = handler

func _on_go_back_requested() -> void:
	if is_transitioning:
		return
	if not back_handler.is_valid():
		back_handler = Callable()
		return
	back_handler.call()

## Lightweight transition intended only for UI/menu scenes.
## direction is retained for call-site compatibility; menu transitions are fade-only.
func transition_menu_to(scene_path: String, direction: int = 1) -> Error:
	if is_transitioning:
		push_warning(
			"SceneTransitionManager: transition lain masih berjalan."
		)
		return ERR_BUSY
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error(
			"SceneTransitionManager: scene tidak ditemukan: " + scene_path
		)
		return ERR_FILE_NOT_FOUND

	# Menu scenes used to be loaded synchronously by change_scene_to_file(),
	# which can stall the main thread on asset-heavy Hero/Pavilion screens.
	# Request the PackedScene first and let the existing veil animation remain
	# responsive while ResourceLoader completes the work in the background.
	var request_error: Error = ResourceLoader.load_threaded_request(
		scene_path,
		"PackedScene",
		false,
		ResourceLoader.CACHE_MODE_REUSE
	)
	if request_error != OK:
		push_error(
			"SceneTransitionManager: gagal memulai background load menu "
			+ scene_path
			+ ". Error code: "
			+ str(request_error)
		)
		return request_error

	target_scene_path = scene_path
	transition_started_at = Time.get_ticks_msec()
	is_transitioning = true
	transition_started.emit(scene_path)
	_run_menu_transition(scene_path, clampi(direction, -1, 1))
	return OK

func _run_menu_transition(scene_path: String, _direction: int) -> void:
	var reduced_effects: bool = SettingsManager.reduced_effects
	var out_duration: float = (
		MENU_REDUCED_OUT_DURATION if reduced_effects else MENU_OUT_DURATION
	)
	var in_duration: float = (
		MENU_REDUCED_IN_DURATION if reduced_effects else MENU_IN_DURATION
	)

	menu_overlay = _create_menu_overlay()

	var out_tween: Tween = create_tween()
	out_tween.set_parallel(true)
	out_tween.set_trans(Tween.TRANS_QUAD)
	out_tween.set_ease(Tween.EASE_IN)
	out_tween.tween_property(
		menu_overlay,
		"color",
		MENU_VEIL_COLOR,
		out_duration
	)
	await out_tween.finished

	var packed_scene: PackedScene = await _await_menu_packed_scene(scene_path)
	if packed_scene == null:
		if is_transitioning and target_scene_path == scene_path:
			_fail_menu_transition(ERR_CANT_OPEN)
		return

	DebugLogger.system(str(
		"Menu background load ready: ",
		scene_path,
		" | ",
		Time.get_ticks_msec() - transition_started_at,
		" ms"
	))

	var change_error: Error = get_tree().change_scene_to_packed(packed_scene)
	if change_error != OK:
		_fail_menu_transition(change_error)
		return

	await get_tree().scene_changed

	var in_tween: Tween = create_tween()
	in_tween.set_parallel(true)
	in_tween.set_trans(Tween.TRANS_QUAD)
	in_tween.set_ease(Tween.EASE_OUT)
	if is_instance_valid(menu_overlay):
		in_tween.tween_property(
			menu_overlay,
			"color",
			Color(
				MENU_VEIL_COLOR.r,
				MENU_VEIL_COLOR.g,
				MENU_VEIL_COLOR.b,
				0.0
			),
			in_duration
		)
	await in_tween.finished

	if is_instance_valid(menu_overlay):
		menu_overlay.queue_free()
	menu_overlay = null
	var completed_path: String = target_scene_path
	_reset_state()
	DebugLogger.system(str("Menu transition selesai: ", completed_path))
	transition_completed.emit(completed_path)

func _await_menu_packed_scene(scene_path: String) -> PackedScene:
	while is_transitioning and target_scene_path == scene_path:
		var status: int = ResourceLoader.load_threaded_get_status(scene_path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(scene_path) as PackedScene
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			return null
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return null
		await get_tree().process_frame
	return null


func _create_menu_overlay() -> ColorRect:
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "MenuTransitionOverlay"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.color = Color(
		MENU_VEIL_COLOR.r,
		MENU_VEIL_COLOR.g,
		MENU_VEIL_COLOR.b,
		0.0
	)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return overlay

func _fail_menu_transition(error_code: Error) -> void:
	var failed_path: String = target_scene_path
	push_error(
		"SceneTransitionManager: gagal membuka menu "
		+ failed_path
		+ ". Error code: "
		+ str(error_code)
	)
	if is_instance_valid(menu_overlay):
		menu_overlay.queue_free()
	menu_overlay = null
	_reset_state()
	transition_failed.emit(failed_path, int(error_code))

func transition_to(
	scene_path: String,
	context: Dictionary = {}
) -> Error:
	if is_transitioning:
		push_warning(
			"SceneTransitionManager: transition lain masih berjalan."
		)
		return ERR_BUSY
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error(
			"SceneTransitionManager: scene tidak ditemukan: " + scene_path
		)
		return ERR_FILE_NOT_FOUND

	loading_screen = LOADING_SCREEN_SCENE.instantiate()
	if loading_screen == null:
		push_error("SceneTransitionManager: LoadingScreen gagal dibuat.")
		return ERR_CANT_CREATE

	add_child(loading_screen)
	loading_screen.configure(context)
	loading_screen.play_intro()
	target_scene_path = scene_path
	minimum_display_time = maxf(
		float(context.get("minimum_display_time", 0.45)),
		0.2
	)
	transition_started_at = Time.get_ticks_msec()
	completing_transition = false
	is_transitioning = true
	previous_tree_paused = get_tree().paused
	get_tree().paused = true

	var request_error: Error = ResourceLoader.load_threaded_request(
		target_scene_path,
		"PackedScene",
		false,
		ResourceLoader.CACHE_MODE_REUSE
	)
	if request_error != OK:
		_fail_transition(request_error)
		return request_error

	transition_started.emit(target_scene_path)
	DebugLogger.system(str("Celestial Gate membuka: ", target_scene_path))
	set_process(true)
	return OK

func _process(_delta: float) -> void:
	if not is_transitioning or target_scene_path.is_empty():
		return

	var progress: Array = []
	var status: int = (
		ResourceLoader.load_threaded_get_status(
			target_scene_path,
			progress
		)
	)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not progress.is_empty() and is_instance_valid(loading_screen):
			loading_screen.set_progress(minf(float(progress[0]), 0.94))
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		if is_instance_valid(loading_screen):
			loading_screen.set_progress(1.0)
		var elapsed_seconds: float = (
			Time.get_ticks_msec() - transition_started_at
		) / 1000.0
		if elapsed_seconds < minimum_display_time:
			return
		if not completing_transition:
			completing_transition = true
			_finish_transition.call_deferred()
		return
	if status == ResourceLoader.THREAD_LOAD_FAILED:
		_fail_transition(ERR_CANT_OPEN)
		return
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fail_transition(ERR_INVALID_DATA)

func _finish_transition() -> void:
	set_process(false)
	var completed_path: String = target_scene_path
	var packed_scene: PackedScene = (
		ResourceLoader.load_threaded_get(completed_path) as PackedScene
	)
	if packed_scene == null:
		_fail_transition(ERR_INVALID_DATA)
		return

	var change_error: Error = get_tree().change_scene_to_packed(packed_scene)
	if change_error != OK:
		_fail_transition(change_error)
		return

	await get_tree().scene_changed
	if is_instance_valid(loading_screen):
		await loading_screen.play_outro()
		loading_screen.queue_free()
	get_tree().paused = false
	_reset_state()
	DebugLogger.system(str("Celestial Gate selesai: ", completed_path))
	transition_completed.emit(completed_path)

func _fail_transition(error_code: Error) -> void:
	var failed_path: String = target_scene_path
	set_process(false)
	push_error(
		"SceneTransitionManager: gagal membuka scene "
		+ failed_path
		+ ". Error code: "
		+ str(error_code)
	)
	if is_instance_valid(loading_screen):
		loading_screen.queue_free()
	get_tree().paused = previous_tree_paused
	_reset_state()
	transition_failed.emit(failed_path, int(error_code))

func _reset_state() -> void:
	is_transitioning = false
	target_scene_path = ""
	minimum_display_time = 0.45
	transition_started_at = 0
	loading_screen = null
	completing_transition = false
	previous_tree_paused = false
