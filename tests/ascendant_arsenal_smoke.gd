extends SceneTree
var Cast: Script
const Sets=preload("res://scripts/data/equipment_set_catalog.gd")
const Slow=preload("res://scripts/weapon/jade_binding_slow.gd")
const Ledger=preload("res://scripts/weapon/run_combat_ledger.gd")
var checks: int=0
var failures: int=0
var eq: Node
var world: Node2D
var actor: Actor
class Stats extends Node:
 var critical: bool=false
 var resonance: bool=false
 func calculate_damage_result(value: float) -> Dictionary:return {"damage":value,"is_critical":critical}
 func has_sword_dao_resonance() -> bool:return resonance
class Actor extends CharacterBody2D:
 var player_stats: Node
 var level: int=1
 var experience: int=0
 var experience_to_next_level: int=10
class Victim extends Node2D:
 var max_hp: float=10000
 var current_hp: float=10000
 var is_dead: bool=false
 var hits: int=0
 var received: float=0
 func take_damage(value: float) -> void:
  var actual: float=minf(current_hp,value)
  current_hp-=actual;received+=actual;hits+=1
  if current_hp<=0:is_dead=true
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("ARSENAL_FAIL "+label)
func equip(set_id: String="") -> void:
 eq.active_run_loadout_snapshot={}
 eq.equipped_item_ids={"armament":"","robe":"","bracer":"","boots":"","pendant":""}
 for id: String in Sets.get_piece_ids(set_id):eq.equipped_item_ids[str(eq.get_item_data(id).slot)]=id
 eq.active_run_loadout_snapshot=eq.build_active_run_loadout_snapshot()
func victim(at: Vector2,boss: bool=false) -> Victim:
 var v:=Victim.new();world.add_child(v);v.position=at;v.add_to_group("enemy")
 if boss:v.add_to_group("boss")
 return v
func cast(id: String,target: Node2D,lv: int=1) -> Node:
 var c: Node=Cast.new();world.add_child(c);c.configure(actor,target,id,lv,10+5*(lv-1));c.set_physics_process(false);return c
func advance(c: Node,seconds: float) -> void:
 for i: int in range(ceili(seconds/.01)):
  if c.is_queued_for_deletion():break
  c._physics_process(.01)
func clear() -> void:
 for node: Node in get_nodes_in_group("enemy"):node.queue_free()
 for node: Node in get_nodes_in_group("ascendant_armament_cast"):node.queue_free()
 await process_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_arsenal_qa"):quit(2);return
 # This fixture measures hits/authority, not playback. Prevent incidental SFX
 # before simulated casts; the dedicated audio runtime suite stays enabled.
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 await process_frame
 eq=root.get_node("EquipmentManager")
 Cast=load("res://scripts/weapon/ascendant_armament_cast.gd")
 world=Node2D.new();root.add_child(world);current_scene=world
 actor=Actor.new();actor.add_to_group("player");actor.name="player_1"
 actor.player_stats=Stats.new();actor.player_stats.name="PlayerStats";actor.add_child(actor.player_stats);world.add_child(actor)
 for id: String in ["frost_lotus","vermilion_verdict","celestial_aegis"]:
  var pieces: Array[String]=Sets.get_piece_ids(id)
  check(pieces.size()==4,"exactly four pieces "+id)
  check(not Sets.get_active_passive(pieces).is_empty(),"full passive "+id)
  pieces.pop_back();pieces.append("void_piercer_spear")
  check(Sets.get_active_passive(pieces).is_empty(),"weapon cannot finish set "+id)
 equip("frost_lotus")
 var v:=victim(Vector2(100,0));Ledger.apply_hit(v,10,"phoenix_war_fan")
 check(is_equal_approx(Slow.movement_factor(v),.8),"Frost applied after real damage")
 var boss:=victim(Vector2(120,0),true);Ledger.apply_hit(boss,10,"fire_orb")
 check(is_equal_approx(Slow.movement_factor(boss),.94),"Frost bosses only6 percent")
 Slow.apply(v,.20,.6,.88);v.get_node("JadeBindingSlow").set_physics_process(false)
 v.get_node("JadeBindingSlow")._physics_process(.21)
 check(is_equal_approx(Slow.movement_factor(v),.8),"weaker refresh never prolongs strong slow")
 v.get_node("JadeBindingSlow")._physics_process(.40)
 check(Slow.movement_factor(v)==1,"expiration restores movement")
 equip("vermilion_verdict");v.current_hp=3500;v.max_hp=10000
 Ledger.apply_hit(v,100,"void_piercer_spear")
 check(is_equal_approx(v.current_hp,3388),"Verdict12 percent below35 percent")
 boss.current_hp=3500;Ledger.apply_hit(boss,100,"fire_orb")
 check(is_equal_approx(boss.current_hp,3394),"Verdict boss6 percent")
 Ledger.apply_hit(v,100,"set_bleed")
 check(is_equal_approx(v.current_hp,3288),"Verdict never amplifies DoT")
 v.current_hp=3501;Ledger.apply_hit(v,100,"fire_orb")
 check(v.current_hp==3401,"threshold uses pre-hit HP")
 await clear();equip()
 for id: String in ["phoenix_war_fan","void_piercer_spear","astral_resonance_bell"]:
  check(Sets.get_set_id_for_item(id).is_empty(),"standalone weapon "+id)
  for lv: int in [1,3,5,7]:
   v=victim(Vector2(100 if id!="astral_resonance_bell" else 45,0))
   var c: Node=cast(id,v,lv)
   var base: float=10+5*(lv-1)
   advance(c,2.6)
   var expected: float=base*(2.86 if lv>=5 else 2.2) if id=="void_piercer_spear" else base*.8*(2+int(lv>=3)+int(lv>=7)) if id=="astral_resonance_bell" else base*.9
   check(is_equal_approx(v.received,expected),"actual solo damage "+id+" Lv."+str(lv)+" got "+str(v.received))
   print("ARSENAL_MEASURE ",id," Lv.",lv," hits=",v.hits," hp_damage=",v.received)
   check(Ledger.SOURCES.has(id),"ledger source "+id)
   await clear()
  v=victim(Vector2(100,0),true)
  var outside:=victim(Vector2(301,0),true)
  var c: Node=cast(id,v,7);advance(c,2.6)
  check(outside.hits==0,"boss range300 "+id)
  await clear()
 # Actual hits at the extended edge, with unchanged per-cast damage.
 for id: String in ["phoenix_war_fan","void_piercer_spear"]:
  for distance: float in [295.0,390.0]:
   v=victim(Vector2(distance,0),distance<300)
   var extended: Node=cast(id,v,7);advance(extended,2.6)
   check(v.hits>0,"extended range actual hit "+id+str(distance))
   check(is_equal_approx(v.received,40*(.90 if id=="phoenix_war_fan" else 2.86)),"extended reach preserves damage "+id)
   await clear()
 # Snapshot line can be dodged; fan central path remains a true path.
 v=victim(Vector2(160,0));var spear: Node=cast("void_piercer_spear",v,7)
 advance(spear,.20);check(v.hits==0,"spear charge has no early damage")
 v.position.y=70;advance(spear,.50);check(v.hits==0,"moving target dodges snapshot thrust")
 await clear()
 v=victim(Vector2(45,0));var bell: Node=cast("astral_resonance_bell",v,7)
 actor.position=Vector2(600,0);advance(bell,2.6)
 check(v.hits==4,"bell zone persists at original position after movement")
 actor.position=Vector2.ZERO;await clear()
 for id: String in ["void_piercer_spear","astral_resonance_bell"]:
  for i: int in range(20):victim(Vector2(40+i,0))
  var c: Node=cast(id,get_nodes_in_group("enemy")[0],7);advance(c,2.6)
  var count: int=0;var hits: int=0
  for target: Node in get_nodes_in_group("enemy"):
   if target.hits>0:count+=1
   hits+=target.hits
  check(count==(8 if id=="void_piercer_spear" else 12),"bounded crowd targets "+id)
  check(hits==(16 if id=="void_piercer_spear" else 48),"bounded crowd hit phases "+id)
  await clear()
 actor.player_stats.critical=true;actor.player_stats.resonance=true
 for id: String in ["phoenix_war_fan","void_piercer_spear","astral_resonance_bell"]:
  v=victim(Vector2(45,0));var c: Node=cast(id,v,7);advance(c,.35)
  if not c.is_queued_for_deletion():advance(c,2.3)
  check(c.resonance_used,"real crit resonance consumes once "+id)
  var expected: float=86.4 if id=="phoenix_war_fan" else 149.6 if id=="void_piercer_spear" else 140.8
  check(is_equal_approx(v.received,expected),"resonance empowers exactly one eligible hit "+id)
  await clear()
 actor.player_stats.critical=false;actor.player_stats.resonance=false
 equip("celestial_aegis")
 var hp: Node=load("res://tests/hero_health_fixture.gd").new();hp.name="PlayerHealth";actor.add_child(hp)
 var guard: Node=load("res://scripts/effects/celestial_aegis_guard.gd").new();hp.add_child(guard);guard.set_physics_process(false)
 guard._physics_process(7.9);check(hp.qi_shield_charges==0,"Aegis full quiet wait")
 hp.take_damage(10);check(guard.quiet==0,"accepted hit resets Aegis")
 guard._physics_process(8);check(hp.qi_shield_charges==1,"Aegis grants single shield without heal")
 guard._physics_process(32);check(hp.qi_shield_charges==1 and hp.current_health==90,"Aegis never banks shields/heals")
 hp.hit_guard_remaining=0;hp.take_damage(10);check(guard.quiet==0 and hp.qi_shield_charges==0,"shield block restarts wait")
 hp.is_dead=true;guard._physics_process(10);check(hp.qi_shield_charges==0,"no dead-player shield")
 equip()
 print("ASCENDANT_ARSENAL_QA checks=",checks," failures=",failures)
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit(1 if failures else 0)
