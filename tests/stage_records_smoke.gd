extends SceneTree
const Book=preload("res://scripts/data/stage_record_book.gd")
const Ledger=preload("res://scripts/weapon/run_combat_ledger.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,caption: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("STAGE_RECORDS_FAIL "+caption)
func settle(count: int=6) -> void:
 for i: int in range(count):await process_frame
func swipe(at: Vector2) -> void:
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.button_mask=MOUSE_BUTTON_MASK_LEFT;down.pressed=true;down.position=at;root.push_input(down,true);await settle(1)
 for i: int in range(1,10):
  var motion:=InputEventMouseMotion.new();motion.position=at+Vector2(0,-110)*float(i)/9;motion.relative=Vector2(0,-110.0/9);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true);await settle(1)
 down.pressed=false;down.button_mask=0;down.position=at+Vector2(0,-110);root.push_input(down,true);await settle(6)
func _initialize() -> void:run.call_deferred()
func sample() -> Dictionary:
 return {"time_ms":182345,"hits":0,"deaths":0,"complete":true,"damage_complete":true,"skills":[{"id":"spirit_sword","level":7,"armament_id":"jade_binding_chain"},{"id":"fire_orb","level":4,"armament_id":""}],"damage":{"jade_binding_chain":4500,"fire_orb":600}}
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 create_timer(85).timeout.connect(func():quit(1))
 await settle(20)
 var journey: Node=root.get_node("JourneyManager");var saves: Node=root.get_node("SaveManager")
 if "--resume" in OS.get_cmdline_user_args():
  check(journey.stage_records.has("1-1"),"journey records survive process restart")
  check(journey.stage_records["1-1"].last.damage.fire_orb==17,"final hit and full build persist")
  check(journey.stage_records["1-1"].survivor and journey.stage_records["1-1"].untouched,"medals survive restart")
  print("STAGE_RECORDS_RESTART checks=",checks," failures=",failures)
  await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0);return
 var visible: Array=preload("res://scripts/data/player_goal_catalog.gd").context(root,false).stages
 check(visible.filter(func(stage: Dictionary):return stage.chapter==1 and stage.stage==6).is_empty(),"legacy hidden stage is preserved in saves but never becomes an unreachable replay objective")
 var goal: Dictionary=preload("res://scripts/data/player_goal_catalog.gd").choose({"stages":[],"cultivation_maxed":true,"trial_complete":true,"daily_complete":true,"record_target":{"chapter":5,"stage":1}})
 check(goal.action=="journey" and goal.chapter==5 and goal.button=="REPLAY 5-1","settled endgame account gets an explicit replay target")
 var model: Dictionary=sample();var id: String="a".repeat(32)
 check(Book.valid_run(model),"actual report schema valid")
 for bad: Variant in [NAN,-1,0,86400001,"123"]:
  var invalid: Dictionary=model.duplicate(true);invalid.time_ms=bad;check(not Book.valid_run(invalid),"invalid duration rejected "+str(bad))
 for bad: Variant in [-1,NAN,1.5,"0"]:
  var invalid: Dictionary=model.duplicate(true);invalid.hits=bad;check(not Book.valid_run(invalid),"invalid HP count rejected")
 check(Book.clock(182345)=="03:02.3","natural compact combat clock")
 var records: Dictionary=Book.merge({},"1-1",id,model)
 check(records["1-1"].survivor and records["1-1"].untouched and records["1-1"].clears==1,"real full stats earn medals")
 check(Book.merge(records,"1-1",id,model).is_empty(),"duplicate completion is idempotent")
 var slower: Dictionary=model.duplicate(true);slower.time_ms=200000;slower.hits=5;slower.deaths=1
 records=Book.merge(records,"1-1","b".repeat(32),slower)
 check(records["1-1"].best_ms==182345 and records["1-1"].clears==2,"slower replay preserves best time")
 check(records["1-1"].untouched and records["1-1"].last.deaths==1,"latest build and earned medals have separate lifetimes")
 var legacy: Dictionary=model.duplicate(true);legacy.complete=false
 var legacy_records: Dictionary=Book.merge({},"1-1","c".repeat(32),legacy)
 check(not legacy_records["1-1"].survivor and not legacy_records["1-1"].untouched,"legacy unknown stats cannot mint medals")
 check(Book.clean({"99-99":records["1-1"]},["1-1"]).is_empty(),"unknown stage pruned")
 var corrupt: Dictionary=records.duplicate(true);corrupt["1-1"].last.skills=[{"id":"fake","level":1}]
 check(Book.clean(corrupt,["1-1"]).is_empty(),"corrupt optional row safely pruned")
 check(Book.clean(JSON.parse_string(JSON.stringify(records)),["1-1"])==records,"JSON cloud integer roundtrip")
 journey.cleared_stage_keys=["1-1"]
 var before: Dictionary=journey.build_save_data();var stone_before: int=root.get_node("ProgressionManager").spirit_stone;var jade_before: int=root.get_node("PavilionManager").get_local_celestial_jade()
 check(journey.record_stage_clear(1,1,id,model),"record saves through real journey domain")
 check(not journey.record_stage_clear(1,1,id,model),"real manager rejects duplicate record")
 check(not journey.record_stage_clear(2,1,"d".repeat(32),model),"uncleared stage cannot gain record")
 var stable_records: Dictionary=journey.stage_records.duplicate(true)
 check(bool(saves.begin_save_write_barrier("record_qa","QA write interruption").success),"save fence acquired")
 check(not journey.record_stage_clear(1,1,"f".repeat(32),model) and journey.stage_records==stable_records,"failed record save preserves prior committed records")
 saves.end_save_write_barrier("record_qa")
 journey.stage_records.clear();journey._load_progress();check(journey.stage_records["1-1"].best_ms==182345,"real save reload restores records")
 check(root.get_node("ProgressionManager").spirit_stone==stone_before and root.get_node("PavilionManager").get_local_celestial_jade()==jade_before,"records never grant currency")
 # Optional missing data in an old Journey save must retain all existing progression.
 var old_save: Dictionary=journey.build_save_data();old_save.erase("stage_records")
 saves.write_save_data("journey",old_save);journey._load_progress()
 check(journey.stage_records.is_empty() and journey.cleared_stage_keys==["1-1"],"legacy Journey remains intact with empty records")
 journey.record_stage_clear(1,1,"e".repeat(32),model)
 # Real combat metrics and checkpoint restoration, including legacy report compatibility.
 journey.selected_chapter_id=1;journey.selected_stage_id=1;journey.begin_selected_stage()
 root.get_node("GameSession").start_new_game()
 check(change_scene_to_file("res://scenes/levels/level_1.tscn")==OK,"actual combat scene")
 await create_timer(.4).timeout
 var world: Node=current_scene
 var tutorial: Node=world.get_node_or_null("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
 if tutorial!=null:tutorial._on_skip_pressed()
 paused=false
 world.get_node("WaveManager").set_process(false)
 var spawner: Node=world.get_node("EnemySpawner");spawner.set_process(false);spawner.clear_normal_enemies();await settle()
 var player: Node=world.get_node("player_1");player.set_physics_process(false);player.get_node("WeaponManager").set_process(false)
 var ledger: Node=player.get_node("WeaponManager/RunCombatLedger");var hp: Node=player.get_node("PlayerHealth")
 hp.take_damage(2);check(ledger.hp_hits==1 and ledger.metrics_complete,"real HP loss counted once")
 hp.health_changed.emit(hp.current_health,hp.max_health);check(ledger.hp_hits==1,"unchanged HP is not damage")
 hp.died.emit();check(ledger.deaths==1,"death disqualifies no-revive medal")
 world.get_node("GameOverManager").game_over_triggered=false;world.get_node("GameOverUI").hide();paused=false
 var checkpoint: Node=world.get_node("CheckPointManager")
 check(checkpoint.save_checkpoint(),"checkpoint with metrics writes")
 var saved: Dictionary=saves.read_save_data("checkpoint").data.run_combat_report
 check(saved.metrics.hits==1 and saved.metrics.deaths==1,"metrics persisted in real checkpoint")
 ledger.restore(saved);check(ledger.hp_hits==1 and ledger.deaths==1 and ledger.metrics_complete,"Continue restores HP/death counters")
 var old_report: Dictionary=saved.duplicate(true);old_report.erase("metrics");ledger.restore(old_report)
 check(not ledger.metrics_complete and not ledger.partial,"old complete damage report keeps totals but HP history is unknown")
 var bad_metrics: Dictionary=saved.duplicate(true);bad_metrics.metrics.hits=-1
 check(not Ledger.valid_snapshot(bad_metrics),"invalid metric checkpoint rejected")
 # Restore fresh data, then real boss defeat transaction. Final lethal HP loss is recorded after return.
 ledger.restore({"version":1,"totals":{},"partial":false,"metrics":{"hits":0,"deaths":0,"complete":true}})
 world.get_node("SurvivalManager").survival_time=180.25
 var victory: Node=world.get_node("VictoryManager")
 var boss: Node=spawner.boss_scene.instantiate();world.add_child(boss);boss.set_physics_process(false);boss.current_hp=17;boss.phase_transition_invulnerability=0;boss.phase_two_hp_ratio=0
 victory._on_boss_spawned(boss)
 Ledger.apply_hit(boss,1000,"fire_orb");await create_timer(1.4).timeout;await settle(14)
 check(victory.victory_processed and victory.record_result in ["best","saved"],"actual victory writes personal record after reward transaction")
 check(journey.stage_records["1-1"].last.damage.fire_orb==17,"final boss killing hit included in saved report")
 check(ledger.frozen,"ledger frozen at post-hit record boundary")
 var summary: Label=world.get_node("VictoryUI").find_child("PersonalRecordSummary",true,false)
 check(summary!=null and summary.visible and summary.text.contains("03:00"),"result exposes saved run record")
 var cloud: Dictionary=preload("res://scripts/managers/progress_backup_snapshot.gd").capture()
 check(not cloud.is_empty() and cloud.domains.journey.stage_records==journey.stage_records,"records fit existing full cloud snapshot validation")
 paused=false;current_scene=null;world.free();await settle()
 # Real stage selector opener and consistent native scrolling on phones.
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(390,844)
 root.get_node("RefineOnboarding").completed=true
 var stage_ui: Control=load("res://scenes/ui/stage_select.tscn").instantiate();root.add_child(stage_ui);current_scene=stage_ui;await settle(18)
 var opener: Button=stage_ui.find_child("OpenCombatRecords",true,false);check(opener!=null,"production Journey exposes records")
 opener.pressed.emit();await settle(15)
 var sheet: Control=stage_ui.get_node("StageRecordsPanel");check(load("res://scripts/ui/stage_records_panel.gd").open(stage_ui)==sheet,"repeated opener cannot stack popups")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(896,504)]:
  root.size=dims;await settle(12)
  check(stage_ui.start_button.get_global_rect().end.x<=dims.x and opener.get_global_rect().end.x<=dims.x,"Journey actions fit width "+str(dims))
  check(opener.get_global_rect().end.y<=dims.y,"Journey record opener fits height "+str(dims))
  var selected_node: Control=stage_ui._stage_node_refs[stage_ui.preview_stage_id].button
  check(stage_ui.map_scroll.get_global_rect().has_point(selected_node.get_global_rect().get_center()),"selected stage remains visible after layout settles "+str(dims))
  for ref: Dictionary in stage_ui._stage_node_refs.values():
   check(ref.plate.position.x>=0 and ref.plate.position.x+ref.plate.size.x<=stage_ui.map_scroll.size.x+1,"map label stays inside phone canvas")
  var paper: Control=sheet._panel;check(paper.get_global_rect().position.x>=0 and paper.get_global_rect().end.x<=dims.x,"record width fits "+str(dims))
  check(paper.get_global_rect().end.y<=dims.y,"record height fits "+str(dims))
  check(sheet._list.size.x<=sheet._scroll.size.x+1,"record cards fit scroll width "+str(dims))
  check(sheet._scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER,"shared scrollbar policy")
 root.size=Vector2i(390,844);await settle();var original: int=sheet._scroll.scroll_vertical
 await swipe(sheet._scroll.get_global_rect().get_center());check(sheet._scroll.scroll_vertical>original+30,"first real swipe on a record card scrolls")
 sheet._select(5);await settle();check(sheet._list.get_child_count()==6 and sheet.chapter==5,"all five realms browsable without launching or selecting stages")
 var persisted: Dictionary=journey.build_save_data()
 sheet.close();await settle();check(journey.build_save_data()==persisted,"record browsing never writes progression")
 current_scene=null;stage_ui.free();await settle()
 print("STAGE_RECORDS checks=",checks," failures=",failures)
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0)
