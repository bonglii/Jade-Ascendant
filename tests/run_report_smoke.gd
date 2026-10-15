extends SceneTree
const Ledger=preload("res://scripts/weapon/run_combat_ledger.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("RUN_REPORT_FAIL "+label)
func _initialize() -> void:run.call_deferred()
func settle() -> void:
 await process_frame
 await process_frame
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_report_qa"):quit(2);return
 root.content_scale_size=Vector2i.ZERO
 await create_timer(.2).timeout
 if "--resume" in OS.get_cmdline_user_args():
  root.get_node("GameSession").continue_saved_game()
  check(change_scene_to_file("res://scenes/levels/level_1.tscn")==OK,"restart scene")
  await create_timer(.4).timeout
  var restored: Node=current_scene.get_node("player_1/WeaponManager/RunCombatLedger")
  check(not restored.partial and restored.totals.size()==Ledger.SOURCES.size(),"restart complete source ledger")
  var durable: Dictionary=root.get_node("SaveManager").read_save_data("checkpoint").data.run_combat_report
  check(restored.totals==durable.totals and float(restored.totals.get("fire_orb",0))>=33.5,"restart restores latest autosaved cumulative damage")
  check(is_equal_approx(float(restored.totals.get("celestial_returning_glaive",0)),53.5),"restart cumulative phase-capped damage")
  print("RUN_REPORT_RESTART checks=",checks," failures=",failures)
  await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0)
  return
 root.get_node("GameSession").start_new_game()
 check(change_scene_to_file("res://scenes/levels/level_1.tscn")==OK,"actual arena")
 await create_timer(.3).timeout
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
 var world: Node=current_scene
 var player: Node2D=world.get_node("player_1")
 player.set_physics_process(false)
 var manager: Node=player.get_node("WeaponManager")
 manager.set_process(false)
 world.get_node("WaveManager").set_process(false)
 var owner: Node=world.get_node("EnemySpawner")
 owner.set_process(false);owner.clear_normal_enemies();await settle()
 var ledger: Node=manager.get_node("RunCombatLedger")
 check(ledger.totals.is_empty() and not ledger.partial,"new run starts complete empty")
 var victim: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate()
 victim.max_hp=100;world.add_child(victim);victim.set_physics_process(false)
 victim.global_position=player.global_position+Vector2(150,0)
 Ledger.apply_hit(victim,30,"fire_orb")
 check(is_equal_approx(float(ledger.totals.get("fire_orb",0)),30),"actual HP damage")
 Ledger.apply_hit(victim,900,"thunder_talisman")
 check(is_equal_approx(float(ledger.totals.get("thunder_talisman",0)),70),"overkill capped")
 Ledger.apply_hit(victim,900,"thunder_talisman")
 check(is_equal_approx(float(ledger.totals.get("thunder_talisman",0)),70),"dead target no credit")
 await settle()
 var boss: Node2D=owner.boss_scene.instantiate()
 world.add_child(boss);boss.set_physics_process(false)
 boss.phase_transition_timer=1.0
 Ledger.apply_hit(boss,100,"jade_binding_chain")
 check(not ledger.totals.has("jade_binding_chain"),"phase ward no credit")
 boss.phase_transition_timer=0;boss.phase_transition_invulnerability=1;boss.phase_two_hp_ratio=.5
 boss.current_hp=100;boss.max_hp=100
 Ledger.apply_hit(boss,900,"celestial_returning_glaive")
 check(is_equal_approx(float(ledger.totals.get("celestial_returning_glaive",0)),50),"phase threshold counts applied portion")
 boss.queue_free();await settle()
 for source: String in Ledger.SOURCES:
  var old: float=float(ledger.totals.get(source,0))
  victim=load("res://scenes/enemy/enemy_1.tscn").instantiate();victim.max_hp=100;world.add_child(victim);victim.set_physics_process(false)
  Ledger.apply_hit(victim,3.5,source)
  check(is_equal_approx(float(ledger.totals.get(source,0))-old,3.5),"all source buckets "+source)
  victim.queue_free()
 await settle()
 var saved: Dictionary=ledger.snapshot()
 check(Ledger.valid_snapshot(saved),"valid snapshot")
 ledger.record("invalid",20);ledger.record("fire_orb",NAN);ledger.record("fire_orb",-1)
 check(ledger.snapshot()==saved,"invalid sources and amounts rejected")
 ledger.restore({});check(ledger.partial and ledger.totals.is_empty(),"legacy continue marked partial")
 ledger.restore(saved);check(ledger.snapshot()==saved,"restore exact values")
 for bad: Variant in [{"version":1,"totals":{"fire_orb":NAN},"partial":false},{"version":1,"totals":{"unknown":1},"partial":false},{"version":1,"totals":{"fire_orb":-1},"partial":false},{"version":1,"totals":{"fire_orb":"9"},"partial":false}]:
  check(not Ledger.valid_snapshot(bad),"invalid saved report")
 manager.add_fire_orb();manager.add_thunder_talisman()
 var stats: Node=player.get_node("PlayerStats")
 stats.upgrade_power();stats.upgrade_attack_speed();stats.sword_intent_level=2;stats.unlock_sword_dao_resonance()
 player.movement_speed_level=1;player.spiritual_insight_level=2
 player.get_node("PlayerHealth").iron_body_level=1
 var skills: Array=ledger.skills();var found: Dictionary={}
 for skill: Dictionary in skills:found[skill.id]=skill.level
 check(found.fire_orb==1 and found.thunder_talisman==1 and found.power==1 and found.attack_speed==1,"actual acquired skill levels")
 check(found.sword_intent==2 and found.sword_dao_resonance==1 and found.spiritual_insight==2 and found.iron_body==1,"utility and synergy skills")
 check(not found.has("blood_qi") and not found.has("yin_yang_blades"),"untaken skills excluded")
 var checkpoint: Node=world.get_node("CheckPointManager")
 check(checkpoint.save_checkpoint(),"checkpoint with report saves")
 var raw: Dictionary=root.get_node("SaveManager").read_save_data("checkpoint").data
 check(raw.run_combat_report==ledger.snapshot(),"persisted report exact")
 var bad_checkpoint: Dictionary=raw.duplicate(true)
 bad_checkpoint.run_combat_report={"version":1,"totals":{"unknown":9},"partial":false}
 var repaired: Dictionary=checkpoint.normalize_checkpoint_save_data(bad_checkpoint)
 check(not repaired.is_empty() and not repaired.has("run_combat_report"),"invalid optional statistics never block valid progress")
 var legacy_checkpoint: Dictionary=raw.duplicate(true);legacy_checkpoint.erase("run_combat_report")
 check(not checkpoint.normalize_checkpoint_save_data(legacy_checkpoint).is_empty(),"legacy checkpoint still accepted")
 ledger.totals.clear();check(checkpoint.load_checkpoint(),"Continue restores checkpoint")
 check(ledger.snapshot()==saved,"Continue restores full cumulative damage")
 # Exercise each real caster, not just labelled helper calls.
 owner.clear_normal_enemies();await settle()
 for source: String in ["spirit_sword","fire_orb","thunder_talisman","yin_yang_blades","heavenly_sword_rain","eight_trigrams_formation","jade_binding_chain","celestial_returning_glaive"]:
  var baseline: Array[Node]=world.get_children()
  var actual: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate()
  actual.max_hp=10000;world.add_child(actual);actual.set_physics_process(false)
  actual.global_position=player.global_position+Vector2(60,0)
  var caster: Node=load("res://scripts/weapon/"+source+"_weapon.gd").new()
  if source in ["jade_binding_chain","celestial_returning_glaive"]:caster.configure_armament(source)
  player.add_child(caster)
  var before_damage: float=float(ledger.totals.get(source,0))
  var before_hp: float=float(actual.current_hp)
  if source=="yin_yang_blades":
   caster.activate(player)
   actual.global_position=player.get_node("CombatOrigin").global_position+Vector2(caster.get_current_orbit_radius(),0)
  else:caster.attack(player,actual)
  await create_timer(3.0,false).timeout
  var applied: float=before_hp-float(actual.current_hp)
  check(applied>0 and is_equal_approx(float(ledger.totals.get(source,0))-before_damage,applied),"real caster attribution "+source)
  if source=="yin_yang_blades":caster.clear_blades()
  caster.queue_free()
  for child: Node in world.get_children():
   if child not in baseline:child.queue_free()
  await settle()
 # Capture happens after take_damage returns, so final killing blow is counted.
 ledger.totals.clear();ledger.partial=false
 var victory: Node=world.get_node("VictoryUI")
 boss=owner.boss_scene.instantiate();world.add_child(boss);boss.set_physics_process(false)
 boss.current_hp=17;boss.phase_transition_invulnerability=0
 boss.boss_defeated.connect(victory.show_victory)
 paused=true
 Ledger.apply_hit(boss,1000,"fire_orb")
 await settle()
 check(is_equal_approx(float(ledger.totals.get("fire_orb",0)),17),"final boss killing hit included")
 check(ledger.frozen,"victory freezes totals after final hit")
 var ceremony: Node=victory.get_node("ResultCeremony")
 check(ceremony._report_damage.size()>0 and ceremony._report_skills.size()>0,"victory reports real data")
 var frozen: Dictionary=ledger.snapshot();ledger.record("fire_orb",100)
 check(ledger.snapshot()==frozen,"post-victory no late credit")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(720,1600),Vector2i(896,504)]:
  root.size=dims;await settle();ceremony.fit();await settle()
  var panel: Control=ceremony._panel
  check(panel.get_global_rect().position.x>=-.5 and panel.get_global_rect().end.x<=dims.x+.5,"result fits width "+str(dims))
  check(panel.get_global_rect().end.y<=dims.y+.5,"result fits height "+str(dims))
  check(victory.main_menu_button.get_global_rect().end.y<=panel.get_global_rect().end.y-15,"home inside sheet")
  for mode: bool in [false,true]:
   ceremony._show_skills=mode;ceremony._refresh_report_rows();await settle()
   check(ceremony._report_rows.size.x<=ceremony._scroll.size.x+1,"report tab inside reader")
   for label: Label in ceremony._report_rows.find_children("Report*","Label",true,false):
    check(label.get_line_count()==1 and label.size.x>=40,"numbers stay one line")
    check(label.get_global_rect().end.x<=ceremony._scroll.get_global_rect().end.x+1,"numbers inside reader")
 print("RUN_REPORT_QA checks=",checks," failures=",failures)
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0)
