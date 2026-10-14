extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("ELITE_PACING_FAIL "+label)
func _initialize() -> void:run.call_deferred()
func settle() -> void:
 await process_frame
 await process_frame
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_pacing_qa"):quit(2);return
 await process_frame
 var journey: Node=root.get_node("JourneyManager")
 for chapter: int in journey.get_chapter_ids():
  for stage: int in journey.get_stage_ids(chapter):
   var data: Dictionary=journey.get_stage_data(chapter,stage)
   var schedule: Dictionary=data.elite_schedule
   var waves: Array=schedule.keys();waves.sort()
   var expected: Array={2:[4,8],3:[3,6,8],4:[2,4,6,8]}[waves.size()]
   check(waves==expected,"authored slots "+str(chapter)+"-"+str(stage))
   check(not schedule.has(9) and waves[-1]==8,"last elite gets two waves "+str(chapter)+"-"+str(stage))
   for value: int in schedule.values():check(value in [1,2],"existing elite type")
 root.get_node("GameSession").start_new_game()
 check(change_scene_to_file("res://scenes/levels/level_1.tscn")==OK,"real scene")
 await create_timer(.3).timeout
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
 var owner: Node=current_scene.get_node("EnemySpawner")
 var wave: Node=current_scene.get_node("WaveManager")
 owner.set_process(false);wave.set_process(false)
 current_scene.get_node("player_1").set_physics_process(false)
 current_scene.get_node("player_1/WeaponManager").set_process(false)
 owner.clear_normal_enemies();await settle()
 wave.current_wave=4;owner.try_spawn_elite_for_current_wave()
 check(owner.has_active_scheduled_elite() and owner.elite_spawned_waves.has(4),"real first slot")
 var first: Node
 for enemy: Node in get_nodes_in_group("enemy"):
  if enemy.has_meta("qi_magnet_wave"):first=enemy
 first.set_physics_process(false)
 wave.current_wave=8
 for i: int in range(12):owner.try_spawn_elite_for_current_wave()
 check(not owner.elite_spawned_waves.has(8),"blocked slot does not consume marker")
 check(get_nodes_in_group("enemy").size()==1,"retries never stack")
 first.die();owner.try_spawn_elite_for_current_wave();await settle()
 check(owner.elite_spawned_waves.has(8) and owner.has_active_scheduled_elite(),"death unlocks pending slot same wave")
 var second: Node
 for enemy: Node in get_nodes_in_group("enemy"):
  if enemy.has_meta("qi_magnet_wave"):second=enemy
 second.set_physics_process(false)
 for i: int in range(12):owner.try_spawn_elite_for_current_wave()
 check(get_nodes_in_group("enemy").size()==1,"one spawn per slot")
 # No deferred slot spills into wave9 or changes the wave timer.
 owner.elite_spawned_waves.clear();wave.current_wave=8
 owner.try_spawn_elite_for_current_wave()
 var timer: float=wave.wave_timer
 wave.current_wave=9;second.die();owner.try_spawn_elite_for_current_wave();await settle()
 check(not owner.elite_spawned_waves.has(8) and not owner.has_active_scheduled_elite(),"missed window does not spill")
 check(wave.wave_timer==timer,"elite waits never alter clock")
 owner.elite_spawned_waves.clear();wave.current_wave=4;owner.try_spawn_elite_for_current_wave()
 var first_timer: float=wave.wave_timer
 wave.current_wave=10;owner._process(.016);await settle()
 check(owner.boss_spawned and not owner.has_active_scheduled_elite(),"final wave clears surviving elite and spawns boss")
 check(wave.wave_timer==first_timer,"boss not delayed by elite")
 # Old5/9 and4/7 awards survive the new4/8 schedule; no free extra drops.
 var anchor:=Node2D.new();current_scene.add_child(anchor)
 owner.restore_qi_magnet_state({"awarded_waves":[5,9],"pending":[{"x":1000,"y":1200},{"x":1300,"y":1400}]})
 await settle()
 check(owner.qi_magnet_awarded_waves.has(5) and owner.qi_magnet_awarded_waves.has(9),"old schedule ledger preserved")
 check(get_nodes_in_group("qi_magnet").size()==2,"old pending pickups survive")
 owner._on_qi_magnet_elite_defeated(anchor,4);owner._on_qi_magnet_elite_defeated(anchor,8);await settle()
 check(get_nodes_in_group("qi_magnet").size()==2 and owner.qi_magnet_awarded_waves.size()==2,"old completed ledger blocks new schedule bonus")
 owner.restore_qi_magnet_state({"awarded_waves":[5],"pending":[{"x":1500,"y":1600}]})
 owner._on_qi_magnet_elite_defeated(anchor,8);await settle()
 check(owner.qi_magnet_awarded_waves.size()==2 and get_nodes_in_group("qi_magnet").size()==2,"one old award plus remaining new milestone")
 owner.restore_qi_magnet_state({"awarded_waves":[4.5,-1,99,INF,NAN,5,5,9,8],"pending":[{"x":1100,"y":1100},{"x":1200,"y":1200},{"x":1300,"y":1300}]})
 await settle()
 check(owner.qi_magnet_awarded_waves.size()==2 and get_nodes_in_group("qi_magnet").size()==2,"invalid waves duplicates and over-cap rejected")
 print("ELITE_PACING_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
