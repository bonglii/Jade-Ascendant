extends SceneTree
const LayoutContract = preload("res://tests/pavilion_layout_contract.gd")
## Actual Pavilion, managers and shader. No purchase, claim or equip action.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func frames(count: int = 8) -> void:
	for index: int in count: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("AURA_PAVILION " + label)
func snapshot() -> Dictionary:
	return {"pavilion":root.get_node("PavilionManager").state.duplicate(true),"inventory":root.get_node("InventoryManager").item_counts.duplicate(true),"stones":root.get_node("ProgressionManager").spirit_stone}
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.local/aura_native_images")
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(), "GPU capture has pixels: " + label)
	if image != null and not image.is_empty():
		check(image.save_png("res://.local/aura_native_images/" + label + ".png") == OK,"native capture saved: " + label)
func swipe(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.button_mask = MOUSE_BUTTON_MASK_LEFT; down.position = at
	root.push_input(down, true); await frames(1)
	for index: int in range(1,9):
		var drag := InputEventMouseMotion.new()
		drag.position = at + Vector2(0,-15 * index); drag.relative = Vector2(0,-15); drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(drag,true); await frames(1)
	down.position = at + Vector2(0,-120); down.pressed = false; down.button_mask = 0
	root.push_input(down,true); await frames()
func run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_user_data_dir().contains("jade_aura_live_qa"): quit(2); return
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size = Vector2i.ZERO
	var guide: Node = root.get_node_or_null("RefineOnboarding")
	if guide != null: guide.completed = true; guide.set_process(false)
	var conf := ConfigFile.new(); conf.set_value("meta","version",2); conf.set_value("tutorials","pavilion",true); conf.save("user://jade_onboarding.cfg")
	var journey: Node = root.get_node("JourneyManager")
	for chapter: int in journey.get_chapter_ids():
		for stage: int in journey.get_stage_ids(chapter): journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
	var before: Dictionary = snapshot()
	for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
		root.size = dims
		change_scene_to_file("res://scenes/ui/pavilion_screen.tscn"); await frames(15)
		var screen: Control = current_scene
		if screen.has_node("JadeOnboardingOverlay"): screen.get_node("JadeOnboardingOverlay").hide()
		# Review the actual whole production menu before the isolated effect views.
		for tab: String in ["summon"]:
			screen._select_focus_tab(tab); await frames(16)
			check(LayoutContract.inspect(screen).is_empty(),"native whole-page layout: " + tab + " " + str(dims))
			await capture(tab + "-" + str(dims.x))
			if tab == "summon":
				screen._select_summon_mode(true); await frames(16)
				check(LayoutContract.inspect(screen).is_empty(),"native paid-mode layout " + str(dims))
				await capture("paid-" + str(dims.x))
				screen._select_summon_mode(false); await frames()

		check(snapshot() == before,"browsing all native production pages is read-only")
		if not root.get_node("PavilionManager").is_aura_feature_enabled():
			check(not screen.focus_pages.has("aura") and not is_instance_valid(screen._focus_aura_preview), "held aura is absent from the actual native UI")
			check(snapshot() == before, "holding aura retains the saved state")
			current_scene.queue_free(); current_scene = null; await frames()
			continue
		screen._select_focus_tab("aura"); await frames()
		var layout_errors: Array[String] = LayoutContract.inspect(screen)
		check(layout_errors.is_empty(), "actual Pavilion layout: " + str(layout_errors))
		check(screen.content.get_global_rect().end.x <= dims.x + 1, "Pavilion width fits " + str(dims))
		for id: String in ["jade_aura","golden_aura","astral_aura","ascendant_aura"]:
			screen._preview_focus_aura(id); await create_timer(0.35).timeout
			check(screen._focus_aura_preview.aura_id == id, "production preview selects " + id)
			check(screen._focus_aura_preview._actor.material != null, "actual production body material present")
			await capture(id + "-" + str(dims.x))
		check(snapshot() == before, "browsing native previews never changes actual manager state")
		if dims.x == 390:
			var scroll: ScrollContainer = screen.scroll_container
			var button: Button = screen._focus_aura_buttons.plain
			var initial: int = scroll.scroll_vertical
			var selection: String = screen._focus_aura_id
			# Use a visible part of the genuine button; viewport size alone is not proof.
			var visible_button: Rect2 = button.get_global_rect().intersection(scroll.get_global_rect())
			check(visible_button.size.x > 20 and visible_button.size.y > 20, "swipe source is inside the visible scroll viewport")
			if visible_button.size.x > 20 and visible_button.size.y > 20: await swipe(visible_button.get_center())
			check(scroll.scroll_vertical > initial + 20, "first native swipe starts on an aura button")
			check(snapshot() == before and not is_instance_valid(screen._focus_sheet), "swipe cannot equip, spend or open a sheet")
			check(screen._focus_aura_id == selection, "native swipe cannot accidentally select a different aura")
		root.get_node("SettingsManager").reduced_effects = true
		screen._preview_focus_aura("ascendant_aura"); root.get_node("SettingsManager").settings_changed.emit(); await frames()
		check(not screen._focus_aura_preview.is_processing(), "native reduced preview has no aura update loop")
		await capture("reduced-" + str(dims.x))
		root.get_node("SettingsManager").reduced_effects = false
		current_scene.queue_free(); current_scene = null; await frames()
	print("AURA_PAVILION checks=%d failures=%d; NATIVE_GUI=%s; PHONE=NOT_TESTED" % [checks,failures,str(DisplayServer.get_name() != "headless")])
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit(1 if failures else 0)
