extends SceneTree
const Goals=preload("res://scripts/data/player_goal_catalog.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("HOME_BOSS_FLOW "+why)
func frames(n: int=8) -> void:
 for i: int in n:await process_frame
func tap(at: Vector2) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=at;e.pressed=true;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true);await frames(1)
 e.pressed=false;e.button_mask=0;root.push_input(e,true);await frames(8)
func capture(name_value: String) -> void:
 if DisplayServer.get_name()=="headless" or OS.get_environment("JADE_HOME_BOSS_CAPTURE").is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("JADE_HOME_BOSS_CAPTURE")+"/"+name_value+".png")
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 create_timer(75).timeout.connect(func():push_error("HOME_BOSS_FLOW_TIMEOUT");quit(1))
 await frames(12);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var context: Dictionary={"daily_ready":5,"achievement_ready":3,"event_ready":2,"stages":[{"chapter":1,"stage":3,"implemented":true,"unlocked":true,"cleared":false}]}
 check(Goals.choose(context).action=="trials","recommendation reader retains earned claim guidance")
 check(Goals.choose_progression(context).action=="journey","claims never replace chapter navigation")
 context.checkpoint=true;check(Goals.choose_progression(context).action=="continue","valid saved run keeps primary Continue")
 context.read_only=true;check(Goals.choose_progression(context).action=="recovery","save recovery remains protected")
 var config:=ConfigFile.new();config.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]:config.set_value("tutorials",key,true)
 config.save("user://jade_onboarding.cfg")
 root.get_node("RefineOnboarding").completed=true
 var journey: Node=root.get_node("JourneyManager");journey.selected_chapter_id=1;journey.selected_stage_id=3;journey.unlocked_stage_keys=["1-1","1-2","1-3"];journey.cleared_stage_keys=["1-1","1-2"]
 var daily: Node=root.get_node("DailyQuestManager")
 for id: String in daily.get_daily_quest_ids():daily.set_progress_at_least(id,daily.get_target(id))
 var claimed: Array=daily.claimed_quest_ids.duplicate();var stones: int=root.get_node("ProgressionManager").spirit_stone
 root.size=Vector2i(720,1600);change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(25)
 var home: Node=current_scene;var p: Node=home.get_node("HomeUI/HomeProductionOverlay")
 check(daily.get_claimable_count()>0 and p._goal.action=="journey","actual claim-ready managers do not hijack Home")
 check(p.chapter_label.text.contains("01") and not p.realm_title.text.contains("REWARDS"),"chapter identity stays stable")
 for language: String in ["en","id"]:
  root.get_node("SettingsManager").language=language
  for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(720,1600)]:
   root.size=dims;await frames(12)
   p.set_process(false);p.event_action.text=tr("CLAIM REWARD")+" ›";p._layout_sanctuary();await frames(4)
   var area: Rect2=Rect2(Vector2.ZERO,p.event_card.size).grow(-maxf(14,18*p.portrait_unit))
   for label: Control in [p.event_card.get_node("EventKind"),p.boss_progress,p.boss_reward,p.event_action]:check(area.encloses(label.get_rect()),"event row inside frame "+label.name+language+str(dims))
   check(not p.boss_reward.get_rect().intersects(p.event_action.get_rect()),"event reward/CTA do not overlap")
   if dims.x==720 and language=="en":await capture("home-claims-still-journey")
 p.lower_scroll.ensure_control_visible(p.journey_button);await frames()
 await tap(p.journey_button.get_global_rect().get_center())
 for i: int in 120:
  await frames(1)
  if current_scene!=home:break
 check(current_scene!=home and current_scene.scene_file_path.contains("chapter_select"),"real Journey tap opens chapters without claiming")
 check(daily.claimed_quest_ids==claimed and root.get_node("ProgressionManager").spirit_stone==stones,"chapter tap neither consumes nor grants rewards")
 journey.select_stage(1,3);var level_path: String=journey.begin_selected_stage();root.get_node("GameSession").start_new_game();change_scene_to_file(level_path);await frames(25)
 var tutorial: Node=current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay");tutorial._on_skip_pressed();paused=false
 var spawner: Node=current_scene.get_node("EnemySpawner");spawner.set_process(false);current_scene.get_node("WaveManager").set_process(false)
 current_scene.get_node("player_1").set_physics_process(false)
 var hud: Node=current_scene.get_node("HUD");var polish: Node=current_scene.find_child("HUDCombatPolish",true,false)
 if polish==null:check(false,"production warning presenter loads");quit(1);return
 for dims: Vector2i in [Vector2i(320,568),Vector2i(720,1600)]:
  root.size=dims;await frames(12)
  for reduced: bool in [false,true]:
   root.get_node("SettingsManager").reduced_effects=reduced
   polish._show_boss_warning();await frames(8)
   check(polish._warning_panel.get_node("BossCrest").portrait!=null,"warning reuses actual boss2D portrait")
   check(polish._warning_panel.size.y<190,"compact warning ribbon")
   hud._on_pause_pressed();await frames(2)
   var before: float=polish._warning_tween.get_total_elapsed_time();await create_timer(.2).timeout
   check(paused and hud.pause_overlay.visible and hud.pause_overlay.z_index>polish._warning_panel.z_index,"pause above pre-warning")
   check(absf(polish._warning_tween.get_total_elapsed_time()-before)<.04,"pre-warning reading time freezes during pause")
   await tap(hud.resume_button.get_global_rect().get_center());check(not paused,"real Resume tap works with warning visible")
   polish._warning_tween.kill();polish._hide_boss_warning()
   if get_nodes_in_group("boss").is_empty():spawner.spawn_boss();await frames(15)
   else:
    hud.boss_panel.visible=true
    hud._show_encounter_banner("PHASE 1",Color.GOLD)
    polish._extend_boss_arrival_banner(get_nodes_in_group("boss")[0].get_instance_id())
    await frames(5)
   for enemy: Node in get_nodes_in_group("enemy"):enemy.process_mode=Node.PROCESS_MODE_DISABLED
   var banner: Control=hud._encounter_banner
   check(banner.visible and banner.get_node("BossCrest").portrait!=null,"arrival has production boss portrait")
   check(banner.get_rect().end.x<=banner.get_parent().size.x+1,"arrival fits actual safe area")
   hud._on_pause_pressed();await frames(2)
   before=hud._encounter_banner_tween.get_total_elapsed_time();await create_timer(.2).timeout
   check(hud.pause_overlay.z_index>banner.z_index and absf(hud._encounter_banner_tween.get_total_elapsed_time()-before)<.04,"arrival stays behind pause and preserves reading time")
   if dims.x==720 and not reduced:await capture("boss-arrival-paused")
   await tap(hud.resume_button.get_global_rect().get_center());check(not paused,"arrival cannot intercept Resume")
   if not reduced:await capture("boss-arrival-ribbon" if dims.x==720 else "boss-arrival-small")
   hud._encounter_banner_tween.kill();hud._hide_encounter_banner();hud.boss_panel.visible=false
 paused=false
 if current_scene!=null:current_scene.queue_free();current_scene=null
 await frames(6)
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("HOME_BOSS_FLOW checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
