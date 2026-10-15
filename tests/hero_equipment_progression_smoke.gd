extends SceneTree
var checks: int=0
var failures: int=0
var Sets: Script
var Status: Script
var eq: Node
var inv: Node
var saver: Node
var progress: Node
class TestStats extends Node:
 func calculate_damage_result(value: float) -> Dictionary:return {"damage":value,"is_critical":false}
 func has_sword_dao_resonance() -> bool:return false
class TestActor extends Node2D:
 var player_stats: Node
class Victim extends Node2D:
 var current_hp: float=1000
 var is_dead: bool=false
 var hits: int=0
 var hook: Script
 func take_damage(value: float) -> void:
  current_hp-=value;hits+=1
  hook.on_hit(self,value)
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("HERO_RULES_FAILURE "+message)
func _initialize() -> void:run.call_deferred()
func equip_set(set_id: String) -> void:
 for slot: String in eq.get_slot_ids():eq.equipped_item_ids[slot]=""
 for id: String in Sets.get_piece_ids(set_id):
  inv.item_counts[id]=1;eq.equipped_item_ids[str(eq.get_item_data(id).slot)]=id
func ids() -> Array[String]:
 var out: Array[String]=[]
 for slot: String in eq.get_slot_ids():
  var id: String=str(eq.equipped_item_ids[slot])
  if not id.is_empty():out.append(id)
 return out
func settle_game() -> void:
 await create_timer(.4).timeout
 var nodes: Array[Node]=[current_scene]
 while not nodes.is_empty():
  var node: Node=nodes.pop_back()
  if node.has_method("_on_skip_pressed"):node._on_skip_pressed()
  if node.name in ["EnemySpawner","WaveManager"]:node.set_process(false);node.set_physics_process(false)
  nodes.append_array(node.get_children())
 paused=false
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_hero_qa"):quit(2);return
 await create_timer(.4).timeout
 eq=root.get_node("EquipmentManager");inv=root.get_node("InventoryManager");saver=root.get_node("SaveManager");progress=root.get_node("ProgressionManager")
 Sets=load("res://scripts/data/equipment_set_catalog.gd");Status=load("res://scripts/effects/equipment_set_status.gd")
 if "--resume" in OS.get_cmdline_user_args():
  check(eq.get_loadout_item_star("nine_heavens_star_sword")==2,"restart preserves ascension")
  check(eq.get_item_weapon_level("nine_heavens_star_sword")==12,"restart preserves weapon level")
  check(inv.get_item_count("nine_heavens_star_sword")==2,"restart preserves identical copies")
  check(eq._normalize_active_run_loadout_snapshot(eq.active_run_loadout_snapshot).get("weapon_levels",{}).get("nine_heavens_star_sword",0)==3,"restart retains frozen level separately")
  root.get_node("GameSession").continue_saved_game()
  change_scene_to_file("res://scenes/levels/level_1.tscn");await settle_game()
  check(eq.get_item_weapon_level("nine_heavens_star_sword")==3,"actual Continue applies frozen permanent level")
  var starter: Node=current_scene.get_node("player_1/WeaponManager").get_weapon_by_name("Spirit Sword")
  check(starter.level==5 and starter.base_damage==30,"run refinement remains independent")
  print("HERO_RULES_RESTART_CHECKS=",checks,";FAILURES=",failures);quit(1 if failures else 0);return
 eq.active_run_loadout_snapshot.clear();eq.weapon_levels.clear();eq.ascension_stars.clear();inv.item_counts.clear()
 for set_id: String in Sets.SET_ORDER:
  var pieces: Array[String]=Sets.get_piece_ids(set_id)
  check(pieces.size()==4,"four non-weapon pieces "+set_id)
  equip_set(set_id)
  var state: Dictionary=Sets.get_dominant_set_state(ids())
  check(state.piece_count==4 and state.max_pieces==4 and state.full_resonance,"4/4 full set "+set_id)
  var standalone: Array[String]=ids();standalone.append("celestial_returning_glaive")
  check(Sets.get_piece_count(set_id,standalone)==4,"weapon cannot increase count "+set_id)
  if Sets.get_set_rarity(set_id) in ["common","rare"]:
   check(Sets.get_active_passive(ids()).is_empty(),"common/rare no special passive "+set_id)
   check(Sets.get_gameplay_bonus("max_health_flat",ids())>0 and Sets.get_gameplay_bonus("critical_chance_bonus",ids())==0,"common/rare set HP only "+set_id)
  else:
   check(not Sets.get_active_passive(ids()).is_empty(),"epic/legendary four-piece passive "+set_id)
   var partial: Array[String]=ids();partial.pop_back()
   check(Sets.get_active_passive(partial).is_empty(),"three pieces cannot activate passive "+set_id)
 for id: String in eq.get_item_ids_for_slot("armament"):check(Sets.get_set_id_for_item(id).is_empty(),"all weapons standalone "+id)
 equip_set("nine_heavens")
 var sword: String="nine_heavens_star_sword"
 inv.item_counts[sword]=1;inv.item_counts["refinement_shard"]=9999;progress.spirit_stone=50000
 check(not eq.can_ascend_item(sword),"generic fragments cannot ascend")
 inv.item_counts["mistveil_jian"]=9
 check(not eq.can_ascend_item(sword),"different weapon cannot ascend target")
 inv.item_counts[sword]=3
 var reentrant: Array[bool]=[]
 var callback: Callable=func(_id: String,_count: int):reentrant.append(eq.ascend_item(sword))
 inv.inventory_changed.connect(callback)
 check(eq.ascend_item(sword),"one identical duplicate ascends")
 inv.inventory_changed.disconnect(callback)
 check(reentrant==[false],"reward signal cannot reenter ascension")
 check(eq.get_item_star(sword)==2 and inv.get_item_count(sword)==2 and inv.get_item_count("refinement_shard")==9999,"one copy consumed, owned original and shards retained")
 check(eq.get_weapon_level_cap(sword)==20,"2 stars open cap20")
 for star: int in range(1,6):check(eq.get_weapon_level_cap(sword,star)==star*10,"star level cap "+str(star))
 var stones: int=progress.spirit_stone
 check(eq.level_weapon(sword),"permanent weapon level upgrades")
 check(eq.get_item_weapon_level(sword)==2 and progress.spirit_stone==stones-40,"cost and level commit together")
 check(is_equal_approx(eq.get_weapon_level_multiplier(sword),1.01),"level damage multiplier")
 eq.weapon_levels[sword]=20
 check(not eq.can_level_weapon(sword),"cap prevents further leveling")
 eq.weapon_levels[sword]=1
 saver.begin_save_write_barrier("hero_qa","upgrade failure fixture")
 var before: Dictionary=eq.build_equipment_save_data();var before_counts: Dictionary=inv.item_counts.duplicate(true);stones=progress.spirit_stone
 check(not eq.ascend_item(sword) and not eq.level_weapon(sword),"write barrier rejects both upgrades")
 check(eq.build_equipment_save_data()==before and inv.item_counts==before_counts and progress.spirit_stone==stones,"failed upgrade preserves all balances")
 saver.end_save_write_barrier("hero_qa")
 eq.weapon_levels[sword]=3;eq.equipped_item_ids.armament=sword
 var frozen: Dictionary=eq.build_active_run_loadout_snapshot();eq.active_run_loadout_snapshot=frozen
 eq.weapon_levels[sword]=12
 var actor:=TestActor.new();var mock_stats:=TestStats.new();actor.player_stats=mock_stats;actor.add_child(mock_stats);root.add_child(actor);actor.add_to_group("player")
 check(eq.get_item_weapon_level(sword)==3,"active run uses frozen permanent level")
 actor.remove_from_group("player")
 check(eq.get_item_weapon_level(sword)==12,"hub uses next-run level")
 var legacy: Dictionary=frozen.duplicate(true);legacy.erase("weapon_levels")
 check(not eq._normalize_active_run_loadout_snapshot(legacy).is_empty(),"legacy snapshot compatible at level1")
 var bad: Dictionary=frozen.duplicate(true);bad.weapon_levels[sword]=51
 check(eq._normalize_active_run_loadout_snapshot(bad).is_empty(),"invalid snapshot level rejected")
 eq.active_run_loadout_snapshot.clear()
 var target:=Victim.new();target.hook=Status;target.position=Vector2(10000,10000);root.add_child(target)
 var weapon: Node=load("res://scripts/weapon/spirit_sword_weapon.gd").new();weapon.configure_armament(sword);actor.add_child(weapon)
 weapon.create_projectile(actor,target)
 var projectile: Area2D=null
 for child: Node in root.get_children():
  if child is Area2D:projectile=child
 check(projectile!=null and is_equal_approx(projectile.damage,11.1),"actual starter attack includes permanent level12 multiplier")
 if projectile!=null:projectile.queue_free()
 weapon.queue_free();target.queue_free();await process_frame
 actor.add_to_group("player")
 for set_id: String in ["crimson_shadow","nine_heavens","solar_meridian","stillwater_mirror"]:
  equip_set(set_id)
  var victim:=Victim.new();victim.hook=Status;root.add_child(victim);victim.add_to_group("enemy")
  victim.take_damage(100)
  var status: Node=victim.get_node_or_null("EquipmentSetStatus")
  if set_id=="stillwater_mirror":
   check(status==null and Sets.get_active_passive(ids()).reduction==.08,"armor has no DOT and exact8% defense")
  else:
   check(status!=null,"real hit activates status "+set_id)
   status.set_physics_process(false)
   var age: float=status.age
   victim.take_damage(10);check(victim.get_node("EquipmentSetStatus")==status and status.age==age,"repeated hit cannot stack/extend status")
   var passive: Dictionary=Sets.get_active_passive(ids());var n: int=4 if passive.kind=="poison" else 3
   var hp: float=victim.current_hp
   for i: int in range(n):status._physics_process(1.0)
   check(is_equal_approx(victim.current_hp,hp-100*float(passive.ratio)*n),"DOT ratio and tick count "+set_id)
   check(victim.hits==2+n,"DOT never recursively procs")
   await process_frame
   check(victim.get_node_or_null("EquipmentSetStatus")==null,"status expires "+set_id)
  victim.queue_free();await process_frame
 equip_set("stillwater_mirror")
 var health: Node=load("res://tests/hero_health_fixture.gd").new();actor.add_child(health);health.iron_body_level=2
 health.take_damage(10)
 check(is_equal_approx(health.current_health,91.72),"real damage path combines10% Iron Body then8% set armor")
 eq.equipped_item_ids.boots="";health.current_health=100;health._physics_process(.31);health.take_damage(10)
 check(is_equal_approx(health.current_health,91),"missing fourth piece disables real armor")
 health.queue_free()
 equip_set("nine_heavens")
 var boss:=Victim.new();boss.hook=Status;root.add_child(boss);boss.add_to_group("enemy");boss.add_to_group("boss")
 boss.take_damage(100)
 var boss_status: Node=boss.get_node("EquipmentSetStatus");boss_status.set_physics_process(false)
 check(is_equal_approx(boss_status.tick_damage,3.0),"boss DOT reduced by50%")
 boss_status.set_physics_process(true)
 paused=true;var pause_age: float=boss_status.age;await create_timer(.08,true).timeout
 check(boss_status.age==pause_age,"status respects tree pause")
 paused=false;boss_status.set_physics_process(true)
 boss.queue_free();actor.queue_free();await process_frame
 # Real summon: all equipment pre-owned, every duplicate survives exactly once.
 var pavilion: Node=root.get_node("PavilionManager");var journey: Node=root.get_node("JourneyManager")
 for chapter: int in journey.get_chapter_ids():
  for stage: int in journey.get_stage_ids(chapter):journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
 for id: String in eq.get_item_ids():inv.item_counts[id]=1
 pavilion.state.pavilion_seals=10
 var old_shards: int=inv.get_item_count("refinement_shard");var old_total: int=inv.get_total_item_count()
 var summon: Dictionary=pavilion.summon_equipment(10)
 check(summon.success,"real10 pull commits")
 check(inv.get_total_item_count()==old_total+10 and inv.get_item_count("refinement_shard")==old_shards,"duplicates preserved without shard conversion")
 for result: Dictionary in summon.results:check(result.duplicate and result.duplicate_shards==0,"reveal metadata reports retained duplicate")
 # Actual HERO surface, filters, material details and small-screen containment.
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await create_timer(.5).timeout
 var screen: Control=current_scene
 for dimensions: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504)]:
  root.content_scale_size=Vector2i.ZERO;root.size=dimensions;await create_timer(.25).timeout
  screen._layout();await create_timer(.1).timeout
  check(screen.grid.columns==5,"five backpack columns "+str(dimensions))
  check(screen.page.size.x<=screen.content.size.x+1,"no horizontal clipping "+str(dimensions))
  check(screen.nav.get_global_rect().end.y<=root.size.y+1,"navigation stays onscreen "+str(dimensions))
  screen._show_detail(sword);await create_timer(.05).timeout
  check(screen.detail.get_global_rect().end.y<=screen.nav.position.y+1,"detail never covers navigation")
  screen._close_detail()
 screen.filter_id="material";screen._refresh_all();await process_frame
 check(screen.card_buttons.is_empty(),"retired refinement fragment stays hidden")
 screen.filter_id="all";screen._refresh_all();await process_frame
 screen.query="no_such_equipment";screen._rebuild_grid();screen._rebuild_grid()
 check(screen.page.get_node_or_null("EmptyResult")!=null,"empty search state")
 screen.query="";screen._rebuild_grid()
 # Persist additive progression and frozen run snapshot for separate-process read.
 inv.item_counts[sword]=2;eq.ascension_stars[sword]=2;eq.weapon_levels[sword]=3;eq.equipped_item_ids.armament=sword
 eq.active_run_loadout_snapshot.clear()
 root.get_node("GameSession").start_new_game()
 change_scene_to_file("res://scenes/levels/level_1.tscn");await settle_game()
 var starter: Node=current_scene.get_node("player_1/WeaponManager").get_weapon_by_name("Spirit Sword")
 for i: int in range(4):starter.upgrade()
 check(current_scene.get_node("CheckPointManager").save_checkpoint(),"real run checkpoint saved")
 await process_frame
 change_scene_to_file("res://scenes/ui/main_menu.tscn");await create_timer(.3).timeout
 eq.weapon_levels[sword]=12
 check(saver.write_save_batch({"equipment":eq.build_equipment_save_data(),"inventory":{"version":1,"item_counts":inv.item_counts}}),"new fields persist through existing journal")
 print("HERO_RULES_CHECKS=",checks,";FAILURES=",failures)
 quit(1 if failures else 0)
