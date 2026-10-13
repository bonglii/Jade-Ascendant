extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("NOTICE_FAILURE "+label)
func settle() -> void:await create_timer(.2).timeout
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_hero_qa"):quit(2);return
 await create_timer(.5).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 change_scene_to_file("res://scenes/ui/cultivation_menu.tscn");await settle();await settle()
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(720,1600)]:
  root.size=dims;await settle()
  var kicker: Label=current_scene.mastery_value.get_parent().get_child(0)
  check(kicker.size.x>100,"foundation kicker has reserved width "+str(dims))
  check(kicker.get_line_count()<=2,"foundation no per-character wrapping "+str(dims))
 var journey: Node=root.get_node("JourneyManager")
 var key: String=journey.get_stage_key(1,2)
 if key not in journey.unlocked_stage_keys:journey.unlocked_stage_keys.append(key)
 journey.select_stage(1,2)
 var path: String=journey.begin_selected_stage();root.get_node("GameSession").start_new_game()
 change_scene_to_file(path);await settle();await settle()
 var hud: Node=current_scene.get_node("HUD")
 var safe: Control=hud.get_node("ScreenRoot/HUDSafeArea")
 var polish: Node=current_scene.find_child("HUDCombatPolish",true,false)
 check(polish!=null,"actual stage has warning extension")
 current_scene.get_node("EnemySpawner").set_process(false);current_scene.get_node("WaveManager").set_process(false)
 var presenter: Node=root.get_node("AchievementManager/AchievementUnlockPresenter")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(720,1600)]:
  root.size=dims;await settle()
  for reduced: bool in [false,true]:
   root.get_node("SettingsManager").reduced_effects=reduced
   polish._show_boss_warning();await settle()
   var warning: Control=polish._warning_panel
   check(warning.get_rect().position.x>0,"warning has horizontal margin")
   check(absf(warning.get_rect().get_center().x-safe.size.x*.5)<2,"warning stays centered through reveal")
   check(warning.position.y>=safe.get_node("TopHUD").get_rect().end.y,"warning below top HUD")
   check(warning.get_rect().end.x<=safe.size.x+1,"warning fits phone width")
   check(polish._warning_main.get_global_rect().intersects(polish._warning_stage_chip.get_global_rect())==false,"stage chip no longer covers title")
   check(not polish._warning_stage_label.text.contains("TRIAL 0"),"stage identity has actual chapter")
   polish._hide_boss_warning()
   if polish._warning_tween!=null:polish._warning_tween.kill()
   hud.boss_panel.visible=true;hud.boss_name_label.text="MISTBLADE WARDEN"
   hud._show_encounter_banner("PHASE 1",Color.GOLD);await settle()
   var banner: Control=hud._encounter_banner
   check(absf(banner.get_rect().get_center().x-safe.size.x*.5)<2,"phase notice stays centered")
   check(banner.position.y>=hud.boss_panel.get_rect().end.y,"phase notice below boss HP")
   check(banner.get_rect().end.x<=safe.size.x+1,"phase notice fits phone")
   hud._hide_encounter_banner();hud._encounter_banner_tween.kill();hud.boss_panel.visible=false
 # Real boss-spawn signal and polish override must retain the same safe geometry.
 root.size=Vector2i(648,1152);await settle()
 current_scene.get_node("EnemySpawner").spawn_boss();await settle();await settle()
 check(hud._encounter_banner.visible and hud._encounter_banner.position.y>=hud.boss_panel.get_rect().end.y,"actual boss arrival is beneath boss HP")
 check(hud._encounter_banner.find_child("RealmTag",true,false)!=null,"arrival has ornate stage identity")
 for enemy: Node in get_nodes_in_group("enemy"):enemy.process_mode=Node.PROCESS_MODE_DISABLED
 var boss: Node=current_scene.get_node("EnemySpawner").current_boss if current_scene.get_node("EnemySpawner").get("current_boss")!=null else null
 if boss!=null:boss.process_mode=Node.PROCESS_MODE_DISABLED
 for reduced: bool in [false,true]:
  root.get_node("SettingsManager").reduced_effects=reduced
  hud._show_encounter_banner("PHASE 2",Color.GOLD)
  presenter._on_achievement_unlocked("first_boss_defeat");await settle()
  check(not presenter._active and presenter._pending_ids.size()==1,"achievement queues behind boss warning")
  await create_timer(1).timeout
  check(hud._encounter_banner.modulate.a>.9,"phase notice holds full opacity beyond reveal in both modes")
  hud._encounter_banner_tween.kill();hud._hide_encounter_banner();await settle()
  check(presenter._active,"queued achievement begins after warning")
  await create_timer(3).timeout
  check(presenter._active and presenter._panel.modulate.a>.9,"achievement holds full opacity beyond old lifetime in both modes")
  hud._show_encounter_banner("PHASE 2",Color.GOLD);await settle()
  check(presenter._active and not presenter._panel.visible,"active achievement yields to newly arriving boss notice")
  await create_timer(1).timeout
  hud._encounter_banner_tween.kill();hud._hide_encounter_banner();await settle()
  check(presenter._active and presenter._panel.visible and presenter._panel.modulate.a>.9,"achievement resumes with reading time preserved")
  await create_timer(2.5).timeout
  check(not presenter._active,"achievement completes after five-second reading time")
 # Toast fits long copy on the small phone, without changing reward state.
 root.size=Vector2i(320,568);await settle()
 var before: Dictionary=root.get_node("ProgressionManager").build_progression_save_data().duplicate(true)
 presenter._build_toast(safe,{"title":"A Very Long Eternal Record Title","description":"Defeat the guardian and complete the cultivation milestone to receive a permanent reward.","category":"boss"});await settle()
 check(presenter._panel.get_rect().end.x<=safe.size.x+1,"long achievement fits narrow phone")
 check(presenter._panel.get_rect().end.y<=safe.size.y+1,"bounded achievement copy fits phone height")
 check(root.get_node("ProgressionManager").build_progression_save_data()==before,"notice never claims or spends rewards")
 presenter._abort_sequence()
 print("COMBAT_NOTICE_CHECKS=",checks,";FAILURES=",failures);quit(1 if failures else 0)
