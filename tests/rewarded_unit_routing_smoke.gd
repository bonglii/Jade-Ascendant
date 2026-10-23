extends SceneTree
const Catalog = preload("res://scripts/monetization/rewarded_unit_catalog.gd")
class FakeAd extends RewardedAd:
 var destroyed: int = 0
 var shown: int = 0
 var received: Dictionary = {}
 var listener: OnUserEarnedRewardListener
 func _init(uid: int = 100) -> void: super(uid)
 func register_callbacks() -> void: pass
 func set_server_side_verification_options(options: ServerSideVerificationOptions): received = options.convert_to_dictionary()
 func show(value := OnUserEarnedRewardListener.new()) -> void: listener = value; shown += 1
 func destroy() -> void: destroyed += 1
class Store extends RefCounted:
 var value: Dictionary = {}
 func save_state(data: Dictionary) -> bool: value = data.duplicate(true); return true
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("REWARDED_UNITS " + message)
func probe() -> Node:
 var p: Node = load("res://tests/fixtures/odyssey_provider_probe.gd").new()
 p._consent_gate_open = true; p._ads_initialized = true
 return p
func complete(p: Node, unit: String, id: int) -> FakeAd:
 var ad := FakeAd.new(id)
 p._on_rewarded_loaded(ad, p._load_epoch, unit, p._slot(unit).generation)
 return ad
func run() -> void:
 if not OS.get_user_data_dir().contains("JadeShopNoticeQA-"): quit(2); return
 var ids: Dictionary = {}
 var expected: Dictionary = {"dice":"8339864838", "pavilion":"2136559730", "revive":"9686167686", "general":"9338683323"}
 for unit: String in Catalog.UNITS:
  ids[unit] = Catalog.unit_id(unit, false)
  check(str(ids[unit]).ends_with("/" + str(expected[unit])), "owner supplied ID " + unit)
  check(Catalog.unit_id(unit, true) == Catalog.TEST_UNIT, "debug uses Google test inventory " + unit)
 check(Catalog.release_configuration_valid(Catalog.APP_ID, ids), "four distinct production IDs under correct app")
 var duplicate: Dictionary = ids.duplicate(); duplicate.pavilion = duplicate.dice
 check(not Catalog.release_configuration_valid(Catalog.APP_ID, duplicate), "duplicate inventory rejected")
 var sample: Dictionary = ids.duplicate(); sample.pavilion = Catalog.TEST_UNIT
 check(not Catalog.release_configuration_valid(Catalog.APP_ID, sample), "test unit forbidden in production")
 var foreign: Dictionary = ids.duplicate(); foreign.pavilion = "ca-app-pub-1111111111111111/2136559730"
 check(not Catalog.release_configuration_valid(Catalog.APP_ID, foreign), "wrong publisher rejected")
 check(not Catalog.release_configuration_valid(Catalog.APP_ID.replace("9576090733", "9576090734"), ids), "wrong App ID rejected")
 for entry: Array in [["odyssey_roll","dice"],["pavilion_seal","pavilion"],["game_over_revive","revive"],["offline_cultivation_double","general"],["liveops_boss_hunt_double","general"],["liveops_treasure_hunt_double","general"]]:
  check(Catalog.unit_for(entry[0]) == entry[1], "shipping placement routes " + entry[0])
 for name: String in ["", "unregistered", "dao_choice_reroll"]:
  check(Catalog.unit_for(name).is_empty(), "unknown/planned placement rejected")
 # Real release resolver with a native transport double: no live ad requests.
 var release_probe: Node = probe(); release_probe.debug_inventory=false
 release_probe._warm_all_units()
 var order: Array = ["general", "pavilion", "dice", "revive"]
 check(release_probe.requests[0].id == ids.general, "launch meditation cache is warmed first")
 for i: int in range(order.size()):
  check(release_probe.requests[i].id == ids[order[i]], "actual production loader uses matching unique ID " + str(order[i]))
 release_probe.free()
 var timeout_probe: Node = probe(); timeout_probe._warm_all_units()
 var kept: Array[FakeAd] = []
 for unit: String in ["dice","pavilion","revive"]: kept.append(complete(timeout_probe,unit,400+kept.size()))
 var timed_generation: int=timeout_probe._slot("general").generation
 timeout_probe.clock += 45000; timeout_probe._process(0.0)
 check(timeout_probe._slot("general").state == "load_timeout" and not timeout_probe._slot("general").loading, "missing load callback releases only its own pending slot")
 check(timeout_probe.rewarded_available("pavilion_seal"), "loading timeout leaves unrelated cache ready")
 var late_load := FakeAd.new(450)
 timeout_probe._on_rewarded_loaded(late_load,timeout_probe._load_epoch,"general",timed_generation)
 check(late_load.destroyed == 1, "timed-out load cannot enter cache later")
 timeout_probe.clock += 15000; timeout_probe._process(0.0)
 check(timeout_probe.loads == 5 and timeout_probe._slot("general").loading,"timed-out unit retries with a fresh generation")
 timeout_probe.free()
 var p: Node = probe()
 p._warm_all_units()
 check(p.loads == 4, "one cached ad request per category")
 p._warm_all_units(); p.rewarded_available("pavilion_seal")
 check(p.loads == 4, "availability polling never duplicates a pending load")
 for request: Dictionary in p.requests:
  check(request.id == Catalog.TEST_UNIT, "mock SDK request is test ID")
 var dice: FakeAd = complete(p,"dice",201)
 var revive: FakeAd = complete(p,"revive",203)
 var general: FakeAd = complete(p,"general",204)
 p._on_rewarded_failed_to_load(null,p._load_epoch,"pavilion",p._slot("pavilion").generation)
 check(p.rewarded_available("odyssey_roll") and p.rewarded_available("game_over_revive") and p.rewarded_available("offline_cultivation_double"), "Pavilion failure leaves three other units ready")
 check(not p.rewarded_available("pavilion_seal"), "failed unit is unavailable during its backoff")
 p.clock += 14999; p._process(0.0); check(p.loads == 4,"retry waits own due time")
 p.clock += 1; p._process(0.0); check(p.loads == 5,"only failed unit retries")
 var pavilion: FakeAd = complete(p,"pavilion",202)
 check(p.rewarded_available("pavilion_seal"), "recovered unit available")
 var results: Array[String] = []; var earned: Array[int] = []
 p.request_finished.connect(func(id: int, status: String): results.append(str(id)+":"+status))
 p.reward_confirmed.connect(func(id: int): earned.append(id))
 p.show_rewarded(10,"odyssey_roll")
 check(dice.shown == 0 and results.back() == "10:unavailable", "dice cannot show without authoritative intent")
 var nonce: String = "a".repeat(32); p.prepare_odyssey_ssv(nonce); p.show_rewarded(11,"odyssey_roll")
 check(dice.shown == 1 and p._active_unit == "dice" and dice.received.custom_data == nonce, "dice uses its own ad and exact intent nonce")
 check(not p.rewarded_available("pavilion_seal") and not p.rewarded_available("game_over_revive"), "only one fullscreen video globally")
 p.show_rewarded(12,"pavilion_seal"); check(pavilion.shown == 0, "second category cannot interrupt video")
 dice.listener.on_user_earned_reward.call(null); dice.listener.on_user_earned_reward.call(null)
 dice.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
 p._finalize_rewarded_dismissal(11)
 check(earned == [11] and results.back() == "11:completed", "SDK duplicate earned credits once")
 check(dice.destroyed == 1 and pavilion.destroyed == 0 and general.destroyed == 0 and revive.destroyed == 0, "only consumed dice cache destroyed")
 check(p._slot("dice").loading and p.loads == 6, "only consumed category refills")
 p.show_rewarded(13,"pavilion_seal")
 check(pavilion.shown == 1 and pavilion.received.custom_data == "" and pavilion.received.user_id == "", "Pavilion never inherits Odyssey SSV nonce")
 dice.listener.on_user_earned_reward.call(null); dice.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
 check(p._active_request_id == 13 and earned == [11], "late dice callback cannot credit/close Pavilion")
 pavilion.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
 p._finalize_rewarded_dismissal(13)
 check(results.back() == "13:cancelled" and earned == [11], "cancelled Pavilion grants nothing")
 p.show_rewarded(14,"game_over_revive")
 revive.full_screen_content_callback.on_ad_failed_to_show_full_screen_content.call(null)
 revive.listener.on_user_earned_reward.call(null)
 check(results.back() == "14:failed" and earned == [11], "failed revive cannot credit late earned")
 check(p.rewarded_available("liveops_boss_hunt_double"), "general cache unaffected by revive failure")
 p._slot("general").loaded_at = p.clock - 56*60*1000
 p.warm_rewarded_ad("offline_cultivation_double")
 check(general.destroyed == 1 and p._slot("general").loading, "only expired category reloads")
 var generation: int = p._slot("general").generation
 var epoch: int = p._load_epoch
 p._pause_ads_for_privacy()
 var stale := FakeAd.new(300); p._on_rewarded_loaded(stale,epoch,"general",generation)
 check(stale.destroyed == 1 and not p._consent_gate_open, "late previous-consent load destroyed")
 for unit: String in Catalog.UNITS:
  check(p._slot(unit).ad == null and not p._slot(unit).loading and p._slot(unit).retry_at == 0,"privacy clears cache and retry " + unit)
 p._consent_gate_open = true; p._warm_all_units()
 var new_generation: int = p._slot("general").generation
 p._on_rewarded_failed_to_load(null,epoch,"general",generation)
 check(p._slot("general").loading and p._slot("general").generation == new_generation, "stale failure cannot overwrite new generation")
 var next: FakeAd = complete(p,"general",301)
 p._on_rewarded_loaded(next,p._load_epoch,"general",new_generation)
 check(next.destroyed == 0 and p._slot("general").ad == next, "duplicate load cannot destroy retained ad")
 var status: Dictionary = p.get_runtime_status()
 check(status.units.size() == 4 and status.units.general.ready and not status.has("ad_unit_id") and not str(status).contains(nonce), "support exposes safe per-category state without nonce")
 p.free()
 # Exercise production manager callback owner fence; no bridge/currency call used.
 var manager: Node = load("res://scripts/managers/monetization_manager.gd").new()
 var provider: Node = probe(); var store := Store.new()
 manager.provider=provider; manager.policy_store=store
 manager.active_request=88; manager.active_placement="pavilion_seal"; manager.active_grant_id="b".repeat(32); manager.active_reward_owner="old-account"
 var delivered: Array[String] = []
 manager.verified_rewarded_completed.connect(func(placement: String,_id: String): delivered.append(placement))
 manager._on_reward_confirmed(88)
 check(delivered.is_empty() and manager.active_request == -1 and manager.placement_counts.is_empty(), "account switch rejects old reward without spending new owner quota")
 manager.active_request=89;manager.active_placement="pavilion_seal";manager.active_grant_id="c".repeat(32);manager.active_reward_owner=manager._reward_owner();manager.reward_consumed=false
 manager._on_reward_confirmed(89); manager._on_reward_confirmed(89)
 check(delivered == ["pavilion_seal"] and manager.placement_counts.pavilion_seal == 1, "current owner receives one durable legacy callback")
 check(not manager.placement_counts.has("odyssey_roll"), "client playback never spends server dice quota")
 manager._on_request_finished(89,"completed");provider.free();manager.free()
 await process_frame
 var factory: GDScript = load("res://addons/admob/internal/mock/mock_admob_factory.gd")
 RewardedAd._plugin=null
 for mock: Variant in factory._mocks.values():
  if is_instance_valid(mock): mock.free()
 factory._mocks.clear()
 print("REWARDED_UNIT_ROUTING=PASS; checks=",checks," failures=",failures,"; NATIVE_TRANSPORT=DOUBLE; LIVE_ADS=NONE")
 quit(1 if failures else 0)
