extends SceneTree
class Ad extends RewardedAd:
 var received: Dictionary={}
 var shown: bool=false
 var destroyed: bool=false
 func _init()->void: super(771)
 func register_callbacks()->void: pass
 func set_server_side_verification_options(options: ServerSideVerificationOptions): received=options.convert_to_dictionary()
 func show(_listener: OnUserEarnedRewardListener=OnUserEarnedRewardListener.new())->void: shown=true
 func destroy()->void: destroyed=true
class Store extends RefCounted:
 func save_state(_value: Dictionary)->bool: return true
func _initialize()->void: call_deferred("run")
func check(value: bool,why: String)->void:
 if not value: push_error(why);quit(1)
func run()->void:
 var provider: Node=load("res://tests/fixtures/odyssey_provider_probe.gd").new();provider._consent_gate_open=true;provider._ads_initialized=true;provider._slot("dice").loading=false
 var ad:=Ad.new();provider._slot("dice").loading=true;provider._on_rewarded_loaded(ad,0,"dice",0);check(provider._slot("dice").ad==ad,"Actual SDK wrapper accepts loaded ad")
 var nonce: String="a".repeat(32);provider.prepare_odyssey_ssv(nonce);provider.show_rewarded(7,"odyssey_roll")
 check(ad.shown and ad.received.custom_data==nonce and ad.received.user_id==nonce,"SDK options carry the exact server nonce and a nonempty opaque optional identity")
 var manager: Node=load("res://scripts/managers/monetization_manager.gd").new();manager.provider=provider;manager.policy_store=Store.new();manager.active_request=7;manager.active_placement="odyssey_roll";manager.active_grant_id="b".repeat(32);manager.timeout_left=90.0
 manager._process(100.0);check(manager.active_request==7,"A valid video longer than 90 seconds must not lose its callback")
 provider._on_user_earned_reward(null,7);provider._on_rewarded_dismissed(7);provider._finalize_rewarded_dismissal(7)
 check(ad.destroyed and provider._active_request_id<0 and provider.loads==4,"Dismissal releases SDK state and preloads the next ad once")
 var expired:=Ad.new();provider._slot("dice").ad=expired;provider._slot("dice").loaded_at=provider.clock-56*60*1000;provider._slot("dice").loading=false;provider.warm_rewarded_ad()
 check(expired.destroyed and provider._slot("dice").ad==null and provider.loads==5,"Expired cached ad is replaced before another tap")
 manager.free();provider.free();await process_frame
 # SDK desktop preview caches Node mocks outside the scene tree; release only this test's mocks.
 var factory: GDScript=load("res://addons/admob/internal/mock/mock_admob_factory.gd")
 RewardedAd._plugin=null
 for mock: Variant in factory._mocks.values():
  if is_instance_valid(mock): mock.free()
 factory._mocks.clear()
 print("ODYSSEY_AD_PROVIDER=PASS; REAL_SDK_GDSCRIPT; NONEMPTY_SSV; LONG_VIDEO; DISMISS; CACHE_EXPIRY")
 quit()
