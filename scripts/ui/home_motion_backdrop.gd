extends TextureRect
## Silent local Theora loop; poster is visible until a decoded frame is ready.
const VIDEO: String="res://assets/ui/home/sanctuary/motion/lin_yue_sanctuary.ogv"
const SOURCE_SIZE: Vector2=Vector2(540,960)
var _player: VideoStreamPlayer
var _loading: bool=false
var _failed: bool=false
var _suspended: bool=false
var _first_frame: bool=false
var _fade: float=0.0
var _poll: float=0.0
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 mouse_filter=Control.MOUSE_FILTER_IGNORE;material=null;clip_contents=true
 resized.connect(_fit_video);visibility_changed.connect(_sync_playback)
 SettingsManager.settings_changed.connect(_sync_playback)
 call_deferred("_sync_playback")
func _motion_allowed() -> bool:
 return not SettingsManager.reduced_effects and not _suspended and is_visible_in_tree()
func _sync_playback() -> void:
 if not is_inside_tree():return
 if is_instance_valid(_player):
  _player.paused=not _motion_allowed() or _popup_visible()
  return
 if not _motion_allowed() or _loading or _failed:return
 var error: Error=ResourceLoader.load_threaded_request(VIDEO,"VideoStream",false,ResourceLoader.CACHE_MODE_IGNORE)
 _loading=error==OK;_failed=error!=OK
func _popup_visible() -> bool:
 var scene: Node=get_tree().current_scene
 if scene==null:return true
 for child: Node in scene.get_children():
  if child is Control and child.visible and bool(child.get_meta("liveops_popup",false)):return true
 if scene.has_method("_close_profile_sheet"):
  var profile: Variant=scene.get("profile_overlay")
  if is_instance_valid(profile) and profile is CanvasItem and profile.is_visible_in_tree():return true
 var idle: Node=get_node_or_null("/root/IdleCultivationManager/IdleCultivationPresenter")
 if idle!=null:
  var popup: Variant=idle.get("_popup")
  if is_instance_valid(popup) and popup is CanvasItem and popup.is_visible_in_tree():return true
 return false
func _process(delta: float) -> void:
 if _loading:
  var status: int=ResourceLoader.load_threaded_get_status(VIDEO)
  if status==ResourceLoader.THREAD_LOAD_LOADED:
   _loading=false
   var stream: VideoStream=ResourceLoader.load_threaded_get(VIDEO) as VideoStream
   if stream==null:_failed=true;return
   if not _motion_allowed():return
   _player=VideoStreamPlayer.new();_player.name="LinYueMotion"
   _player.mouse_filter=Control.MOUSE_FILTER_IGNORE;_player.expand=true
   _player.loop=true;_player.volume_db=-80;_player.modulate.a=0
   _player.stream=stream;add_child(_player);_fit_video();_player.play();_sync_playback()
  elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
   _loading=false;_failed=true
 if not is_instance_valid(_player):return
 _poll+=delta
 if _poll>=.2:_poll=0;_sync_playback()
 if not _first_frame and _player.stream_position>.05:_first_frame=true
 if _first_frame and not _player.paused:
  _fade=minf(.35,_fade+delta);_player.modulate.a=_fade/.35
func _fit_video() -> void:
 if not is_instance_valid(_player):return
 var factor: float=maxf(size.x/SOURCE_SIZE.x,size.y/SOURCE_SIZE.y)
 var fitted: Vector2=(SOURCE_SIZE*factor).ceil()
 _player.size=fitted;_player.position=((size-fitted)*.5).floor()
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_PAUSED:_suspended=true;_sync_playback()
 elif what==NOTIFICATION_APPLICATION_RESUMED:_suspended=false;_sync_playback()
func _exit_tree() -> void:
 if is_instance_valid(_player):_player.stop();_player.stream=null
