extends SceneTree
const Prefs=preload("res://scripts/ui/joystick_prefs.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("CONTROL_COMFORT_FAIL "+label)
func frames(n: int=4) -> void:
	for i: int in n: await process_frame
func touch(index: int,at: Vector2,pressed: bool) -> void:
	var e:=InputEventScreenTouch.new();e.index=index;e.position=at;e.pressed=pressed;root.push_input(e,true)
func drag(index: int,at: Vector2) -> void:
	var e:=InputEventScreenDrag.new();e.index=index;e.position=at;root.push_input(e,true)
func swipe(at: Vector2,distance: float) -> void:
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.button_mask=MOUSE_BUTTON_MASK_LEFT;press.pressed=true;press.position=at;root.push_input(press,true);await frames(1)
	for i: int in range(1,9):
		var move:=InputEventMouseMotion.new();move.position=at+Vector2(0,-distance*i/8.0);move.relative=Vector2(0,-distance/8.0);move.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(move,true);await frames(1)
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=at+Vector2(0,-distance);root.push_input(release,true);await frames(6)
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless" or OS.get_environment("JADE_CONTROLS_CAPTURE").is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("JADE_CONTROLS_CAPTURE")+"/"+label+".png")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"): quit(2);return
	await frames(8);await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	if "--resume-controls" in OS.get_cmdline_user_args():
		check(Prefs.get_mode()==Prefs.Mode.FIXED_FULL,"mode survives actual process restart")
		check(Prefs.get_size_index()==2 and is_equal_approx(Prefs.get_opacity(),.75),"size/opacity survive together")
		print("CONTROLS_RESTART checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0);return
	check(Prefs.get_mode()==Prefs.Mode.FLOATING_FULL,"missing/legacy mode defaults to small-drag full speed")
	check(Prefs.save_preferences(2,.75)==OK and Prefs.get_mode()==Prefs.Mode.FLOATING_FULL,"old two-argument saves remain compatible")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var onboarding:=ConfigFile.new();onboarding.set_value("meta","version",2);onboarding.set_value("tutorials","home",true);onboarding.save("user://jade_onboarding.cfg")
	root.get_node("RefineOnboarding").completed=true
	for language: String in ["en","id"]:
		root.get_node("SettingsManager").language=language
		for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844)]:
			root.size=dims;change_scene_to_file("res://scenes/ui/settings_screen.tscn");await frames(20)
			var settings: Control=current_scene;var option: OptionButton=settings.joystick_mode_choice
			var scroll: ScrollContainer=settings._settings_scroll
			scroll.ensure_control_visible(option);await frames()
			check(option.item_count==3 and option.size.y>=44,"all three modes have safe touch target "+language+str(dims))
			check(option.get_global_rect().end.x<=dims.x and option.get_global_rect().position.x>=0,"mode dropdown stays inside phone")
			var old_mode: int=Prefs.get_mode();var before: int=scroll.scroll_vertical
			await swipe(option.get_global_rect().get_center(),110)
			check(scroll.scroll_vertical>before and not option.get_popup().visible,"first swipe on new dropdown scrolls without opening popup")
			check(Prefs.get_mode()==old_mode,"swipe does not change stored mode")
			for mode: int in 3:
				settings._on_joystick_mode_selected(mode)
				check(Prefs.get_mode()==mode and not settings.joystick_mode_hint.text.is_empty(),"mode selection persists with matching hint")
			settings._on_reset_controls_pressed()
			check(Prefs.get_mode()==Prefs.DEFAULT_MODE and Prefs.get_size_index()==1 and is_equal_approx(Prefs.get_opacity(),1),"reset restores full-speed defaults")
			await frames();scroll.ensure_control_visible(option);await frames()
			if dims.x==390: await capture("controls-settings-"+language)
	root.get_node("GameSession").start_new_game();change_scene_to_file("res://scenes/levels/level_1.tscn");await frames(22)
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
	current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED
	current_scene.get_node("EnemySpawner").clear_normal_enemies();current_scene.get_node("WaveManager").set_process(false)
	var player: Node2D=current_scene.get_node("player_1");player.set_physics_process(false)
	player.get_node("WeaponManager").set_process(false)
	var layer:=CanvasLayer.new();layer.layer=100;root.add_child(layer)
	var joystick: Control=load("res://scripts/ui/virtual_joystick.gd").new();layer.add_child(joystick);joystick.size=Vector2(390,844)
	joystick.platform_visible=true;joystick._process(0)
	for mode: int in 3:
		Prefs.save_preferences(1,.8,mode);joystick._process(0)
		var start: Vector2=joystick._get_idle_center() if mode==Prefs.Mode.FIXED_FULL else Vector2(180,620)
		touch(4,start,true)
		var center: Vector2=joystick.floating_center
		drag(7,center+Vector2(70,0));check(joystick.movement_vector==Vector2.ZERO,"second finger cannot hijack analog")
		drag(4,center+Vector2(joystick.base_radius*.1,0));check(joystick.movement_vector==Vector2.ZERO,"deadzone prevents accidental drift")
		drag(4,center+Vector2(joystick.base_radius*.3,0))
		if mode!=Prefs.Mode.FLOATING_ANALOG:
			check(is_equal_approx(joystick.movement_vector.length(),1),"small valid drag immediately reaches full speed")
			player._physics_process(1.0/60)
			check(is_equal_approx(player.velocity.length(),player.get_effective_movement_speed()),"actual player receives full movement speed")
		else: check(joystick.movement_vector.length()>0 and joystick.movement_vector.length()<.5,"proportional mode retains gentle movement")
		drag(4,center+Vector2(joystick.base_radius*1.4,joystick.base_radius*1.4))
		check(is_equal_approx(joystick.movement_vector.length(),1) and joystick.raw_offset.length()<=joystick.base_radius+.01,"diagonal and overdrag stay bounded")
		touch(4,center,false);check(Input.get_vector("ui_left","ui_right","ui_up","ui_down")==Vector2.ZERO,"release clears all actions")
		if mode==Prefs.Mode.FIXED_FULL:
			touch(4,Vector2(370,620),true);check(joystick.active_touch_index==-1,"fixed mode ignores touches away from visible base")
			touch(4,start,true);check(joystick.floating_center.is_equal_approx(start),"fixed base stays anchored")
		else:
			touch(4,Vector2(230,560),true);check(joystick.floating_center.is_equal_approx(Vector2(230,560)),"floating base follows first touch")
		drag(4,joystick.floating_center+Vector2(35,0));paused=true;joystick._process(0)
		check(joystick.movement_vector==Vector2.ZERO and joystick.active_touch_index==-1,"pause clears pointer and prevents stuck movement")
		touch(4,start,false);paused=false;joystick._process(0)
		touch(4,start,true);drag(4,joystick.floating_center+Vector2(35,0));joystick._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(Input.get_vector("ui_left","ui_right","ui_up","ui_down")==Vector2.ZERO,"focus loss clears movement")
		touch(4,start,false)
	for mode: int in [1,0,2,1]:
		Prefs.save_preferences(2,.75,mode);joystick._process(0)
		check(is_equal_approx(joystick.base_radius,72*1.22),"live preference changes do not compound radius")
	layer.free()
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("CONTROLS_COMFORT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
