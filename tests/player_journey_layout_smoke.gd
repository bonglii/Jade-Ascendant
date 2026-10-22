extends SceneTree
var checks: int=0
var failures: int=0
func check(value: bool,caption: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("PLAYER_JOURNEY_LAYOUT "+caption)
func frames(count: int=10) -> void:
 for i: int in range(count):await process_frame
func swipe(at: Vector2) -> void:
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.pressed=true;event.position=at;root.push_input(event,true);await frames(1)
 for i: int in range(1,9):
  var motion:=InputEventMouseMotion.new();motion.position=at+Vector2(0,-110)*float(i)/8;motion.relative=Vector2(0,-110.0/8);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true);await frames(1)
 event.position=at+Vector2(0,-110);event.pressed=false;event.button_mask=0;root.push_input(event,true);await frames(5)
func shot(name: String) -> void:
 var output: String=OS.get_environment("JADE_JOURNEY_RENDER_DIR")
 if output.is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+name+".png")
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 create_timer(70).timeout.connect(func():quit(1))
 await frames()
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var journey: Node=root.get_node("JourneyManager")
 journey.select_stage(1,1)
 var scene: Control=load("res://scenes/ui/stage_select.tscn").instantiate();root.add_child(scene);current_scene=scene;await frames(20)
 for dimensions: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.size=dimensions;await frames(20)
  check(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(1).encloses(scene.map_scroll.get_global_rect()),"Realm map stays in viewport "+str(dimensions))
  print("REALM_GEOMETRY dims=",dimensions," map=",scene.map_scroll.size," header=",scene._realm_header.size," start=",scene.start_button.get_global_rect()," title=",scene._preview_title.size)
  check(scene.map_scroll.size.y>dimensions.y*.28,"map has meaningful room "+str(dimensions))
  check(scene.start_button.get_global_rect().end.x<=dimensions.x,"main stage button stays inside phone "+str(dimensions))
  check(scene._preview_reward.get_global_rect().end.x<=dimensions.x,"actual reward text fits "+str(dimensions))
  check(scene._realm_header.size.y<=120,"Realm header remains compact "+str(dimensions))
  check(scene.map_scroll.get_global_rect().grow(2).encloses(scene._stage_node_refs[1].plate.get_global_rect()),"selected stage title is fully visible after initial focus "+str(dimensions))
  await shot("realm-"+str(dimensions.x))
 scene.map_scroll.scroll_vertical=0;await frames(4)
 var old_scroll: int=scene.map_scroll.scroll_vertical
 var selection: int=journey.selected_stage_id
 var first_card: Control=scene._stage_node_refs[5].button
 var start: Vector2=first_card.get_global_rect().get_center()
 if not scene.map_scroll.get_global_rect().has_point(start):start=scene.map_scroll.get_global_rect().get_center()
 await swipe(start)
 check(scene.map_scroll.scroll_vertical>old_scroll+20,"first swipe beginning on a map seal scrolls naturally")
 check(journey.selected_stage_id==selection,"map swipe does not select a stage")
 check(scene.map_scroll.get_v_scroll_bar().modulate.a==0,"scroll axis works while scrollbar chrome stays hidden")
 var transition: Node=root.get_node("SceneTransitionManager")
 for language: String in ["en","id"]:
  root.get_node("SettingsManager").language=language
  var notice: Control=preload("res://scripts/ui/run_verification_notice.gd").open(transition,"ACCOUNT_MISMATCH","••••3388@gmail.com")
  await frames(15)
  await shot("verification-"+language)
  var body_scroll: ScrollContainer=notice.find_child("VerificationScroll",true,false)
  check(body_scroll.size.x<=notice._panel.size.x-40,"notice text has horizontal inset "+language)
  notice.close();await frames(3)
 root.get_node("SettingsManager").language="en"
 current_scene=null;scene.queue_free();await frames()
 var account: Control=load("res://scripts/ui/google_account_card.gd").new();account.custom_minimum_size=Vector2(300,0);root.add_child(account);await frames()
 check(not account._footer.text.contains("Cloud Save is not active"),"account card no longer contradicts implemented cloud backup")
 check(account._footer.text.contains("Local progress"),"guest status describes local saves honestly")
 account.queue_free();await frames()
 var settings: Control=load("res://scenes/ui/settings_screen.tscn").instantiate();root.add_child(settings);current_scene=settings;await frames(12)
 var summary: String=settings.get_support_summary()
 check(summary.contains("Compass run entry stage="),"support report retains the actual event gate category")
 check(not summary.contains("3388@gmail.com"),"display-only email hints are excluded from support report")
 current_scene=null;settings.queue_free();await frames()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("PLAYER_JOURNEY_LAYOUT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
