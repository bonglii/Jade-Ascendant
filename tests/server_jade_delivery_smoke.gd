extends SceneTree
const View=preload("res://scripts/monetization/server_jade_recovery_view.gd")
var checks:int=0
var failures:int=0
class Bridge extends Node:
 var reads:Array[String]=[]
 var repairs:Array[String]=[]
 func refreshPaidWalletSnapshotV2(id:String)->void:reads.append(id)
 func repairVerifiedPlayPurchasesV2(id:String)->void:repairs.append(id)
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 if not OS.get_user_data_dir().contains("jade_server_delivery_qa"):quit(2);return
 var view=View.new();view.bind_owner("a")
 check(view.snapshot(0).balance==-1,"unknown is not zero")
 check(not view.accept("b",{"status":"ready","balance":100,"revision":1},0),"owner isolation")
 check(view.accept("a",{"status":"ready","balance":100,"revision":1},0),"verified balance")
 check(not view.accept("a",{"status":"ready","balance":50,"revision":0},1),"revision rollback")
 check(not view.accept("a",{"status":"ready","balance":99,"revision":1},1),"same revision conflict")
 check(not view.snapshot(120001).confirmed,"stale expires")
 check(not view.snapshot(1).can_spend,"display cannot spend")
 for bad:Variant in [true,"100",-1,0.5,INF,NAN]:
  check(not view.accept("a",{"status":"ready","balance":bad,"revision":2},2),"invalid amount")
 view.bind_owner("b");check(view.snapshot(2).balance==-1,"account clears old balance")
 var repair:Dictionary={"repair_contract_version":1,"state":"server_reconciled","verified_purchases":1,"new_wallet_credits":1}
 check(not View.parse_repair(JSON.stringify(repair)).is_empty(),"valid repair")
 repair.new_wallet_credits=2;check(View.parse_repair(JSON.stringify(repair)).is_empty(),"repair count bounds")
 var manager=load("res://tests/fixtures/server_jade_manager.gd").new();var bridge=Bridge.new();root.add_child(bridge);root.add_child(manager)
 manager.test_owner="a";manager.test_bridge=bridge
 var local_before:int=manager.get_celestial_jade()
 check(manager.request_server_jade_snapshot(),"read starts")
 check(not manager.request_server_jade_snapshot(),"spam coalesces")
 var id:String=bridge.reads[-1]
 manager._on_server_wallet_v2("wrong",false,"","")
 check(manager._server_read_id==id,"foreign callback ignored")
 var payload:String=JSON.stringify({"hybrid_policy_version":1,"paid_wallet":{"currency":"celestial_jade","authority":"server","balance":100,"revision":1},"local_wallet_authority":"device_only_untrusted","legacy_wallet_migration":"requires_explicit_reconciliation"})
 manager._on_server_wallet_v2(id,true,"WALLET_SNAPSHOT_READ_ONLY",payload)
 check(manager.get_server_jade_view().balance==100,"actual manager publishes server balance")
 check(manager.get_celestial_jade()==local_before,"no fabricated local grant")
 manager.request_server_jade_snapshot();id=bridge.reads[-1];manager.test_owner="b"
 manager._on_server_wallet_v2(id,true,"WALLET_SNAPSHOT_READ_ONLY",payload)
 check(manager.get_server_jade_view().balance==-1,"late account response rejected")
 check(manager.recover_server_jade(),"repair starts")
 check(not manager.recover_server_jade(),"repair spam coalesces")
 manager._on_server_repair_v2(bridge.repairs[-1],true,"SERVER_LEDGER_RECONCILED",JSON.stringify({"repair_contract_version":1,"state":"server_reconciled","verified_purchases":1,"new_wallet_credits":1}))
 check(bridge.reads.size()==3,"repair refreshes server balance")
 id=manager._server_read_id;manager._server_recovery_timeout("old",false)
 check(manager._server_read_id==id,"old timeout cannot cancel new read")
 manager._server_recovery_timeout(id,false)
 check(manager._server_read_id.is_empty(),"current timeout clears busy")
 var treasury=load("res://scripts/ui/liveops/celestial_treasury_screen.gd").new();root.add_child(treasury)
 treasury._on_purchase_state_changed("jade_pouch_100","pending","Pending")
 check(not treasury._purchase_busy and "jade_pouch_100" in treasury._pending_products,"pending leaves recovery accessible")
 treasury._on_purchase_delivery_finished("jade_pouch_100",true,"")
 check(treasury._billing_message.contains("SERVER WALLET") and not treasury._billing_message.contains("REWARD DELIVERED"),"no false local delivery copy")
 check(treasury._subtitle.text.contains("UNCONFIRMED"),"unknown paid balance not zero")
 treasury._layout_ui()
 check(treasury._subtitle.text.contains("UNCONFIRMED"),"resize retains live balance disclosure")
 treasury.queue_free()
 manager.queue_free();bridge.queue_free()
 print("SERVER_JADE_DELIVERY checks=%d failures=%d"%[checks,failures]);await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0)
