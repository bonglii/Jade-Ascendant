extends SceneTree
var check_count: int=0
var failures: int=0
func check(ok: bool,message: String) -> void:
 check_count+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_arsenal_qa"):quit(2);return
 await process_frame
 var eq: Node=root.get_node("EquipmentManager")
 var inv: Node=root.get_node("InventoryManager")
 var p: Node=root.get_node("PavilionManager")
 var j: Node=root.get_node("JourneyManager")
 var economy: Script=load("res://scripts/data/economy_catalog.gd")
 var sets: Script=load("res://scripts/data/equipment_set_catalog.gd")
 j.cleared_stage_keys.clear()
 check(p.get_summon_pool_by_rarity().values().all(func(a: Array):return a.is_empty()),"No summon before1-5")
 for stage: int in range(1,6):j.cleared_stage_keys.append(j.get_stage_key(1,stage))
 var pool: Dictionary=p.get_summon_pool_by_rarity()
 var targets: Array[String]=["void_piercer_spear"]
 for set_id: String in ["frost_lotus","vermilion_verdict","celestial_aegis"]:
  for id: String in sets.get_piece_ids(set_id):
   check(id in pool[str(eq.get_item_data(id).rarity)],"new armor in pool "+id)
   inv.item_counts[id]=1;check(not eq.can_ascend_item(id),"one armor copy cannot ascend "+id)
   inv.item_counts[id]=2;check(eq.ascend_item(id),"matching armor duplicate ascends "+id)
 check("phoenix_war_fan" in pool.epic,"fan epic pool")
 check(not p.get_wish_target_options().has("phoenix_war_fan"),"Epic uses ordinary Epic drop; no false Legendary wish")
 var out: Dictionary={"scope":"Production offline sampler, active56-item pool after Bell retirement, default rates, fixed Legendary target, fresh pity, seed14102026; no live/ad/calendar guarantee.","experiments_per_target":1000,"targets":{}}
 var rng_seed: int=p.rng.seed
 var rng_state: int=p.rng.state
 p.rng.seed=14102026
 for id: String in targets:
  var totals: Array[int]=[];var firsts: Array[int]=[]
  check(p.get_wish_target_options().has(id),"Legendary wish available "+id)
  for campaign: int in range(1000):
   var state: Dictionary={"wish_item_id":id,"wish_fate_guaranteed":false,"pity_rare_plus":0,"pity_epic_plus":0,"pity_legendary":0}
   var copies: int=0;var pulls: int=0
   while copies<5 and pulls<495:
    var result: Dictionary=p._roll_rarity(state,pool,economy.get_base_drop_rates())
    var rarity: String=result.rarity
    var chosen: String=p._choose_item_for_rarity(rarity,pool,bool(result.hard_legendary_pity),state)
    if rarity=="legendary":state.wish_fate_guaranteed=chosen!=id
    pulls+=1
    if chosen==id:
     copies+=1
     if copies==1:firsts.append(pulls)
    p._advance_pity(state,rarity,true)
   check(copies==5,"hard upper bound "+id+" campaign"+str(campaign))
   totals.append(pulls)
  totals.sort();firsts.sort()
  var sum: int=0;var first_sum: int=0
  for n: int in totals:sum+=n
  for n: int in firsts:first_sum+=n
  out.targets[id]={"mean_first":first_sum/1000.0,"mean_five":sum/1000.0,"median_five":totals[499],"p95_five":totals[949],"maximum_observed":totals[999],"hard_upper_bound":495}
 p.rng.seed=rng_seed;p.rng.state=rng_state
 var file:=FileAccess.open("/tmp/jade-qa/arsenal-acquisition.json",FileAccess.WRITE);file.store_string(JSON.stringify(out,"  "));file.close()
 print("ARSENAL_ACQUISITION_QA checks=",check_count," failures=",failures)
 quit(1 if failures else 0)
