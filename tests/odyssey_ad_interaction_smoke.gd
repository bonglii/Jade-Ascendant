extends SceneTree
class Ads extends Node:
 signal rewarded_request_finished(placement: String,result: String)
 signal rewarded_completed(placement: String)
 var provider: Node
 var available: bool=false
 var cooldown: int=0
 var showing: bool=false
 func rewarded_available(_placement: String)->bool: return available and cooldown==0
 func get_rewarded_policy_status(_placement: String)->Dictionary: return {"cooldown_remaining_seconds":cooldown}
 func is_rewarded_request_active(_placement: String)->bool: return showing
class Warm extends Node:
 var calls: int=0
 func warm_rewarded_ad()->void: calls+=1
class Native extends RefCounted:
 var sent: Array=[]
 func requestOdysseyV1(id: String,body: String)->void: sent.append([id,body])
func _initialize()->void: call_deferred("run")
func check(value: bool,why: String)->void:
 if not value: push_error(why);quit(1)
func sample(owner: String,nonce: String,stage: String,used: int=0)->Dictionary:
 return {"owner_binding":owner,"server_time":1800000000,"event":{"id":"dragon-test","enabled":true,"ads_enabled":true,"starts_at":1799999900,"ends_at":1801000000},"state":{"tickets":3+used,"daily_ads":used,"day":"2027-01-15","missions":[],"milestones":[],"ad_delivery":{"configured":true,"stage":stage,"nonce":nonce,"expires_at":1800001200}}}
func run()->void:
 var ads:=Ads.new();ads.name="MonetizationManager";var warm:=Warm.new();ads.provider=warm;ads.add_child(warm);root.add_child(ads)
 var client: Node=load("res://tests/fixtures/odyssey_delivery_client.gd").new();client.native=Native.new();client.name="OdysseyClient";root.add_child(client);client.set_process(false);client._binding=client.test_binding;client._setup_ads()
 var nonce: String="d".repeat(32);client.snapshot=sample(client._binding,nonce,"none");client._received_msec=Time.get_ticks_msec();client.status="connected"
 check(not client.ad_control().enabled and "DISIAPKAN" in client.ad_control().text and warm.calls>0,"An unloaded SDK ad must visibly preload instead of promising instant playback")
 ads.available=true;ads.cooldown=3;check(not client.ad_control().enabled and "3s" in client.ad_control().text,"Cooldown must explain why another ad cannot start")
 ads.cooldown=0;check(client.ad_control().enabled,"Loaded ad becomes available without server polling")
 client.snapshot.state.daily_ads=2;check(not client.ad_control().enabled and "2/2" in client.ad_control().text,"Daily cap must be explicit")
 check(not client.watch_ad() and client.native.sent.is_empty(),"Third ad must never request a new server intent after two confirmed rewards")
 client.snapshot.state.daily_ads=0;client._ad_nonce=nonce;client._ad_before=0;client._ad_day="2027-01-15";client._ad_expires_at=1800001200
 ads.rewarded_completed.emit("odyssey_roll")
 check(client.ad_waiting() and client._read_at==0 and client.get_ad_reward_notice().is_empty() and int(client.snapshot.state.tickets)==3,"SDK earned starts immediate verification but never a reward notification or local die")
 ads.rewarded_request_finished.emit("odyssey_roll","cancelled");client._ad_attempts=2;client._observe_ad_delivery(sample(client._binding,nonce,"pending"))
 check(client.ad_waiting(),"A late dismiss result must not discard an earned pending reward")
 check(client.refresh(),"Receipt polling starts after SDK earned")
 client._on_result(client._request_id,true,"ok",JSON.stringify(sample(client._binding,nonce,"credited",1)))
 check(int(client.snapshot.state.tickets)==4 and not client.ad_waiting(),"Only server confirmation increases visible balance")
 var notice: Dictionary=client.get_ad_reward_notice();check(not notice.is_empty() and notice.key==nonce and notice.amount==1,"One server-confirmed die creates one explicit reward notice")
 client.acknowledge_ad_reward_notice("wrong");check(not client.get_ad_reward_notice().is_empty(),"Wrong acknowledgement cannot consume a notice")
 ads.showing=true
 var screen: Control=load("res://scripts/ui/odyssey_screen.gd").new();screen.size=Vector2(648,1152);root.add_child(screen);screen._app_focused=true
 screen._show_ad_reward_notice();check(not client.get_ad_reward_notice().is_empty(),"Server notice waits until the actual ad is dismissed")
 ads.showing=false;screen._app_focused=false;screen._show_ad_reward_notice();check(not client.get_ad_reward_notice().is_empty(),"Background app cannot consume an unseen reward notice")
 screen._app_focused=true;screen._show_ad_reward_notice();await process_frame
 check(client.get_ad_reward_notice().is_empty(),"Foreground confirmation produces the explicit banner once")
 var banners: int=0
 for node: Node in screen.safe.get_children():
  if node.get_script()!=null and node.get_script().resource_path.ends_with("odyssey_ad_reward_notice.gd"):
   banners+=1;check(node.get_global_rect().end.x<=screen.safe.get_global_rect().end.x,"Reward banner stays within the safe area")
 check(banners==1,"Exactly one reward banner is created")
 client._observe_ad_delivery(sample(client._binding,nonce,"credited",1));check(client.get_ad_reward_notice().is_empty(),"Repeated read does not repeat the reward notice")
 screen.queue_free();await process_frame
 check(client._ad_poll_delay(1)<=2000 and client._ad_poll_delay(20)<=30000,"Fast initial checks keep bounded backoff")
 client._ad_reward_notice=notice;client.test_binding="f".repeat(64);client._process(0.0);check(client.get_ad_reward_notice().is_empty(),"Account change removes another player's notice")
 client._clear_ad_wait();client.queue_free();ads.queue_free();await process_frame
 print("ODYSSEY_AD_INTERACTION=PASS; PRELOAD; COOLDOWN; THIRD_AD_BLOCK; EARLY_VERIFY; SERVER_ONLY_NOTICE; REPLAY; ACCOUNT_FENCE")
 quit()
