extends SceneTree

var checks: int=0
var failures: int=0
var activations: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("HOME_SANCTUARY_FAIL "+message)
func frames(count: int=5) -> void:
 for i: int in range(count):await process_frame
func activated() -> void:activations+=1
func within(inner: Rect2, outer: Rect2) -> bool:
 return inner.position.x>=outer.position.x-1 and inner.position.y>=outer.position.y-1 and inner.end.x<=outer.end.x+1 and inner.end.y<=outer.end.y+1
func destination(path: String) -> bool:
 for i: int in range(200):
  if current_scene!=null and current_scene.scene_file_path==path and not root.get_node("SceneTransitionManager").is_transitioning:return true
  await create_timer(.02).timeout
 return false
func run() -> void:
 create_timer(90).timeout.connect(func():push_error("HOME_TEST_WATCHDOG");quit(3))
 if not OS.get_user_data_dir().contains("jade_home_sanctuary_qa"):quit(2);return
 await create_timer(.5).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var config:=ConfigFile.new();config.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]:config.set_value("tutorials",key,true)
 config.save("user://jade_onboarding.cfg")
 var guide: Node=root.get_node("RefineOnboarding");guide.completed=true;guide.set_process(false)
 var prewarm: Node=root.get_node_or_null("MenuResourcePrewarm")
 if prewarm!=null:prewarm.queue_free()
 var save: Node=root.get_node("SaveManager")
 var journey: Node=root.get_node("JourneyManager")
 var progress: Node=root.get_node("ProgressionManager")
 var pavilion: Node=root.get_node("PavilionManager")
 var inventory: Node=root.get_node("InventoryManager")
 var live: Node=root.get_node("LiveOpsManager")
 journey.selected_chapter_id=1;journey.cleared_stage_keys=[journey.get_stage_key(1,1),journey.get_stage_key(1,3)]
 var economy: Array=[progress.spirit_stone,pavilion.get_celestial_jade(),inventory.item_counts.duplicate(true)]
 var checkpoint: Dictionary={"version":1,"chapter_id":1,"stage_id":2,"survival_time":45.0,"wave":2,"wave_timer":3.0,"difficulty_level":1,"player_level":2,"experience":5,"experience_to_next_level":10}
 check(save.write_save_data("checkpoint",checkpoint).success,"isolated real checkpoint fixture")
 var checkpoint_before: Dictionary=save.read_save_data("checkpoint").data.duplicate(true)
 var started: int=Time.get_ticks_msec()
 change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(15)
 print("HOME_SANCTUARY_FIXTURE_READY_MS=",Time.get_ticks_msec()-started)
 var home: Node=current_scene
 var presenter: Node=home.get_node("HomeUI/HomeProductionOverlay")
 check(presenter.continue_button.visible,"validated checkpoint exposes Continue")
 check(presenter.next_path_label.text.contains("1-2"),"non-contiguous clears use first missing stage")
 check(presenter.realm_progress.value==2,"actual clear count")
 check(presenter.profile_exp.value==progress.get_hero_progress_ratio(),"actual hero progress")
 check(presenter.profile_name.text==root.get_node("PlayerIdentityManager").get_profile_snapshot().display_name,"actual player name")
 check(presenter.boss_progress.text.begins_with(str(live.get_boss_hunt_unlocked_count())),"actual boss event progress")
 check(not presenter.boss_reward.text.contains("JADE"),"does not invent sample preview reward")
 check(home.get_node("KeyArt").texture.resource_path.contains("sanctuary/motion/lin_yue_poster"),"approved local motion poster installed")
 var count: int=presenter.get_child_count()
 var font: int=presenter.profile_name.get_theme_font_size("font_size")
 await create_timer(.7).timeout
 check(presenter.get_child_count()==count,"periodic refresh does not rebuild page")
 check(presenter.profile_name.get_theme_font_size("font_size")==font,"no first-open font pop")
 var manager: Node=root.get_node("HubResourceBarManager")
 manager._refresh_scene_binding();manager._sync_values();await frames()
 var bar: Control=home.find_child("SharedHubResourceBar",true,false)
 check(bar.get_node("ResourceRow").get_child_count()==3,"wallet preserves reward flight indices")
 check(root.get_node("RewardDeliveryPresenter")._wallet_cell("celestial_jade")==bar.get_node("ResourceRow").get_child(1),"flight target still maps to jade")
 for viewport: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(720,1600),Vector2i(896,504)]:
  root.size=viewport;await frames(10)
  var screen:=Rect2(Vector2.ZERO,Vector2(viewport))
  for node: Control in [presenter.profile_shortcut,presenter.mailbox_button,presenter.settings_shortcut,presenter.lower_scroll,home.get_node("HomeUI/HubNav"),bar]:
   check(within(node.get_global_rect(),screen),"screen bounds "+str(viewport)+" "+str(node.name))
  for button: Button in [presenter.journey_button,presenter.continue_button,presenter.settings_shortcut,presenter.mailbox_button]:
   var frame: Control=button.get_node("SanctuaryFrame")
   check(within(frame.get_global_rect(),button.get_global_rect()),"scaled frame fits "+str(viewport)+" "+str(button.name))
   check(frame.show_behind_parent and button.get_node("SanctuaryGlass").show_behind_parent,"decorations cannot cover native button text")
   check(button.size.y>=42,"tap target height "+str(button.name))
  for label: Control in [presenter.profile_name,presenter.profile_rank,presenter.profile_status,presenter.profile_exp]:
   check(within(label.get_rect(),Rect2(Vector2.ZERO,presenter.profile_shortcut.size)),"profile content bounds "+str(viewport))
  check(presenter.journey_button.get_rect().end.x<=presenter.journey_card.size.x+1,"CTA does not expand past journey card "+str(viewport))
  for index: int in range(3):
   var cell: Control=bar.get_node("ResourceRow").get_child(index)
   var button: Control=bar.get_node("WalletSource%d"%index)
   if not button.size.is_equal_approx(cell.size):print("WALLET_RECT ",viewport," ",button.get_rect()," cell=",cell.get_rect())
   check(button.size.is_equal_approx(cell.size) and button.position.is_equal_approx(bar.get_node("ResourceRow").position+cell.position),"wallet hitboxes settle after layout "+str(viewport))
  presenter.lower_scroll.scroll_vertical=10000;await frames()
  if viewport.y<=568:check(presenter.lower_scroll.scroll_vertical>0,"short screen content actually scrolls")
  presenter.lower_scroll.scroll_vertical=0;await frames()
  presenter._capture_press(presenter.event_button)
  var drag:=InputEventScreenDrag.new();drag.relative=Vector2(18,0)
  presenter._track_gesture(drag,presenter.event_button)
  presenter._activate(Callable(self,"activated"),presenter.event_button)
  check(activations==0,"swipe ending at origin cannot activate event")
  presenter._capture_press(presenter.event_button)
  var previous: int=activations
  presenter._activate(Callable(self,"activated"),presenter.event_button)
  check(activations==previous+1,"stationary release still activates")
  activations=0
 root.size=Vector2i(648,1152);await frames()
 presenter._open_profile();await frames()
 check(home.profile_overlay!=null and home.profile_overlay.visible,"existing interactive profile opens")
 home._close_profile_sheet();await frames()
 for scene: String in [presenter.MAILBOX_SCENE,presenter.SEVEN_DAY_SCENE,presenter.EVENT_CENTER_SCENE,presenter.BOSS_SCENE]:
  presenter._open_live_popup(scene);await frames(8)
  check(live._active_live_popup!=null and live._active_live_popup.scene_file_path==scene,"native popup opens "+scene)
  live.close_live_popup();await frames(8)
  check(live._active_live_popup==null and current_scene==home,"popup close preserves Home")
 presenter._open_spirit_meditation();await frames(8)
 var meditation: Node=root.get_node("IdleCultivationManager/IdleCultivationPresenter")
 check(meditation._popup!=null,"premium meditation keeps existing presenter")
 meditation._close_popup();await frames(8)
 check(save.read_save_data("checkpoint").data==checkpoint_before,"Home and popups do not rewrite checkpoint")
 check([progress.spirit_stone,pavilion.get_celestial_jade(),inventory.item_counts]==economy,"presentation does not mint or consume currency")
 checkpoint.defeat_pending=true;check(save.write_save_data("checkpoint",checkpoint).success,"mark checkpoint unresumable")
 await frames(8);check(not presenter.continue_button.visible,"save signal refreshes invalid Continue immediately")
 var transition: Node=root.get_node("SceneTransitionManager")
 transition.is_transitioning=true;presenter._capture_press(presenter.journey_button)
 presenter._activate(Callable(self,"activated"),presenter.journey_button)
 check(activations==0,"transition blocks repeated activation");transition.is_transitioning=false
 check(manager._format_count(1234567890)=="1.2B","huge Home balances stay readable")
 var routes: Array=[
  ["res://scenes/ui/chapter_select.tscn","_call_main_menu",["_on_journey_pressed"]],
  ["res://scenes/ui/skill_book_screen.tscn","_open_menu_scene",[presenter.LIBRARY_SCENE]],
  ["res://scenes/ui/daily_quest_screen.tscn","open_currency_sources",[0]],
  ["res://scenes/ui/pavilion_screen.tscn","open_currency_sources",[2]]
 ]
 for route: Array in routes:
  # Rebind to the current scene, since previous Home ownership has ended.
  var method: String=route[1];var arguments: Array=route[2]
  var old_home_id: int=current_scene.get_instance_id()
  presenter.callv(method,arguments)
  check(await destination(route[0]),"actual navigation reaches "+str(route[0]))
  manager._on_sanctuary_currency_source(old_home_id,2)
  check(current_scene.scene_file_path==route[0],"stale Home wallet cannot redirect new page")
  root.get_node("SceneTransitionManager").transition_menu_to("res://scenes/ui/main_menu.tscn",1)
  check(await destination("res://scenes/ui/main_menu.tscn"),"return to Home")
  await frames(8);presenter=current_scene.get_node("HomeUI/HomeProductionOverlay")
  check(not presenter.continue_button.visible,"invalid checkpoint remains hidden across navigation")
  check(presenter.get_child_count()==count,"reentry does not accumulate page nodes")
  root.size=Vector2i(390,844);await frames();root.size=Vector2i(648,1152);await frames()
 check(save.read_save_data("checkpoint").data.defeat_pending,"navigation preserves saved run status")

 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);current_scene.queue_free();await frames(8)
 root.size=Vector2i(320,568);await frames(3)
 root.size=Vector2i(648,1152);await frames(3)
 check(not is_instance_valid(root.get_node("HubResourceBarManager")._resource_bar),"leaving Home releases wallet and viewport callbacks")
 print("HOME_SANCTUARY_SMOKE checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
