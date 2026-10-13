extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("PERF_TOUCH_FAIL "+label)
func wait_frame(count: int=3) -> void:
 for i: int in range(count):await process_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_hero_qa"):quit(2);return
 await create_timer(.5).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var account: Node=root.get_node("GoogleAccountManager")
 check(not account.get_account_snapshot().signed_in,"desktop does not fabricate native sign-in")
 # Presentation may allow local Guest during anonymous setup; real Google operations stay guarded.
 change_scene_to_file("res://scenes/ui/google_account_entry.tscn");await wait_frame()
 var entry: Node=current_scene
 entry._on_account_state_changed({"signed_in":false,"native_ready":true,"busy":true,"operation":"anonymous_identity"})
 check(not entry.guest_button.disabled and entry.google_button.disabled,"guest available while identity initializes; Google remains serialized")
 entry._on_account_state_changed({"signed_in":false,"native_ready":true,"busy":true,"operation":"sign_in"})
 check(entry.guest_button.disabled and entry.google_button.disabled,"real native sign-in cannot be interrupted with account entry actions")
 account._busy=true;account._operation="sign_in";account._operation_started_msec=Time.get_ticks_msec()-125
 check(account.get_account_snapshot().elapsed_msec>=125,"operation snapshot exposes timing without token or UID")
 account._finish_operation();check(account._last_operation_elapsed_msec>=125 and not account._busy,"latency completion preserves existing lifecycle")
 var account_card: Node=load("res://scripts/ui/google_account_card.gd").new();entry.add_child(account_card)
 account_card._refresh({"native_ready":true,"busy":true,"operation":"anonymous_identity"})
 check(account_card._status.text.contains("identity"),"account card identifies anonymous initialization accurately")
 account_card._refresh({"native_ready":true,"busy":true,"operation":"link_google"})
 check(account_card._status.text.contains("Connecting"),"Google linking is not mislabeled sign-out")
 var baseline: Dictionary=root.get_node("ProgressionManager").build_progression_save_data().duplicate(true)
 change_scene_to_file("res://scenes/ui/achievement_screen.tscn");await wait_frame(4)
 var screen: Node=current_scene
 var presenter: Node=screen.get_node("TrialsProductionPresenter")
 check(screen.achievement_list.get_child_count()==0,"hidden legacy achievement cards never built")
 check(presenter.achievement_card_nodes.size()>0,"first records immediately available")
 check(presenter.daily_card_nodes.is_empty(),"inactive section does not inflate entry cost")
 check(presenter.achievement_card_nodes.size()<root.get_node("AchievementManager").get_achievement_ids().size(),"record build yields instead of blocking entire frame")
 presenter._switch_section("daily");await wait_frame(6)
 check(presenter.active_section=="daily" and presenter.daily_card_nodes.size()==root.get_node("DailyQuestManager").get_daily_quest_ids().size(),"rapid tab cancels stale build and completes correct section")
 check(presenter.achievement_list.get_node_or_null("TrialsLoadingLabel")!=null,"cancelled hidden records retain loading indicator until revisited")
 presenter._switch_section("achievement");await wait_frame(60)
 check(presenter.achievement_card_nodes.size()==root.get_node("AchievementManager").get_achievement_ids().size(),"all records eventually settle")
 check(presenter.achievement_list.get_node_or_null("TrialsLoadingLabel")==null,"loading copy removed after final card")
 var nodes: Dictionary=presenter.achievement_card_nodes.duplicate()
 presenter._refresh();await wait_frame()
 check(nodes==presenter.achievement_card_nodes,"unchanged cards preserve identity on progress refresh")
 check(root.get_node("ProgressionManager").build_progression_save_data()==baseline,"UI optimization cannot spend or grant rewards")
 # Fallback legacy controller is still usable if production ownership is absent.
 screen.set_meta("trials_production_owned",false);screen._refresh_screen()
 check(screen.achievement_list.get_child_count()==root.get_node("AchievementManager").get_achievement_ids().size(),"legacy fallback still constructs records")
 screen.set_meta("trials_production_owned",true)
 change_scene_to_file("res://scenes/ui/daily_quest_screen.tscn");await wait_frame(12)
 check(current_scene.quest_list.get_child_count()==0,"daily old hidden offer/card builders skipped")
 var guard: Node=root.get_node("MobileTouchPresentationGuard")
 var button:=Button.new();button.text="LIVE OPS";current_scene.add_child(button)
 var normal:=StyleBoxFlat.new();normal.bg_color=Color.DARK_GREEN
 var hover:=StyleBoxFlat.new();hover.bg_color=Color.GOLD
 var pressed:=StyleBoxFlat.new();pressed.bg_color=Color.RED
 button.add_theme_stylebox_override("normal",normal);button.add_theme_stylebox_override("hover",hover);button.add_theme_stylebox_override("pressed",pressed)
 check(button.get_theme_stylebox("hover")==hover,"desktop keeps hover until touch is observed")
 var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=Vector2(100,100);guard._input(touch);await wait_frame()
 check(button.get_theme_stylebox("hover")==normal,"touch does not synthesize glowing desktop hover")
 check(button.get_theme_stylebox("pressed")==pressed and not button.disabled,"tap feedback and enabled state preserved")
 var replacement:=StyleBoxFlat.new();replacement.bg_color=Color.BLUE
 button.add_theme_stylebox_override("normal",replacement);await wait_frame()
 check(button.get_theme_stylebox("hover")==replacement,"dynamic eligibility/theme changes stay touch-safe")
 var later:=Button.new();later.add_theme_stylebox_override("normal",normal);later.add_theme_stylebox_override("hover",hover);current_scene.add_child(later);await wait_frame()
 check(later.get_theme_stylebox("hover")==normal,"new popup controls also suppress touch hover")
 button.grab_focus();touch.pressed=false;guard._input(touch);await wait_frame()
 check(not button.has_focus(),"touch release clears persistent focus highlight")
 var nav: Node=current_scene.find_child("HubNav",true,false)
 nav._on_tab_hover(0,true);check(nav.hovered_tab==-1,"custom hub icon hover suppressed on touch")
 # Scene changes during incremental construction safely invalidate the old build.
 presenter=current_scene.get_node("TrialsProductionPresenter");presenter._switch_section("achievement")
 change_scene_to_file("res://scenes/ui/cultivation_menu.tscn");await wait_frame(8)
 current_scene.meridian_map._on_hover_changed("vitality",true)
 check(current_scene.meridian_map.hovered_path=="","custom meridian hover also suppressed")
 var warm: Node=root.get_node("MenuResourcePrewarm")
 check("res://scenes/ui/daily_quest_screen.tscn" in warm.FAST_NAV_SCENES and "res://scenes/ui/achievement_screen.tscn" in warm.FAST_NAV_SCENES,"both Trials entry scenes participate in background prewarm")
 for cycle: int in range(5):
  change_scene_to_file("res://scenes/ui/achievement_screen.tscn");await wait_frame(4)
  var old_presenter: Node=current_scene.get_node("TrialsProductionPresenter")
  current_scene.remove_child(old_presenter)
  old_presenter._refresh()
  check(not old_presenter.is_inside_tree(),"detached record builder exits safely "+str(cycle))
  old_presenter.queue_free()
  change_scene_to_file("res://scenes/ui/daily_quest_screen.tscn");await wait_frame(4)
 print("MENU_PERF_TOUCH_CHECKS=",checks,";FAILURES=",failures);quit(1 if failures else 0)
