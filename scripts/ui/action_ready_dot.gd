extends RefCounted
## One presentation contract. Counts come from the owning managers, never grants.
static func show_on(host: Control, count_value: int, badge_name: String="ActionReadyDot") -> Panel:
 var dot: Panel=host.get_node_or_null(NodePath(badge_name)) as Panel
 if dot==null:
  dot=Panel.new(); dot.name=badge_name; dot.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var skin:=StyleBoxFlat.new(); skin.bg_color=Color("ee3d43"); skin.border_color=Color("ffe0a1")
  skin.set_border_width_all(1); skin.set_corner_radius_all(8); skin.shadow_color=Color(0.45,0.02,0.025,0.4); skin.shadow_size=2
  dot.add_theme_stylebox_override("panel",skin)
  host.add_child(dot); dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
  dot.offset_left=-22; dot.offset_right=-8; dot.offset_top=7; dot.offset_bottom=21
 dot.visible=count_value>0
 dot.set_meta("action_count",maxi(0,count_value))
 return dot
static func _number(context: Node, manager_name: String, method: String) -> int:
 var manager: Node=context.get_node_or_null("/root/"+manager_name)
 return maxi(0,int(manager.call(method))) if manager!=null and manager.has_method(method) else 0
static func count(context: Node, source: String) -> int:
 var saves: Node=context.get_node_or_null("/root/SaveManager")
 if saves!=null and saves.is_progress_read_only() and source not in ["mail","home","all_events"]: return 0
 match source:
  "daily": return _number(context,"DailyQuestManager","get_claimable_count")
  "achievement": return _number(context,"AchievementManager","get_claimable_count")
  "trials": return count(context,"daily")+count(context,"achievement")
  "seven_day": return _number(context,"LiveOpsManager","get_login_claimable_count")
  "pilgrimage": return _number(context,"LiveOpsManager","get_pilgrimage_claimable_count")
  "boss_hunt": return _number(context,"LiveOpsManager","get_boss_hunt_claimable_count")
  "heavenly_ladder": return _number(context,"LiveOpsManager","get_heavenly_ladder_claimable_count")
  "treasure_hunt": return _number(context,"LiveOpsManager","get_treasure_hunt_claimable_count")
  "five_elements":
   var live: Node=context.get_node_or_null("/root/LiveOpsManager")
   var convergence_ready: int=int(live!=null and live.is_five_elements_convergence_unlocked() and not live.is_five_elements_convergence_claimed())
   return _number(context,"LiveOpsManager","get_five_elements_claimable_count")+convergence_ready
  "mail": return _number(context,"LiveOpsManager","get_home_mail_badge_count")
  "profile": return int(_number(context,"ProgressionManager","get_next_claimable_hero_milestone")>0)
  "meditation": return int(_number(context,"IdleCultivationManager","get_claimable_units")>0)
  "pavilion": return _number(context,"PavilionManager","can_claim_meditation")+_number(context,"PavilionManager","can_claim_starter_seals")
  "hero":
   var equipment: Node=context.get_node_or_null("/root/EquipmentManager")
   var total: int=0
   if equipment!=null:
    for item: String in equipment.get_item_ids():
     if equipment.can_ascend_item(item) or equipment.can_level_weapon(item): total+=1
   return total
  "cultivation":
   var mastery: Node=context.get_node_or_null("/root/CultivationMasteryManager")
   if mastery==null: return 0
   if mastery.trial_ready(): return 1
   for path: String in mastery.state.get("choices",{}):
    if mastery.can_choose(path) and str(mastery.state.choices[path]).is_empty(): return 1
   return 0
  "odyssey", "odyssey_missions", "odyssey_milestones":
   var client: Node=context.get_node_or_null("/root/OdysseyClient")
   return odyssey_count(client.snapshot,client.server_time(),source) if client!=null else 0
  "all_events":
   var total: int=0
   for key: String in ["seven_day","pilgrimage","boss_hunt","heavenly_ladder","treasure_hunt","five_elements","odyssey","daily","pavilion"]: total+=count(context,key)
   return total
  "home": return count(context,"all_events")+count(context,"mail")+count(context,"meditation")+count(context,"profile")
 return 0
static func odyssey_count(snapshot: Dictionary, now: float, source: String="odyssey") -> int:
 var event: Dictionary=snapshot.get("event",{}) if snapshot.get("event") is Dictionary else {}
 if not bool(event.get("enabled",false)) or now<float(event.get("starts_at",0)) or now>=float(event.get("ends_at",0))+259200: return 0
 var state: Dictionary=snapshot.get("state",{})
 var mission_count: int=0; var milestone_count: int=0
 var today: String=Time.get_datetime_string_from_unix_time(int(now)).substr(0,10)
 if now<float(event.get("ends_at",0)) and state.get("day","")==today:
  for target: int in [1,3,5]:
   if int(state.get("daily_rolls",0))>=target and target not in state.get("missions",[]): mission_count+=1
  if state.get("task_day","")==today:
   if int(state.get("daily_gifts",0))>=3 and "gifts" not in state.get("task_claims",[]): mission_count+=1
   if int(state.get("daily_guardians",0))>=1 and "guardian" not in state.get("task_claims",[]): mission_count+=1
 for target: int in [24,48,72]:
  if preload("res://scripts/data/odyssey_progress.gd").ready(state,target) and target not in state.get("milestones",[]): milestone_count+=1
 return mission_count if source=="odyssey_missions" else milestone_count if source=="odyssey_milestones" else mission_count+milestone_count
