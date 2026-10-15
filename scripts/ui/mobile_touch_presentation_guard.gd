extends Node
## Visual hover suppression and scrollbar policy; never consumes scrolling input.
var touch_mode: bool=false
var _applying: bool=false
var _tracked: Dictionary={}
var _pending: Dictionary={}
var _scrollers: Dictionary={}
var _pressed: WeakRef
var _distance: float=0.0
var _tick: float=0.0
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 touch_mode=OS.has_feature("android") or DisplayServer.is_touchscreen_available()
 get_tree().node_added.connect(_on_node_added)
 _scan(get_tree().root)
func _scan(node: Node) -> void:
 if node is Button:_track(node)
 if node is ScrollContainer:_track_scroll(node)
 for child: Node in node.get_children():_scan(child)
func _on_node_added(node: Node) -> void:
 if node is Button:_track.call_deferred(node)
 if node is ScrollContainer:_track_scroll.call_deferred(node)
func _track_scroll(scroll: ScrollContainer) -> void:
 if not is_instance_valid(scroll) or not scroll.is_inside_tree():return
 var id: int=scroll.get_instance_id()
 if not _scrollers.has(id):
  _scrollers[id]=weakref(scroll)
  scroll.tree_exiting.connect(func():_scrollers.erase(id),CONNECT_ONE_SHOT)
 _hide_scrollbars(scroll)
func _hide_scrollbars(scroll: ScrollContainer) -> void:
 # SHOW_NEVER keeps the enabled axis scrollable; DISABLED must stay disabled.
 if scroll.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED:scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
 if scroll.vertical_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED:scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
func _process(delta: float) -> void:
 _tick+=delta
 if _tick<.25:return
 _tick=0
 for ref: WeakRef in _scrollers.values():
  var scroll: ScrollContainer=ref.get_ref()
  if is_instance_valid(scroll):_hide_scrollbars(scroll)
func _track(button: Button) -> void:
 if not is_instance_valid(button) or not button.is_inside_tree():return
 var id: int=button.get_instance_id()
 if not _tracked.has(id):
  _tracked[id]=weakref(button)
  button.theme_changed.connect(_queue_apply.bind(button))
  button.button_down.connect(_capture.bind(button))
  button.tree_exiting.connect(func():_tracked.erase(id),CONNECT_ONE_SHOT)
  if button is OptionButton:
   button.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
   button.pressed.connect(func():
    if bool(button.get_meta("jade_scroll_cancelled",false)):button.get_popup().hide.call_deferred())
 _apply(button)
func _capture(button: Button) -> void:
 _pressed=weakref(button);_distance=0
 button.set_meta("jade_scroll_cancelled",false)
func _queue_apply(button: Button) -> void:
 if _applying or not is_instance_valid(button):return
 var id: int=button.get_instance_id()
 if _pending.has(id):return
 _pending[id]=true;_apply_queued.call_deferred(button,id)
func _apply_queued(button: Button,id: int) -> void:
 _pending.erase(id);_apply(button)
func _apply(button: Button) -> void:
 if _applying or not touch_mode or not is_instance_valid(button) or not button.is_inside_tree():return
 _applying=true
 var normal: StyleBox=button.get_theme_stylebox("normal")
 for key: String in ["hover","hover_pressed"]:
  if button.get_theme_stylebox(key)!=normal:button.add_theme_stylebox_override(key,normal)
 var ink: Color=button.get_theme_color("font_color")
 for key: String in ["font_hover_color","font_hover_pressed_color"]:
  if button.get_theme_color(key)!=ink:button.add_theme_color_override(key,ink)
 _applying=false
func _input(event: InputEvent) -> void:
 if event is InputEventScreenTouch or event is InputEventScreenDrag:
  if not touch_mode:
   touch_mode=true
   for ref: WeakRef in _tracked.values():
    var button: Button=ref.get_ref()
    if is_instance_valid(button):_apply(button)
 var movement: float=0
 if event is InputEventScreenDrag:movement=event.relative.length()
 elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:movement=event.relative.length()
 if movement>0 and _pressed!=null:
  var button: Button=_pressed.get_ref()
  if is_instance_valid(button):
   _distance+=movement
   if _distance>=10:button.set_meta("jade_scroll_cancelled",true)
 if event is InputEventScreenDrag or (event is InputEventScreenTouch and not event.pressed):_release_touch_focus.call_deferred()
func _release_touch_focus() -> void:
 var focused: Control=get_viewport().gui_get_focus_owner()
 if focused is BaseButton:focused.release_focus()
