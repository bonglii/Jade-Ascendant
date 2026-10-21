extends SceneTree
const Goals=preload("res://scripts/data/player_goal_catalog.gd")
const Journal=preload("res://scripts/data/reward_receipt_journal.gd")
const Guide=preload("res://scripts/data/build_guidance_catalog.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,caption: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("PLAYER_DIRECTION "+caption)
func settle(frames: int=8) -> void:
 for i: int in range(frames):await process_frame
func swipe(at: Vector2) -> void:
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.button_mask=MOUSE_BUTTON_MASK_LEFT;down.pressed=true;down.position=at;root.push_input(down,true);await settle(1)
 for i: int in range(1,9):
  var motion:=InputEventMouseMotion.new();motion.position=at+Vector2(0,-90)*float(i)/8;motion.relative=Vector2(0,-90.0/8);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true);await settle(1)
 down.pressed=false;down.button_mask=0;down.position=at+Vector2(0,-90);root.push_input(down,true);await settle(3)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 create_timer(85).timeout.connect(func():quit(1))
 await settle()
 var context: Dictionary={"stages":[{"chapter":1,"stage":6,"implemented":true,"unlocked":true,"cleared":true},{"chapter":2,"stage":1,"implemented":true,"unlocked":true,"cleared":false},{"chapter":3,"stage":1,"implemented":false,"unlocked":true,"cleared":false}]}
 check(Goals.choose(context).get("chapter")==2,"recommend first available uncleared stage after a completed chapter")
 context.checkpoint=true;check(Goals.choose(context).action=="continue","saved run precedes all new objectives")
 context.read_only=true;check(Goals.choose(context).action=="recovery","read-only recovery precedes all mutations")
 context={"stages":[],"mastery_choice":true};check(Goals.choose(context).action=="cultivation","maxed path advertises mastery")
 context={"stages":[],"cultivation_maxed":true,"trial_ready":true};check(Goals.choose(context).title=="GOLDEN CORE TRIAL","endgame advertises real existing trial")
 context.trial_complete=true;context.daily_ready=2;check(Goals.choose(context).action=="trials","completed tribulation yields to daily claims")
 context.daily_ready=0;context.daily_complete=true;context.event_ready=1;check(Goals.choose(context).action=="events","earned event reward is actionable")
 context.event_ready=0;check(Goals.choose(context).action=="library","settled account still has a build objective")
 var journal:=Journal.new();journal.bind_owner("test-account-a")
 var stamp: int=int(Time.get_unix_time_from_system())
 check(journal.record("TRIALS","claim-a",{"celestial_jade":20,"spirit_stone":50},stamp),"record successful authoritative payload")
 check(not journal.record("TRIALS","claim-a",{"celestial_jade":20},stamp),"duplicate callback cannot duplicate display receipt")
 journal.record("TRIALS","claim-b",{"pavilion_seal":1},stamp+1)
 check(journal.entries.size()==1 and int(journal.entries[0].reward.celestial_jade)==20 and int(journal.entries[0].count)==2,"batch reward receipt coalesces without dropping currencies")
 check(journal.flush(),"atomic receipt cache flush succeeds")
 var restored:=Journal.new();restored.bind_owner("test-account-a")
 check(restored.entries==journal.entries,"receipt cache reload preserves actual received amounts")
 restored.bind_owner("test-account-b");check(restored.entries.is_empty(),"receipt history does not leak across accounts")
 check(Journal.clean({"celestial_jade":-1,"spirit_stone":NAN,"items":{"refinement_shard":10}}).is_empty(),"invalid counters and retired fragments cannot become receipts")
 for i: int in range(40):journal.record("REWARD","bounded-%d"%i,{"spirit_stone":1},stamp+10+i*3)
 check(journal.entries.size()==30,"receipt history is bounded")
 journal.flush();journal.record("REWARD","backup-proof",{"spirit_stone":2},stamp+200);journal.flush()
 var damaged:=FileAccess.open(journal.path(),FileAccess.WRITE);damaged.store_string("{}");damaged.close()
 var fallback:=Journal.new();fallback.bind_owner("test-account-a");check(fallback.entries.size()==30,"receipt cache corruption falls back without touching player saves")
 var stress:=Journal.new();stress.bind_owner("stress-account");var many_items: Dictionary={}
 for i: int in range(64):many_items["i".repeat(60)+str(i)]=100
 for i: int in range(30):stress.record("REWARD","stress-%d"%i,{"items":many_items},stamp+i*3)
 check(stress.flush() and FileAccess.open(stress.path(),FileAccess.READ).get_length()<=65536,"large reward receipts stay within the cache read bound")
 var stress_reload:=Journal.new();stress_reload.bind_owner("stress-account");check(not stress_reload.entries.is_empty(),"bounded large receipt cache remains reloadable")
 var eq: Node=root.get_node("EquipmentManager");var before: Dictionary=eq.build_equipment_save_data().duplicate(true)
 for stars: int in range(1,6):
  var total: int=0
  for level: int in range(1,stars*10):total+=eq.weapon_level_cost_at(level,stars*10)
  check(total==[720,2470,5220,8970,13720][stars-1],"audit and production share weapon cost at star "+str(stars))
 var ids: Array[String]=Guide.Sets.get_piece_ids("nine_heavens")
 check(Guide.loadout(ids).active and Guide.loadout(ids).passive.kind=="poison","complete poison set guidance matches authoritative passive")
 ids.pop_back();ids.append("heavenweaver_compass");check(not Guide.loadout(ids).active,"independent weapon never substitutes for a fourth set piece")
 for id: String in Guide.Sets.SET_ORDER:check(not str(Guide.set_advice(id).advice).is_empty(),"set has disclosed playstyle "+id)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(390,844)
 var library: Control=load("res://scenes/ui/skill_book_screen.tscn").instantiate();root.add_child(library);current_scene=library;await settle();library._set_mode("BUILDS");await settle(20)
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844)]:
  root.size=dims;await settle(12)
  print("DIRECTION_LIBRARY dims=",dims," size=",library.size," cards=",library._list.get_child_count())
  check(library.size.x<=dims.x+1 and library._list.get_child_count()>10,"build guide fits phone and lists real sets "+str(dims))
 var book_scroll: ScrollContainer=library.find_child("SkillBookScroll",true,false);var prior_scroll: int=book_scroll.scroll_vertical
 await swipe(book_scroll.get_global_rect().get_center());check(book_scroll.scroll_vertical>prior_scroll+25,"build cards respond to a native first swipe")
 library._set_filter("WEAPONS");await settle();check(not library._list.get_children().is_empty(),"weapon playstyles are discoverable")
 library._search.text="not-a-real-weapon";library._on_search(library._search.text);check(library._count.text.begins_with("0"),"build guide search filters actual entries")
 current_scene=null;library.free();await settle()
 var home: Control=load("res://scenes/ui/main_menu.tscn").instantiate();root.add_child(home);current_scene=home;await settle(28)
 check(home.find_child("NextGoalHint",true,false)!=null,"production Home renders a real next-step hint")
 var presenter: Node=root.get_node("RewardClaimResultPresenter");presenter._sync_receipt_owner()
 for i: int in range(20):presenter.receipt_journal.record("QA REWARD","fixture-display-%d"%i,{"spirit_stone":i+1,"celestial_jade":20,"pavilion_seal":1},stamp+i*4)
 presenter._on_reward_granted("stage_clear","chapter_1_stage_1_repeat",{"spirit_stone":3})
 presenter._on_reward_granted("stage_clear","chapter_1_stage_1_repeat",{"spirit_stone":3})
 check(int(presenter.receipt_journal.entries[0].reward.spirit_stone)==6,"legitimate repeat clears sharing a source ID retain both receipts")
 presenter.open_receipts();await settle()
 var panel: Control=home.find_child("RewardReceiptsPanel",true,false);check(panel!=null,"profile reward history uses one owned popup")
 presenter.open_receipts();check(home.find_children("RewardReceiptsPanel","Control",true,false).size()==1,"history cannot be spammed into multiple popups")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844)]:
  root.size=dims;await settle();var paper: Control=panel.find_child("ReceiptPaper",true,false);check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(paper.get_global_rect()),"receipt popup remains inside phone "+str(dims))
  check(paper.get_global_rect().encloses(panel.find_child("ReceiptScroll",true,false).get_global_rect()),"multi-currency receipt list stays inside its frame "+str(dims))
 var receipt_scroll: ScrollContainer=panel.find_child("ReceiptScroll",true,false);prior_scroll=receipt_scroll.scroll_vertical
 await swipe(receipt_scroll.get_global_rect().get_center());check(receipt_scroll.scroll_vertical>prior_scroll+25,"receipt cards respond to a native first swipe")
 panel.call("close");await settle();check(not is_instance_valid(panel),"history dismisses without triggering a grant")
 current_scene=null;home.free();await settle()
 check(eq.build_equipment_save_data()==before,"read-only guides preserve equipment and upgrades")
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("PLAYER_DIRECTION checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
