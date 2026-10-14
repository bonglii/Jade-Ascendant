extends SceneTree
func _initialize() -> void:run.call_deferred()
func frames(count: int=8) -> void:
 for i: int in range(count):await process_frame
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_home_sanctuary_render_qa"):quit(2);return
 await create_timer(.5).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var config:=ConfigFile.new();config.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]:config.set_value("tutorials",key,true)
 config.save("user://jade_onboarding.cfg")
 var guide: Node=root.get_node("RefineOnboarding");guide.completed=true;guide.set_process(false)
 var prewarm: Node=root.get_node_or_null("MenuResourcePrewarm")
 if prewarm!=null:prewarm.queue_free()
 await frames(2)
 var dir: String=OS.get_environment("JADE_HOME_RENDER_DIR")
 if dir.is_empty():dir="/tmp/jade-qa/home-sanctuary-render"
 DirAccess.make_dir_recursive_absolute(dir)
 change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(14)
 for viewport: Vector2i in [Vector2i(648,1152),Vector2i(390,844),Vector2i(320,568),Vector2i(896,504)]:
  root.size=viewport;await frames(10)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(dir+"/home-%dx%d.png"%[viewport.x,viewport.y])
 root.get_node("AudioManager").release_runtime_audio();current_scene.queue_free();await frames(8)
 print("HOME_SANCTUARY_NATIVE_RENDER=PASS; 4 viewport captures");quit(0)
