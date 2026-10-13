extends SceneTree
var checks: int=0
var failures: int=0
var m: Node
var progress: Node
var journey: Node
var saver: Node
class Target:
 extends Node2D
 var received: float=0
 func take_damage(amount: float) -> void:received+=amount
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("MASTERY_FAILURE "+label)
func settle() -> void:await create_timer(.18).timeout
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_hero_qa"):quit(2);return
 await create_timer(.5).timeout
 m=root.get_node("CultivationMasteryManager");progress=root.get_node("ProgressionManager");journey=root.get_node("JourneyManager");saver=root.get_node("SaveManager")
 if "--restart" in OS.get_cmdline_user_args():
  var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://mastery_expect.json"))
  check(m.ready_state and m.state.realm==1,"restart preserves Golden Core")
  check(m.state.choices==expected.choices and int(m.state.clears)==int(expected.clears),"restart preserves choices and one-time realm result")
  print("CULTIVATION_MASTERY_RESTART_CHECKS=",checks,";FAILURES=",failures);quit(1 if failures else 0);return
 check(m.ready_state and m.state.realm==0,"old player gets safe empty mastery domain")
 check(not m.choose("vitality","ward",""),"mastery locked before path Lv10")
 for path: String in ["vitality","sword_power","swift_qi"]:progress.set(path+"_level",10)
 var unchanged: Dictionary=progress.build_progression_save_data().duplicate(true)
 check(m.choose("vitality","ward","") and m.choose("sword_power","focus","") and m.choose("swift_qi","stride",""),"one mastery per max path can be selected")
 check(not m.choose("vitality","renewal",""),"stale choice callback rejected")
 check(not m.choose("vitality","pulse","ward"),"cross-path selection rejected")
 saver.begin_save_write_barrier("mastery_qa","choice failure fixture")
 var before: Dictionary=m.state.duplicate(true)
 check(not m.choose("vitality","renewal","ward") and m.state==before,"failed write retains choice")
 saver.end_save_write_barrier("mastery_qa")
 check(progress.build_progression_save_data()==unchanged,"mastery never spends or resets old progression")
 journey.active_run_chapter_id=1;journey.active_run_stage_id=1;journey.m7d_run_id="a".repeat(32)
 check(m.get_run_choices().vitality=="ward","new run freezes choice")
 check(m.choose("vitality","renewal","ward"),"hub can change next-run choice")
 check(m.get_run_choices().vitality=="ward","active run retains frozen choice")
 journey.m7d_run_id="b".repeat(32);check(m.get_run_choices().vitality=="renewal","new nonce gets next-run choice")
 var choices: Dictionary=m.state.choices.duplicate(true)
 var checkpoint: String=saver.get_save_path("checkpoint")
 var checkpoint_fixture:=FileAccess.open(checkpoint,FileAccess.WRITE);checkpoint_fixture.store_string("fixture");checkpoint_fixture.close()
 check(not m.trial_ready(),"trial cannot overwrite an existing checkpoint")
 DirAccess.remove_absolute(checkpoint)
 journey.clear_active_run(false)
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 change_scene_to_file("res://scenes/ui/cultivation_menu.tscn");await settle();await settle()
 var screen: Control=current_scene
 check(screen.refine_button.text in ["OPEN MASTERY","BUKA MASTERY"] and not screen.refine_button.disabled,"MAX opens mastery instead of dead end")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.size=dims;await settle()
  var panel: Control=screen.mastery_panel
  for id: String in ["renewal","ward","focus","pulse","stride","flow"]:
   var button: Button=panel.find_child("Mastery_"+id,true,false)
   check(button!=null and button.get_global_rect().size.x<=dims.x,"mastery choice fits "+id+str(dims))
  check(panel.find_child("RealmTrialAction",true,false)!=null,"breakthrough goal visible")
 root.size=Vector2i(320,568);await settle()
 screen._show_result("sword_power",9,10,1000,100000000,99999000);await settle();await settle()
 check(screen.result_panel.get_global_rect().size.x<=320,"refinement modal fits narrow phone")
 check(screen.result_panel.get_global_rect().end.y<=568,"refinement modal stays inside viewport")
 check(screen.result_scroll.vertical_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED,"long result scrolls with fixed CTA")
 screen._hide_result();await settle();await settle()
 root.size=Vector2i(648,1152);await settle()
 # Bounded splash: no more than three recipients, no recurrence or DOT proc.
 check(m.choose("sword_power","pulse","focus"),"pulse choice selectable")
 journey.active_run_chapter_id=1;journey.active_run_stage_id=1;journey.m7d_run_id="c".repeat(32)
 var source:=Target.new();source.add_to_group("enemy");current_scene.add_child(source)
 var targets: Array[Target]=[]
 for i: int in range(5):
  var target:=Target.new();target.add_to_group("enemy");target.position=Vector2(i+1,0);current_scene.add_child(target);targets.append(target)
 m.on_enemy_hit(source,100)
 var affected: int=0
 for target: Target in targets:
  if target.received>0:affected+=1;check(is_equal_approx(target.received,15),"pulse damage bounded at 15 percent")
 check(affected==3,"pulse max three recipients")
 m.on_enemy_hit(source,100)
 check(targets.reduce(func(sum: float,t: Target):return sum+t.received,0.0)==45,"pulse cooldown blocks immediate second hit")
 m._process(3);source.set_meta("jade_set_dot_inflight",true);m.on_enemy_hit(source,100)
 check(targets.reduce(func(sum: float,t: Target):return sum+t.received,0.0)==45,"DOT cannot trigger pulse")
 source.queue_free()
 for target: Target in targets:target.queue_free()
 await settle();journey.clear_active_run(false)
 # Actual stage spawn applies health/stats/movement hooks and owns the trial witness.
 for stage: int in range(1,6):
  var key: String=journey.get_stage_key(1,stage)
  if key not in journey.unlocked_stage_keys:journey.unlocked_stage_keys.append(key)
 if journey.get_stage_key(1,5) not in journey.cleared_stage_keys:journey.cleared_stage_keys.append(journey.get_stage_key(1,5))
 check(m.choose("vitality","ward","renewal"),"defense chosen for verified combat test")
 var before_trial: Dictionary=m.state.duplicate(true)
 var before_journey: Dictionary=journey.build_save_data().duplicate(true)
 saver.begin_save_write_barrier("mastery_trial_qa","trial failure fixture")
 check(m.prepare_trial().is_empty() and m.state==before_trial and journey.build_save_data()==before_journey,"trial write failure preserves both domains")
 saver.end_save_write_barrier("mastery_trial_qa")
 check(not m.prepare_trial().is_empty(),"trial rollback fixture prepares")
 m.cancel_prepared_trial()
 check(m.state==before_trial and journey.build_save_data()==before_journey,"failed transition rollback restores both domains")
 var path: String=m.prepare_trial()
 check(not path.is_empty(),"trial prepares atomic mastery/journey run")
 root.get_node("GameSession").start_new_game();change_scene_to_file(path);await settle();await settle()
 var player: Node=root.get_tree().get_first_node_in_group("player");var health: Node=player.get_node("PlayerHealth");var stats: Node=player.get_node("PlayerStats")
 health.qi_shield_charges=0;health.iron_body_level=0
 var hp: float=health.current_health;health.take_damage(10)
 check(is_equal_approx(hp-health.current_health,9.4),"ward applies actual six percent reduction")
 check(int(m.state.trial.hits)==1,"trial counts actual HP damage")
 health.heal(1);check(int(m.state.trial.hits)==1,"healing never counts as damage")
 check(is_instance_valid(m.trial_hud) and m.trial_hud.text.contains("1/3"),"live trial HUD follows damage counter")
 check(player.get_effective_movement_speed()>float(player.speed),"stride applies actual movement bonus")
 var stored: Dictionary=m.state.duplicate(true)
 m._on_stage_completed(1,5,false)
 check(m.state.realm==0 and m.state==stored,"fake stage signal cannot grant realm without victory")
 current_scene.get_node("VictoryManager")._on_boss_defeated();await settle()
 check(m.state.realm==1 and m.state.clears==1 and m.state.trial.status=="complete","real victory pipeline grants Golden Core")
 m._on_stage_completed(1,5,false);check(m.state.clears==1,"duplicate victory cannot regrant realm clear")
 paused=false;change_scene_to_file("res://scenes/ui/cultivation_menu.tscn");await settle();await settle()
 check(current_scene.mastery_panel.body.get_child(0).get_child(1).get_child(0).text=="GOLDEN CORE","realm visible on return to cultivation")
 check(progress.vitality_level==10 and progress.sword_power_level==10 and progress.swift_qi_level==10,"breakthrough never resets max upgrades")
 check(m.choose("vitality","renewal","ward") and m.choose("sword_power","focus","pulse") and m.choose("swift_qi","flow","stride"),"alternate mastery choices selected for next run")
 # A failed trial remains failed through healing/revive and never grants realm.
 path=m.prepare_trial();root.get_node("GameSession").start_new_game();change_scene_to_file(path);await settle();await settle()
 player=root.get_tree().get_first_node_in_group("player");health=player.get_node("PlayerHealth");health.qi_shield_charges=0
 stats=player.get_node("PlayerStats")
 check(is_equal_approx(stats.attack_cooldown,maxf(.2,pow(.95,10)*.96)),"flow applies actual cooldown and preserves floor")
 var deterministic: Node=load("res://tests/mastery_stats_fixture.gd").new();player.add_child(deterministic)
 var high: float=deterministic.calculate_damage_result(10).damage
 health.take_damage(health.max_health*.4)
 var low: float=deterministic.calculate_damage_result(10).damage
 check(high>low,"focus contributes only while HP is high")
 var heal_before: float=health.current_health
 for n: int in range(20):health._on_enemy_killed()
 check(is_equal_approx(health.current_health-heal_before,1),"renewal heals exactly one HP per twenty kills")
 for i: int in range(4):health.take_damage(.1)
 check(m.state.trial.status=="failed" and m.state.trial.hits==4,"four damage hits fail the trial")
 health.heal(1);current_scene.get_node("VictoryManager")._on_boss_defeated();await settle()
 check(m.state.clears==1,"failed trial cannot increase clear count")
 paused=false;change_scene_to_file("res://scenes/ui/cultivation_menu.tscn");await settle();await settle()
 var file:=FileAccess.open("user://mastery_expect.json",FileAccess.WRITE);file.store_string(JSON.stringify({"choices":m.state.choices,"clears":m.state.clears}));file.close()
 print("CULTIVATION_MASTERY_CHECKS=",checks,";FAILURES=",failures)
 quit(1 if failures else 0)
