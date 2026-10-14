extends SceneTree
const Sets=preload("res://scripts/data/equipment_set_catalog.gd")
var checks: int=0
var failures: int=0
class Player extends CharacterBody2D:
 var player_stats: Node
 var level: int=1
 var experience: int=0
 var experience_to_next_level: int=10
class Victim extends CharacterBody2D:
 var is_dead: bool=false
 var current_hp: float=100000.0
 var received: float=0.0
 var hits: int=0
 var hook: Script
 func take_damage(value: float) -> void:
  received+=value;current_hp-=value;hits+=1
  if hook!=null:hook.on_hit(self,value)
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("COMBAT_FAIRNESS_FAIL "+label)
func victim(where: Vector2,boss: bool=false) -> Victim:
 var target:=Victim.new();current_scene.add_child(target);target.position=where;target.add_to_group("enemy")
 if boss:target.add_to_group("boss")
 return target
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_combat_fairness_qa"):quit(2);return
 await process_frame
 var world:=Node2D.new();root.add_child(world);current_scene=world
 var actor:=Player.new();actor.name="player_1";actor.add_to_group("player")
 var health: Node=load("res://tests/hero_health_fixture.gd").new();health.name="PlayerHealth";actor.add_child(health)
 var stats: Node=load("res://scripts/stats/player_stats.gd").new();stats.name="PlayerStats";actor.player_stats=stats;actor.add_child(stats)
 var manager: Node=load("res://scripts/weapon/weapon_manager.gd").new();manager.name="WeaponManager";actor.add_child(manager)
 world.add_child(actor);manager.set_process(false);health.set_physics_process(false)
 var hp_events: Array[float]=[];var blocks: Array[int]=[]
 health.health_changed.connect(func(hp: float,_max: float):hp_events.append(hp))
 health.qi_shield_blocked.connect(func(remaining: int):blocks.append(remaining))
 health.take_damage(10)
 for i: int in range(9):health.take_damage(10)
 check(health.current_health==90 and hp_events.size()==1,"ten same-frame hits apply one actual HP event")
 health._physics_process(.29);health.take_damage(17)
 check(health.current_health==90,"guard rejects another source inside window")
 health._physics_process(.02);health.take_damage(17)
 check(health.current_health==73 and hp_events.size()==2,"next distinct hit lands after protection expires")
 health._physics_process(.31);health.take_damage(0);health.take_damage(NAN)
 check(not health.is_hit_guarded(),"invalid and zero hits do not reserve protection")
 health.current_health=100;health.qi_shield_charges=2;health.take_damage(17)
 for i: int in range(9):health.take_damage(10)
 check(health.current_health==100 and health.qi_shield_charges==1 and blocks==[1],"same burst consumes one shield, emits one block, no HP loss")
 health.set_physics_process(true);paused=true
 var remaining: float=health.hit_guard_remaining;await create_timer(.4,true).timeout
 check(is_equal_approx(health.hit_guard_remaining,remaining),"combat pause freezes the guard clock")
 paused=false;health.set_physics_process(false);health._physics_process(.31);health.take_damage(17)
 check(health.qi_shield_charges==0 and blocks==[1,0],"a later distinct hit consumes the next shield")
 health._physics_process(.31);health.current_health=5;health.take_damage(10)
 check(health.is_dead and health.current_health==0,"first lethal hit still kills normally")
 check(health.revive_from_rewarded() and health.hit_guard_remaining==0,"rewarded revive clears transient old-life guard")
 health.take_damage(17)
 check(health.current_health==60,"existing rewarded revive protection still owns its window")
 health.rewarded_revive_invulnerable_until_msec=Time.get_ticks_msec()-1;health.take_damage(17)
 check(health.current_health==43,"damage resumes after revive protection ends")
 health._physics_process(.31);health.current_health=100
 var real_enemy: Node=load("res://scenes/enemy/enemy_1.tscn").instantiate()
 for i: int in range(5):real_enemy.damage_player(actor)
 check(health.current_health==90,"production contact method participates in shared guard")
 real_enemy.free();health._physics_process(.31)
 # Real boss windup still owns its impact; player protection only gates accepted damage.
 health.current_health=100;health._physics_process(.31);health.set_physics_process(true)
 var boss_actor: Node=load("res://scenes/enemy/boss_1.tscn").instantiate()
 boss_actor.configure_encounter(load("res://scripts/data/chapter_one_catalog.gd").STAGES[1])
 world.add_child(boss_actor);boss_actor.set_physics_process(false);boss_actor.position=Vector2(80,0)
 boss_actor.attack_player();paused=true;await create_timer(.4,true).timeout
 check(health.current_health==100 and boss_actor._melee_cast_pending,"actual boss anticipation stays paused")
 paused=false;await create_timer(.25,false).timeout
 check(health.current_health==94 and not boss_actor._melee_cast_pending,"real melee hits once after windup")
 boss_actor.attack_player();await create_timer(.25,false).timeout
 check(health.current_health==94,"second close-timed melee respects the existing player guard")
 await create_timer(.08,false).timeout;boss_actor.attack_player();await create_timer(.25,false).timeout
 check(health.current_health==88,"later boss melee still damages after the guard expires")
 boss_actor.attack_player();actor.position.x=1000;await create_timer(.25,false).timeout
 check(health.current_health==88,"dodging actual melee remains effective")
 actor.position=Vector2.ZERO;boss_actor.queue_free();await process_frame
 health.set_physics_process(false);health._physics_process(.31)
 var old_eq: Dictionary=root.get_node("EquipmentManager").equipped_item_ids.duplicate(true)
 var old_snapshot: Dictionary=root.get_node("EquipmentManager").active_run_loadout_snapshot.duplicate(true)
 var chain: Node=load("res://scripts/weapon/jade_binding_chain_weapon.gd").new();chain.configure_armament("jade_binding_chain");actor.add_child(chain)
 var glaive: Node=load("res://scripts/weapon/celestial_returning_glaive_weapon.gd").new();glaive.configure_armament("celestial_returning_glaive");actor.add_child(glaive)
 var sword: Node=manager.get_weapon_by_name("Spirit Sword")
 for factor: float in [1.0,pow(.95,10),.2]:
  stats.attack_cooldown=factor
  for weapon: Node in [chain,glaive]:
   var requested: float=manager.get_requested_weapon_cooldown(weapon)
   var actual: float=manager.get_weapon_cooldown(weapon)
   var potency: float=manager.get_cast_tempo_damage_multiplier(weapon)
   check(is_equal_approx(potency/actual,1.0/requested),"tempo preserves virtual damage-per-second without extra casts "+weapon.armament_id)
   check(actual>=(1.25 if weapon==chain else 1.75),"cast bounds remain intact")
  check(manager.get_cast_tempo_damage_multiplier(sword)==1.0 and is_equal_approx(manager.get_weapon_cooldown(sword),factor),"ordinary Sword keeps its existing cadence and damage")
 stats.attack_cooldown=.2
 var target:=victim(Vector2(180,0),true)
 chain.attack(actor,target)
 var cast: Node=get_nodes_in_group("jade_binding_cast").back();cast.set_process(false)
 var snapshot: float=cast.base_damage
 stats.attack_cooldown=1.0;cast._process(.23);cast._process(.60)
 check(is_equal_approx(snapshot,10.0*1.25/.36) and is_equal_approx(target.received,snapshot*1.8),"real Chain snapshots tempo potency then seals/detonates normally")
 cast.queue_free();target.queue_free();await process_frame
 stats.attack_cooldown=.2;target=victim(Vector2(180,0),true);glaive.attack(actor,target)
 var launch: Node=get_nodes_in_group("returning_glaive_flight").back();launch.set_physics_process(false)
 snapshot=launch.base_damage;stats.attack_cooldown=1.0
 for i: int in range(45):launch._physics_process(.025)
 check(is_equal_approx(snapshot,10.0*1.75/.42) and target.hits==3 and is_equal_approx(target.received,snapshot*2.1),"real Glaive uses snapshotted potency on outbound, spin and return")
 launch.queue_free();target.queue_free();await process_frame
 var Flight: Script=load("res://scripts/weapon/returning_glaive_flight.gd")
 for distance: float in [40,80,180,230]:
  target=victim(Vector2(distance,0),true)
  var flight: Node=Flight.new();world.add_child(flight);flight.configure(actor,target.position,10,1,1,0);flight.set_physics_process(false)
  for i: int in range(45):flight._physics_process(.025)
  check(target.hits==3 and is_equal_approx(target.received,21),"spin actually reaches stationary boss at "+str(distance))
  flight.queue_free();target.queue_free();await process_frame
 target=victim(Vector2(180,0),true)
 var flight: Node=Flight.new();world.add_child(flight);flight.configure(actor,target.position,10,1,1,0);flight.set_physics_process(false)
 for i: int in range(19):flight._physics_process(.025)
 check(flight.phase==1 and target.hits==1,"outbound completes before spin damage")
 target.position.y=80
 for i: int in range(26):flight._physics_process(.025)
 check(target.hits==1,"moving out of the snapshot path dodges spin/return")
 flight.queue_free();target.queue_free();await process_frame
 var eq: Node=root.get_node("EquipmentManager")
 var Status: Script=load("res://scripts/effects/equipment_set_status.gd")
 for set_id: String in ["crimson_shadow","nine_heavens","solar_meridian"]:
  eq.equipped_item_ids={"armament":"","robe":"","bracer":"","boots":"","pendant":""}
  for id: String in Sets.get_piece_ids(set_id):eq.equipped_item_ids[str(eq.get_item_data(id).slot)]=id
  eq.active_run_loadout_snapshot=eq.build_active_run_loadout_snapshot()
  for boss: bool in [false,true]:
   target=victim(Vector2(180,0),boss);target.hook=Status;target.take_damage(3)
   var status: Node=target.get_node("EquipmentSetStatus");status.set_physics_process(false)
   var ratio: float=float(Sets.get_active_passive(Sets.get_piece_ids(set_id)).ratio)*(0.5 if boss else 1.0)
   check(is_equal_approx(status.tick_damage,3*ratio),"first hit applies correct DOT/boss ratio "+set_id)
   status._physics_process(1)
   var tick_count: int=status.ticks_left;var age: float=status.age;var clock: float=status.clock
   target.take_damage(15)
   check(is_equal_approx(status.tick_damage,15*ratio),"strong detonation replaces weaker seal potency")
   target.take_damage(2)
   check(is_equal_approx(status.tick_damage,15*ratio),"weaker later hit cannot downgrade DOT")
   check(status.ticks_left==tick_count and status.age==age and status.clock==clock and target.get_node("EquipmentSetStatus")==status,"potency refresh never extends ticks, clock or instances")
   target.set_meta(&"jade_set_dot_inflight",true);Status.on_hit(target,1000);target.remove_meta(&"jade_set_dot_inflight")
   check(is_equal_approx(status.tick_damage,15*ratio),"DOT damage cannot recursively amplify itself")
   var before: float=target.current_hp
   for i: int in range(tick_count):status._physics_process(1)
   check(is_equal_approx(target.current_hp,before-15*ratio*tick_count),"remaining ticks use upgraded potency without new ticks")
   await process_frame
   check(target.get_node_or_null("EquipmentSetStatus")==null,"DOT still expires on original schedule")
   target.queue_free();await process_frame
 eq.equipped_item_ids=old_eq;eq.active_run_loadout_snapshot=old_snapshot
 var up: Node=load("res://scripts/ui/level_up.gd").new();up.weapon_manager=manager
 manager.weapons.clear();manager.weapons.append(chain)
 check(up.get_upgrade_effect("attack_speed").contains("STRONGER"),"refinement card discloses real tempo benefit")
 check(load("res://scripts/data/skill_catalog.gd").get_upgrade_description("attack_speed").contains("casting limit"),"Skill Book explains extra tempo")
 up.free();chain.queue_free();glaive.queue_free();actor.queue_free()
 print("COMBAT_FAIRNESS_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
