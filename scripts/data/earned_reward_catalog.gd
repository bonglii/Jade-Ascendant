extends RefCounted
## Earned currency only. Does not write the paid server wallet or change prices.
## Existing claim IDs remain authoritative; previously claimed rewards never replay.
const LOGIN_JADE: Array[int] = [5,10,10,15,15,20,25]
const ACHIEVEMENT_PREMIUM: Dictionary = {
 "first_stage_clear":[10,0], "first_boss_defeat":[15,0],
 "stage_1_5_clear":[25,1], "stage_1_6_clear":[25,0],
 "enemy_slayer_500":[10,0], "enemy_slayer_1000":[20,0],
 "enemy_slayer_2500":[30,0], "enemy_slayer_5000":[50,1],
 "cultivator_level_15":[10,0], "cultivator_level_25":[25,0],
 "art_master":[15,0], "chapter_two_master":[50,1],
 "chapter_three_master":[75,1], "journey_complete_16":[100,1],
 "trial_veteran_30":[20,0], "trial_veteran_60":[30,0],
 "trial_veteran_100":[50,1], "boss_slayer_25":[25,0],
 "boss_slayer_50":[50,1], "cultivation_master_20":[20,0],
 "cultivation_master_30":[30,0]
}
static func premium(source: String, id: String) -> Dictionary:
 var amounts: Array = []
 if source == "achievement": amounts = ACHIEVEMENT_PREMIUM.get(id,[])
 elif source == "pavilion":
  var pattern := RegEx.new()
  pattern.compile("^live_ops_login_(?:day_([1-7])|cycle_[1-9][0-9]*_day_([1-7]))$")
  var match_result: RegExMatch = pattern.search(id)
  if match_result != null:
   var day: int = int(match_result.get_string(1) if not match_result.get_string(1).is_empty() else match_result.get_string(2))
   amounts = [LOGIN_JADE[day-1],1 if day == 7 else 0]
 if amounts.is_empty(): return {}
 return {"celestial_jade":int(amounts[0]),"pavilion_seal":int(amounts[1])}
