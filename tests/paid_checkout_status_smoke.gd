extends SceneTree
const Paid = preload("res://scripts/monetization/paid_gameplay_v2.gd")
const Fixture = preload("res://tests/fixtures/paid_gameplay_manager_v2.gd")
class Bridge extends Node:
 var id: String=""
 func requestPaidGameplayV2(request_id: String,_raw: String) -> void: id=request_id
func _initialize() -> void: call_deferred("run")
func run() -> void:
 if not OS.get_user_data_dir().contains("JadeRefundCheckoutQA-") and not OS.get_user_data_dir().ends_with("jade_refund_checkout_qa"): quit(2); return
 create_timer(10).timeout.connect(func() -> void: quit(1))
 var manager: Node=Fixture.new();var bridge:=Bridge.new();root.add_child(bridge);root.add_child(manager)
 manager.set("test_bridge",bridge);manager.set("_binding","a".repeat(64))
 assert(Paid.local_catalog_hash()==Paid.HASH)
 assert(manager.call("refresh")); assert(manager.get("status")=="loading")
 manager.call("_on_result",bridge.id,false,"ACCOUNT_HELD","")
 assert(manager.get("status")=="account_held");assert(manager.get("last_transport_stage")=="ACCOUNT_HELD")
 assert(not manager.call("checkout_ready"));assert(int(manager.get("_next_read"))-Time.get_ticks_msec()>59000)
 assert(manager.call("refresh"));var active_id: String=bridge.id
 manager.call("_on_result","foreign",false,"FORBIDDEN","");assert(manager.get("busy"));assert(manager.get("last_transport_stage")=="request_in_flight")
 var value: Dictionary={"paid_gameplay_version":2,"account_binding":"a".repeat(64),"catalog_hash":Paid.HASH,"state":"ready","revision":0,"wallet":{"balance":0,"revision":2},"inventory":{},"stars":{},"slots":{"armament":"","robe":"","bracer":"","boots":"","pendant":""},"pity":{"rare_plus":0,"epic_plus":0,"legendary":0},"wish":"","wish_guaranteed":false,"lifetime_pulls":0,"rates":{"common":6000,"rare":2900,"epic":900,"legendary":200},"lease_seconds":120}
 manager.call("_on_result",active_id,true,"PAID_GAMEPLAY_VERIFIED",JSON.stringify({"snapshot":value,"operation":null}))
 assert(manager.call("checkout_ready"));assert(manager.call("paid_balance")==0);assert(manager.get("last_transport_stage")=="PAID_GAMEPLAY_VERIFIED")
 assert(manager.call("refresh"));manager.call("_on_result",bridge.id,false,"BACKEND_NOT_READY","")
 assert(manager.get("status")=="verification_unavailable");assert(manager.get("last_transport_stage")=="BACKEND_NOT_READY");assert(not manager.call("checkout_ready"))
 var cmd: Dictionary={"request_id":"11111111-1111-4111-8111-111111111111","expected_revision":0,"kind":"wish","item_id":""}
 assert(manager.call("_persist",cmd));assert(manager.call("refresh"));manager.call("_on_result",bridge.id,false,"ACCOUNT_HELD","")
 assert(manager.call("_read_pending")==cmd)
 var journal: String=manager.call("_journal_path");assert(DirAccess.remove_absolute(journal)==OK)
 assert(manager.call("refresh"));manager.set("_deadline",0);manager.set("_next_read",Time.get_ticks_msec()+60000);manager.call("_process",1.0)
 assert(manager.get("status")=="request_timeout");assert(manager.get("last_transport_stage")=="REQUEST_TIMEOUT");assert(not manager.get("busy"))
 manager.queue_free();bridge.queue_free();await process_frame
 print("PAID_CHECKOUT_STATUS=PASS; HELD_REASON; ZERO_BALANCE_RECOVERY; FOREIGN_CALLBACK_FENCE; PENDING_JOURNAL_PRESERVED; BACKEND_FAILURE; TIMEOUT")
 quit()
