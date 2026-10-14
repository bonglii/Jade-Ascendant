extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("BOSS_AUTOFIRE_FAIL "+label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_boss_refinement_qa"):quit(2);return
 change_scene_to_file("res://scenes/levels/level_1.tscn")
 await create_timer(.3).timeout
 current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
 var player: Node2D=current_scene.get_node("player_1")
 player.set_physics_process(false)
 var origin: Vector2=player.position
 var manager: Node=player.get_node("WeaponManager")
 manager.set_process(false)
 for realm: int in [1,5]:
  for existing: Node in get_nodes_in_group("enemy"):existing.free()
  var boss: Node2D=load("res://scenes/enemy/boss_1.tscn").instantiate()
  if realm==5:boss.set_script(load("res://scripts/enemy/realm_boss.gd"))
  var catalog: Script=load("res://scripts/data/chapter_one_catalog.gd" if realm==1 else "res://scripts/data/chapter_five_catalog.gd")
  boss.configure_encounter(catalog.STAGES[1]);current_scene.add_child(boss);boss.set_physics_process(false)
  boss.position=player.position+Vector2(265,0)
  boss.attack_timer=1000;boss.ranged_attack_timer=1000;boss.shockwave_timer=1000
  for weapon: Node in manager.attack_timers:manager.attack_timers[weapon]=0.0
  manager._cached_target=null;manager._target_refresh_remaining=0
  var before: int=manager._fired_attacks
  manager._process(.016)
  check(manager._fired_attacks==before,"outside range does not invent attacks")
  boss.set_physics_process(true);await create_timer(1.5).timeout;boss.set_physics_process(false)
  manager._target_refresh_remaining=0;manager._process(.016)
  check(manager._fired_attacks==before+1,"stationary player auto-fires after boss closes gap realm"+str(realm))
  check(player.position==origin,"no player movement needed")
  check(boss.position.distance_to(player.position)<230,"same production boss range")
  check(boss.visual_action_timer<=0,"pressure occurs between casts")
  boss.free()
 print("BOSS_AUTOFIRE_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
