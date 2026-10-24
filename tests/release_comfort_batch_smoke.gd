extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("RELEASE_COMFORT_FAIL "+label)
func frames(count: int=4) -> void:
 for i: int in count:await process_frame
func _initialize() -> void:run.call_deferred()
func capture(label: String) -> void:
 if DisplayServer.get_name()=="headless" or OS.get_environment("JADE_COMFORT_CAPTURE").is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("JADE_COMFORT_CAPTURE")+"/"+label+".png")
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 await frames(12)
 if "--restart-welcome" in OS.get_cmdline_user_args():
  var saved_mail: Node=root.get_node("ServerMailManager");saved_mail._owner="f".repeat(64)
  check(saved_mail.is_announcement_seen("c".repeat(32)),"first-open marker survives actual process restart")
  var saved_center: Node=root.get_node("AnnouncementCenter");saved_center.set_process(false)
  var epoch: int=int(Time.get_unix_time_from_system())
  var previous_entry: Dictionary={"id":"c".repeat(32),"title":"Welcome","body":"Already presented","kind":"notice","display_policy":"first_open","starts_at":epoch-1,"expires_at":epoch+3600}
  check(saved_center.accept_snapshot("f".repeat(64),[previous_entry],epoch) and saved_center._queue.is_empty(),"restart feed does not replay welcome")
  await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
  print("COMFORT_RESTART checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1);return
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var config:=ConfigFile.new();config.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]:config.set_value("tutorials",key,true)
 config.save("user://jade_onboarding.cfg");root.get_node("RefineOnboarding").completed=true
 var audio: Node=root.get_node("AudioManager");audio.equipment_change_suppress_until_msec=0
 var before: Dictionary=audio.variation_cursor.duplicate(true)
 for i: int in 4:root.get_node("PavilionManager")._paid_gameplay_changed()
 check(audio.variation_cursor==before,"repeated server loadout refresh silent")
 check(int(root.get_node("EquipmentManager").get_meta("quiet_loadout_sync_depth",-1))==0,"quiet context restored")
 audio._on_equipment_changed_audio("armament","spirit_sword")
 check(audio.variation_cursor!=before,"manual equip retains feedback")
 root.size=Vector2i(390,844);change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(30)
 var home: Node=current_scene;var p: Node=home.get_node("HomeUI/HomeProductionOverlay");p.set_process(false)
 var info: Dictionary={"current":1,"total":10}
 p._cancel_feature_motion();p._apply_feature("boss_hunt","boss",info,1,3)
 var hit_rect: Rect2=p.event_button.get_rect()
 p._request_feature("pilgrimage","pilgrimage",info,2,3);await create_timer(.10).timeout
 check(p._featured_key=="boss_hunt" and p._feature_offset<0,"outgoing slide precedes content change")
 await create_timer(.18).timeout;check(p._featured_key=="pilgrimage","content and destination swap together")
 await create_timer(.45).timeout
 check(is_zero_approx(p._feature_offset) and p._feature_pending.is_empty(),"transition settles")
 check(p.event_button.get_rect()==hit_rect,"tap area stays fixed")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.size=dims;await frames(10);p._layout_sanctuary();await frames()
  var caption: Control=p.find_child("EventsCaption",true,false)
  check(caption!=null and caption.position.y>=0 and caption.size.y>=caption.get_parent().size.y-1,"compact heading baseline "+str(dims))
  check(caption.get_rect().end.x<=caption.get_parent().size.x+1,"caption inside frame "+str(dims))
  p._request_feature("boss_hunt","boss",info,1,3);p._layout_sanctuary();check(is_zero_approx(p._feature_offset),"resize normalizes slide")
 root.get_node("SettingsManager").reduced_effects=true;p._request_feature("treasure_hunt","treasure",info,3,3)
 check(p._featured_key=="treasure_hunt" and p._feature_motion==null,"reduced effects fallback")
 root.get_node("SettingsManager").reduced_effects=false;root.size=Vector2i(390,844);await frames(10);await capture("home-events")
 var progression: Node=root.get_node("ProgressionManager");progression.hero_experience_total=0
 for lv: int in range(1,10):progression.hero_experience_total+=progression.get_hero_experience_to_next_for_level(lv)
 progression.hero_milestones_claimed.clear()
 var presenter: Node=root.get_node("RewardClaimResultPresenter");presenter._close_popup();presenter._pending_entries.clear();presenter._result_queue.clear()
 home._open_profile_sheet();await create_timer(.4).timeout;home._on_hero_milestone_claim_pressed(10);await create_timer(1.3).timeout
 check(progression.is_hero_milestone_claimed(10),"real milestone claim awarded")
 check(is_instance_valid(presenter._popup) and presenter._popup.is_visible_in_tree(),"milestone reward visible")
 if is_instance_valid(presenter._popup):
  check(presenter._popup.z_index>home.profile_overlay.z_index,"reward layer above profile");await capture("milestone-above-profile")
 check(not progression.can_claim_hero_milestone(10),"claimed milestone is no longer eligible")
 if is_instance_valid(presenter._popup):
  var actions: Array[Node]=presenter._popup.find_children("*","Button",true,false)
  if not actions.is_empty():
   var button: Button=actions[0] as Button
   var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=button.get_global_rect().get_center();event.pressed=true;event.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(event,true);await frames(1)
   event.pressed=false;event.button_mask=0;root.push_input(event,true);await frames(6)
   check(not is_instance_valid(presenter._popup) and home.profile_overlay.visible,"reward action receives input above Profile")
 presenter._close_popup();home._close_profile_sheet();await frames(8)
 var mail: Node=root.get_node("ServerMailManager");var center: Node=root.get_node("AnnouncementCenter");center.set_process(false)
 var owner: String="f".repeat(64);mail._owner=owner
 var now: int=int(Time.get_unix_time_from_system())
 var entry: Dictionary={"id":"c".repeat(32),"title":"Welcome, cultivator","body":"One-time welcome message.","kind":"notice","display_policy":"first_open","starts_at":now-1,"expires_at":now+3600,"cancelled":false}
 center._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);check(center.accept_snapshot(owner,[entry],now),"welcome accepted")
 center._next_at=0;center._check_left=0;center._process(.3)
 check(center.visible and mail.is_announcement_seen(str(entry.id)),"first presentation persisted before dismissal")
 var stored: Dictionary=root.get_node("SaveManager").read_save_data("server_mail").get("data",{})
 check(str(entry.id) in stored.get("announcement_seen",{}).get(owner,[]),"first-open marker saved to disk")
 center.set_account_owner("");center.accept_snapshot(owner,[entry],now);check(center._queue.is_empty() and not center.visible,"new presentation session does not replay welcome")
 var other: String="e".repeat(64);mail._owner=other;check(center.accept_snapshot(other,[entry],now) and center._queue.size()==1,"different account has independent welcome")
 center._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);center._next_at=0;center._check_left=0;center._process(.3)
 check(not center.visible and not mail.is_announcement_seen(str(entry.id)),"background cannot consume welcome")
 center._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);center._check_left=0;center._process(.3);check(center.visible,"safe foreground displays welcome");center._dismiss()
 var prewarm: Node=root.get_node_or_null("MenuResourcePrewarm");var deadline: int=Time.get_ticks_msec()+15000
 while prewarm!=null and bool(prewarm.get("_prewarm_started")) and Time.get_ticks_msec()<deadline:await create_timer(.1).timeout
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("RELEASE_COMFORT_BATCH checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
