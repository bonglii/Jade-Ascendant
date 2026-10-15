extends SceneTree
const Paid = preload("res://scripts/monetization/paid_gameplay_v2.gd")
const Fixture = preload("res://tests/fixtures/paid_gameplay_manager_v2.gd")
var checks: int=0
var failures: int=0
var watchdog: Timer
class Bridge extends Node:
 var id: String=""
 var body: String=""
 func requestPaidGameplayV2(request_id: String, raw: String) -> void:
  id=request_id;body=raw
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error("PAID_V2_QA "+message)
func state(binding: String="") -> Dictionary:
 if binding.is_empty(): binding="a".repeat(64)
 return {"paid_gameplay_version":2,"account_binding":binding,"catalog_hash":Paid.HASH,"state":"ready","revision":0,"wallet":{"balance":1500,"revision":1},"inventory":{"cloudstep_boots":9},"stars":{"cloudstep_boots":2},"slots":{"armament":"","robe":"","bracer":"","boots":"cloudstep_boots","pendant":""},"pity":{"rare_plus":0,"epic_plus":10,"legendary":10},"wish":"","wish_guaranteed":false,"lifetime_pulls":10,"rates":{"common":6000,"rare":2900,"epic":900,"legendary":200},"lease_seconds":120}
func reply(manager: Node, bridge: Bridge, snapshot: Dictionary, op: Variant=null) -> void:
 manager.call("_on_result",bridge.id,true,"PAID_GAMEPLAY_VERIFIED",JSON.stringify({"snapshot":snapshot,"operation":op}))
func _on_deadline() -> void:
 push_error("PAID_V2_QA aborted after 25 seconds; inspect the first preceding script error")
 quit(1)
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_paid_v2_qa"): quit(2);return
 watchdog=Timer.new();watchdog.one_shot=true;watchdog.wait_time=25
 root.add_child(watchdog);watchdog.timeout.connect(_on_deadline);watchdog.start()
 await process_frame
 var pavilion: Node=root.get_node("PavilionManager")
 var equipment: Node=root.get_node("EquipmentManager")
 var inventory: Node=root.get_node("InventoryManager")
 var saver: Node=root.get_node("SaveManager")
 check(Paid.local_catalog_hash()==Paid.HASH,"shipping catalog pin")
 var good: Dictionary=state()
 check(Paid.valid_snapshot(good,"a".repeat(64)),"known valid contract")
 var decoded: Variant=JSON.parse_string(JSON.stringify(good))
 check(Paid.valid_snapshot(decoded,"a".repeat(64)),"actual Godot JSON floating-number decoding")
 check(not Paid.valid_snapshot(good,"b".repeat(64)),"account isolation")
 for v: Variant in [-1,0.5,true,"1500",INF,NAN]:
  var bad: Dictionary=good.duplicate(true);bad.wallet.balance=v
  check(not Paid.valid_snapshot(bad,"a".repeat(64)),"invalid wallet value")
 var bad: Dictionary=good.duplicate(true);bad.slots.armament="cloudstep_boots"
 check(not Paid.valid_snapshot(bad,"a".repeat(64)),"slot boundary")
 bad=good.duplicate(true);bad.stars.cloudstep_boots=6
 check(not Paid.valid_snapshot(bad,"a".repeat(64)),"max stars")
 bad=good.duplicate(true);bad.rates.common=6001
 check(not Paid.valid_snapshot(bad,"a".repeat(64)),"fixed odds")
 bad=good.duplicate(true);bad.state="unfunded"
 check(not Paid.valid_snapshot(bad,"a".repeat(64)),"unfunded cannot assert ownership")
 bad=good.duplicate(true);bad.inventory.fake_item=1;bad.stars.fake_item=1
 check(not Paid.valid_snapshot(bad,"a".repeat(64)),"unknown equipment")
 var manager: Node=Fixture.new();var bridge:=Bridge.new();root.add_child(bridge);root.add_child(manager)
 manager.set("test_bridge",bridge);manager.set("_binding","a".repeat(64))
 var journal: String=manager.call("_journal_path")
 check(not FileAccess.file_exists(journal),"isolated empty journal")
 check(manager.call("refresh"),"read dispatch")
 manager.call("_on_result","foreign",true,"PAID_GAMEPLAY_VERIFIED",JSON.stringify({"snapshot":good,"operation":null}))
 check(bool(manager.get("busy")),"foreign callback ignored")
 reply(manager,bridge,good)
 check(manager.call("checkout_ready"),"verified read unlocks candidate checkout")
 check(int(manager.call("paid_balance"))==1500,"wallet display")
 var cmd: Dictionary={"request_id":"11111111-1111-4111-8111-111111111111","expected_revision":0,"kind":"refine","item_id":"cloudstep_boots"}
 check(Paid.valid_command(cmd),"known valid command")
 var wrong: Dictionary=cmd.duplicate();wrong.balance=9999
 check(not Paid.valid_command(wrong),"client balance is forbidden in commands")
 wrong=cmd.duplicate();wrong.item_id="fake_item"
 check(not Paid.valid_command(wrong),"unknown command item")
 var immediate: Dictionary={"request_id":"22222222-2222-4222-8222-222222222222","expected_revision":0,"kind":"wish","item_id":""}
 check(manager.call("_persist",immediate),"persist initial command")
 check(manager.call("_read_pending")==immediate,"journal restores canonical integer fields")
 check(manager.call("_dispatch",immediate),"initial command dispatch")
 reply(manager,bridge,good,{"request_id":immediate.request_id,"kind":"wish","outcome":null})
 check(not FileAccess.file_exists(journal) and manager.call("checkout_ready"),"initial integer command receipt retires journal")
 check(Paid.canonical_command(JSON.parse_string(JSON.stringify(cmd)))==cmd,"JSON command numbers canonicalized")
 check(manager.call("_persist",cmd),"durable command journal")
 check(not manager.call("_persist",cmd),"second pending command refused")
 check(manager.call("refresh"),"pending resumes identical request")
 check(bridge.id==cmd.request_id and bridge.body==JSON.stringify(cmd),"replay identity preserved")
 manager.set("_next_read",Time.get_ticks_msec()+60000);manager.set("_deadline",0);manager.call("_process",1.0)
 check(not bool(manager.get("busy")),"timeout releases UI")
 check(FileAccess.file_exists(journal),"timeout retains retry evidence")
 check(manager.call("refresh"),"recovery after timeout")
 var updated: Dictionary=good.duplicate(true);updated.revision=1;updated.inventory.cloudstep_boots=8;updated.stars.cloudstep_boots=3
 reply(manager,bridge,updated,{"request_id":cmd.request_id,"kind":"refine","outcome":null})
 check(not FileAccess.file_exists(journal),"only matching server receipt retires pending command")
 check(int(manager.call("item_star","cloudstep_boots"))==3,"confirmed stars")
 var original: Node=pavilion.paid_gameplay;pavilion.paid_gameplay=manager
 var host:=Control.new();root.add_child(host)
 for dimensions: Vector2 in [Vector2(320,568),Vector2(390,844),Vector2(648,1152),Vector2(860,405)]:
  host.size=dimensions
  load("res://scripts/ui/paid_armory_panel.gd").open_for(host,"cloudstep_boots")
  await process_frame;await process_frame
  var panel: Control=host.get_node("ServerArmory")
  panel.size=dimensions;panel.call("_fit")
  await process_frame
  var frame: Control=panel.get("_panel")
  check(frame.position.x>=0 and frame.position.y>=0 and frame.get_rect().end.x<=dimensions.x and frame.get_rect().end.y<=dimensions.y,"armory fits "+str(dimensions))
  var scroller: ScrollContainer=panel.get("_scroll")
  check(scroller.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER and scroller.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"armory scrollbar policy")
  panel.call("_close");await process_frame
 host.free()
 var local_jade: int=pavilion.get_local_celestial_jade()
 check(pavilion.get_celestial_jade()==local_jade+1500,"combined display")
 check(pavilion._save_state(),"isolated local save writes")
 var saved: Dictionary=saver.read_save_data("pavilion")
 check(saved.get("data",{}).get("celestial_jade",-1)==local_jade,"paid wallet excluded from local save")
 var local: Dictionary=equipment.equipped_item_ids.duplicate(true)
 var stars: Dictionary=equipment.ascension_stars.duplicate(true)
 var frozen: Dictionary=equipment.active_run_loadout_snapshot.duplicate(true)
 equipment.equipped_item_ids.boots="";equipment.active_run_loadout_snapshot={}
 check(equipment.get_loadout_equipped_item_id("boots")=="cloudstep_boots","actual equipment overlay")
 check(equipment.get_loadout_item_star("cloudstep_boots")==3,"actual equipment star overlay")
 var previous_count: int=inventory.get_item_count("cloudstep_boots")
 inventory._migrate_equipped_items_to_inventory()
 check(inventory.get_item_count("cloudstep_boots")==previous_count,"legacy inventory migration cannot mint paid equipment")
 var snapshot: Dictionary=equipment.build_active_run_loadout_snapshot()
 check(snapshot.equipped_item_ids.boots=="" and not snapshot.ascension_stars.has("cloudstep_boots"),"paid ownership excluded from offline run save")
 var player:=Node2D.new();root.add_child(player);player.add_to_group("player")
 check(equipment.get_runtime_equipped_item_id("boots")=="cloudstep_boots","combat reads paid loadout")
 manager.snapshot.slots.boots=""
 check(equipment.get_runtime_equipped_item_id("boots")=="cloudstep_boots","run selection frozen across remote changes")
 manager.set("_expires",0)
 check(equipment.get_runtime_equipped_item_id("boots")=="","expired lease removes paid overlay")
 player.free();pavilion.paid_gameplay=original
 equipment.equipped_item_ids=local;equipment.ascension_stars=stars;equipment.active_run_loadout_snapshot=frozen
 manager.set("test_binding","b".repeat(64));manager.set("_binding","b".repeat(64))
 check(manager.call("_read_pending").is_empty(),"another account has its own journal")
 manager.free();bridge.free()
 watchdog.stop();watchdog.free()
 print("PAID_GAMEPLAY_V2_CHECKS=",checks,"; FAILURES=",failures)
 await process_frame
 quit(0 if failures==0 else 1)
