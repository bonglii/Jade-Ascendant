extends Control

## One startup presentation; GoogleAccountManager retains ownership of auth.
## No network wait or currency/save mutation. Resources load while the seal animates.
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const ACCOUNT_ENTRY_SCENE: String = "res://scenes/ui/google_account_entry.tscn"
const MINIMUM_BRAND_SECONDS: float = 0.65
var _started_ms: int = 0
var _routing: bool = false
var _next_scene: String = ""

func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	$Presentation/Retry.pressed.connect(_retry)
	_route_first_entry.call_deferred()

func _route_first_entry() -> void:
	if _routing:
		return
	_routing = true
	GoogleAccountManager.refresh_provider()
	var account: Dictionary = GoogleAccountManager.get_account_snapshot()
	_next_scene = MAIN_MENU_SCENE if bool(account.get("signed_in", false)) else ACCOUNT_ENTRY_SCENE
	if not ResourceLoader.exists(_next_scene, "PackedScene"):
		_next_scene = MAIN_MENU_SCENE
	var request_error: Error = ResourceLoader.load_threaded_request(_next_scene, "PackedScene", false, ResourceLoader.CACHE_MODE_REUSE)
	if request_error != OK:
		_show_failure()
		return
	var packed: PackedScene = null
	while is_inside_tree():
		var status: int = ResourceLoader.load_threaded_get_status(_next_scene)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# Always consume a successful request, including error/retry routes.
			packed = ResourceLoader.load_threaded_get(_next_scene) as PackedScene
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_show_failure()
			return
		await get_tree().process_frame
	if packed == null:
		_show_failure()
		return
	var minimum: float = 0.15 if SettingsManager.reduced_effects else MINIMUM_BRAND_SECONDS
	var remaining: float = minimum - float(Time.get_ticks_msec() - _started_ms) / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout
	if not is_inside_tree():
		return
	# The branded Boot already covers loading. Do not stack a second Gate intro.
	# Scene changes detach Boot before the next scene is ready. Keep its artwork
	# on the existing persistent transition layer through the first new draw.
	var cover := TextureRect.new()
	cover.name = "BootHandoffCover"
	cover.texture = $Background.texture
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneTransitionManager.add_child(cover)
	SceneTransitionManager.release_boot_cover(cover)
	var change_error: Error = get_tree().change_scene_to_packed(packed)
	if change_error != OK:
		cover.queue_free()
		_show_failure()

func _show_failure() -> void:
	_routing = false
	$Presentation.show_failure()
	push_warning("Boot: local scene unavailable; retry is available without signing out.")

func _retry() -> void:
	if _routing:
		return
	$Presentation.clear_failure()
	_route_first_entry()
