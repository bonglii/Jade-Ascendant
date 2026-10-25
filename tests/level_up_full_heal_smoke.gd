extends SceneTree
var checks: int=0
var failures: int=0
var levels: Array[Dictionary]=[]
var health_events: Array[Vector2]=[]
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("LEVEL_UP_FULL_HEAL "+message)
func frames(count: int=6) -> void:
 for frame: int in count:await process_frame
func _initialize() -> void:run.call_deferred()
func finish(marker: String) -> void:
 paused=false
 current_scene.queue_free();current_scene=null
 await frames(8)
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print(marker+" checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_level_heal_qa"):quit(2);return
 create_timer(60).timeout.connect(func():push_error("LEVEL_HEAL_TIMEOUT");quit(1))
 await frames()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 var resume: bool="--resume" in OS.get_cmdline_user_args()
 if resume:root.get_node("GameSession").continue_saved_game()
 else:
  root.get_node("GameSession").start_new_game();root.get_node("JourneyManager").begin_selected_stage()
 change_scene_to_file("res://scenes/levels/level_1.tscn");await frames(22)
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
 var spawner: Node=current_scene.get_node("EnemySpawner");spawner.set_process(false);spawner.clear_normal_enemies()
 current_scene.get_node("WaveManager").set_process(false)
 var actor: Node=current_scene.get_node("player_1");actor.set_physics_process(false);actor.get_node("WeaponManager").set_process(false)
 var health: Node=actor.get_node("PlayerHealth")
 var ledger: Node=actor.get_node("WeaponManager/RunCombatLedger")
 var panel: Control=current_scene.get_node("HUD").level_up_panel
 var checkpoint: Node=current_scene.get_node("CheckPointManager")
 health.health_changed.connect(func(hp: float,maximum: float):health_events.append(Vector2(hp,maximum)))
 actor.level_changed.connect(func(value: int):levels.append({"level":value,"hp":health.current_health,"maximum":health.max_health}))
 if resume:
  check(actor.level==5 and is_equal_approx(health.max_health,105) and is_equal_approx(health.current_health,98),"new process Continue keeps wounded saved HP; restore is not a level-up")
  check(ledger.hp_hits==3 and is_equal_approx(ledger.hp_loss,47),"restart keeps actual hit history despite earlier full heals")
  var old_level: int=actor.level
  health.hit_guard_remaining=0;health.take_damage(10000);await frames(3)
  check(health.is_dead and health.current_health==0,"real lethal damage")
  actor.add_experience(actor.experience_to_next_level)
  check(health.is_dead and health.current_health==0 and actor.level==old_level and not panel.visible,"late EXP cannot revive or open choices after death")
  await finish("LEVEL_UP_FULL_HEAL_RESTART");return
 check(root.get_node("EquipmentManager").get_secondary_bonus("level_up_heal_flat",4)==0,"fresh build has no equipment healing requirement")
 health.take_damage(20)
 actor.add_experience(9)
 check(actor.level==1 and is_equal_approx(health.current_health,80),"EXP below threshold does not heal")
 actor.add_experience(1)
 check(actor.level==2 and health.current_health==health.max_health and paused and panel.visible,"actual EXP level-up fully heals before skill choice")
 check(levels.size()==1 and levels[0].hp==levels[0].maximum,"level observers see restored HP")
 check(health_events.back()==Vector2(100,100),"HUD receives normal full-HP health signal")
 check(ledger.hp_hits==1 and is_equal_approx(ledger.hp_loss,20),"healing never erases damage or grants no-hit credit")
 var options: Array=panel.current_upgrades.duplicate()
 var events_before: int=health_events.size()
 actor.add_experience(26)
 check(actor.level==2 and actor.experience==26 and panel.current_upgrades==options and health_events.size()==events_before,"same-frame surplus EXP neither replaces choice nor heals again")
 panel.close_level_up();await frames(3)
 check(actor.level==3 and actor.experience==14 and health.current_health==health.max_health and panel.visible,"first pending level resolves after one choice")
 panel.close_level_up();await frames(3)
 check(actor.level==4 and actor.experience==0 and health.current_health==health.max_health and panel.visible,"second pending level also fully heals")
 check(levels.size()==3,"exactly one signal per earned level")
 panel.close_level_up();await frames(3)
 check(not panel.visible and not paused,"queue ends normally without another level")
 health.hit_guard_remaining=0;health.take_damage(20)
 actor.add_experience(0)
 check(health.current_health==80,"no heal for zero EXP or a normal frame")
 health.upgrade_body_refinement()
 check(health.max_health==105 and health.current_health==85,"Body Refinement keeps its existing HP increase, not a fake run level")
 actor.add_experience(actor.experience_to_next_level)
 check(actor.level==5 and health.current_health==105 and health.current_health==health.max_health,"full heal uses current maximum after HP upgrades")
 check(panel.find_child("Subtitle",true,false).text.contains("HP"),"existing congratulations explains recovery without a new popup")
 panel.close_level_up();await frames(3)
 health.hit_guard_remaining=0;health.take_damage(7)
 check(health.current_health==98 and ledger.hp_hits==3 and is_equal_approx(ledger.hp_loss,47),"post-heal damage uses correct ledger baseline")
 check(checkpoint.save_checkpoint(),"wounded state saved through production checkpoint")
 health.heal(health.max_health)
 check(checkpoint.load_checkpoint() and health.current_health==98 and actor.level==5,"same-process checkpoint restore preserves wounded HP")
 check(ledger.hp_hits==3 and is_equal_approx(ledger.hp_loss,47),"checkpoint restore does not invent an extra hit")
 # Every normal build gets the recovery row; gear descriptions no longer imply
 # full recovery requires the old small item-only bonus.
 change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(18)
 current_scene._open_profile_sheet();await frames(8)
 var copy: String=""
 for label: Label in current_scene.find_children("*","Label",true,false):copy+=label.text+"\n"
 check(copy.contains("FULL HP") or copy.contains("HP PENUH"),"profile shows universal full recovery without special equipment")
 await finish("LEVEL_UP_FULL_HEAL")
