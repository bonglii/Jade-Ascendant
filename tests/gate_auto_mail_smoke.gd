extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("GATE_MAIL_FAIL "+label)
func _initialize() -> void:run.call_deferred()
func settle() -> void:
 for i: int in range(6):await process_frame
func inside(outer: Rect2,inner: Rect2) -> bool:
 return inner.position.x>=outer.position.x-1 and inner.position.y>=outer.position.y-1 and inner.end.x<=outer.end.x+1 and inner.end.y<=outer.end.y+1
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_gate_mail_qa"):quit(2);return
 await process_frame
 root.content_scale_size=Vector2i.ZERO
 var progress: Dictionary=root.get_node("ProgressionManager").build_progression_save_data().duplicate(true)
 change_scene_to_file("res://scenes/ui/google_account_entry.tscn");await settle()
 var entry: Control=current_scene
 for locale: String in ["en","id"]:
  root.get_node("SettingsManager").language=locale;entry._apply_copy()
  for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504),Vector2i(1280,800)]:
   root.size=dims;await settle()
   for state: Dictionary in [{"native_ready":false,"busy":false},{"native_ready":true,"busy":false},{"native_ready":true,"busy":true,"operation":"google_sign_in"},{"native_ready":false,"busy":true,"operation":"anonymous_identity"}]:
    entry._on_account_state_changed(state);await settle();entry._layout_gate();await settle()
    var tag: String=str(dims)+locale+str(state)
    var safe: Rect2=entry._safe.get_global_rect()
    check(inside(safe,entry.login_panel.get_global_rect()),"panel safe "+tag)
    check(inside(safe,entry.privacy_note.get_global_rect()),"footer safe "+tag)
    check(entry.google_button.size.y>=48 and entry.guest_button.size.y>=48,"touch targets "+tag)
    check(entry.google_button.disabled==(bool(state.busy) or not bool(state.native_ready)),"Google actual availability "+tag)
    check(not entry.brand_label.visible and entry._logo.texture!=null,"one logo "+tag)
    if not bool(state.native_ready) and not bool(state.busy):check(entry._panel_content.get_child(3)==entry.guest_button,"Guest first when Google unavailable")
    if bool(state.native_ready) and not bool(state.busy):check(entry._panel_content.get_child(3)==entry.google_button,"Google first when ready")
    if str(state.get("operation",""))=="anonymous_identity":check(not entry.guest_button.disabled,"guest remains usable during anonymous preparation")
   if locale=="en" and dims==Vector2i(390,844) and "--render" in OS.get_cmdline_user_args():
    entry._on_account_state_changed({"native_ready":false,"busy":false});await settle();await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/jade-qa/gate-portrait.png")
   if locale=="en" and dims==Vector2i(896,504) and "--render" in OS.get_cmdline_user_args():
    entry._on_account_state_changed({"native_ready":true,"busy":false});await settle();await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/jade-qa/gate-landscape.png")
 check(progress==root.get_node("ProgressionManager").build_progression_save_data(),"entry presentation cannot mutate progress")
 var mail: Node=root.get_node("ServerMailManager")
 var now: int=Time.get_ticks_msec()
 mail._backgrounded=false;mail._refreshing=false;mail._last_started_msec=now-15000;mail._last_success_msec=now;mail._next_refresh_msec=now+180000;mail._list_failures=0
 check(not mail._refresh_due(now) and not mail._refresh_due(now,true),"fresh cache skips automatic/open request")
 check(mail._refresh_due(now+180000),"periodic sync at3minutes")
 check(mail._refresh_due(now+30000,true),"opening stale mailbox refreshes after30s")
 mail._refreshing=true;check(not mail._refresh_due(now+200000,true),"no overlapping sync")
 mail._refreshing=false;mail._last_started_msec=now;check(not mail._refresh_due(now+1000,true),"rapid reopen/profile events throttled")
 mail._last_started_msec=now-15000;mail._backgrounded=true;check(not mail._refresh_due(now+200000,true),"no polling while backgrounded")
 mail._backgrounded=false;mail._list_failures=0
 for expected: int in [60,120,240,300,300]:
  mail._pending={"kind":"list"};mail._refreshing=true;mail._incoming.clear();mail._incoming.append({"partial":"discard"})
  mail._fail("offline")
  check(absi(mail._next_refresh_msec-Time.get_ticks_msec()-expected*1000)<50,"backoff "+str(expected))
  check(not mail._refreshing and mail._incoming.is_empty(),"failed page releases sync and partial page")
  check(not mail._refresh_due(Time.get_ticks_msec()+30000,true),"opening cannot bypass error backoff")
 mail._owner="a".repeat(64);mail._pending={"kind":"list","cursor":""};mail._state.cache={}
 check(mail._accept_page({"version":1,"server_time":100,"entries":[],"next_cursor":""}),"final page accepted")
 check(mail._list_failures==0 and absi(mail._next_refresh_msec-Time.get_ticks_msec()-180000)<50,"success resets interval/backoff")
 mail._owner="";mail._auth_node=null
 change_scene_to_file("res://scenes/ui/mailbox_screen.tscn");await settle()
 check(current_scene.find_child("MailboxServerSyncButton",true,false)==null,"manual sync button removed")
 check(current_scene._server_status!=null,"automatic sync retains status")
 if "--render" in OS.get_cmdline_user_args():
  root.size=Vector2i(390,844);await settle();await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/tmp/jade-qa/mail-auto-sync.png")
 change_scene_to_file("res://scenes/ui/google_account_entry.tscn");await settle()
 entry=current_scene
 entry._on_guest_pressed();entry._on_guest_pressed()
 check(entry._moving_to_home,"guest transition starts once")
 for frame: int in range(1200):
  await process_frame
  if current_scene!=null and current_scene.scene_file_path=="res://scenes/ui/main_menu.tscn":break
 check(current_scene.scene_file_path=="res://scenes/ui/main_menu.tscn","guest enters actual Home")
 change_scene_to_file("res://scenes/ui/google_account_entry.tscn");await settle()
 entry=current_scene;entry._on_account_state_changed({"signed_in":true})
 for frame: int in range(1200):
  await process_frame
  if current_scene!=null and current_scene.scene_file_path=="res://scenes/ui/main_menu.tscn":break
 check(current_scene.scene_file_path=="res://scenes/ui/main_menu.tscn","restored session bypass keeps actual navigation")
 check(progress==root.get_node("ProgressionManager").build_progression_save_data(),"guest/restored presentation preserves progression")
 print("GATE_AUTO_MAIL_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
