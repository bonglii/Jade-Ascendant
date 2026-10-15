extends SceneTree
var checks:int=0
var failures:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func run()->void:
 if not OS.get_user_data_dir().contains("jade_motion_render_qa"):quit(2);return
 await create_timer(.3).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(720,1600)
 root.get_node("SettingsManager").reduced_effects=false
 var prewarm:Node=root.get_node_or_null("MenuResourcePrewarm")
 if prewarm!=null:prewarm.queue_free()
 var guide:Node=root.get_node("RefineOnboarding");guide.completed=true;guide.set_process(false)
 var cfg:=ConfigFile.new();cfg.set_value("meta","version",2)
 for key:String in ["home","equipment","pavilion"]:cfg.set_value("tutorials",key,true)
 cfg.save("user://jade_onboarding.cfg")
 change_scene_to_file("res://scenes/ui/main_menu.tscn")
 await create_timer(.5).timeout
 var host:Node=current_scene.get_node("KeyArt")
 for i:int in range(100):
  if host._first_frame and host._fade>=.35:break
  await create_timer(.1).timeout
 check(host._first_frame and host._fade>=.35,"real decoder reaches first frame and full fade")
 if is_instance_valid(host._player):
  check(host._player.loop and host._player.volume_db<=-80,"silent looping video")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/tmp/jade-107/home-motion-preview.png")
  var before:float=host._player.stream_position;await create_timer(.5).timeout
  check(host._player.stream_position!=before,"actual playback advances")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/tmp/jade-107/home-motion-preview-next.png")
  var overlay:=ColorRect.new();overlay.set_meta("liveops_popup",true);current_scene.add_child(overlay)
  host._sync_playback();check(host._player.paused,"overlay pauses decoder")
  overlay.queue_free();await process_frame;host._sync_playback();check(not host._player.paused,"closing overlay resumes decoder")
 var weak:WeakRef=weakref(host)
 current_scene.queue_free();current_scene=null;await process_frame
 check(weak.get_ref()==null,"leaving releases actual stream")
 print("HOME_MOTION_RENDER checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
