extends SceneTree
const Manager=preload("res://scripts/managers/update_notifications.gd")
const SettingsCard=preload("res://scripts/ui/update_notification_settings.gd")
var checks: int=0
var failures: int=0
class FakeNative:
 extends RefCounted
 var calls: Array[bool]=[]
 var system_opened: int=0
 var data: Dictionary={"supported":true,"opt_in":false,"permission":false,"education_shown":false,"busy":false,"stage":"off","subscribed":false}
 func getUpdateNotificationStatus() -> String: return JSON.stringify(data)
 func setUpdateNotificationsEnabled(value: bool) -> bool:
  calls.append(value);data.opt_in=value;data.education_shown=true;return true
 func openUpdateNotificationSettings() -> void: system_opened+=1
func check(value: bool, caption: String) -> void:
 checks+=1
 if not value: failures+=1;push_error("NOTIFICATION_DIRECT "+caption)
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_celestial_board_qa"): quit(2);return
 var viewport:=SubViewport.new();viewport.size=Vector2i(648,1152);root.add_child(viewport)
 var native:=FakeNative.new();var manager: CanvasLayer=Manager.new();viewport.add_child(manager);manager.native=native
 check(not manager._safe_home(),"no automatic prompt outside safe Home")
 check(native.calls.is_empty(),"reading status does not request permission")
 manager._request_native_once({"supported":false,"education_shown":false});check(native.calls.is_empty(),"unsupported platform has no prompt")
 manager._request_native_once({"supported":true,"education_shown":true});check(native.calls.is_empty(),"previous denial or opt-out stays respected")
 manager._request_native_once({"supported":true,"education_shown":false,"busy":true});check(native.calls.is_empty(),"wait for an existing native operation")
 manager._request_native_once(native.data);check(native.calls==[true],"first request directly calls Android permission bridge")
 check(manager.get_child_count()==0,"no custom in-game education/modal tree exists")
 manager._request_native_once(native.data);manager._request_native_once({"supported":true,"education_shown":false})
 check(native.calls==[true],"one request maximum per session even before callback")
 var source: String=FileAccess.get_file_as_string("res://scripts/managers/update_notifications.gd")
 check(not source.contains("_show_prompt") and not source.contains("native.has_method("),"removed education popup and JNI reflection trap")
 var card: VBoxContainer=SettingsCard.new();card.updates=manager;card.size=Vector2(480,300);viewport.add_child(card);await process_frame
 check(not card.toggle.disabled and card.toggle.text=="DISABLE ALERTS","settings still offers explicit opt out")
 card.toggle.pressed.emit();check(native.calls==[true,false],"explicit disable is retained")
 native.data.opt_in=true;native.data.stage="system_blocked";card._refresh();card.system.pressed.emit()
 check(native.system_opened==1,"denied permissions have an explicit Android settings route")
 native.data.supported=false;card._refresh();check(card.toggle.disabled and not card.system.visible,"unsupported settings state is honest")
 viewport.free();await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("NOTIFICATION_DIRECT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
