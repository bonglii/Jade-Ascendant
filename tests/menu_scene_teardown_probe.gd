extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
 for i: int in range(n):await process_frame
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_paid_v2_qa"):quit(2);return
 await frames(15)
 for i: int in range(8):
  change_scene_to_file("res://scenes/ui/equipment_screen.tscn" if i%2==0 else "res://scenes/ui/main_menu.tscn")
  await frames(20)
 paused=false;await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 if current_scene!=null:current_scene.queue_free();current_scene=null
 await create_timer(.8).timeout;await frames(12);print("LEAK_PROBE_DONE");quit()
