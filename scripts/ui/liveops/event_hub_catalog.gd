extends RefCounted
## Read-only hub adapter. Claims, rewards and progress belong to existing managers.
const Economy=preload("res://scripts/data/economy_catalog.gd")
const IDS: Array[String]=["seven_day","boss_hunt","pilgrimage","heavenly_ladder","treasure_hunt","five_elements","daily","pavilion"]
const TITLES: Dictionary={"seven_day":["Seven Days of Ascension","Tujuh Hari Ascension"],"boss_hunt":["Celestial Boss Hunt","Perburuan Boss"],"pilgrimage":["Jade Valley Pilgrimage","Ziarah Lembah Jade"],"heavenly_ladder":["Heavenly Ladder","Tangga Surgawi"],"treasure_hunt":["Celestial Treasure Hunt","Perburuan Harta"],"five_elements":["Path of Five Elements","Jalan Lima Elemen"],"daily":["Daily Trials","Trial Harian"],"pavilion":["Celestial Pavilion","Paviliun Surgawi"]}
const DESCRIPTIONS: Dictionary={"seven_day":["Return daily. Ascend with every gift.","Kembali tiap hari. Raih hadiah perjalananmu."],"boss_hunt":["Defeat realm guardians. Claim your bounty.","Kalahkan penjaga realm. Raih hadiahnya."],"pilgrimage":["Explore the realms. Unlock new milestones.","Jelajahi realm. Buka pencapaian baru."],"heavenly_ladder":["Rise through each stage of your journey.","Taklukkan setiap tahap perjalananmu."],"treasure_hunt":["Uncover treasures along your path.","Temukan harta di sepanjang perjalanan."],"five_elements":["Master five trials. Unlock Convergence.","Tuntaskan lima trial. Buka Convergence."],"daily":["Complete today's disciplines and claim rewards.","Selesaikan latihan hari ini dan raih hadiah."],"pavilion":["Meditate, collect seals and summon equipment.","Meditasi, kumpulkan seal dan summon equipment."]}
const METHODS: Dictionary={
 "pilgrimage":["get_pilgrimage_milestone_ids","get_pilgrimage_milestone","get_pilgrimage_unlocked_count","get_pilgrimage_claimed_count"],
 "boss_hunt":["get_boss_hunt_milestone_ids","get_boss_hunt_milestone","get_boss_hunt_unlocked_count","get_boss_hunt_claimed_count"],
 "heavenly_ladder":["get_heavenly_ladder_milestone_ids","get_heavenly_ladder_milestone","get_heavenly_ladder_cleared_stage_count","get_heavenly_ladder_claimed_count"],
 "treasure_hunt":["get_treasure_hunt_cache_ids","get_treasure_hunt_cache","get_treasure_hunt_unlocked_count","get_treasure_hunt_claimed_count"],
 "five_elements":["get_five_elements_trial_ids","get_five_elements_trial","get_five_elements_unlocked_count","get_five_elements_claimed_count"]}
static func copy(en: String,id: String) -> String:
 return id if TranslationServer.get_locale().begins_with("id") else en
static func title(key: String) -> String:return copy(TITLES[key][0],TITLES[key][1])
static func description(key: String) -> String:return copy(DESCRIPTIONS[key][0],DESCRIPTIONS[key][1])
static func preview(context: Node,key: String) -> Dictionary:
 var live: Node=context.get_node_or_null("/root/LiveOpsManager")
 if live==null:return {"current":0,"total":1,"complete":false,"reward":{}}
 var result: Dictionary={"current":0,"total":1,"complete":false,"reward":{}}
 if key=="seven_day":
  result.current=live.get_active_login_day_count();result.total=7;result.complete=live.is_new_player_event_complete()
  for day: int in range(1,8):
   if not live.is_login_day_claimed(day):result.reward=live.get_login_reward(day);break
 elif METHODS.has(key):
  var methods: Array=METHODS[key];var ids: Array=live.call(methods[0]);var claimed: int=int(live.call(methods[3]))
  result.current=int(live.call(methods[2]));result.total=live.get_heavenly_ladder_total_stage_count() if key=="heavenly_ladder" else ids.size()
  result.complete=not ids.is_empty() and claimed>=ids.size()
  for entry_id: String in ids:
   var entry: Dictionary=live.call(methods[1],entry_id)
   if not bool(entry.get("claimed",false)):
    if result.reward.is_empty() or bool(entry.get("unlocked",false)):result.reward=entry.get("reward",{})
    if bool(entry.get("unlocked",false)):break
  if key=="five_elements":
   var convergence: Dictionary=live.get_five_elements_convergence()
   result.complete=live.is_five_elements_complete()
   if claimed>=ids.size() and not bool(convergence.get("claimed",false)):result.reward=convergence.get("reward",{})
 elif key=="daily":
  var daily: Node=context.get_node_or_null("/root/DailyQuestManager")
  if daily!=null:
   result.current=daily.get_completed_count();result.total=daily.get_daily_quest_ids().size();result.reward={}
   for quest_id: String in daily.get_daily_quest_ids():
    if not daily.is_claimed(quest_id):result.reward={"spirit_stone":daily.get_reward(quest_id)};break
   result.complete=int(result.current)>=int(result.total) and daily.get_claimable_count()==0
 elif key=="pavilion":
  var pavilion: Node=context.get_node_or_null("/root/PavilionManager")
  if pavilion!=null:
   result.current=int(not pavilion.can_claim_meditation())+int(not pavilion.can_claim_starter_seals());result.total=2
   if pavilion.can_claim_starter_seals():result.reward={"pavilion_seal":Economy.STARTER_SEAL_GRANT}
   elif pavilion.can_claim_meditation():result.reward={"spirit_stone":pavilion.MEDITATION_REWARD}
   result.complete=int(result.current)==2
 var rewards: Node=context.get_node_or_null("/root/RewardManager")
 if rewards!=null and rewards.has_method("retire_fragments"):result.reward=rewards.retire_fragments(result.reward)
 return result
