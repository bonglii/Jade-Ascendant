extends Node
## Suppress synthetic desktop hover on touch screens without disabling actions.
var touch_mode: bool = false
var _applying: bool = false
var _tracked: Dictionary = {}
var _pending: Dictionary = {}
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 touch_mode=OS.has_feature("android") or DisplayServer.is_touchscreen_available()
 get_tree().node_added.connect(_on_node_added)
 if touch_mode:_scan(get_tree().root)
func _scan(node: Node) -> void:
 if node is Button:_track(node)
 for child: Node in node.get_children():_scan(child)
func _on_node_added(node: Node) -> void:
 if touch_mode and node is Button:_track.call_deferred(node)
func _track(button: Button) -> void:
 if not is_instance_valid(button) or not button.is_inside_tree():return
 var id: int=button.get_instance_id()
 if not _tracked.has(id):
  _tracked[id]=true
  button.theme_changed.connect(_queue_apply.bind(button))
  button.tree_exiting.connect(func():_tracked.erase(id),CONNECT_ONE_SHOT)
 _apply(button)
func _queue_apply(button: Button) -> void:
 if not is_instance_valid(button):return
 var id: int=button.get_instance_id()
 if _pending.has(id):return
 _pending[id]=true;_apply_queued.call_deferred(button,id)
func _apply_queued(button: Button,id: int) -> void:
 _pending.erase(id);_apply(button)
func _apply(button: Button) -> void:
 if _applying or not touch_mode or not is_instance_valid(button) or not button.is_inside_tree():return
 _applying=true
 var normal: StyleBox=button.get_theme_stylebox("normal")
 if button.get_theme_stylebox("hover")!=normal:button.add_theme_stylebox_override("hover",normal)
 var pressed: StyleBox=button.get_theme_stylebox("pressed")
 if button.get_theme_stylebox("hover_pressed")!=pressed:button.add_theme_stylebox_override("hover_pressed",pressed)
 var ink: Color=button.get_theme_color("font_color")
 if button.get_theme_color("font_hover_color")!=ink:button.add_theme_color_override("font_hover_color",ink)
 _applying=false
func _input(event: InputEvent) -> void:
 if event is InputEventScreenTouch or event is InputEventScreenDrag:
  if not touch_mode:
   touch_mode=true;_scan(get_tree().root)
  if event is InputEventScreenDrag or (event is InputEventScreenTouch and not event.pressed):_release_touch_focus.call_deferred()
func _release_touch_focus() -> void:
 var focused: Control=get_viewport().gui_get_focus_owner()
 if focused is BaseButton:focused.release_focus()
