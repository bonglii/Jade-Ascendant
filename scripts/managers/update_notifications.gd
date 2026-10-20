extends CanvasLayer
## Device preference only; never attached to a Google account or cloud save.
var native: Object
var _tick: float=0.0
var _home_since: int=0
var _requested_this_session: bool=false
func _ready() -> void:
 if OS.get_name()!="Android" or not Engine.has_singleton("JadeMonetizationNativeBridge"): set_process(false); return
 native=Engine.get_singleton("JadeMonetizationNativeBridge")
 # Android JNI methods are callable but Object.has_method() is not a capability probe.
 # The release exporter verifies the notification-enabled native candidate.
func status() -> Dictionary:
 if native==null: return {"supported":false,"stage":"unavailable"}
 var result: Variant=JSON.parse_string(str(native.call("getUpdateNotificationStatus")))
 return result if result is Dictionary else {"supported":false,"stage":"unavailable"}
func enable(value: bool) -> void:
 if native!=null: native.call("setUpdateNotificationsEnabled",value)
func open_system_settings() -> void:
 if native!=null: native.call("openUpdateNotificationSettings")
func _safe_home() -> bool:
 var scene: Node=get_tree().current_scene
 if scene==null or scene.scene_file_path!="res://scenes/ui/main_menu.tscn" or get_tree().paused: return false
 var account: Node=get_node_or_null("/root/GoogleAccountManager")
 if account!=null and account.has_method("get_account_snapshot") and bool(account.call("get_account_snapshot").get("busy",false)): return false
 var transitions: Node=get_node_or_null("/root/SceneTransitionManager")
 if transitions!=null and bool(transitions.get("is_transitioning")): return false
 for canvas: Node in get_tree().root.find_children("*","CanvasLayer",true,false):
  if canvas==self or not (canvas as CanvasLayer).visible: continue
  var caption: String=str(canvas.name).to_lower()
  if "tutorial" in caption or "announcement" in caption or "onboarding" in caption: return false
 for control: Node in get_tree().root.find_children("*","Control",true,false):
  var caption: String=str(control.name).to_lower()
  if "popup" not in caption and "modal" not in caption and "overlay" not in caption and "dialog" not in caption and "tutorial" not in caption: continue
  var view: Control=control as Control
  if view is ColorRect and (view as ColorRect).color.a<=0.01: continue
  if view.modulate.a<=0.01: continue
  if view.is_visible_in_tree() and view.mouse_filter!=Control.MOUSE_FILTER_IGNORE and view.size.length()>20: return false
 return true
func _process(delta: float) -> void:
 _tick-=delta
 if _tick>0: return
 _tick=0.5
 if not _safe_home(): _home_since=0; return
 if _home_since==0: _home_since=Time.get_ticks_msec(); return
 if Time.get_ticks_msec()-_home_since<3000: return
 var data: Dictionary=status()
 if not data.get("supported",false) or data.get("education_shown",true): set_process(false); return
 _request_native_once(data)
func _request_native_once(data: Dictionary) -> void:
 # Native choose() records the preference before opening Android's activity.
 # An earlier denial/opt-out is respected; Settings remains the explicit retry.
 if _requested_this_session or not bool(data.get("supported",false)) or bool(data.get("education_shown",true)) or bool(data.get("busy",false)): return
 _requested_this_session=true
 enable(true)
 set_process(false)
