extends "res://tests/player_six_fixes_combat.gd"
func _initialize() -> void:
 if DisplayServer.get_name()=="headless":push_error("Native GUI is required");quit(2);return
 run.call_deferred()
func review_attack(_boss: Node2D, _attack: Node, id: String) -> void:
 root.size=Vector2i(648,1152)
 await create_timer(.28).timeout
 await RenderingServer.frame_post_draw
 var pixels: Image=root.get_texture().get_image()
 check(pixels!=null and not pixels.is_empty(),"native combat image "+id)
 if pixels!=null and not pixels.is_empty():
  DirAccess.make_dir_recursive_absolute("res://.local/six_native_combat")
  check(pixels.save_png("res://.local/six_native_combat/"+id+".png")==OK,"native combat capture "+id)
