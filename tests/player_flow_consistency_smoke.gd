extends SceneTree
const Numbers=preload("res://scripts/ui/readable_numbers.gd")
const JourneyProgress=preload("res://scripts/data/odyssey_progress.gd")
const Arena=preload("res://scripts/game/boss_combat_arena.gd")
class FakeBoss extends CharacterBody2D:
 signal boss_defeated
class AdClient extends "res://scripts/monetization/odyssey_client.gd":
 var ads_shown: int=0
 func _live_binding() -> String:return "a".repeat(64)
 func _show_ad() -> void:ads_shown+=1
 func _save_ad_wait() -> bool:return true
 func _can_prewarm() -> bool:return false
var checks: int=0
var failures: int=0
func check(ok: bool,caption: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("PLAYER_FLOW "+caption)
func settle(frames: int=6) -> void:
 for i: int in range(frames):await process_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 create_timer(75).timeout.connect(func() -> void:quit(1))
 await settle()
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(390,844)
 var marker:=Label.new();marker.text="#01";root.add_child(marker);preload("res://scripts/ui/liveops/event_identity_catalog.gd").wrap_mobile_controls(marker)
 check(marker.autowrap_mode==TextServer.AUTOWRAP_OFF and marker.custom_minimum_size.x>20,"numbered event markers reserve their natural width")
 marker.free()
 var progress_state: Dictionary={"journey_laps_version":2,"laps":3,"rolls":30,"journey_legacy_rolls":0,"milestones":[]}
 check(not JourneyProgress.ready(progress_state,24),"milestone dot does not use roll count")
 progress_state.laps=4;check(JourneyProgress.ready(progress_state,24),"milestone dot unlocks at a completed lap")
 progress_state.milestones=[24,48,72];check(not JourneyProgress.visible({"enabled":true,"ends_at":int(Time.get_unix_time_from_system())+100},progress_state,int(Time.get_unix_time_from_system())),"completed season disappears")
 progress_state.milestones=[];progress_state.laps=0;check(not JourneyProgress.visible({"enabled":true,"ends_at":int(Time.get_unix_time_from_system())-10},progress_state,int(Time.get_unix_time_from_system())),"expired season without earned claims disappears")
 var client:=AdClient.new();root.add_child(client);client.set_process(false);client._binding="a".repeat(64)
 var now: int=int(Time.get_unix_time_from_system());client.snapshot={"event":{"id":"qa-flow","enabled":true,"starts_at":now-5,"ends_at":now+1000},"state":{"day":"qa-day","daily_ads":0},"server_time":now};client._received_msec=Time.get_ticks_msec()
 client._prepared_ad={"owner":client._binding,"nonce":"b".repeat(32),"event_id":"qa-flow","day":"qa-day","expires_at":now+1000}
 check(client.ads_shown==0 and not client.ad_waiting(),"preparing does not show an ad or start fake verification")
 check(client._activate_prepared_ad() and client.ads_shown==1 and client.ad_waiting(),"tap opens a prepared ad without another server dispatch")
 check(not client._activate_prepared_ad() and client.ads_shown==1,"prepared nonce cannot be shown twice")
 client._prepared_ad={"owner":"c".repeat(64),"nonce":"d".repeat(32),"event_id":"qa-flow","day":"qa-day","expires_at":now+1000}
 check(not client._prepared_ad_valid(),"prepared ad cannot cross accounts")
 client.free()
 var billing: Node=load("res://scripts/monetization/google_play_billing_provider.gd").new()
 billing.secure_account_binding="a".repeat(64);billing.secure_authority_ready=true
 var cleared: Array[bool]=[]
 billing.purchase_state_changed.connect(func(_product: String,_status: String,_message: String) -> void:cleared.append(str(billing.active_product_id).is_empty()))
 for code: int in [1,2]:
  billing.active_product_id="jade_pouch_100";billing._active_purchase_binding=billing.secure_account_binding;billing._on_purchase_updated({"response_code":code})
 check(cleared==[true,true],"explicit cancel/failure releases checkout before notifying its UI")
 billing.free()
 for value: int in [0,1,999,9999,10000,999999,1000000,999999999,1000000000,9223372036854775807]:
  var formatted: String=Numbers.compact(value)
  check(not formatted.contains("e+") and not formatted.contains("nan") and formatted.length()<=10,"readable finite compact counter "+str(value))
 check(Numbers.compact(-1)=="0" and Numbers.compact(10000)=="10K","unavailable negative counter and compact threshold are bounded")
 var quests: Node=root.get_node("DailyQuestManager")
 check(quests.get_daily_quest_ids().size()==6,"fresh account has six daily records")
 var legacy: Array[String]=["defeat_20_enemies","reach_level_5","clear_1_stage"]
 quests.active_quest_ids=legacy.duplicate();quests.claimed_quest_ids.assign(["defeat_20_enemies"]);quests._expand_daily_records()
 check(quests.active_quest_ids.size()==6 and "defeat_20_enemies" in quests.claimed_quest_ids,"legacy daily expansion preserves all previous claims")
 for category: String in ["combat","progression","journey"]:
  var count: int=0
  for id: String in quests.active_quest_ids:
   if quests.DAILY_QUESTS[id].category==category:count+=1
  check(count==2,"two records per discipline "+category)
 var achievements: Node=root.get_node("AchievementManager")
 for id: String in ["enemy_slayer_10000","enemy_slayer_25000","trial_veteran_200","trial_veteran_300","boss_slayer_100","boss_slayer_200"]:
  check(achievements.has_achievement(id) and int(achievements.get_reward_data(id).get("celestial_jade",0))>0,"new permanent record has earned premium reward "+id)
 achievements.achievement_progress["enemy_slayer_10000"]=9000;achievements._on_enemy_killed();check(achievements.get_progress("enemy_slayer_10000")==9001,"new records use the real enemy kill hook")
 var world:=Node2D.new();root.add_child(world)
 var player:=CharacterBody2D.new();world.add_child(player);var boss:=FakeBoss.new();world.add_child(boss)
 var arena:=Arena.new();arena.player_actor=player;arena.boss_actor=boss;world.add_child(arena);await physics_frame
 check(arena.get_node("JadeBoundary").get_child_count()==48,"arena has physical boundaries instead of only a painted circle")
 player.position=Vector2(800,0);boss.position=Vector2(0,800);arena._physics_process(.1)
 check(player.position.length()<=Arena.RADIUS-21 and boss.position.length()<=Arena.RADIUS-21,"player and boss cannot escape the enclosure")
 var ray:=PhysicsRayQueryParameters2D.create(Vector2.ZERO,Vector2(600,0),16)
 check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"arena wall exists on the player's collision layer")
 boss.boss_defeated.emit();await settle();check(not is_instance_valid(arena),"arena releases on boss defeat")
 world.free()
 var save: Node=root.get_node("SaveManager")
 var snapshot_a: Dictionary=save.read_save_data("player_profile").get("data",{}).duplicate(true);snapshot_a.display_name="QA A"
 var snapshot_b: Dictionary=snapshot_a.duplicate(true);snapshot_b.display_name="QA B"
 check(bool(save.write_save_data("player_profile",snapshot_a).get("success",false)) and bool(save.write_save_data("player_profile",snapshot_b).get("success",false)),"local save writes remain atomic with a valid backup")
 var damaged:=FileAccess.open(save.get_save_path("player_profile"),FileAccess.WRITE);damaged.store_var("invalid save dictionary");damaged.close()
 var recovered: Dictionary=save.read_save_data("player_profile")
 check(bool(recovered.get("success",false)) and bool(recovered.get("recovered",false)) and recovered.get("data",{}).get("player_uid")==snapshot_a.get("player_uid"),"damaged primary restores valid backup without changing identity")
 var settings: Control=load("res://scenes/ui/settings_screen.tscn").instantiate();root.add_child(settings);await settle()
 check(settings.find_children("*","VBoxContainer",true,false).all(func(n: Node) -> bool:return n.get_script()==null or n.get_script().resource_path!="res://scripts/ui/update_notification_settings.gd"),"settings has no notification controls")
 var recovery: Control=settings.find_child("AccountRecoveryTools",true,false)
 check(recovery!=null and not recovery.visible and settings.find_child("ProgressBackupCard",true,false)!=null,"essential save recovery is available but collapsed")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.size=dims;await settle();check(settings.size.x<=dims.x+1,"settings remains inside narrow viewport "+str(dims))
 settings.free();await settle()
 var records: Control=load("res://scenes/ui/achievement_screen.tscn").instantiate();root.add_child(records);current_scene=records;await settle(28)
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844)]:
  root.size=dims;await settle(10)
  var amounts: Array[Node]=records.find_children("PremiumRewardAmount","Label",true,false)
  check(not amounts.is_empty() and amounts.all(func(n: Node) -> bool:return n.get_line_count()==1 and n.size.y<40),"achievement premium amounts stay on one line "+str(dims))
  var rows: Array[Node]=records.find_children("RecordActions","BoxContainer",true,false)
  check(rows.any(func(n: Node) -> bool:return bool(n.get_meta("premium_reward",false)) and n.vertical),"premium reward preview reserves a row above its action "+str(dims))
 current_scene=null;records.free();await settle()
 var identity: Control=load("res://scripts/ui/player_identity_card.gd").new();root.add_child(identity);await settle()
 check(identity._progress_label.text.begins_with("Lv.") and not identity._uid.text.is_empty(),"profile has level, rank, realm and UID")
 identity.free();await settle()
 var home: Control=load("res://scenes/ui/main_menu.tscn").instantiate();root.add_child(home);current_scene=home;await settle(28)
 var onboarding: Control=home.find_child("ResponsiveOnboardingCard",true,false)
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844)]:
  root.size=dims;await settle()
  if onboarding!=null:check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(onboarding.get_global_rect()),"first-run guide fits phone viewport "+str(dims))
 if onboarding!=null:
  for node: Node in home.find_children("*","Button",true,false):
   if node.text in ["SKIP GUIDE","LEWATI PANDUAN"]:node.pressed.emit();break
 await settle();root.size=Vector2i(390,844)
 var live: Node=root.get_node("LiveOpsManager")
 for event_id: String in ["jade_valley_pilgrimage","heavenly_ladder","celestial_treasure_hunt","path_of_five_elements"]:
  live.open_live_popup("res://scenes/ui/"+event_id+"_screen.tscn");await settle()
  check(live._active_live_popup!=null and bool(live._active_live_popup.get_meta("liveops_popup",false)),"consistent stage-clear popup "+event_id)
  live.close_live_popup();await settle()
 current_scene=null;home.free();await settle()
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("PLAYER_FLOW_CONSISTENCY checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
