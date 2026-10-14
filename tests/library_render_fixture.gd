extends SceneTree
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for i: int in range(3):await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/jade-qa/"+name+".png")
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_library_render_qa"):quit(2);return
	print("RENDER_TRACE start")
	await process_frame;paused=false
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
	print("RENDER_TRACE load library")
	change_scene_to_file("res://scenes/ui/skill_book_screen.tscn")
	await settle();print("RENDER_TRACE library ready")
	await shot("library-equipment-final")
	current_scene._set_mode("SKILLS");await settle();await shot("library-skills-final")
	current_scene._set_mode("EQUIPMENT");current_scene._set_filter("SETS");await settle();await shot("library-sets-final")
	print("LIBRARY_RENDER_PASS")
	current_scene.queue_free();current_scene=null;await settle();quit(0)
