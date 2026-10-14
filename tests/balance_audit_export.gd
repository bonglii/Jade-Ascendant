extends SceneTree
## Read-only catalog/runtime export; refuses the real player profile.
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_balance_qa"):push_error("Use isolated jade_balance_qa XDG profile");quit(2);return
 await create_timer(.5).timeout
 var progression: Node=root.get_node("ProgressionManager")
 var equipment: Node=root.get_node("EquipmentManager")
 var rewards: Node=root.get_node("RewardManager")
 var before: Dictionary={"progression":progression.build_progression_save_data().duplicate(true),"equipment":equipment.build_equipment_save_data().duplicate(true),"inventory":root.get_node("InventoryManager").item_counts.duplicate(true),"pavilion":root.get_node("PavilionManager").state.duplicate(true)}
 var economy: Script=load("res://scripts/data/economy_catalog.gd")
 var sets: Script=load("res://scripts/data/equipment_set_catalog.gd")
 var output: Dictionary={"stages":[],"equipment":[],"sets":[],"weapons":[],"idle":[],"milestones":[],"economy":{"rates":economy.get_base_drop_rates(),"pity":economy.get_pity_limits(),"single":economy.get_summon_cost(1),"ten":economy.get_summon_cost(10),"daily_completion_jade":economy.DAILY_COMPLETION_JADE,"cycle_jade":economy.ACTIVE_DAY_CYCLE_BONUS_JADE,"cycle_seals":economy.ACTIVE_DAY_CYCLE_BONUS_SEALS,"ad_cap_per_cycle":economy.REWARDED_AD_MAX_PER_CYCLE}}
 var authored_level: Node=load("res://scenes/levels/level_1.tscn").instantiate()
 var health: Node=authored_level.get_node("player_1/PlayerHealth")
 output.player={"authored_max_health":health.max_health,"body_refinement_hp":health.BODY_REFINEMENT_HP_PER_LEVEL,"blood_qi_heal":health.BLOOD_QI_HEAL_AMOUNT}
 authored_level.free()
 output.permanent_weapon_progression=[]
 for stars: int in range(1,6):
  var cap: int=10*stars
  var cost: int=0
  for level: int in range(1,cap):cost+=20*(level+1)
  output.permanent_weapon_progression.append({"stars":stars,"level_cap":cap,"max_damage_multiplier":1.0+(cap-1)*.01,"total_stones_from_level1":cost})
 var chapters: Array[String]=["one","two","three","four","five"]
 for i: int in range(5):
  var catalog: Script=load("res://scripts/data/chapter_"+chapters[i]+"_catalog.gd")
  for stage_id: int in catalog.STAGES:
   var data: Dictionary=catalog.get_stage(stage_id)
   # Instantiate the authored boss scene off-tree and apply its real encounter adapter.
   var stage_scene: PackedScene=load(str(data.scene_path))
   # Instantiation off-tree resolves inherited scene properties. SceneState
   # exposes only authored overrides, so inherited boss_scene was missed.
   var authored_stage: Node=stage_scene.instantiate()
   var authored_spawner: Node=authored_stage.get_node("EnemySpawner")
   var boss_scene: PackedScene=authored_spawner.get("boss_scene")
   authored_stage.free()
   var boss: Node
   if boss_scene!=null:
    boss=boss_scene.instantiate()
    if boss.has_method("configure_encounter"):boss.configure_encounter(data)
   var entry: Dictionary={"chapter":i+1,"stage":stage_id,"name":data.display_name,"wave_duration":data.get("wave_duration",30),"enemy_cap":data.get("enemy_cap",0),"enemy_hp_multiplier":data.get("enemy_hp_multiplier",1.0),"difficulty_interval":data.get("difficulty_interval",60),"boss_hp":float(boss.get("max_hp")) if boss!=null else float(data.get("boss_stats",{}).get("max_hp",0)),"boss_damage":float(boss.get("attack_damage")) if boss!=null else float(data.get("boss_stats",{}).get("attack_damage",0)),"first_reward":rewards.get_stage_clear_reward(i+1,stage_id,true),"repeat_reward":rewards.get_stage_clear_reward(i+1,stage_id,false)}
   output.stages.append(entry)
   if boss!=null:boss.free()
 for id: String in equipment.get_item_ids():
  output.equipment.append({"id":id,"star1":equipment._build_effective_item_data(id,1),"star5":equipment._build_effective_item_data(id,5)})
 for id: String in sets.SET_ORDER:
  var pieces: Array[String]=sets.get_piece_ids(id)
  var bonuses: Dictionary={}
  for stat: String in ["max_health_flat","damage_bonus","critical_chance_bonus","stationary_damage_bonus","high_health_damage_bonus","attack_cooldown_reduction"]:bonuses[stat]=sets.get_gameplay_bonus(stat,pieces)
  output.sets.append({"id":id,"rarity":sets.get_set_rarity(id),"pieces":pieces,"bonuses":bonuses,"passive":sets.get_four_piece_passive(id)})
 for name_value: String in ["spirit_sword","fire_orb","thunder_talisman","yin_yang_blades","heavenly_sword_rain","eight_trigrams_formation","jade_binding_chain","celestial_returning_glaive"]:
  var weapon: Node=load("res://scripts/weapon/"+name_value+"_weapon.gd").new()
  if weapon.has_method("_ready"):weapon._ready()
  for target_level: int in [1,3,5,7]:
   while int(weapon.get("level"))<target_level:weapon.upgrade()
   var row: Dictionary={"id":name_value,"level":target_level,"cooldown":float(weapon.get("cooldown"))}
   for prop: Dictionary in weapon.get_property_list():
    var key: String=str(prop.name)
    if key in ["base_damage","damage","chain_count","blade_count","strike_count","strike_radius","formation_count","formation_duration","pulse_interval"]:row[key]=weapon.get(key)
   output.weapons.append(row)
  weapon.free()
 var idle: Node=root.get_node("IdleCultivationManager")
 for tier: int in [1,3,6,11,16]:output.idle.append(idle.get_rates_for_tier(tier))
 for level: int in progression.HERO_MILESTONE_LEVELS:output.milestones.append({"level":level,"reward":rewards.get_hero_milestone_reward(level)})
 output.login_rewards=[]
 for day: int in range(1,8):output.login_rewards.append(root.get_node("LiveOpsManager").get_login_reward(day))
 output.daily_quests=root.get_node("DailyQuestManager").DAILY_QUESTS.duplicate(true)
 output.hero_exp_cap=progression.get_hero_total_experience_cap()
 # Simulate local sampler only: default rates, full pool, fixed target, fresh pity.
 var pavilion: Node=root.get_node("PavilionManager")
 var old_seed: int=pavilion.rng.seed
 var old_rng_state: int=pavilion.rng.state
 pavilion.rng.seed=13102026
 var pool: Dictionary={"common":[],"rare":[],"epic":[],"legendary":[]}
 for item: Dictionary in output.equipment:pool[str(item.star1.rarity)].append(item.id)
 var totals: Array[int]=[]
 var first_targets: Array[int]=[]
 for experiment: int in range(1000):
  var pity: Dictionary={"wish_item_id":"celestial_returning_glaive","wish_fate_guaranteed":false,"pity_rare_plus":0,"pity_epic_plus":0,"pity_legendary":0}
  var copies: int=0
  var pulls: int=0
  while copies<5 and pulls<495:
   pulls+=1
   var result: Dictionary=pavilion._roll_rarity(pity,pool,economy.get_base_drop_rates())
   var rarity: String=str(result.rarity)
   var chosen: String=pavilion._choose_item_for_rarity(rarity,pool,bool(result.hard_legendary_pity),pity)
   if rarity=="legendary":pity.wish_fate_guaranteed=chosen!="celestial_returning_glaive"
   if chosen=="celestial_returning_glaive":
    copies+=1
    if copies==1:first_targets.append(pulls)
   pavilion._advance_pity(pity,rarity,true)
  if copies!=5:push_error("target hard pity failed");quit(1);return
  totals.append(pulls)
 totals.sort();first_targets.sort()
 var sum_pulls: int=0
 var sum_first: int=0
 for value: int in totals:sum_pulls+=value
 for value: int in first_targets:sum_first+=value
 output.gacha_simulation={"seed":13102026,"experiments":1000,"scope":"default offline rates; all rarities populated; fixed target; fresh pity each campaign","mean_pulls_first_target":float(sum_first)/1000.0,"mean_pulls_five_copies":float(sum_pulls)/1000.0,"median_pulls_five_copies":totals[499],"p95_pulls_five_copies":totals[949],"max_observed_five_copies":totals[999],"hard_upper_bound":495}
 pavilion.rng.seed=old_seed;pavilion.rng.state=old_rng_state
 var after: Dictionary={"progression":progression.build_progression_save_data(),"equipment":equipment.build_equipment_save_data(),"inventory":root.get_node("InventoryManager").item_counts,"pavilion":root.get_node("PavilionManager").state}
 if before!=after:push_error("Audit changed player state");quit(1);return
 var path: String=OS.get_environment("JADE_BALANCE_AUDIT_OUTPUT")
 if path.is_empty():path="user://jade_balance_audit.json"
 var file: FileAccess=FileAccess.open(path,FileAccess.WRITE)
 if file==null:quit(1);return
 file.store_string(JSON.stringify(output,"\t"));file.close()
 print("BALANCE_AUDIT_EXPORT=PASS; PLAYER_STATE_UNCHANGED; STAGES=",output.stages.size()," EQUIPMENT=",output.equipment.size()," WEAPON_ROWS=",output.weapons.size())
 quit()
