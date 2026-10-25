extends RefCounted
## Read-only guidance. Opening Home must never select a stage, grant a reward or start a run.
static func choose(goal_state: Dictionary) -> Dictionary:
 if bool(goal_state.get("read_only",false)):return {"action":"recovery","title":"ACCOUNT RECOVERY","hint":"Open Settings to review your saved progress.","button":"OPEN SETTINGS"}
 if bool(goal_state.get("checkpoint",false)):return {"action":"continue","title":"YOUR RUN IS SAVED","hint":"Resume with the same skills and equipment.","button":"CONTINUE RUN"}
 if int(goal_state.get("daily_ready",0))+int(goal_state.get("achievement_ready",0))>0:return {"action":"trials","title":"TRIAL REWARDS READY","hint":"Collect earned Daily and Achievement rewards.","button":"CLAIM TRIALS"}
 for stage: Dictionary in goal_state.get("stages",[]):
  if not bool(stage.get("implemented",false)) or not bool(stage.get("unlocked",false)) or bool(stage.get("cleared",false)):continue
  var chapter: int=int(stage.chapter);var number: int=int(stage.stage)
  var hint: String="First-clear rewards available."
  if chapter==1 and number==1:hint="Unlock Spirit Meditation and the first refinement guide."
  elif chapter==1 and number==5:hint="Unlock the Pavilion equipment collection."
  return {"action":"journey","chapter":chapter,"stage":number,"title":"NEXT · STAGE %d-%d"%[chapter,number],"hint":hint,"button":"PLAY %d-%d"%[chapter,number]}
 if bool(goal_state.get("mastery_choice",false)):return {"action":"cultivation","title":"CHOOSE YOUR DAO","hint":"A maxed cultivation path has a mastery choice ready.","button":"CHOOSE MASTERY"}
 if bool(goal_state.get("trial_ready",false)) and not bool(goal_state.get("trial_complete",false)):return {"action":"cultivation","title":"GOLDEN CORE TRIAL","hint":"Defeat the 1-5 guardian with at most 3 HP hits.","button":"VIEW TRIBULATION"}
 if int(goal_state.get("event_ready",0))>0:return {"action":"events","title":"EVENT REWARDS READY","hint":"Collect the milestones you have already earned.","button":"VIEW EVENTS"}
 if not bool(goal_state.get("cultivation_maxed",false)) and bool(goal_state.get("cultivation_affordable",true)):return {"action":"cultivation","title":"STRENGTHEN YOUR DAO","hint":"Develop your permanent paths and unlock mastery.","button":"OPEN CULTIVATION"}

 if not bool(goal_state.get("daily_complete",false)):return {"action":"trials","title":"TODAY'S DISCIPLINES","hint":"Complete all daily trials for %d Celestial Jade."%int(goal_state.get("daily_completion_jade",20)),"button":"VIEW DAILY TRIALS"}

 var collection: Dictionary=goal_state.get("collection",{})
 if int(collection.get("total",0))>int(collection.get("owned",0)):
  var indonesian: bool=goal_state.get("language","")=="id"
  return {"action":"collection","title":"TARGET KOLEKSI" if indonesian else "YOUR COLLECTION TARGET","hint":("%d / %d bagian dimiliki. Lihat relik yang belum terkumpul." if indonesian else "%d / %d pieces owned. Track the relics still missing.")%[int(collection.owned),int(collection.total)],"button":"LIHAT TARGET" if indonesian else "VIEW TARGET"}
 var target: Dictionary=goal_state.get("record_target",{})
 if not target.is_empty():
  var indonesian: bool=goal_state.get("language","")=="id"
  return {"action":"journey","chapter":int(target.chapter),"stage":int(target.stage),"title":("TAKLUKKAN STAGE %d-%d" if indonesian else "MASTER STAGE %d-%d")%[int(target.chapter),int(target.stage)],"hint":"Menang tanpa HP berkurang. Target rekor pribadi." if indonesian else "Aim for a clear with zero HP hits. Personal record only.","button":("ULANGI %d-%d" if indonesian else "REPLAY %d-%d")%[int(target.chapter),int(target.stage)]}
 return {"action":"library","title":"MASTER YOUR BUILD","hint":"Explore set roles, independent weapons and resonances.","button":"EXPLORE BUILDS"}

## The chapter card has its own stable navigation contract. Recommendations
## remain available through Trials/event dots and the guidance readers.
static func choose_progression(state: Dictionary) -> Dictionary:
 if bool(state.get("read_only",false)) or bool(state.get("checkpoint",false)):return choose(state)
 var available: Array=[]
 for stage: Dictionary in state.get("stages",[]):
  if not bool(stage.get("implemented",false)) or not bool(stage.get("unlocked",false)):continue
  available.append(stage)
  if not bool(stage.get("cleared",false)):return choose({"stages":[stage]})
 var target: Dictionary=available[0] if not available.is_empty() else {"chapter":1,"stage":1}
 return {"action":"journey","chapter":int(target.chapter),"stage":int(target.stage),"title":"STAGE %d-%d"%[int(target.chapter),int(target.stage)],"hint":"Pilih bab dan lanjutkan perjalananmu." if str(state.get("language","en"))=="id" else "Choose a chapter and continue your journey.","button":"ENTER JOURNEY"}

static func context(root: Node, has_checkpoint: bool) -> Dictionary:
 var journey: Node=root.get_node("JourneyManager")
 var result: Dictionary={"language":root.get_node("SettingsManager").language,"read_only":root.get_node("SaveManager").is_progress_read_only(),"checkpoint":has_checkpoint,"stages":[],"daily_ready":root.get_node("DailyQuestManager").get_claimable_count(),"daily_complete":root.get_node("DailyQuestManager").get_completed_count()>=root.get_node("DailyQuestManager").get_daily_quest_ids().size()}
 var chapters: Array=journey.get_chapter_ids();chapters.erase(journey.selected_chapter_id);chapters.push_front(journey.selected_chapter_id)
 for chapter: int in chapters:
  for stage: int in preload("res://scripts/ui/journey_art_catalog.gd").get_presentation_stage_ids(chapter,journey.get_stage_ids(chapter)):result.stages.append({"chapter":chapter,"stage":stage,"implemented":journey.is_stage_implemented(chapter,stage),"unlocked":journey.is_stage_unlocked(chapter,stage),"cleared":journey.is_stage_cleared(chapter,stage)})
 var mastery: Node=root.get_node_or_null("CultivationMasteryManager")
 result.cultivation_affordable=false;result.cultivation_maxed=true;result.mastery_choice=false;result.trial_ready=false;result.trial_complete=false
 for path: String in ["vitality","sword_power","swift_qi"]:
  var maxed: bool=int(root.get_node("ProgressionManager").get(path+"_level"))>=10
  var cost: int=int(root.get_node("ProgressionManager").call("get_"+path+"_cost"))
  if not maxed and cost>0 and int(root.get_node("ProgressionManager").spirit_stone)>=cost:result.cultivation_affordable=true
  result.cultivation_maxed=bool(result.cultivation_maxed) and maxed
  if mastery!=null and mastery.ready_state and maxed and str(mastery.state.get("choices",{}).get(path,"")).is_empty():result.mastery_choice=true
 if mastery!=null and mastery.ready_state:
  result.trial_ready=mastery.trial_ready();result.trial_complete=int(mastery.state.get("realm",0))>=1
 result.achievement_ready=root.get_node("AchievementManager").get_claimable_count()
 result.daily_completion_jade=preload("res://scripts/data/economy_catalog.gd").DAILY_COMPLETION_JADE
 result.event_ready=preload("res://scripts/ui/action_ready_dot.gd").count(root,"all_events")
 var companion: Node=root.get_node_or_null("PlayerCompanion")
 result.collection=companion.goal_progress() if companion!=null else {}
 result.record_target={}
 for stage: Dictionary in result.stages:
  if stage.implemented and stage.unlocked and stage.cleared and not bool(journey.stage_records.get(journey.get_stage_key(int(stage.chapter),int(stage.stage)),{}).get("untouched",false)):
   result.record_target={"chapter":stage.chapter,"stage":stage.stage};break
 return result
