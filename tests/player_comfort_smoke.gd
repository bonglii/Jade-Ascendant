extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("PLAYER_COMFORT " + why)
func frames(n: int = 8) -> void:
	for i: int in n: await process_frame
func capture(name_value: String) -> void:
	var directory: String = OS.get_environment("JADE_COMFORT_CAPTURE")
	if DisplayServer.get_name() == "headless" or directory.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory + "/" + name_value + ".png")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"): quit(2); return
	create_timer(70).timeout.connect(func(): push_error("PLAYER_COMFORT_TIMEOUT"); quit(1))
	await frames(12)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	check(clear.g > clear.r * 2 and clear.r < .04, "engine handoff has branded clear color, not default gray")
	root.size = Vector2i(390,844)
	change_scene_to_file("res://scenes/system/boot.tscn"); await frames(2)
	var cover_observed: Array[bool] = [false]
	var changed: Callable = func():
		if current_scene != null and current_scene.scene_file_path != "res://scenes/system/boot.tscn": cover_observed[0] = root.get_node("SceneTransitionManager").has_node("BootHandoffCover")
	scene_changed.connect(changed)
	await create_timer(1.3).timeout; await frames(8)
	scene_changed.disconnect(changed)
	check(cover_observed[0], "boot art remains present at scene change")
	check(not root.get_node("SceneTransitionManager").has_node("BootHandoffCover"), "handoff cover is removed after new frame")
	var settings: Node = root.get_node("SettingsManager")
	var config := ConfigFile.new(); config.set_value("meta", "version", 2)
	for key: String in ["home","equipment","pavilion"]: config.set_value("tutorials",key,true)
	config.save("user://jade_onboarding.cfg"); root.get_node("RefineOnboarding").completed = true
	var scenes: Array[String] = ["main_menu","cultivation_menu","equipment_screen","daily_quest_screen","pavilion_screen"]
	for dims: Vector2i in [Vector2i(320,568),Vector2i(720,1600)]:
		root.size = dims
		var first: Rect2
		for id: String in scenes:
			change_scene_to_file("res://scenes/ui/"+id+".tscn"); await frames(14)
			var nav: Control = current_scene.find_child("HubNav",true,false) as Control
			check(nav != null and nav.sanctuary_style and nav.sanctuary_frame != null,"same ornamental navbar "+id+str(dims))
			if nav == null: continue
			var box: Rect2 = nav.get_global_rect()
			if id == "main_menu": first = box
			check(box.size.is_equal_approx(first.size) and box.position.is_equal_approx(first.position),"navbar geometry "+id+str(dims))
			check(nav.tab_buttons.size() == 5 and nav.tab_buttons[0].size.x > 45,"five touch targets stay usable")
			if dims.x==720: await capture("nav-"+id)
	change_scene_to_file("res://scenes/ui/main_menu.tscn"); await frames(12)
	var progression: Node = root.get_node("ProgressionManager")
	var notice: Node = root.get_node("RewardDeliveryPresenter/HeroLevelNotice")
	var baseline: Dictionary = progression.build_progression_save_data()
	baseline.hero_experience_total = 0
	progression.apply_progression_save_data(baseline,false); await frames()
	check(not notice.panel.visible and notice.to_level==0,"save load is silent")
	var earned: Dictionary = progression.preview_add_hero_experience(baseline,300)
	progression.apply_progression_save_data(earned,true)
	await create_timer(.4).timeout; await frames(4)
	check(notice.panel.visible and notice.shown_level == 3,"real progression grant produces one coalesced level-up")
	for language: String in ["en","id"]:
		settings.language = language
		for dims: Vector2i in [Vector2i(320,568), Vector2i(720,1600)]:
			root.size = dims; notice._layout(); await frames(3)
			check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(notice.panel.get_global_rect()),"level card fits phone "+language+str(dims))
			check(notice.panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"notification never blocks navigation")
	await capture("hero-level-up")
	var shown: int = notice.shown_level
	progression.apply_progression_save_data(earned,false); await frames(4)
	check(notice.shown_level==shown and notice.to_level==0,"same saved level never replays celebration")
	var audio: Node = root.get_node("AudioManager")
	var first_stream: AudioStream = audio._get_sfx_stream("ui")
	for name_value: String in ["Back","Claim","Summon","Sort","Buy","Equip"]:
		var button := Button.new();button.name = name_value
		check(audio._resolve_button_sfx(button)=="ui","one touch cue "+name_value)
		button.free()
	check(audio._get_sfx_stream("ui")==first_stream and audio._get_sfx_pitch("ui")==1.0,"tap asset and pitch never alternate")
	check(first_stream.resource_path.contains("presentation_v2/ui_tap_01"),"legacy soft click active pending asset choice")
	check(audio.SFX.sword[0].resource_path.contains("presentation_v2"),"legacy weapon audio restored")
	check(not audio.SFX.has("impact_compass"),"extra continuous dragon impact layer removed")
	var world := Node2D.new(); root.add_child(world)
	var courier: Node2D = load("res://scripts/weapon/heavenweaver_compass_cast.gd").new()
	world.add_child(courier); courier.set_physics_process(false)
	courier._resize_heads(1, Vector2.ZERO)
	var valid_shape: bool = true
	var smooth_head: bool = true
	for reduced: bool in [false,true]:
		settings.reduced_effects = reduced
		var head: Dictionary = courier.heads[0]
		for step: int in 90:
			courier.age += 1.0/60.0
			head.point = Vector2(260+step*2.0, 700+sin(step*.08)*25)
			head.angle = 0.0 if step<45 else PI
			var before_angle: float = head.get("visual_angle",head.angle)
			courier._update_dragon(head,1.0/60.0,0)
			smooth_head = smooth_head and absf(angle_difference(before_angle,head.visual_angle)) <= .101
			if not reduced and step == 40: await capture("dragon-painted-body")
			var spine: PackedVector2Array = head.spine
			for j: int in range(1,spine.size()):
				valid_shape = valid_shape and spine[j].is_finite() and absf(spine[j].distance_to(spine[j-1])-courier.DRAGON_BODY_LENGTH/(spine.size()-1)) < .01
		check(head.spine.size() == (8 if reduced else 12),"bounded dragon joint count")
	check(valid_shape,"dragon keeps finite continuous body spacing through reversal")
	check(smooth_head,"dragon head turning is bounded through reversal")
	for head: Dictionary in courier.heads: head.mesh.mesh = null; head.face.texture = null
	world.free()
	var journey: Node = root.get_node("JourneyManager")
	journey.select_stage(1,1)
	root.get_node("GameSession").start_new_game()
	change_scene_to_file(journey.begin_selected_stage()); await frames(20)
	var tutorial: Node = current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
	tutorial._on_skip_pressed()
	paused = true
	var victory: CanvasLayer = current_scene.get_node("VictoryUI")
	victory.show()
	var next_earned: Dictionary = progression.preview_add_hero_experience(earned,200)
	progression.apply_progression_save_data(next_earned,true)
	await create_timer(.4).timeout; await frames(4)
	check(notice.panel.visible and notice.shown_level == 4,"permanent level celebration appears on actual paused Victory result")
	victory.hide(); await frames(2)
	check(not notice.panel.visible,"Pause still hides permanent level notice outside Victory")
	paused = false
	if is_instance_valid(current_scene): current_scene.free(); current_scene = null
	first_stream = null
	await frames(4)
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("PLAYER_COMFORT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
