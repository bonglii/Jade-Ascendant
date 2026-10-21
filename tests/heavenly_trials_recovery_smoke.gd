extends SceneTree
class Bridge extends Node:
 var requests: Array[Dictionary]=[]
 func requestHeavenlyTrialsV1(request_id: String,body: String) -> void:requests.append({"id":request_id,"body":body})
class FakeAd extends RewardedAd:
 var verification: Dictionary={}
 var shown: int=0
 func _init() -> void:super(991)
 func register_callbacks() -> void:pass
 func set_server_side_verification_options(value: ServerSideVerificationOptions):verification=value.convert_to_dictionary()
 func show(_listener:=OnUserEarnedRewardListener.new()) -> void:shown+=1
 func destroy() -> void:pass
var checks: int=0
var failures: int=0
func check(value: bool,caption: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("TRIALS_RECOVERY_FAIL "+caption)
func settle(frames: int=6) -> void:
 for i: int in range(frames):await process_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_heavenly_trials_qa"):quit(2);return
 create_timer(60).timeout.connect(func():quit(1));await settle(20)
 var transport: Node=load("res://tests/fixtures/heavenly_trials_transport.gd").new();root.add_child(transport);transport.set_process(false);transport._owner=transport.simulated_binding
 var bridge:=Bridge.new();root.add_child(bridge);transport.test_bridge=bridge
 var now: int=int(Time.get_unix_time_from_system());var snapshot: Dictionary={"version":1,"owner_binding":transport.simulated_binding,"server_time":now,"week":{"id":"ht_qa_0","ends_at":now+1000},"campaign":{"enabled":true},"progress":[],"previous_progress":[]}
 transport.snapshot=snapshot;transport._received=Time.get_ticks_msec()
 if FileAccess.file_exists(transport._path()):DirAccess.remove_absolute(transport._path())
 check(transport.refresh(),"read dispatches")
 var read_id: String=transport._request
 check(transport.action("claim_all"),"explicit action queues behind background read")
 var pending: Dictionary=transport._pending();check(not pending.is_empty(),"queued action is durable before dispatch")
 transport._result(read_id,true,"VERIFIED",JSON.stringify(snapshot));await settle()
 check(bridge.requests.size()==2 and transport._request==pending.request_id,"same queued ID dispatches after read")
 transport._result(transport._request,false,"NETWORK_UNAVAILABLE","")
 check(transport._pending()==pending,"uncertain network preserves exact request")
 check(transport.refresh(),"recover retry dispatches")
 check(bridge.requests.back().id==pending.request_id,"retry never creates a new claim ID")
 transport._result(pending.request_id,true,"VERIFIED",JSON.stringify(snapshot))
 check(transport._pending().is_empty(),"verified result clears journal")
 transport.test_bridge=null
 check(transport.action("claim_all"),"durably stored action accepted even when native transport unavailable")
 check(not transport._pending().is_empty(),"transport recovery retains exact journal")
 transport.test_bridge=bridge;check(transport.refresh(),"journal dispatches after native transport recovers")
 transport._result(transport._request,true,"VERIFIED",JSON.stringify(snapshot))
 transport.busy=true;transport._request="a".repeat(32);transport.simulated_binding="bob".sha256_text();transport._result(transport._request,true,"VERIFIED",JSON.stringify(snapshot))
 check(transport._owner!="bob".sha256_text() and transport.busy,"old-owner callback is ignored")
 transport.simulated_binding="alice".sha256_text();transport.busy=false
 transport._ad_pending="c".repeat(32);check(transport._save_ad_wait(),"ad wait persisted before presentation")
 transport._ad_pending="";transport._load_ad_wait();check(transport._ad_pending=="c".repeat(32) and transport.ad_status=="verifying_reward","restart recovers pending SSV without replaying an ad")
 transport._clear_ad_wait();check(not FileAccess.file_exists(transport._ad_wait_path()),"confirmed ad clears wait file")
 var provider: Node=load("res://tests/fixtures/odyssey_provider_probe.gd").new();provider._consent_gate_open=true;provider._ads_initialized=true;provider.debug_inventory=false
 var units: Script=load("res://scripts/monetization/rewarded_unit_catalog.gd");units.trials_unit_id=""
 check(not provider.rewarded_available("heavenly_trials_bonus"),"unconfigured optional unit safely unavailable")
 check(not provider.configure_trials_unit(str(units.UNITS.dice.id)),"cannot reuse dice unit")
 check(provider.configure_trials_unit("ca-app-pub-3082528078187093/1111111111"),"dedicated owner unit config accepted")
 provider.warm_rewarded_ad("heavenly_trials_bonus");check(provider.loads==1,"new optional unit actually enters SDK load path")
 check(provider.requests[0].id.ends_with("/1111111111"),"load uses dedicated unit, no fallback")
 var ad:=FakeAd.new();provider._on_rewarded_loaded(ad,provider._load_epoch,"trials",provider._slot("trials").generation)
 provider.prepare_trials_ssv("d".repeat(32));provider.show_rewarded(7,"heavenly_trials_bonus")
 check(ad.shown==1 and str(ad.verification.get("custom_data","")).length()==32,"only trial nonce goes into Trial ad")
 check(provider._trials_ssv_nonce.is_empty() and provider._odyssey_ssv_nonce.is_empty(),"nonce is consumed and never leaks to another placement")
 provider.free();bridge.free();transport.free();units.trials_unit_id=""
 await process_frame
 var factory: GDScript=load("res://addons/admob/internal/mock/mock_admob_factory.gd")
 RewardedAd._plugin=null
 for mock: Variant in factory._mocks.values():
  if is_instance_valid(mock):mock.free()
 factory._mocks.clear()
 print("HEAVENLY_TRIALS_RECOVERY checks=",checks," failures=",failures)
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0)
