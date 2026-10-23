extends SceneTree
const Goals=preload("res://scripts/data/player_goal_catalog.gd")
const Economy=preload("res://scripts/data/economy_catalog.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,caption: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("RETENTION_LOOP "+caption)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_retention_qa"):quit(2);return
 create_timer(70).timeout.connect(func():quit(1))
 for i: int in range(12):await process_frame
 var daily: Node=root.get_node("DailyQuestManager")
 var pavilion: Node=root.get_node("PavilionManager")
 var progress: Node=root.get_node("ProgressionManager")
 var save: Node=root.get_node("SaveManager")
 var resumed: bool="--resume" in OS.get_cmdline_user_args()
 if resumed:
  var receipt:=ConfigFile.new();check(receipt.load("user://retention_assert.cfg")==OK,"saved fixture receipt loads in a new process")
  check(daily.get_claimable_count()==0 and daily.claimed_quest_ids.size()==daily.get_daily_quest_ids().size(),"claimed daily state survives restart")
  check(pavilion.get_local_celestial_jade()==int(receipt.get_value("balance","jade")),"earned Jade survives without repeating completion grant")
  check(progress.spirit_stone==int(receipt.get_value("balance","stones")),"quest Stones survive restart")
  check(daily.claim_all_rewards()==0,"restart cannot claim the same quests again")
 else:
  var hashes: Dictionary={}
  for domain: String in save.get_save_domain_ids():
   if save.get_save_scope(domain) in [save.SCOPE_PERMANENT,save.SCOPE_ACTIVE_RUN]:
    var file: String=save.get_save_path(domain);hashes[domain]=FileAccess.get_sha256(file) if FileAccess.file_exists(file) else "missing"
  for i: int in range(50):Goals.choose(Goals.context(root,false))
  for domain: String in hashes:
   var file: String=save.get_save_path(domain)
   check(hashes[domain]==(FileAccess.get_sha256(file) if FileAccess.file_exists(file) else "missing"),"guidance reads never write "+domain)
  var next: Dictionary={"stages":[{"chapter":1,"stage":1,"implemented":true,"unlocked":true,"cleared":false}],"cultivation_affordable":false}
  check(Goals.choose(next).get("stage")==1,"first session still points at authored stage1-1")
  next.daily_ready=2;check(Goals.choose(next).action=="trials","earned daily rewards precede another run or unaffordable sink")
  next.checkpoint=true;check(Goals.choose(next).action=="continue","real Continue precedes claims")
  next.read_only=true;check(Goals.choose(next).action=="recovery","recovery precedes Continue and claims")
  next={"stages":[],"cultivation_maxed":false,"cultivation_affordable":false,"daily_complete":false}
  check(Goals.choose(next).action=="trials","no-Stones post-progression player gets an actionable daily target")
  next.event_ready=1;check(Goals.choose(next).action=="events","earned event milestone is visible before resource spending")
  next.event_ready=0;next.achievement_ready=1;check(Goals.choose(next).action=="trials","achievement rewards use the same actionable Trials route")
  next.achievement_ready=0;next.cultivation_affordable=true;check(Goals.choose(next).action=="cultivation","affordable permanent progress remains a target")
  next.cultivation_maxed=true;next.daily_complete=true;next.record_target={"chapter":5,"stage":5}
  check(Goals.choose(next).get("stage")==5,"settled endgame offers an existing record target without invented rewards")
  next.collection={"id":"set:nine_heavens","owned":1,"total":4}
  check(Goals.choose(next).action=="collection","an explicit collection goal takes priority over optional record replay")
  next.collection.owned=4
  check(Goals.choose(next).get("stage")==5,"completed collection never traps the player on the same target")
  var rotations: Dictionary={}
  for day: int in range(1,29):
   var ids: Array[String]=daily._pick_quests_for_date("2026-10-%02d"%day)
   check(ids.size()==6 and ids==daily._pick_quests_for_date("2026-10-%02d"%day),"six deterministic daily quests "+str(day))
   var categories: Dictionary={"combat":0,"progression":0,"journey":0}
   for id: String in ids:categories[str(daily.DAILY_QUESTS[id].category)]+=1
   check(categories.values().all(func(n: int):return n==2),"each day has combat, growth and stage goals "+str(day))
   rotations[str(ids)]=true
  check(rotations.size()>1,"daily rotation varies without rolling RNG on menu entry")
  var before_jade: int=pavilion.get_local_celestial_jade();var before_stones: int=progress.spirit_stone
  var stones: int=0
  for id: String in daily.get_daily_quest_ids():stones+=daily.get_reward(id);daily.set_progress_at_least(id,daily.get_target(id))
  check(Goals.choose(Goals.context(root,false)).action=="trials","actual completed manager state reaches Home guidance")
  var amount: int=daily.claim_all_rewards()
  for frame: int in range(3):await process_frame
  check(amount==6 and daily.get_claimable_count()==0,"claim all consumes all six actual completed quests")
  check(progress.spirit_stone==before_stones+stones,"actual reward sum matches the selected quests")
  check(pavilion.get_local_celestial_jade()==before_jade+Economy.DAILY_COMPLETION_JADE,"all daily claims award the disclosed20 earned Jade once")
  check(daily.claim_all_rewards()==0 and pavilion.get_local_celestial_jade()==before_jade+Economy.DAILY_COMPLETION_JADE,"spam cannot repeat daily completion Jade")
  root.set_meta("library_open_goal",true)
  change_scene_to_file("res://scenes/ui/skill_book_screen.tscn")
  for frame: int in range(12):await process_frame
  check(current_scene.has_node("PlayerJournal") and current_scene.get_node("PlayerJournal").mode=="goal","collection CTA opens the actual target reader")
  check(not root.has_meta("library_open_goal"),"navigation intent is consumed once")
  var receipt:=ConfigFile.new();receipt.set_value("balance","jade",pavilion.get_local_celestial_jade());receipt.set_value("balance","stones",progress.spirit_stone);receipt.save("user://retention_assert.cfg")
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("RETENTION_LOOP checks=",checks," failures=",failures," resumed=",resumed)
 quit(1 if failures else 0)
