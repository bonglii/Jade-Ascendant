extends SceneTree
const Paid=preload("res://scripts/monetization/paid_gameplay_v2.gd")
const Fixture=preload("res://tests/fixtures/paid_gameplay_manager_v2.gd")
const REF_FILE="user://paid_run_server_fixture.json"
var checks: int=0
var failures: int=0
var paid: Node
var pavilion: Node
var equipment: Node
var saver: Node
var transition: Node
var bridge: Node
var watchdog: Timer
var level_fixture: PackedScene
class Bridge extends Node:
 var manager: Node
 var state: Dictionary={}
 var runs: Dictionary={}
 var calls: Array=[]
 var mode: String=""
 func requestPaidGameplayV2(id: String,raw: String) -> void:
  calls.append(raw)
  if mode=="drop":
   manager.set("_deadline",0);return
  var op: Variant=null
  if raw!="":
   var cmd: Dictionary=JSON.parse_string(raw)
   var outcome: Variant=null
   if cmd.kind=="run_start":
    var stars: Dictionary={}
    for item: String in state.slots.values():
     if item!="": stars[item]=state.stars[item]
    runs[cmd.run_id]={"run_id":cmd.run_id,"slots":state.slots.duplicate(true),"stars":stars,"weapon_level":int(cmd.weapon_level)}
   if cmd.kind in ["run_start","run_resume"]:outcome=runs[cmd.run_id].duplicate(true)
   state.revision=int(state.revision)+1
   op={"request_id":cmd.request_id,"kind":"not_committed" if mode=="cancel" else cmd.kind,"outcome":null if mode=="cancel" else outcome}
  manager.call_deferred("_on_result",id,true,"PAID_GAMEPLAY_VERIFIED",JSON.stringify({"snapshot":state,"operation":op}))
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("PAID_RUN_QA "+message)
func initial_state() -> Dictionary:
 return {"paid_gameplay_version":2,"account_binding":"a".repeat(64),"catalog_hash":Paid.HASH,"state":"ready","revision":0,"wallet":{"balance":1500,"revision":1},"inventory":{"jade_binding_chain":3,"cloudstep_boots":2},"stars":{"jade_binding_chain":3,"cloudstep_boots":2},"slots":{"armament":"jade_binding_chain","robe":"","bracer":"","boots":"cloudstep_boots","pendant":""},"pity":{"rare_plus":0,"epic_plus":10,"legendary":10},"wish":"","wish_guaranteed":false,"lifetime_pulls":10,"rates":{"common":6000,"rare":2900,"epic":900,"legendary":200},"lease_seconds":120}
func settle_game() -> void:
 await create_timer(0.3,true).timeout
 var nodes: Array[Node]=[current_scene]
 while not nodes.is_empty():
  var node: Node=nodes.pop_back()
  if node.has_method("_on_skip_pressed"):node.call("_on_skip_pressed")
  if node.name in ["EnemySpawner","WaveManager"]:node.set_process(false);node.set_physics_process(false)
  nodes.append_array(node.get_children())
 paused=false
func go_level() -> void:
 var error: int=transition.transition_to("res://scenes/levels/level_1.tscn",{"minimum_display_time":0.2})
 check(error==OK,"shipping transition dispatch")
 while transition.is_transitioning:await process_frame
func starter_id() -> String:
 var weapon: Node=current_scene.get_node("player_1/WeaponManager").weapons[0]
 return weapon.get_script().resource_path
func end_test() -> void:
 watchdog.stop();watchdog.queue_free()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 if current_scene!=null:current_scene.queue_free()
 await process_frame;await process_frame
 await create_timer(.1,true).timeout
 print("PAID_RUN_RECOVERY_CHECKS=",checks,";FAILURES=",failures)
 call_deferred("quit",1 if failures else 0)
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_paid_run_qa"):quit(2);return
 watchdog=Timer.new();watchdog.process_mode=Node.PROCESS_MODE_ALWAYS;watchdog.one_shot=true;watchdog.wait_time=40
 root.add_child(watchdog);watchdog.timeout.connect(func():push_error("PAID_RUN_QA timeout");quit(1));watchdog.start()
 await process_frame
 # Warm fixture scripts on the main thread; this tests the paid gate, not cold-loader latency.
 level_fixture=load("res://scenes/levels/level_1.tscn")
 check(level_fixture!=null,"production scene fixture loads")
 root.get_node("SettingsManager").reduced_effects=true
 pavilion=root.get_node("PavilionManager");equipment=root.get_node("EquipmentManager");saver=root.get_node("SaveManager");transition=root.get_node("SceneTransitionManager")
 var session: Node=root.get_node("GameSession")
 paid=Fixture.new();bridge=Bridge.new();bridge.manager=paid;paid.test_bridge=bridge;paid._binding="a".repeat(64)
 root.add_child(bridge);root.add_child(paid);paid.set_process(true);paid._next_read=Time.get_ticks_msec()+600000
 pavilion.paid_gameplay=paid
 check(paid.process_mode==Node.PROCESS_MODE_ALWAYS,"transport deadline continues during loading pause")
 var hub:=Control.new();root.add_child(hub);current_scene=hub
 if "--resume" in OS.get_cmdline_user_args():
  var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REF_FILE));bridge.state=fixture.state;bridge.runs=fixture.runs
  var checkpoint: Dictionary=load("res://scripts/managers/checkpoint_manager.gd").read_checkpoint_result().data
  var ref: Dictionary=checkpoint.paid_run_ref
  check(Paid.valid_run_ref(ref),"opaque run reference survives process restart")
  check(not checkpoint.has("paid_slots") and not checkpoint.has("paid_stars"),"checkpoint has no paid ownership copy")
  check(equipment.get_item_weapon_level("jade_binding_chain")==10,"unverified saved level is capped before login")
  session.continue_saved_game();await go_level();await settle_game()
  check(starter_id().ends_with("jade_binding_chain_weapon.gd"),"Continue instantiates correct starter before checkpoint restore")
  check(equipment.get_runtime_equipped_item_id("boots")=="cloudstep_boots","continued armor uses server run, not empty hub selection")
  check(equipment.get_runtime_item_star("jade_binding_chain")==3,"hub ascension does not upgrade old run")
  check(equipment.get_item_weapon_level("jade_binding_chain")==12,"hub weapon level25 does not replace frozen level12")
  check(bridge.state.slots.armament=="","resume cannot alter hub selection")
  check(root.get_node("InventoryManager").get_item_count("jade_binding_chain")==0,"Continue does not mint offline inventory")
  check(saver.read_save_data("checkpoint").data.paid_run_ref==ref,"Continue preserves run reference")
  paid.snapshot.stars.jade_binding_chain=1
  check(equipment.get_runtime_item_star("jade_binding_chain")==1 and equipment.get_item_weapon_level("jade_binding_chain")==10,"current star downgrade clamps frozen power")
  paid.snapshot.stars.jade_binding_chain=4;paid._expires=0
  check(paid.selected_slot("armament",true)=="","expired ownership cannot use frozen run")
  check(paid.refresh(),"ownership refresh dispatch")
  while paid.busy:await process_frame
  check(equipment.get_runtime_equipped_item_id("armament")=="jade_binding_chain","renewed lease restores same frozen starter")
  change_scene_to_file("res://scenes/ui/main_menu.tscn");await create_timer(0.3,true).timeout
  var original: Dictionary=saver.read_save_data("checkpoint").data.duplicate(true)
  bridge.mode="drop";session.continue_saved_game();var before: Node=current_scene
  await go_level()
  check(current_scene==before and not paused,"network timeout leaves old scene interactive")
  check(saver.read_save_data("checkpoint").data==original,"network timeout preserves checkpoint exactly")
  check(transition.get_node_or_null("PaidRunNotice")!=null,"network failure explains recovery")
  check(not bool(paid.busy),"paused timeout releases transport")
  bridge.mode="cancel";session.continue_saved_game();await go_level()
  check(current_scene==before,"server cancellation cannot start combat")
  check(not FileAccess.file_exists(paid._journal_path()),"cancelled Continue clears journal so account is not stuck")
  check(saver.read_save_data("checkpoint").data==original,"server cancellation preserves checkpoint")
  bridge.mode="";paid.test_binding="b".repeat(64)
  var requests: int=bridge.calls.size()
  check(not await paid.prepare_scene_run(true),"different account cannot resume saved run")
  check(bridge.calls.size()==requests,"account mismatch fails before transport")
  paid.test_binding="a".repeat(64)
  var local: Dictionary=original.duplicate(true);local.erase("paid_run_ref")
  saver.write_save_data("checkpoint",local)
  check(await paid.prepare_scene_run(true),"legacy local Continue stays supported")
  check(paid.selected_slot("armament",true)=="","legacy Continue cannot acquire today's paid hub weapon")
  saver.write_save_data("checkpoint",original)
 else:
  bridge.state=initial_state();paid.snapshot=bridge.state.duplicate(true);paid._expires=Time.get_ticks_msec()+120000
  equipment.weapon_levels["jade_binding_chain"]=12
  session.start_new_game();root.get_node("JourneyManager").begin_selected_stage()
  await go_level();await settle_game()
  check(starter_id().ends_with("jade_binding_chain_weapon.gd"),"new run uses locked paid starter on first frame")
  check(equipment.get_item_weapon_level("jade_binding_chain")==12,"new run freezes local earned weapon level")
  check(current_scene.get_node("CheckPointManager").save_checkpoint(),"actual checkpoint commits")
  var data: Dictionary=saver.read_save_data("checkpoint").data
  check(Paid.valid_run_ref(data.get("paid_run_ref")),"checkpoint stores valid opaque account-bound reference")
  check(data.paid_run_ref.size()==3 and not data.paid_run_ref.has("slots"),"reference cannot assert ownership")
  check(bridge.runs.size()==1 and bridge.state.wallet.balance==1500,"one run record; no additional Jade debit")
  var frozen: Dictionary=bridge.runs.values()[0]
  var bad: Dictionary=frozen.duplicate(true);bad.slots.armament="void_piercer_spear"
  check(not Paid.valid_run_outcome(bad,bridge.state,frozen.run_id),"unowned forged starter rejected")
  bad=frozen.duplicate(true);bad.stars.jade_binding_chain=6
  check(not Paid.valid_run_outcome(bad,bridge.state,frozen.run_id),"invalid frozen stars rejected")
  check(not Paid.valid_run_ref({"version":1,"binding":"a".repeat(64),"run_id":"bad"}),"invalid checkpoint reference rejected")
  # Retry from an existing gameplay scene must read next-run levels, not old runtime levels.
  equipment.weapon_levels["jade_binding_chain"]=25;session.start_new_game()
  await go_level();await settle_game()
  check(equipment.get_item_weapon_level("jade_binding_chain")==25,"new run from old scene uses next-run level25")
  check(bridge.runs.size()==2 and bridge.state.wallet.balance==1500,"retry creates separate run record without charging")
  change_scene_to_file("res://scenes/ui/main_menu.tscn");await create_timer(0.3,true).timeout
  saver.write_save_data("checkpoint",data)
  bridge.state.slots.armament="";bridge.state.slots.boots="";bridge.state.stars.jade_binding_chain=4
  equipment.weapon_levels["jade_binding_chain"]=25;equipment.save_equipment()
  var file:=FileAccess.open(REF_FILE,FileAccess.WRITE);file.store_string(JSON.stringify({"state":bridge.state,"runs":bridge.runs}));file.close()
 await end_test()
