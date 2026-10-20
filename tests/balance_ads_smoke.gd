extends SceneTree
const Provider = preload("res://tests/admob_reward_fence_fixture.gd")
const Economy = preload("res://scripts/data/economy_catalog.gd")
class FakeAd extends RewardedAd:
 var listener: OnUserEarnedRewardListener
 var destroys: int = 0
 func _init(): super(0)
 func show(value := OnUserEarnedRewardListener.new()) -> void: listener=value
 func destroy() -> void: destroys+=1
var checks: int=0
var failures: int=0
var earned: Array[int]=[]
var ended: Array[String]=[]
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error("BALANCE_ADS_FAIL "+label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_balance_qa"): quit(2);return
 await process_frame
 var p: Node=Provider.new()
 root.add_child(p)
 p.reward_confirmed.connect(func(id: int):earned.append(id))
 p.request_finished.connect(func(id: int,status: String):ended.append(str(id)+":"+status))
 var ad: FakeAd=FakeAd.new()
 p._slot("pavilion").ad=ad;p.show_rewarded(101,"pavilion_seal")
 check(p._active_request_id==101,"production show installs active request")
 var old_listener: OnUserEarnedRewardListener=ad.listener
 var old_callback: FullScreenContentCallback=ad.full_screen_content_callback
 old_listener.on_user_earned_reward.call(null)
 old_listener.on_user_earned_reward.call(null)
 check(earned==[101],"duplicate earned is credited once")
 old_callback.on_ad_dismissed_full_screen_content.call()
 check(p._active_request_id==101,"close drains queued callbacks before finalize")
 await process_frame
 check(ended==["101:completed"],"earned completion")
 check(ad.destroys==1,"ad destroyed once")
 var next_ad: FakeAd=FakeAd.new()
 p._slot("pavilion").loading=false;p._slot("pavilion").ad=next_ad;p.show_rewarded(102,"pavilion_seal")
 old_listener.on_user_earned_reward.call(null)
 old_callback.on_ad_dismissed_full_screen_content.call()
 old_callback.on_ad_failed_to_show_full_screen_content.call(null)
 check(earned==[101],"stale reward cannot credit next ad")
 check(p._active_request_id==102,"stale close/failure cannot close next ad")
 check(next_ad.destroys==0,"stale callbacks cannot destroy next ad")
 next_ad.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
 next_ad.listener.on_user_earned_reward.call(null)
 await process_frame
 check(earned==[101,102],"same-request earned queued with close accepted")
 check(ended[-1]=="102:completed","queued-earned completion")
 next_ad.listener.on_user_earned_reward.call(null)
 check(earned.size()==2,"post-finalization reward rejected")
 var cancelled: FakeAd=FakeAd.new()
 p._slot("pavilion").loading=false;p._slot("pavilion").ad=cancelled;p.show_rewarded(103,"pavilion_seal")
 cancelled.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
 await process_frame
 check(ended[-1]=="103:cancelled" and earned.size()==2,"close without earned gives no reward")
 var failed: FakeAd=FakeAd.new()
 p._slot("pavilion").loading=false;p._slot("pavilion").ad=failed;p.show_rewarded(104,"pavilion_seal")
 failed.full_screen_content_callback.on_ad_failed_to_show_full_screen_content.call(null)
 failed.listener.on_user_earned_reward.call(null)
 check(ended[-1]=="104:failed" and earned.size()==2,"failed show gives no reward")
 check(p._is_valid_rewarded_id(p.TEST_REWARDED_AD_UNIT_ID),"test unit syntax")
 check(not p._is_valid_rewarded_id("invalid"),"invalid unit rejected")
 var status: Dictionary=p.get_runtime_status()
 check(not status.has("grant_id") and not status.has("token") and not status.has("ad_unit_id"),"safe diagnostic status")
 check(Economy.REWARDED_AD_MAX_PER_CYCLE==7,"seven rewards per active cycle")
 check(Economy.REWARDED_AD_SEALS==1,"one seal per reward")
 var level: Node=load("res://scenes/levels/level_1.tscn").instantiate()
 var health: Node=level.get_node("player_1/PlayerHealth")
 check(health.max_health==100.0,"authored scene HP100")
 check(health.BODY_REFINEMENT_HP_PER_LEVEL==5.0,"body refinement five")
 check(health.BLOOD_QI_HEAL_AMOUNT==2.0,"blood qi two")
 var manager: Node=root.get_node("MonetizationManager")
 var pavilion: Node=root.get_node("PavilionManager")
 manager.placement_counts.clear();manager.last_reward_unix=0;manager.last_reward_at=-manager.REWARD_COOLDOWN_MSEC
 pavilion.state["rewarded_ads_claimed_in_cycle"]=0
 check(manager.use_test_provider(load("res://scripts/monetization/debug_provider.gd").new()),"test provider attached only in QA")
 var seals_before: int=pavilion.get_pavilion_seals()
 check(manager.show_rewarded("pavilion_seal"),"manager requests reward")
 await process_frame
 check(pavilion.get_pavilion_seals()==seals_before+1,"real durable bridge grants one seal despite duplicate earned")
 check(pavilion.state.rewarded_ads_claimed_in_cycle==1,"one cycle use recorded")
 check(manager.get_rewarded_daily_limit("pavilion_seal")==1,"one daily cap")
 check(not manager.show_rewarded("pavilion_seal"),"daily cap blocks second request")
 level.free();p.queue_free()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 await process_frame
 var factory: GDScript=load("res://addons/admob/internal/mock/mock_admob_factory.gd")
 RewardedAd._plugin=null
 RewardedAdLoader._plugin=null
 for mock: Variant in factory._mocks.values():
  if is_instance_valid(mock): mock.free()
 factory._mocks.clear()
 await process_frame
 print("BALANCE_ADS_SMOKE checks=",checks," failures=",failures)
 call_deferred("quit", 1 if failures else 0)
