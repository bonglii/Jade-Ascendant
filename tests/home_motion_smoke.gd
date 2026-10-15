extends SceneTree
var checks:int=0
var failures:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func run()->void:
 if not OS.get_user_data_dir().contains("jade_motion_qa"):quit(2);return
 await process_frame
 var settings:Node=root.get_node("SettingsManager");settings.reduced_effects=true
 var host:TextureRect=load("res://scripts/ui/home_motion_backdrop.gd").new()
 host.size=Vector2(720,1600);host.texture=load("res://assets/ui/home/sanctuary/motion/lin_yue_poster.webp");root.add_child(host)
 await process_frame
 check(host.texture!=null,"poster loaded")
 check(host._player==null and not host._loading,"reduced effects avoids decoder")
 check(host.clip_contents and host.mouse_filter==Control.MOUSE_FILTER_IGNORE,"clip and click through")
 host._player=VideoStreamPlayer.new();host._player.expand=true;host.add_child(host._player)
 for viewport:Vector2 in [Vector2(320,568),Vector2(390,844),Vector2(720,1600),Vector2(896,504)]:
  host.size=viewport;host._fit_video()
  check(host._player.size.x>=viewport.x and host._player.size.y>=viewport.y,"cover without gaps")
  check((host._player.position*2+host._player.size-viewport).abs().x<=1 and (host._player.position*2+host._player.size-viewport).abs().y<=1,"center within pixel")
 settings.reduced_effects=false;host._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 check(not host._motion_allowed(),"background pauses")
 host._notification(Node.NOTIFICATION_APPLICATION_RESUMED);check(host._motion_allowed(),"foreground resumes")
 host.hide();check(not host._motion_allowed(),"hidden stops playback")
 var weak:WeakRef=weakref(host._player);host.queue_free();await process_frame
 check(weak.get_ref()==null,"leaving frees player")
 print("HOME_MOTION checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
