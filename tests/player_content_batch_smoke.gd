extends SceneTree
## Disposable fixtures. This is neither owner Windows QA nor phone gameplay.
const Preview=preload("res://scripts/data/trial_reward_preview.gd")
const Paths=preload("res://scripts/data/run_path_policy.gd")
var checks: int=0
var failures: int=0
var evidence: Dictionary={}
class Target extends Node2D:
 var current_hp: float=100.0
 var max_hp: float=100.0
 var is_dead: bool=false
 func take_damage(amount: float) -> void:current_hp=maxf(0,current_hp-amount)
func _initialize() -> void:call_deferred("run")
func frames(count: int=6) -> void:
 for i: int in range(count):await process_frame
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("PLAYER_CONTENT "+label)
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_paid_v2_qa"):quit(2);return
 create_timer(90).timeout.connect(func():push_error("PLAYER_CONTENT_TIMEOUT");quit(1))
 await frames(8)
 var settings: Node=root.get_node("SettingsManager")
 var companion: Node=root.get_node("PlayerCompanion")
 var equipment: Node=root.get_node("EquipmentManager")
 var progression: Node=root.get_node("ProgressionManager")
 var daily: Node=root.get_node("DailyQuestManager")
 var mastery: Node=root.get_node("CultivationMasteryManager")
 var snapshot: Dictionary={"week":{"id":"current","reward":{"celestial_jade":12,"pavilion_seal":0,"spirit_stone":145}},"previous":{"id":"old","reward":{"celestial_jade":3,"pavilion_seal":1,"spirit_stone":0}}}
 check(Preview.for_week(snapshot).spirit_stone==145,"current configured reward, never hardcoded 600")
 check(Preview.for_week(snapshot,"old").celestial_jade==3,"grace week uses its own reward")
 check(Preview.for_week(snapshot,"missing").is_empty(),"unknown week never borrows current")
 snapshot.week.reward.spirit_stone=601;check(Preview.for_week(snapshot).is_empty(),"over-budget reward is not displayed as valid")
 snapshot.week.reward.spirit_stone=1.5;check(Preview.for_week(snapshot).is_empty(),"fractional reward rejected")
 var rules=load("res://scripts/data/trial_ruleset_policy.gd")
 var wire: Variant=JSON.parse_string('{"week":{"id":"current","ruleset_version":2,"stage":3,"theme":"jade_wind"}}')
 check(rules.version(wire.week)==2 and not rules.session_config({"week":"current"},wire).is_empty(),"actual JSON-number ruleset and stage supported")
 wire.week.stage=1.5;check(rules.session_config({"week":"current"},wire).is_empty(),"fractional stage rejected before conversion")
 check(Paths.clean({"arts":{"unknown":"focus","fire_orb":"bad"},"boon":"bad"})=={"arts":{},"boon":""},"legacy/malformed path defaults")
 var day: Array[String]=daily._pick_quests_for_date("2026-11-03")
 check(day.size()==6,"lighter next reset retains six quests")
 var budget: int=0
 for id: String in day:budget+=daily.get_reward(id)
 check(budget>=300 and budget<=340,"same authored direct daily reward budget, no new currencies")
 for id: String in daily.active_quest_ids:
  check(daily.get_target(id)<=int({"combat":50,"progression":7,"journey":2}[str(daily.DAILY_QUESTS[id].category)]),"lighter target "+id)
 var old_day: Array[String]=daily.active_quest_ids.duplicate();daily._expand_daily_records();check(daily.active_quest_ids==old_day,"issued six-quest day is not replaced mid-day")
 check(root.get_node("MonetizationManager").ads_suspended(),"temporary ads hold is on")
 check(not root.get_node("MonetizationManager").rewarded_available("pavilion_seal"),"hold never pretends a live ad is ready")
 var chapters=load("res://scripts/data/chronicle_catalog.gd")
 check(chapters.ENTRIES.size()==16,"existing 11 stories plus five fragments")
 var story_ids: Dictionary={}
 for entry: Dictionary in chapters.ENTRIES:
  check(not story_ids.has(entry.id) and not chapters.copy(entry,"body","id").is_empty() and not chapters.copy(entry,"body","en").is_empty(),"unique bilingual story "+str(entry.id));story_ids[entry.id]=true
 # Compile changed production scripts inside the actual autoload context.
 for path: String in ["res://scripts/companion/training_ground.gd","res://scripts/companion/player_journal.gd","res://scripts/ui/liveops/heavenly_trials_screen.gd","res://scripts/gameplay/run_path_choices.gd","res://scripts/game/heavenly_trial_checkpoint.gd"]:
  var script: GDScript=load(path);check(script!=null and script.can_instantiate(),"production script compiles "+path)
 companion.state.seen_bosses=["1-1","1-2","1-3"] # Explicit fixture unlock, not gameplay proof.
 var before_progress: Dictionary=progression.build_progression_save_data().duplicate(true)
 var before_daily: Dictionary=daily.build_save_data().duplicate(true)
 var before_equipment: Dictionary=equipment.build_equipment_save_data().duplicate(true)
 var before_mastery: Dictionary=mastery.state.duplicate(true)
 change_scene_to_file("res://scenes/ui/training_ground.tscn");await frames(18)
 var court: Node=current_scene
 check(court!=null and court.has_method("record_practice_hit"),"real training scene loads")
 if court==null or not court.has_method("record_practice_hit"):quit(1);return
 check(not court._running and court.elapsed==0,"test begins deliberately without advancing clock")
 court._start();await create_timer(1.2).timeout
 var ledger: Node=court.player.get_node("WeaponManager/RunCombatLedger")
 var actual: float=0
 for amount: Variant in ledger.totals.values():actual+=float(amount)
 check(actual>0,"production auto-attack applies actual HP loss")
 evidence.dummy_damage=actual
 court._finish("FIXTURE STOP")
 var manager: Node=court.player.get_node("WeaponManager")
 var damage: GDScript=load("res://scripts/weapon/run_combat_ledger.gd")
 var actor:=Target.new();court.add_child(actor)
 manager.run_paths={"arts":{"spirit_sword":"focus"},"boon":"none"}
 var normal: float=damage.apply_hit(actor,10,"spirit_sword")
 actor.current_hp=100;actor.add_to_group("boss")
 var boss: float=damage.apply_hit(actor,10,"spirit_sword")
 check(is_equal_approx(normal,9.0) and is_equal_approx(boss,12.0),"focus tradeoff measured through production applied HP loss")
 actor.current_hp=100;manager.run_paths={"arts":{"spirit_sword":"sweep"},"boon":"ember"}
 var combined: float=damage.apply_hit(actor,10,"spirit_sword")
 check(is_equal_approx(combined,10.08),"sweep/ember damage compose once")
 actor.queue_free();await frames(2)
 var chooser: Node=manager.get_node("RunPathChoices")
 chooser._offer("boon","ALTAR FIXTURE",[["wind","WIND"]]);check(paused,"choice owns pause")
 chooser._pick("wind");check(not paused and manager.run_paths.boon=="wind","choice commits once and releases pause")
 check(is_equal_approx(Paths.movement(manager.run_paths),1.1),"wind movement tradeoff bounded")
 # Real boss scene with production attack/HP contract; fixture killing hit only tests completion ordering.
 court._select_mode(1);await frames(8);court._start();await frames(8)
 check(is_instance_valid(court._boss),"encountered guardian is playable")
 if is_instance_valid(court._boss):
  var guardian: Node=court._boss;guardian.phase_transition_timer=0;guardian.current_hp=10
  damage.apply_hit(guardian,100000,"spirit_sword");await frames(4)
  check(not court._running and court._outcome.contains("COMPLETE"),"boss completion waits for hit ledger")
  check(court._outgoing>=10,"final killing hit included in training total")
 # Standardized mode uses no permanent bonus, but never mutates the actual permanent loadout.
 court._select_mode(4);await frames(8)
 check(equipment.practice_items.is_empty() and court.get_meta("standard_kit"),"fixed kit isolates gear and mastery")
 check(is_equal_approx(court.player.get_node("PlayerStats").power_multiplier,1.0) and court.player.get_node("PlayerHealth").max_health==100,"fixed power and 100 HP")
 court._start();await frames(5);court._finish("FIXTURE STOP")
 court._select_mode(5);await frames(8);court._start();await frames(20)
 var bearer: Node=court.get_node_or_null("JadeWardBearer")
 check(bearer!=null,"support encounter spawns a distinct ward bearer")
 var protected: Node=null
 for enemy: Node in get_nodes_in_group("companion_training_target"):
  if enemy!=bearer and enemy.damage_reduction_sources.has("practice_ward"):protected=enemy;break
 check(protected!=null,"ward protects nearby authored minions")
 if bearer!=null:
  damage.apply_hit(bearer,100000,"spirit_sword");await frames(6)
  check(not is_instance_valid(bearer) and not court._running,"killing support completes priority objective without XP drops")
 check(get_nodes_in_group("xp_gem").is_empty(),"destructible practice enemies never drop XP")
 court._select_mode(2);await frames(8);court._start()
 for index: int in range(3):
  court.player.position=court._seal.location;court._process(8.1)
 check(court._seals==3 and not court._running,"seal challenge reuses three complete eight-second oath states")
 # Account and permanent domain safety.
 check(progression.build_progression_save_data()==before_progress,"training never mutates currency, cultivation or hero XP")
 check(daily.build_save_data()==before_daily,"training never advances daily progress or claims")
 check(equipment.build_equipment_save_data()==before_equipment,"actual gear/stars/levels remain unchanged")
 check(mastery.state==before_mastery,"training never awards or freezes mastery progression")
 var client: Node=root.get_node("HeavenlyTrialsClient")
 var old_owner: String=client._owner;client._owner="a".repeat(64)
 check(client._save_personal_risk("fixture-session",2) and client.personal_risk("fixture-session")==2,"personal risk survives durable local read")
 check(client.personal_risk("other-session")==0,"risk cannot cross sessions")
 client._owner="b".repeat(64);check(client.personal_risk("fixture-session")==0,"risk cannot cross accounts");client._owner=old_owner
 # Bilingual new copy.
 settings.set_presentation("language","id")
 check(TranslationServer.translate("Keep landing direct hits. Bleed does not stack; stronger hits improve remaining ticks. Bosses take half the DoT.").begins_with("Terus"),"Builds message has complete Indonesian copy")
 settings.set_presentation("language","en")
 evidence.checks=checks;evidence.failures=failures;evidence.scope="HEADLESS_PRODUCTION_FIXTURES_NOT_PHONE_PLAYTEST"
 var output: String=OS.get_environment("JADE_QA_RESULT")
 if not output.is_empty():var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(evidence,"  "));file.close()
 print("PLAYER_CONTENT_BATCH_QA checks=%d failures=%d"%[checks,failures])
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 if current_scene!=null:current_scene.queue_free();current_scene=null
 await frames(3);quit(1 if failures else 0)
