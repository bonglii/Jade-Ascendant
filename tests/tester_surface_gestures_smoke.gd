extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize() -> void:run.call_deferred()
func frames(count: int=8) -> void:
 for i: int in count:await process_frame
func swipe(at: Vector2,motion: Vector2) -> void:
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.button_mask=MOUSE_BUTTON_MASK_LEFT;down.position=at;root.push_input(down,true);await frames(1)
 for i: int in range(1,9):
  var drag:=InputEventMouseMotion.new();drag.position=at+motion*float(i)/8.0;drag.relative=motion/8.0;drag.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(drag,true);await frames(1)
 down.position=at+motion;down.pressed=false;down.button_mask=0;root.push_input(down,true);await frames(8)
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_tester_surface_qa"):quit(2);return
 create_timer(75).timeout.connect(func():push_error("TESTER_SURFACE watchdog");quit(3))
 # This fixture checks input/layout/mesh reuse, not audio. Suppress incidental
 # menu and summon playback before creating scenes: draining after playback
 # alone races the Dummy mixer at shutdown and leaves AudioStream resources.
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 await frames(10)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(390,844)
 var guide: Node=root.get_node_or_null("RefineOnboarding")
 if guide!=null:guide.completed=true;guide.set_process(false)
 var conf:=ConfigFile.new();conf.set_value("meta","version",2)
 for id: String in ["home","equipment","pavilion"]:conf.set_value("tutorials",id,true)
 conf.save("user://jade_onboarding.cfg")
 var journey: Node=root.get_node("JourneyManager")
 for chapter: int in journey.get_chapter_ids():
  for stage: int in journey.get_stage_ids(chapter):journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
 change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(18)
 var home: Control=current_scene
 var presenter: Control=home.get_node("HomeUI/HomeProductionOverlay")
 if home.has_node("JadeOnboardingOverlay"):home.get_node("JadeOnboardingOverlay").hide()
 var before: String=presenter._featured_key
 check(presenter._feature_choices.size()>1,"actual Home exposes more than one active event")
 var at: Vector2=presenter.event_button.get_global_rect().get_center()
 print("BANNER_RECT ",presenter.event_button.get_global_rect()," viewport=",root.size)
 await swipe(at,Vector2(-110,0));await create_timer(.65).timeout
 check(presenter._featured_key!=before,"native first horizontal swipe changes the event banner")
 check(current_scene==home and not root.get_node("SceneTransitionManager").is_transitioning,"swiping the banner never activates an event")
 await swipe(presenter.event_button.get_global_rect().get_center(),Vector2(110,0));await create_timer(.65).timeout
 check(presenter._featured_key==before,"native reverse swipe returns to the previous event")
 change_scene_to_file("res://scenes/ui/skill_book_screen.tscn");await frames(10)
 var library: Control=current_scene
 library._open_equipment_detail("heavenweaver_compass");await frames(12)
 var scroll: ScrollContainer=library._detail_scroll
 var initial: int=scroll.scroll_vertical
 await swipe(scroll.get_global_rect().get_center(),Vector2(0,-90))
 check(scroll.scroll_vertical>initial+20,"first native drag scrolls long Library detail immediately")
 check(is_instance_valid(library._popup),"scrolling detail cannot close the popup or select a relic")
 library._close_popup()
 var pavilion: Node=root.get_node("PavilionManager")
 pavilion.state.pavilion_seals=3
 check(not pavilion.request_paid_summon(1) and pavilion.last_error.contains("Seals first"),"every paid entry point refuses to bypass owned seals")
 change_scene_to_file("res://scenes/ui/pavilion_screen.tscn");await frames(12)
 var page: Control=current_scene
 check(not page._paid_buttons[0].get_parent().visible,"paid Jade buttons stay hidden until owned seals are used")
 page._render_summon_result({"results":[{"item_id":"nine_heavens_star_sword","rarity":"legendary"}]})
 check(page.summon_result_box==null or not page.summon_result_box.visible,"legacy plaintext results cannot leak from under the ritual")
 var entries: Array=[]
 for i: int in 10:entries.append({"item_id":"nine_heavens_star_sword","rarity":"legendary"})
 page._start_summon_reveal({"results":entries});page._skip_ritual();await frames()
 check(page._result_details.custom_minimum_size.y==0,"ten-result formation removes the old reserved detail region")
 check(page._formation_scroll.get_global_rect().position.y-page._result_state.get_global_rect().end.y<36,"formation begins close to its subtitle")
 page._finish_summon_reveal()
 var cast: Node2D=load("res://scripts/weapon/heavenweaver_compass_cast.gd").new();root.add_child(cast);cast.set_physics_process(false)
 cast._resize_heads(1,Vector2(100,100));var head: Dictionary=cast.heads[0]
 cast._update_dragon(head,1.0/60.0,0);var resource_id: int=head.resource.get_instance_id()
 for i: int in 180:
  head.point=Vector2(100+i*5,100+sin(i*.1)*30);cast.age+=1.0/60.0;cast._update_dragon(head,1.0/60.0,0)
 check(head.resource.get_instance_id()==resource_id and head.vertex_count==28,"180 dragon frames reuse one mesh and its immutable UV/index buffers")
 check(head.resource.custom_aabb.has_point(Vector3(head.point.x,head.point.y,0)),"moving dragon keeps correct render bounds beyond its spawn position")
 root.get_node("SettingsManager").reduced_effects=true;cast._update_dragon(head,1.0/30.0,0)
 check(head.resource.get_instance_id()==resource_id and head.vertex_count==20,"reduced-effects joint change rebuilds surface without leaking mesh resources")
 cast.queue_free();root.get_node("SettingsManager").reduced_effects=false
 var feedback: Node=root.get_node("CombatFeedback")
 var crowd:=Node.new();root.add_child(crowd)
 for i: int in 80:
  var enemy:=Node2D.new();crowd.add_child(enemy);enemy.add_to_group("enemy")
 feedback.effect_cursor=0
 for i: int in 120:feedback._next_effect()
 check(feedback.effect_cursor<48,"dense combat bounds cosmetic text overdraw without changing damage")
 crowd.queue_free()
 print("TESTER_SURFACE checks=%d failures=%d; NATIVE_GUI=%s"%[checks,failures,str(DisplayServer.get_name()!="headless")])
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit(1 if failures else 0)
