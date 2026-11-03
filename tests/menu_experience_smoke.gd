extends SceneTree
## Production actors in disposable userdata; never owner Windows or phone proof.
const Policy=preload("res://scripts/data/experience_policy.gd")
const Timeline=preload("res://scripts/data/hit_timeline.gd")
const Rewards=preload("res://scripts/data/trial_reward_preview.gd")
var checks: int=0
var failures: int=0
class MailData extends Node:
 var rows: Array[Dictionary]=[]
 func get_mail_entries() -> Array[Dictionary]:return rows.duplicate(true)
class Wave extends Node:
 var current_wave: int=4
 var final_wave: int=10
func check(ok: bool,title: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("EXPERIENCE_FAIL "+title)
func frames(n: int=4) -> void:
 for i: int in range(n):await process_frame
func _initialize() -> void:call_deferred("begin")
func begin() -> void:
 if not OS.get_user_data_dir().contains("jade_paid_v2_qa"):quit(2);return
 create_timer(90).timeout.connect(func():push_error("EXPERIENCE_TIMEOUT");quit(1))
 await frames()
 var settings: Node=root.get_node("SettingsManager")
 check(root.get_node("MonetizationManager").ads_suspended(),"ad hold on")
 var monday: int=345600-25200+3000*604800
 check(Policy.week(monday-1)+1==Policy.week(monday),"local Monday boundary")
 check(Policy.itinerary(monday)==Policy.itinerary(monday+604799),"frozen itinerary")
 check(Policy.itinerary(monday).mode!=Policy.itinerary(monday+604800).mode,"weekly variety")
 var data: Dictionary={"week":{"id":"now","reward":{"celestial_jade":12,"pavilion_seal":1,"spirit_stone":145}},"previous":{"id":"old","reward":{"celestial_jade":6,"pavilion_seal":0,"spirit_stone":55}},"previous_progress":[{"clears":1,"claimed":0}]}
 check(Rewards.for_hub(data).spirit_stone==55,"earned previous-week preview")
 data.previous_progress[0].claimed=1;check(Rewards.for_hub(data).spirit_stone==145,"current-week preview")
 check(Rewards.for_hub({}).is_empty(),"unknown reward not invented")
 data.week.reward.spirit_stone=601;check(Rewards.for_hub(data).is_empty(),"invalid reward refused")
 data.previous_progress[0].claimed=0;data.previous.erase("id");check(Rewards.for_hub(data).is_empty(),"missing grace identity never borrows current")
 var timeline: Dictionary={"version":1,"clock":12.0,"complete":true,"events":[{"time":1.0,"loss":5.0,"hp":95.0,"source":"melee"},{"time":11.0,"loss":4.0,"hp":91.0,"source":"lightning"}]}
 check(Timeline.recent(timeline).size()==1,"last ten seconds only")
 timeline.events[1].time=0.0;check(Timeline.clean(timeline).is_empty(),"unordered events refused")
 var companion: Node=root.get_node("PlayerCompanion")
 companion.state.seen_bosses=["1-1","1-2","1-3","1-4","1-5"]
 check(not companion.record_training({}, {}, "wrong-owner"),"account guard")
 change_scene_to_file("res://scenes/ui/training_ground.tscn");await frames(12)
 var court: Node=current_scene
 if court==null or not court.has_method("_start"):check(false,"training compiles");quit(1);return
 court._start();await frames()
 var hp: Node=court.player.get_node("PlayerHealth")
 var ledger: Node=court.player.get_node("WeaponManager/RunCombatLedger")
 hp.hit_guard_remaining=0;hp.take_damage(5,"lightning")
 check(ledger.review_events.size()==1 and ledger.review_events[0].source=="lightning","actual hit source")
 check(is_equal_approx(float(ledger.review_events[0].loss),5.0),"actual HP loss")
 hp.qi_shield_charges=1;hp.hit_guard_remaining=0;hp.take_damage(8,"melee")
 check(ledger.review_events.size()==1,"shield not an HP hit")
 var stored: Dictionary=ledger.snapshot();ledger.restore(stored)
 check(ledger.review_complete and ledger.review_events.size()==1,"Continue roundtrip")
 stored.erase("timeline");ledger.restore(stored)
 check(not ledger.review_complete and ledger.hp_hits==1,"legacy counters retained")
 ledger.review_clock=15;hp.hit_guard_remaining=0;hp.take_damage(3,"projectile")
 check(ledger.review_events.size()==1 and ledger.review_events[0].source=="projectile","old events expire")
 var stones: int=root.get_node("ProgressionManager").spirit_stone
 court._select_mode(7);await frames(6);court._start();await frames(4)
 check(court.mode=="pattern" and is_instance_valid(court._boss),"real guardian pattern drill")
 var boss: Node=court._boss;var before: float=boss.current_hp
 check(boss.choose_ranged_pattern()==court._selected_pattern(),"selected authored pattern")
 boss.take_damage(100);check(boss.current_hp==before,"demonstration guardian HP fixed")
 boss.ranged_attack_timer=0;boss.try_ranged_attack();await frames(4)
 check(boss.last_ranged_pattern==court._selected_pattern(),"production cast uses selected pattern")
 court.elapsed=45.1;court._process(.01)
 check(not court._running and not companion.state.training_records.is_empty(),"personal best saved")
 check(root.get_node("ProgressionManager").spirit_stone==stones,"no training currency")
 check(Policy.better({"score":"time","time_ms":45000,"damage":0,"hits":2},{"score":"time","time_ms":45000,"damage":0,"hits":3}),"equal time prefers fewer hits")
 var spawner: Node=load("res://scripts/enemy/enemy_spawner.gd").new();spawner.player=court.player;spawner.stage_profile={"realm_id":2};spawner.formation_enabled=true
 var wave:=Wave.new();spawner.wave_manager=wave
 seed(99);var normal: Vector2=spawner.get_random_spawn_position(false)
 check(is_equal_approx(normal.distance_to(court.player.global_position),spawner.spawn_distance) and spawner.formation_index==0,"elite/boss position unchanged")
 var varied: Vector2=spawner.get_random_spawn_position(true)
 check(is_equal_approx(varied.distance_to(court.player.global_position),spawner.spawn_distance) and spawner.formation_index==1,"ordinary sector retains distance")
 spawner.free();wave.free()
 var cadence: Script=load("res://scripts/data/encounter_cadence_state.gd")
 var raw: Dictionary={"version":1,"spawn_timer":1.3,"kills":9,"spawned":[4],"active":{},"formation":{"enabled":true,"index":12}}
 var clean: Dictionary=cadence.clean(raw,{4:1,8:2},4,10)
 check(clean.formation.index==12 and clean.formation.enabled,"formation state checkpoint")
 raw.erase("formation");clean=cadence.clean(raw,{4:1,8:2},4,10)
 check(not clean.formation.enabled,"legacy cadence keeps original approach")
 raw.formation={"enabled":"bad","index":-1};clean=cadence.clean(raw,{4:1,8:2},4,10)
 check(clean.kills==9 and not clean.formation.enabled,"bad optional formation preserves valid core cadence")
 for realm: int in range(2,6):check(is_finite(Policy.realm_arc(realm,4,8,.2)),"bounded sector "+str(realm))
 settings.set_presentation("high_contrast_warnings",true)
 var hazard:=Node2D.new();court.add_child(hazard);load("res://scripts/experience/accessible_hazard.gd").install(hazard,60,.8)
 check(hazard.get_child_count()==1 and hazard.get_child(0).radius==60,"warning keeps radius")
 settings.set_presentation("high_contrast_warnings",false)
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await frames(12)
 check(current_scene.get_script()!=null,"Hero compiles")
 if current_scene.get_script()==null:quit(1);return
 var slots: Dictionary={}
 for slot: String in root.get_node("EquipmentManager").get_slot_ids():slots[slot]=""
 companion.state.presets["0"]={"name":"Author preview fixture","slots":slots,"server":slots.duplicate()}
 for language: String in ["en","id"]:
  settings.set_presentation("language",language)
  for key: String in ["events","pavilion","cultivate","settings","weekly","odyssey","purchase","timeline","preset","library"]:
   var guide: Control=load("res://scripts/experience/menu_guide.gd").open(current_scene,key,{"index":0})
   await frames(3);check(is_instance_valid(guide) and is_instance_valid(guide.body),"reader "+language+" "+key)
   if key=="odyssey" and language=="en":
    var words: String=""
    for text: Label in guide.body.find_children("*","Label",true,false):words+=text.text
    check(words.contains("WAITING FOR YOUR PROGRESS") and not words.contains("0/72"),"offline Odyssey never invents confirmed progress")
   guide.close();await frames(2)
 var odyssey: Node=root.get_node("OdysseyClient");var old_snapshot: Dictionary=odyssey.snapshot.duplicate(true)
 odyssey.snapshot={"state":{"journey_laps_version":2,"laps":4,"milestones":[]}}
 settings.set_presentation("language","en")
 var confirmed_guide: Control=load("res://scripts/experience/menu_guide.gd").open(current_scene,"odyssey");await frames(3)
 var confirmed_words: String=""
 for text: Label in confirmed_guide.body.find_children("*","Label",true,false):confirmed_words+=text.text
 check(confirmed_words.contains("4/12"),"Odyssey reads confirmed lap-rule progress")
 confirmed_guide.close();odyssey.snapshot=old_snapshot;await frames(2)
 var mail: Node=load("res://scripts/ui/liveops/mailbox_screen.gd").new()
 var authority:=MailData.new()
 authority.rows=[{"id":"b","expires_at":0,"reward":{"spirit_stone":1}},{"id":"a","expires_at":10,"reward":{"spirit_stone":1}},{"id":"c","expires_at":5,"reward":{"spirit_stone":1}}]
 var batch: Node=load("res://scripts/ui/liveops/mailbox_claim_batch.gd").new();mail.live_ops=authority;mail._claim_batch=batch
 var ordered: Array=mail._entries()
 check(ordered[0].id=="c" and ordered[1].id=="a" and ordered[2].id=="b","stable claimable expiry order")
 mail.free();authority.free();batch.free()
 check(root.get_node("MonetizationManager").ads_suspended(),"hold after readers")
 print("MENU_EXPERIENCE_QA checks=",checks," failures=",failures)
 paused=false;await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 if current_scene!=null:current_scene.queue_free();current_scene=null
 await frames(5);quit(1 if failures else 0)
