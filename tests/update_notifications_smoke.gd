extends SceneTree
const Manager=preload("res://scripts/managers/update_notifications.gd")
const SettingsCard=preload("res://scripts/ui/update_notification_settings.gd")
class FakeNative:
 extends RefCounted
 var calls: Array[bool]=[]
 var deferred: int=0
 var system_opened: int=0
 var data: Dictionary={"supported":true,"opt_in":false,"permission":false,"education_shown":false,"stage":"off","subscribed":false}
 func getUpdateNotificationStatus() -> String: return JSON.stringify(data)
 func setUpdateNotificationsEnabled(value: bool) -> bool: calls.append(value); data.opt_in=value; return true
 func deferUpdateNotifications() -> void: deferred+=1; data.education_shown=true
 func openUpdateNotificationSettings() -> void: system_opened+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
 create_timer(8).timeout.connect(func() -> void: quit(1))
 # Regression: JNI reflection may return false for callable annotated methods.
 var manager_source: String=FileAccess.get_file_as_string("res://scripts/managers/update_notifications.gd")
 assert(not manager_source.contains("native.has_method("), "Do not use Object.has_method to gate Android JNI calls")
 var viewport:=SubViewport.new(); viewport.size=Vector2i(648,1152); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
 var native:=FakeNative.new(); var manager: CanvasLayer=Manager.new(); viewport.add_child(manager); manager.native=native
 assert(not manager._safe_home()); assert(native.calls.is_empty())
 assert(manager.status().get("supported",false)); assert(not manager.status().get("permission",true))
 manager._show_prompt(); await process_frame; await process_frame
 assert(native.calls.is_empty()); assert(native.deferred==1)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png("/tmp/jade-update-notification-preview.png")
 var buttons: Array[Node]=manager._shade.find_children("*","Button",true,false)
 assert(buttons.size()==2)
 buttons[1].pressed.emit(); await process_frame; assert(native.calls.is_empty()); assert(manager._shade==null)
 manager._show_prompt(); await process_frame; buttons=manager._shade.find_children("*","Button",true,false); buttons[0].pressed.emit(); await process_frame
 assert(native.calls==[true]); assert(manager._shade==null)
 var card: VBoxContainer=SettingsCard.new(); card.updates=manager; card.size=Vector2(480,300); viewport.add_child(card); await process_frame
 assert(not card.toggle.disabled); assert(card.toggle.text=="DISABLE ALERTS"); card.toggle.pressed.emit(); assert(native.calls==[true,false]); assert(card.toggle.text=="ENABLE UPDATE ALERTS")
 native.data.stage="system_blocked"; native.data.opt_in=true; card._refresh(); assert(card.status_text.text.contains("Android")); card.system.pressed.emit(); assert(native.system_opened==1)
 native.data.supported=false; card._refresh(); assert(card.toggle.disabled and not card.system.visible)
 print("UPDATE_NOTIFICATIONS_UI=PASS; EDUCATION_DOES_NOT_REQUEST_PERMISSION; NOT_NOW_RESPECTED; EXPLICIT_ENABLE; SETTINGS_DISABLE; SYSTEM_BLOCKED; UNSUPPORTED")
 viewport.queue_free(); await process_frame; quit()
