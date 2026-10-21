extends RefCounted
## Read-only guidance. Opening Home must never select a stage, grant a reward or start a run.
static func choose(context: Dictionary) -> Dictionary:
 if bool(context.get("read_only",false)):return {"action":"recovery","title":"ACCOUNT RECOVERY","hint":"Open Settings to review your saved progress.","button":"OPEN SETTINGS"}
 if bool(context.get("checkpoint",false)):return {"action":"continue","title":"YOUR RUN IS SAVED","hint":"Resume with the same skills and equipment.","button":"CONTINUE RUN"}
 for stage: Dictionary in context.get("stages",[]):
  if not bool(stage.get("implemented",false)) or not bool(stage.get("unlocked",false)) or bool(stage.get("cleared",false)):continue
  var chapter: int=int(stage.chapter);var number: int=int(stage.stage)
  var hint: String="First-clear rewards available."
  if chapter==1 and number==1:hint="Unlock Spirit Meditation and the first refinement guide."
  elif chapter==1 and number==5:hint="Unlock the Pavilion equipment collection."
  return {"action":"journey","chapter":chapter,"stage":number,"title":"NEXT · STAGE %d-%d"%[chapter,number],"hint":hint,"button":"PLAY %d-%d"%[chapter,number]}
 if bool(context.get("mastery_choice",false)):return {"action":"cultivation","title":"CHOOSE YOUR DAO","hint":"A maxed cultivation path has a mastery choice ready.","button":"CHOOSE MASTERY"}
 if bool(context.get("trial_ready",false)) and not bool(context.get("trial_complete",false)):return {"action":"cultivation","title":"GOLDEN CORE TRIAL","hint":"Defeat the 1-5 guardian with at most 3 HP hits.","button":"VIEW TRIBULATION"}
 if not bool(context.get("cultivation_maxed",false)):return {"action":"cultivation","title":"STRENGTHEN YOUR DAO","hint":"Develop your permanent paths and unlock mastery.","button":"OPEN CULTIVATION"}
 if int(context.get("daily_ready",0))>0:return {"action":"trials","title":"TRIAL REWARDS READY","hint":"Claim completed disciplines before the daily reset.","button":"CLAIM TRIALS"}
 if not bool(context.get("daily_complete",false)):return {"action":"trials","title":"TODAY'S DISCIPLINES","hint":"Complete all daily trials for %d Celestial Jade."%int(context.get("daily_completion_jade",20)),"button":"VIEW DAILY TRIALS"}
 if int(context.get("event_ready",0))>0:return {"action":"events","title":"EVENT REWARDS READY","hint":"Collect the milestones you have already earned.","button":"VIEW EVENTS"}
 return {"action":"library","title":"MASTER YOUR BUILD","hint":"Explore set roles, independent weapons and resonances.","button":"EXPLORE BUILDS"}

static func context(root: Node, has_checkpoint: bool) -> Dictionary:
 var journey: Node=root.get_node("JourneyManager")
 var result: Dictionary={"read_only":root.get_node("SaveManager").is_progress_read_only(),"checkpoint":has_checkpoint,"stages":[],"daily_ready":root.get_node("DailyQuestManager").get_claimable_count(),"daily_complete":root.get_node("DailyQuestManager").get_completed_count()>=root.get_node("DailyQuestManager").get_daily_quest_ids().size()}
 var chapters: Array=journey.get_chapter_ids();chapters.erase(journey.selected_chapter_id);chapters.push_front(journey.selected_chapter_id)
 for chapter: int in chapters:
  for stage: int in journey.get_stage_ids(chapter):result.stages.append({"chapter":chapter,"stage":stage,"implemented":journey.is_stage_implemented(chapter,stage),"unlocked":journey.is_stage_unlocked(chapter,stage),"cleared":journey.is_stage_cleared(chapter,stage)})
 var mastery: Node=root.get_node_or_null("CultivationMasteryManager")
 result.cultivation_maxed=true;result.mastery_choice=false;result.trial_ready=false;result.trial_complete=false
 for path: String in ["vitality","sword_power","swift_qi"]:
  var maxed: bool=int(root.get_node("ProgressionManager").get(path+"_level"))>=10
  result.cultivation_maxed=bool(result.cultivation_maxed) and maxed
  if mastery!=null and mastery.ready_state and maxed and str(mastery.state.get("choices",{}).get(path,"")).is_empty():result.mastery_choice=true
 if mastery!=null and mastery.ready_state:
  result.trial_ready=mastery.trial_ready();result.trial_complete=int(mastery.state.get("realm",0))>=1
 result.daily_completion_jade=preload("res://scripts/data/economy_catalog.gd").DAILY_COMPLETION_JADE
 result.event_ready=preload("res://scripts/ui/action_ready_dot.gd").count(root,"all_events")
 return result
