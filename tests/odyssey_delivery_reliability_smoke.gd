extends SceneTree
class Native extends RefCounted:
 var sent: Array=[]
 func requestOdysseyV1(id: String,body: String)->void: sent.append([id,body])
class Provider extends Node:
 func rewarded_available(_placement: String)->bool: return true
class Store extends RefCounted:
 func save_state(_value: Dictionary)->bool: return true
func _initialize()->void: call_deferred("run")
func check(value: bool,reason: String)->void:
 if not value: push_error(reason);quit(1)
func data(owner: String,nonce: String,stage: String,tickets: int=3)->Dictionary:
 return {"owner_binding":owner,"server_time":1800000000,"event":{"id":"dragon-test","enabled":true,"purchases_enabled":true,"starts_at":1799999900,"ends_at":1801000000},"state":{"tickets":tickets,"daily_ads":1 if stage=="credited" else 0,"day":"2027-01-15","missions":[],"milestones":[]},"ad_delivery":{"configured":true,"nonce":nonce,"stage":stage,"expires_at":1800001200},"purchase_bonus":{"active":true}}
func run()->void:
 var manager_script: GDScript=load("res://scripts/managers/monetization_manager.gd")
 var manager: Node=manager_script.new();var provider:=Provider.new();manager.provider=provider;manager.policy_store=Store.new();manager.placement_counts={"odyssey_roll":2,"pavilion":1}
 check(manager.rewarded_available("odyssey_roll"),"Old SDK playback counts must not block server-authorized event ads")
 check(not manager.rewarded_available("pavilion"),"Other placements retain their existing daily cap")
 manager.active_request=1;manager.active_placement="odyssey_roll";manager.active_grant_id="b".repeat(32);manager._on_reward_confirmed(1)
 check(int(manager.placement_counts.odyssey_roll)==2,"SDK callback must not consume another event quota")
 manager.free();provider.free()
 var script: GDScript=load("res://tests/fixtures/odyssey_delivery_client.gd")
 var client: Node=script.new();client.native=Native.new();root.add_child(client);client.set_process(false);client._binding=client.test_binding
 var nonce: String="d".repeat(32);client.snapshot=data(client._binding,nonce,"pending");client.status="connected";client._received_msec=Time.get_ticks_msec()
 check(not client.watch_ad() and client.status=="connected","Unavailable SDK ads must not disconnect the event UI")
 client._ad_nonce=nonce;client._ad_before=0;client._ad_day="2027-01-15";client._ad_expires_at=1800001200
 check(client._save_ad_wait(),"Ad intent must be durable before playback")
 client._ad_finished("odyssey_roll","completed")
 check(int(client.snapshot.state.tickets)==3 and client.ad_waiting(),"SDK completion must never grant a die")
 client._observe_ad_delivery(data(client._binding,nonce,"pending"));check(client.ad_waiting(),"An unsigned/pending result must stay pending")
 client._observe_ad_delivery(data(client._binding,"a".repeat(32),"credited",4));check(client.ad_waiting(),"Another receipt must not settle the current ad")
 check(client.refresh(),"Verification should request a server read")
 check(client.status=="refreshing" and client._command.is_empty() and client.native.sent[-1][1]=="","Polling must be a read, never another ad intent")
 client._on_result(client._request_id,true,"ok",JSON.stringify(data(client._binding,nonce,"pending")))
 check(not client.busy and client.status=="connected" and client.ad_waiting(),"Pending read keeps stable confirmed presentation")
 var restored: Node=script.new();restored.native=Native.new();root.add_child(restored);restored.set_process(false);restored._binding=restored.test_binding;restored._load_ad_wait()
 check(restored.ad_waiting() and restored._ad_nonce==nonce,"Restart must restore the same pending nonce without playback")
 restored.snapshot=data(restored._binding,nonce,"pending");restored._received_msec=Time.get_ticks_msec();restored.refresh()
 restored._on_result(restored._request_id,true,"ok",JSON.stringify(data(restored._binding,nonce,"credited",4)))
 check(int(restored.snapshot.state.tickets)==4 and not restored.ad_waiting() and restored.ad_delivery_state=="credited","Only the authoritative credited snapshot settles the die")
 check(not FileAccess.file_exists(restored._ad_path()),"Confirmed receipt removes only its pending-ad journal")
 restored.status="refreshing";check(restored.purchase_bonus_active(),"Read-only polling must not hide top-up offers")
 restored._ad_nonce=nonce;restored._ad_expires_at=1800001200;restored._save_ad_wait();restored.test_binding="f".repeat(64);restored._process(0)
 check(not restored.ad_waiting(),"Account switch must not leak another owner's ad wait")
 client._clear_ad_wait();client.queue_free();restored.queue_free();await process_frame
 print("ODYSSEY_DELIVERY_RELIABILITY=PASS; NO_LOCAL_GRANT; RECEIPT_MATCH; RESTART_RECOVERY; READ_ONLY_POLL; BONUS_STABILITY; ACCOUNT_FENCE")
 quit()
