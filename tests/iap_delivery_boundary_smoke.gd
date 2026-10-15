extends SceneTree
var checks:int=0
var failures:int=0
class Bridge extends Node:
 var reads:Array[String]=[]
 var repairs:Array[String]=[]
 func refreshPaidWalletSnapshotV2(id:String)->void:reads.append(id)
 func repairVerifiedPlayPurchasesV2(id:String)->void:repairs.append(id)
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func run()->void:
 if not OS.get_user_data_dir().contains("jade_iap_boundary_qa"):quit(2);return
 await process_frame
 var manager:Node=load("res://tests/fixtures/server_jade_manager.gd").new();var bridge:=Bridge.new()
 root.add_child(bridge);root.add_child(manager);manager.test_owner="a".repeat(64);manager.test_bridge=bridge
 var before:Dictionary=manager.state.duplicate(true)
 var results:Array[String]=[];manager.billing_purchase_state_changed.connect(func(_id:String,status:String,_text:String):results.append(status))
 check(not manager.purchase_iap("jade_pouch_100"),"checkout cannot sell unsupported fulfillment")
 check(results==["delivery_not_ready"],"specific checkout reason")
 check(not manager.get_paid_delivery_readiness().ready,"delivery gate is independent of native billing")
 check(manager.get_paid_delivery_readiness().recovery_available,"ledger recovery remains available")
 check(not is_instance_valid(manager.billing_provider),"fixture has no Play provider")
 manager.restore_iap_purchases()
 check(bridge.repairs.size()==1 and bridge.reads.size()==1,"consumed purchase recovery works without Play client")
 manager.restore_iap_purchases()
 check(bridge.repairs.size()==1 and bridge.reads.size()==1,"spam coalesces independent recovery")
 var id:String=bridge.repairs[-1]
 manager._on_server_repair_v2(id,false,"FORBIDDEN","")
 check(manager.get_server_jade_view().repair_stage=="FORBIDDEN","tester account denial is not mislabeled timeout")
 check(manager.get_server_jade_view().account_ref=="a".repeat(12),"safe account hash prefix correlates diagnosis")
 manager.recover_server_jade();id=bridge.repairs[-1]
 var repair_events:Array[String]=[];manager.paid_verified_purchase_repair_changed.connect(func(view:Dictionary):repair_events.append(view.status))
 manager._server_recovery_timeout(id,true)
 check(repair_events==["timeout"] and manager.get_server_jade_view().repair_stage=="REQUEST_TIMEOUT","repair timeout releases UI with reason")
 manager.recover_server_jade();var new_id:String=bridge.repairs[-1]
 manager._server_recovery_timeout(id,true)
 check(manager._server_repair_id==new_id,"late timeout cannot cancel next recovery")
 manager.test_owner="b".repeat(64)
 manager._on_server_repair_v2(new_id,true,"SERVER_LEDGER_RECONCILED",JSON.stringify({"repair_contract_version":1,"state":"server_reconciled","verified_purchases":1,"new_wallet_credits":1}))
 check(manager.get_server_jade_view().balance==-1,"account switch rejects previous repair balance")
 check(manager.state==before,"recovery never invents local credit or edits save")
 var treasury:Node=load("res://scripts/ui/liveops/celestial_treasury_screen.gd").new();root.add_child(treasury)
 treasury._on_server_repair_changed({"status":"reconciled","verified_purchases":1,"new_wallet_credits":0})
 check(treasury._billing_message.contains("1 verified") and treasury._billing_message.contains("0 credits recovered"),"replay is not a second reward")
 treasury._on_server_repair_changed({"status":"timeout"})
 check(treasury._billing_message.contains("do not purchase again"),"timeout guides recovery rather than another charge")
 treasury.queue_free();manager.queue_free();bridge.queue_free();await process_frame
 print("IAP_DELIVERY_BOUNDARY checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
