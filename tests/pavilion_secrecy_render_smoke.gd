extends SceneTree
## Real-renderer regression: outcome identity cannot affect any pre-reveal pixel.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().contains("jade_gacha_qa"):
		push_error("Use a real renderer and an isolated jade_gacha_qa directory");quit(2);return
	await create_timer(0.5).timeout
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
	root.get_node("SettingsManager").reduced_effects=false
	var conf:=ConfigFile.new();conf.set_value("tutorials","pavilion",true);conf.save("user://jade_onboarding.cfg")
	change_scene_to_file("res://scenes/ui/pavilion_screen.tscn")
	await create_timer(0.7).timeout
	var screen: Control=current_scene
	if not screen.has_method("_start_summon_reveal"):push_error("Pavilion script not loaded");quit(1);return
	if screen.has_node("JadeOnboardingOverlay"):screen.get_node("JadeOnboardingOverlay").visible=false
	var passed: bool=await pixel_proof(screen)
	screen.queue_free();screen=null
	for _frame in range(4):await process_frame
	await create_timer(0.75).timeout
	quit(0 if passed else 1)
func stage_pixels(screen: Control) -> PackedByteArray:
	for _frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var area: Rect2=screen._reveal_stage.get_global_rect()
	return root.get_texture().get_image().get_region(Rect2i(area)).get_data()
func pixel_proof(screen: Control) -> bool:
	root.size=Vector2i(648,1152)
	await create_timer(0.3).timeout
	var signatures: Dictionary={}
	var equipment: Node=root.get_node("EquipmentManager")
	for rarity: String in ["common","rare","epic","legendary"]:
		var ids: Array[String]=[]
		for id: String in equipment.get_item_ids():
			if str(equipment.get_item_data(id).get("rarity",""))==rarity:ids.append(id)
		var hidden: Array[PackedByteArray]=[]
		var revealed: Array[PackedByteArray]=[]
		for id: String in ids.slice(0,2):
			screen._start_summon_reveal({"results":[{"item_id":id,"rarity":rarity}]})
			screen._reveal_stage.set_process(false)
			screen._reveal_stage.clock=0.0
			screen._reveal_stage.elapsed=screen._reveal_stage.duration*0.99
			screen._reveal_stage._process(0)
			hidden.append(await stage_pixels(screen))
			screen._skip_ritual()
			screen._reveal_stage.clock=1.0
			screen._reveal_stage.queue_redraw()
			revealed.append(await stage_pixels(screen))
			screen._finish_summon_reveal()
			screen._reveal_stage.set_process(true)
		if hidden[0]!=hidden[1]:push_error("IDENTITY PIXEL LEAK "+rarity);return false
		if revealed[0]==revealed[1]:push_error("REVEAL IDENTITIES NOT DISTINCT "+rarity);return false
		signatures[rarity]=hidden[0]
		print("PIXEL_PROOF ",rarity," before=same after=different PASS")
	if signatures.rare==signatures.epic:push_error("RARE AND EPIC MUST LOOK DIFFERENT");return false
	print("RARITY_PIXEL_PROOF blue_Rare_vs_purple_Epic=different PASS")
	return true
