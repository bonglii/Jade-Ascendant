extends SceneTree
var checks: int=0
var failures: int=0
func check(value: bool,caption: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("HEAVENLY_TRIALS_FAIL "+caption)
func settle(frames: int=8) -> void:
 for i: int in range(frames):await process_frame
func _initialize() -> void:run.call_deferred()
func swipe(at: Vector2) -> void:
 var down:=InputEventMouseButton.new();down.position=at;down.button_index=MOUSE_BUTTON_LEFT;down.button_mask=MOUSE_BUTTON_MASK_LEFT;down.pressed=true;root.push_input(down,true);await settle(1)
 for i: int in range(1,10):
  var motion:=InputEventMouseMotion.new();motion.position=at+Vector2(0,-130)*float(i)/9;motion.relative=Vector2(0,-130.0/9);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true);await settle(1)
 down.position=at+Vector2(0,-130);down.pressed=false;down.button_mask=0;root.push_input(down,true);await settle()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_heavenly_trials_qa"):quit(2);return
 create_timer(90).timeout.connect(func():quit(1))
 await settle(25)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var previous: Node=root.get_node_or_null("HeavenlyTrialsClient")
 if previous!=null:root.remove_child(previous);previous.free()
 var client: Node=load("res://tests/fixtures/heavenly_trials_client.gd").new();client.name="HeavenlyTrialsClient";root.add_child(client);client.set_process(false)
 var account_binding: String="alice".sha256_text();client._owner=account_binding;client.status="connected"
 var now: int=int(Time.get_unix_time_from_system())
 var week: Dictionary={"id":"ht_qa_0","theme":"jade_wind","index":0,"stage":5,"starts_at":now-100,"ends_at":now+604700,"reward":{"celestial_jade":40,"pavilion_seal":1,"spirit_stone":600}}
 client.snapshot={"version":1,"owner_binding":account_binding,"server_time":now,"week":week,"previous":null,"campaign":{"enabled":true},"unlock_tier":2,"progress":[],"previous_progress":[],"session":null,"ads_ready":false,"shop_ready":false,"pack_claimed":false,"bonus_seals":0};client._received=Time.get_ticks_msec()
 var journey: Node=root.get_node("JourneyManager");var before: Dictionary=journey.build_save_data();var stone: int=root.get_node("ProgressionManager").spirit_stone;var jade: int=root.get_node("PavilionManager").get_local_celestial_jade()
 var ui: Control=load("res://scenes/ui/heavenly_trials_screen.tscn").instantiate();root.add_child(ui);current_scene=ui;await settle()
 check(ui._tiers.size()==3,"three weekly tiers")
 check(ui._tiers[2].button.disabled,"Ascension remains locked until 3-5")
 check(ui._entry.text.contains("FREE"),"entry clearly free")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.size=dims;await settle(15)
  check(ui._entry.get_global_rect().position.x>=0 and ui._entry.get_global_rect().end.x<=dims.x,"entry fits width "+str(dims))
  check(ui._rewards.get_global_rect().end.y<=dims.y,"footer fits height "+str(dims))
  var scroll: ScrollContainer=ui.find_child("TrialsScroll",true,false)
  check(scroll.size.x<=dims.x,"scroll fits width")
 root.size=Vector2i(390,844);await settle()
 var scroll: ScrollContainer=ui.find_child("TrialsScroll",true,false);var start_scroll: int=scroll.scroll_vertical
 await swipe(ui.find_child("WeeklyHero",true,false).get_global_rect().get_center())
 check(scroll.scroll_vertical>start_scroll+30,"first native gesture scrolls from real art card")
 check(client.commands.is_empty(),"swipe never starts or claims")
 ui._select(2);check(ui._portrait_key=="2_5","boss portrait follows actual selected tier")
 client.busy=true;ui._enter();check(client.commands.size()==1 and client.commands.back().kind=="start","entry queues during background sync instead of discarding tap");client.commands.clear();client.busy=false
 ui._select(1)
 ui._open_rewards();await settle();check(ui._modal.get_global_rect().end.x<=390,"reward modal fits")
 ui._close_modal();ui._open_shop();await settle();check(ui._modal.get_global_rect().end.x<=390,"shop modal fits")
 ui._close_modal();root.size=Vector2i(320,568);await settle()
 var pavilion: Node=root.get_node("PavilionManager");var original_products: Dictionary=pavilion.billing_store_products.duplicate(true)
 pavilion.billing_store_products={"heavenly_trials_support_550":{"formatted_price":"Rp 89.000,00","price_amount_micros":89000000000}};client.snapshot.shop_ready=true
 ui._open_shop();await settle()
 var price_label: Label=ui.find_child("TrialsPrice",true,false)
 check(price_label.text=="Rp 89.000,00" and price_label.autowrap_mode==TextServer.AUTOWRAP_OFF,"localized Play amount never wraps its digits")
 check(price_label.get_global_rect().end.x<=320 and ui._modal.get_global_rect().size.x<=320,"item-left price-right shop fits smallest screen")
 check(not ui.find_child("TrialsCheckout",true,false).disabled,"valid localized Play product enables only the dedicated offer")
 pavilion.billing_store_products=original_products
 check(journey.build_save_data()==before and root.get_node("ProgressionManager").spirit_stone==stone and root.get_node("PavilionManager").get_local_celestial_jade()==jade,"browsing grants nothing and leaves Journey untouched")
 ui._close_modal();current_scene=null;ui.free();await settle()
 # Separate checkpoint IO and real existing actor/weapon/boss scene.
 client.snapshot.session={"id":"a".repeat(32),"week":week.id,"tier":1,"started_at":now-20,"expires_at":now+850};client.launch_session=client.snapshot.session.duplicate(true)
 check(change_scene_to_file("res://scenes/levels/heavenly_trials.tscn")==OK,"real inherited combat loads")
 await create_timer(.4).timeout
 var arena: Node=current_scene
 if arena==null:check(false,"arena ready");quit(1);return
 var checkpoint: Node=arena.get_node("CheckPointManager")
 check(checkpoint.get_script().resource_path.ends_with("heavenly_trial_checkpoint.gd"),"Trial instance overrides checkpoint manager")
 check(checkpoint.save_checkpoint(),"Trial checkpoint saves")
 check(not root.get_node("SaveManager").has_save_file("checkpoint"),"normal Journey checkpoint never created")
 check(not client.checkpoint_data().is_empty(),"account/session bound trial checkpoint can be read")
 check(journey.build_save_data()==before,"trial entry never selects or unlocks Journey stages")
 var spawner: Node=arena.get_node("EnemySpawner");spawner.spawn_boss();await settle()
 check(arena.boss_phase(),"actual authored boss spawns")
 check(arena.get_node_or_null("BossCombatArena/JadeBoundary")!=null,"physical boss arena present")
 var rule: Node2D=load("res://scripts/game/heavenly_trial_rule.gd").new();arena.add_child(rule);rule.rotation=0;rule.position=Vector2.ZERO
 check(rule.contains_point(Vector2(200,25)) and not rule.contains_point(Vector2(200,29)),"wind lane hit boundary matches visible lane")
 rule.theme_id="sunforge";rule._radius=100
 check(rule.contains_point(Vector2(99,0)) and not rule.contains_point(Vector2(101,0)),"solar warning boundary matches hit radius")
 rule.free()
 arena._boss.current_hp=3210.0;arena.elapsed=80.0
 var ledger: Node=arena.get_node("player_1/WeaponManager/RunCombatLedger");ledger.record("spirit_sword",17)
 check(checkpoint.save_checkpoint(),"boss-phase checkpoint saves")
 var frozen: Dictionary=client.checkpoint_data()
 check(float(frozen.get("trials_boss_hp",0))==3210.0 and bool(frozen.get("trials_boss_phase",false)),"boss health and phase are frozen")
 ledger.totals.clear();check(checkpoint.load_checkpoint(),"actual checkpoint restore succeeds without Journey restore")
 check(float(ledger.totals.get("spirit_sword",0))==17,"Continue restores applied-damage ledger")
 check(journey.build_save_data()==before,"Continue never restores Journey identity")
 ledger.record("spirit_sword",25)
 arena.elapsed=300;arena.finish_heavenly_trial(false)
 check(client.commands.size()==1 and client.commands[0].kind=="finish","finish sends one session report")
 check(client.commands[0].args.damage==42,"report uses actual applied damage ledger")
 check(journey.build_save_data()==before,"Trial terminal does not complete Journey")
 for i: int in range(180):
  if not root.get_node("SceneTransitionManager").is_transitioning:break
  await process_frame
 if current_scene!=null:current_scene.free();current_scene=null
 await settle(5)
 # Real scene Continue: restore boss, player/build and damage before final hit.
 check(client.write_checkpoint(frozen),"saved run can be restored after leaving scene")
 client.launch_session=client.snapshot.session.duplicate(true);root.get_node("GameSession").continue_game=true
 check(change_scene_to_file("res://scenes/levels/heavenly_trials.tscn")==OK,"Continue launches actual combat scene again")
 await create_timer(.5).timeout
 var resumed: Node=current_scene
 check(resumed.boss_phase() and absf(resumed.boss_health()-3210.0)<.01,"Continue respawns authored boss with saved health")
 check(resumed.elapsed>=80 and resumed.elapsed<82,"Continue retains encounter clock")
 var resumed_ledger: Node=resumed.get_node("player_1/WeaponManager/RunCombatLedger")
 check(float(resumed_ledger.totals.get("spirit_sword",0))==17,"new scene Continue restores exact weapon ledger")
 check(int(resumed._boss.current_phase)==2,"Continue restores low-health boss phase instead of trapping damage at threshold")
 await create_timer(maxf(.1,float(resumed._boss.phase_transition_timer)+.05)).timeout
 resumed_ledger.hp_hits=0;resumed_ledger.deaths=0
 preload("res://scripts/weapon/run_combat_ledger.gd").apply_hit(resumed._boss,100000.0,"spirit_sword")
 await settle(3)
 check(client.commands.size()==2 and bool(client.commands.back().args.won),"authored boss defeat submits one winning report")
 check(int(client.commands.back().args.damage)==3227,"winning report includes applied final blow without overkill")
 check(journey.build_save_data()==before and root.get_node("ProgressionManager").spirit_stone==stone and root.get_node("PavilionManager").get_local_celestial_jade()==jade,"actual boss defeat cannot grant or complete Journey rewards")
 for i: int in range(180):
  if not root.get_node("SceneTransitionManager").is_transitioning:break
  await process_frame
 if current_scene!=null:current_scene.free();current_scene=null
 await settle(5)
 print("HEAVENLY_TRIALS checks=",checks," failures=",failures)
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0)
