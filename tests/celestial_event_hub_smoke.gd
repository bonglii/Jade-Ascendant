extends SceneTree
const Dot=preload("res://scripts/ui/action_ready_dot.gd")
var checks: int=0
var failures: int=0
func check(value: bool,caption: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("CELESTIAL_HUB "+caption)
func settle(frames: int=8) -> void:
 for i: int in range(frames):await process_frame
func _initialize() -> void:run.call_deferred()
func economy() -> Dictionary:
 return {"pavilion":root.get_node("PavilionManager").state.duplicate(true),"stones":root.get_node("ProgressionManager").spirit_stone,"ledger":root.get_node("LiveOpsManager")._get_ledger().duplicate()}
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_celestial_board_qa") and not OS.get_user_data_dir().contains("jade_event_qa"):quit(2);return
 create_timer(40).timeout.connect(func() -> void:quit(1))
 await create_timer(.4).timeout
 var client: Node=root.get_node("OdysseyClient");client.set_process(false)
 var now: int=int(Time.get_unix_time_from_system());var today: String=Time.get_datetime_string_from_unix_time(now).substr(0,10)
 client.snapshot={"event":{"id":"qa","enabled":true,"starts_at":now-1000,"ends_at":now+8*86400},"state":{"day":today,"task_day":today,"daily_rolls":3,"missions":[],"rolls":36,"milestones":[],"daily_gifts":0,"daily_guardians":0},"server_time":now};client._received_msec=Time.get_ticks_msec();client.status="connected";client.busy=false
 var daily: Node=root.get_node("DailyQuestManager");daily.completed_quest_ids.assign([daily.get_daily_quest_ids()[0]]);daily.claimed_quest_ids.clear()
 var before: Dictionary=economy()
 var viewport:=SubViewport.new();viewport.size=Vector2i(648,1152);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var page: Control=load("res://scenes/ui/event_center_screen.tscn").instantiate();page.set_meta("liveops_popup",true);viewport.add_child(page);await settle()
 check(Dot.count(page,"all_events")==Dot.count(page,"seven_day")+Dot.count(page,"boss_hunt")+Dot.count(page,"pilgrimage")+Dot.count(page,"heavenly_ladder")+Dot.count(page,"treasure_hunt")+Dot.count(page,"five_elements")+Dot.count(page,"odyssey")+Dot.count(page,"daily")+Dot.count(page,"pavilion"),"All Events aggregates every claimable destination in the hub")
 check(page._activity_handles.size()==8,"all eight supporting destinations plus featured Odyssey retained")
 check(page._hero_action.pressed.get_connections().filter(func(c: Dictionary) -> bool:return c.callable.get_method()=="_open_destination")[0].callable.get_bound_arguments()==["odyssey"],"hero opens the real board")
 check(page._hero_action.get_node("ActionReadyDot").visible,"actual Odyssey mission and milestone light the hero dot")
 var identities: Dictionary={}
 for key: String in page._activity_handles:
  var item: Dictionary=page._activity_handles[key];identities[key]=item.card.get_instance_id()
  var connections: Array=item.hit.pressed.get_connections().filter(func(c: Dictionary) -> bool:return c.callable.get_method()=="_open_destination")
  check(connections.size()==1 and connections[0].callable.get_bound_arguments()==[key],"one correct row navigation "+key)
  check(item.cta.pressed.get_connections().filter(func(c: Dictionary) -> bool:return c.callable.get_method()=="_open_destination").is_empty(),"decorative arrow cannot trigger a duplicate navigation "+key)
  check(item.cta.get_node("ActionReadyDot").visible==(Dot.count(page,key)>0),"shared manager-owned readiness "+key)
  check(item.cta.get_node("ActionReadyDot").get_theme_stylebox("panel").bg_color==page._hero_action.get_node("ActionReadyDot").get_theme_stylebox("panel").bg_color,"identical dot appearance "+key)
 for locale: String in ["en","id"]:
  TranslationServer.set_locale(locale)
  for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504)]:
   viewport.size=dims;await settle();page._fit_layout();await settle()
   check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(page._popup.get_rect()),"popup inside viewport "+str(dims)+locale)
   check(page._popup.get_global_rect().encloses(page._close_button.get_global_rect()),"close button stays reachable "+str(dims)+locale)
   check(page._scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED and page._scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER,"no horizontal overflow or visible scrollbar "+locale)
   var scroll_end: float=page._scroll.get_global_rect().end.x
   for key: String in page._activity_handles:
    var item: Dictionary=page._activity_handles[key]
    check(item.card.get_global_rect().end.x<=scroll_end+1,"row fits viewport "+key+str(dims)+locale)
    check(item.card.get_global_rect().encloses(item.title.get_global_rect()),"title stays inside row "+key+str(dims)+locale)
    check(item.card.get_global_rect().encloses(item.cta.get_global_rect()),"open arrow inside row "+key+str(dims)+locale)
   check(page._hero_stage.get_global_rect().encloses(page._hero_action.get_global_rect()),"hero CTA contained "+str(dims)+locale)
   check(page._event_status.size.y<32 and page._ready_count.size.y<32,"timer and readiness stay single-line "+str(dims)+locale)
   check(page._hero_stage.get_global_rect().encloses(page._hero_title.get_global_rect()),"hero title contained "+str(dims)+locale)
   check(economy()==before,"opening, refreshing, resizing and language change never grant rewards")
 page._set_filter("limited");await settle();check(page._hero_stage.visible and not page._activity_handles.seven_day.card.visible,"limited filter shows featured season")
 page._set_filter("progress");await settle();check(not page._hero_stage.visible and page._activity_handles.five_elements.card.visible and not page._activity_handles.pavilion.card.visible,"progress filter keeps trials without shop service")
 page._set_filter("all");await settle()
 page._scroll.scroll_vertical=300;await settle();var scroll_value: int=page._scroll.scroll_vertical
 for i: int in range(25):page._refresh_event_status()
 await settle();check(page._scroll.scroll_vertical==scroll_value,"refresh preserves scroll position")
 for key: String in identities:check(page._activity_handles[key].card.get_instance_id()==identities[key],"refresh and filters reuse cards "+key)
 page._record_button_down("daily");page._on_scroll_started();page._open_destination("daily")
 check(not page._navigating and not root.get_node("SceneTransitionManager").is_transitioning,"scroll release never opens a row")
 page._on_scroll_ended();page._open_destination("daily");check(not page._navigating,"post-swipe touch guard stays active")
 daily.claimed_quest_ids.assign(daily.completed_quest_ids);page._refresh_event_status();check(not page._activity_handles.daily.cta.get_node("ActionReadyDot").visible,"daily dot clears when claim ledger changes")
 var saves: Node=root.get_node("SaveManager");saves.begin_save_write_barrier("celestial-hub-qa","ui-fixture");page._refresh_event_status()
 check(Dot.count(page,"all_events")==0 and not page._hero_action.get_node("ActionReadyDot").visible,"read-only account has no false actionable rewards")
 saves.end_save_write_barrier("celestial-hub-qa");page._refresh_event_status()
 var event: Dictionary=client.snapshot.event.duplicate(true)
 check(page._odyssey_status({},now).contains("SEASON") or page._odyssey_status({},now).contains("MUSIM"),"unknown snapshot never claims connected or ready")
 event.enabled=false;check(page._odyssey_status(event,now) in ["PAUSED","DIJEDA"],"paused season accurate")
 event.enabled=true;event.starts_at=now+100;check(page._odyssey_status(event,now).begins_with("STARTS") or page._odyssey_status(event,now).begins_with("MULAI"),"scheduled timer accurate")
 event.starts_at=now-100;event.ends_at=now-5;check(page._odyssey_status(event,now) in ["CLAIM REWARDS","KLAIM HADIAH"],"post-season grace offers remaining claims")
 check(page._odyssey_status(event,now+259201) in ["SEASON ENDED","MUSIM BERAKHIR"],"expired grace displays closed")
 var live: Node=root.get_node("LiveOpsManager");var pavilion: Node=root.get_node("PavilionManager")
 # Real ledger markers, no mock count implementation: final Convergence is independent.
 var ledger: Array=live._get_ledger().duplicate()
 for key: String in live.get_five_elements_trial_ids():ledger.append(live.FIVE_ELEMENTS_CLAIM_PREFIX+key)
 pavilion.state["claimed_milestone_ids"]=ledger
 check(live.is_five_elements_convergence_unlocked(),"fixture unlocks actual Convergence after five claimed trials")
 check(Dot.count(page,"five_elements")==1,"final Convergence remains one claimable dot after all trial rewards")
 page._refresh_event_status();check(page._activity_handles.five_elements.cta.get_node("ActionReadyDot").visible,"Convergence keeps hub event dot visible")
 ledger.append(live.FIVE_ELEMENTS_CLAIM_PREFIX+live.FIVE_ELEMENTS_CONVERGENCE_ID);pavilion.state["claimed_milestone_ids"]=ledger
 page._refresh_event_status();check(Dot.count(page,"five_elements")==0 and not page._activity_handles.five_elements.cta.get_node("ActionReadyDot").visible,"Convergence claim removes final dot")
 TranslationServer.set_locale("en");viewport.size=Vector2i(648,1152);page._scroll.scroll_vertical=0;await settle()
 var capture_dir: String=OS.get_environment("JADE_HUB_CAPTURE_DIR")
 if not capture_dir.is_empty() and DisplayServer.get_name()!="headless":
  DirAccess.make_dir_recursive_absolute(capture_dir);await RenderingServer.frame_post_draw;viewport.get_texture().get_image().save_png(capture_dir.path_join("celestial-events-648.png"))
  viewport.size=Vector2i(390,844);await settle();await RenderingServer.frame_post_draw;viewport.get_texture().get_image().save_png(capture_dir.path_join("celestial-events-390.png"))
 viewport.free();await settle();await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("EVENT_IDENTITY_QA checks=%d failures=%d"%[checks,failures]);print("CELESTIAL_HUB checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
