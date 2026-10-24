extends SceneTree
var WeaponScript: Script
var Flight: Script
var checks: int=0
var failures: int=0
class Stats extends Node:
 var critical: bool=false
 var resonance: bool=false
 var attack_cooldown: float=1.0
 func calculate_damage_result(value: float) -> Dictionary: return {"damage":value*(2 if critical else 1),"is_critical":critical}
 func has_sword_dao_resonance() -> bool: return resonance
class Player extends CharacterBody2D:
 var player_stats: Node
class Victim extends Node2D:
 var is_dead: bool=false
 var amount: float=0
 var count: int=0
 func take_damage(value: float) -> void: amount+=value;count+=1
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error("GLAIVE_FAILURE "+label)
func victim(pos: Vector2,boss: bool=false) -> Victim:
 var v:=Victim.new();v.position=pos;root.add_child(v);v.add_to_group("enemy")
 if boss: v.add_to_group("boss")
 return v
func flight(p: Node2D,pos: Vector2,lv: int=1,side: float=1,delay: float=0) -> Node:
 var f: Node=Flight.new();root.add_child(f);f.configure(p,pos,10,lv,side,delay);f.set_physics_process(false);return f
func nodes(values: Array) -> Array[Node]:
 var typed: Array[Node]=[];typed.assign(values);return typed
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_glaive_qa"):quit(2);return
 await create_timer(.3).timeout
 WeaponScript=load("res://scripts/weapon/celestial_returning_glaive_weapon.gd");Flight=load("res://scripts/weapon/returning_glaive_flight.gd")
 var p:=Player.new();p.name="player_1";var stats:=Stats.new();stats.name="PlayerStats";p.player_stats=stats;p.add_child(stats);root.add_child(p)
 var w: Node=WeaponScript.new();w.configure_armament("celestial_returning_glaive");p.add_child(w)
 check(w.weapon_name=="Spirit Sword" and w.get_combat_display_name()=="Celestial Returning Glaive","stable save key, distinct public identity")
 check(w.cooldown==2.1,"authored returning cadence")
 var a:=victim(Vector2(100,0));var spin:=victim(Vector2(116,0));var boss:=victim(Vector2(310,0),true)
 var f: Node=flight(p,a.position)
 f._advance(.31,p,get_nodes_in_group("enemy"));check(is_equal_approx(a.amount,8),"swept outbound catches enemy skipped by a slow rendered frame")
 f._advance(.09,p,get_nodes_in_group("enemy"));check(a.count==1,"outbound overlap cannot repeat hit")
 f._advance(.10,p,get_nodes_in_group("enemy"));check(f.phase==1,"flight enters endpoint spin")
 f._advance(.12,p,get_nodes_in_group("enemy"));f._advance(.13,p,get_nodes_in_group("enemy"))
 check(spin.count==2 and is_equal_approx(spin.amount,11),"endpoint spin hits once after outbound, never every tick")
 check(f.phase==2,"spin ends into real return")
 var new_target:=victim(Vector2(100,50));p.position=Vector2(70,120)
 f._advance(.10,p,get_nodes_in_group("enemy"));check(f.global_position.y>0,"return follows current moved player, not frozen launch origin")
 check(new_target.amount==10,"steering return can hit a different enemy")
 for i in range(8):f._advance(.03,p,get_nodes_in_group("enemy"))
 check(f.phase==3 and f.global_position.distance_to(p.position)<.01,"real catch snaps to actual player position")
 check(boss.count==0,"unrelated distant boss receives no path damage")
 f.queue_free();await process_frame
 p.position=Vector2.ZERO
 for lv: int in [1,3,5,7]:
  var before: int=get_nodes_in_group("returning_glaive_flight").size()
  w.level=lv;w.attack(p,a)
  var flights: Array[Node]=get_nodes_in_group("returning_glaive_flight")
  check(flights.size()-before==(2 if lv>=5 else 1),"disc count milestone Lv."+str(lv))
  for i: int in range(flights.size()):
   var projectile: Node=flights[i];projectile.set_physics_process(false)
   check(projectile.curve==(52.0 if lv>=3 else 0.0),"crescent milestone Lv."+str(lv))
   check(projectile.final_refinement==(lv>=7),"closure only Lv.7")
   if i==1:
    check(projectile.side==-1 and projectile.launch_delay==.16,"twin has opposite path and delay")
    var old_pos: Vector2=projectile.global_position
    projectile._physics_process(.10);check(projectile.global_position==old_pos and projectile.launch_delay>0,"second disc cannot fire before delay")
    projectile._physics_process(.10);check(projectile.global_position!=old_pos,"second disc launches after actual delay")
   projectile.queue_free()
  await process_frame
 # Curve mirrors around the aim line rather than duplicating the same projectile.
 var left: Node=flight(p,Vector2(100,0),3,1);var right: Node=flight(p,Vector2(100,0),3,-1)
 left._advance(.23,p,nodes([]));right._advance(.23,p,nodes([]))
 check(left.position.y*right.position.y<0 and is_equal_approx(absf(left.position.y),52.0),"opposite crescent geometry")
 left.queue_free();right.queue_free();await process_frame
 stats.critical=true;stats.resonance=true
 f=flight(p,a.position);f._sweep(Vector2.ZERO,Vector2(110,0),p,nodes([a]),0,.8)
 check(f.outbound_critical,"outbound critical charges resonance")
 stats.critical=false
 var first:=victim(Vector2(50,0));var second:=victim(Vector2(60,0))
 f._sweep(Vector2(80,0),Vector2.ZERO,p,nodes([first,second]),2,1)
 check(is_equal_approx(first.amount,14) and second.amount==10,"only first returning hit receives40 percent base bonus")
 f._sweep(Vector2.ZERO,Vector2(80,0),p,nodes([first,second]),2,1)
 check(first.count==1 and second.count==1,"return damage cannot repeat or recursively create flight")
 f.queue_free();await process_frame
 stats.critical=false;stats.resonance=false
 var close:=victim(Vector2(40,0));var outside:=victim(Vector2(80,60))
 f=flight(p,a.position,7);f.phase=2;f.position=Vector2(20,0)
 f._advance(.04,p,nodes([close,outside]));check(f.phase==3,"Lv.7 closure requires real catch")
 check(is_equal_approx(close.amount,11) and outside.amount==0,"closure radius58 and35 percent base, separate from return75 percent")
 f._advance(.10,p,nodes([close,outside]));check(close.count==2,"caught ring cannot damage every frame")
 f.queue_free();await process_frame
 var unreachable:=victim(Vector2(310,0),true)
 f=flight(p,Vector2(290,0));f._sweep(Vector2(280,0),Vector2(340,0),p,nodes([unreachable]),0,.8)
 check(unreachable.amount==0,"boss reach300 enforced for swept hits")
 var dead:=victim(Vector2(40,0));dead.is_dead=true
 f._sweep(Vector2.ZERO,Vector2(100,0),p,nodes([dead]),0,.8);check(dead.count==0,"dead enemy ignored")
 dead.queue_free();await process_frame
 f._sweep(Vector2.ZERO,Vector2(100,0),p,nodes([]),0,.8);check(is_instance_valid(f),"freed target never retained by flight")
 var age_before: float=f.age;f.set_physics_process(true);paused=true;await create_timer(.10,true).timeout
 check(f.age==age_before,"pause freezes flight and damage")
 paused=false;f.set_physics_process(false);f._physics_process(3.5)
 check(f.is_queued_for_deletion(),"lifetime timeout prevents persistent runaway discs without fake closure")
 await process_frame
 var eq: Node=root.get_node("EquipmentManager");eq.active_run_loadout_snapshot={"equipped_item_ids":{"armament":"celestial_returning_glaive"},"ascension_stars":{"celestial_returning_glaive":1}}
 var manager: Node=load("res://scripts/weapon/weapon_manager.gd").new();p.add_child(manager);manager.set_process(false)
 var starter: Node=manager.get_weapon_by_name("Spirit Sword")
 check(starter.get_script()==WeaponScript,"runtime equipment chooses actual returning attack")
 stats.attack_cooldown=.1;check(manager.get_weapon_cooldown(starter)==1.75,"cooldown floor bounds maximum four simultaneous discs")
 var up: Node=load("res://scripts/ui/level_up.gd").new();up.weapon_manager=manager
 check(up.get_upgrade_display_name("spirit_sword")=="Celestial Returning Glaive","correct refinement title")
 for lv: int in [2,4,6]:
  starter.level=lv;check(up._get_weapon_upgrade_effect("spirit_sword").contains(["CRESCENT","TWIN","CLOSURE"][[2,4,6].find(lv)]),"refinement card reports actual milestone")
 check(up.get_upgrade_display_name("sword_dao_resonance")=="Returning Dao Resonance","existing synergy gets weapon-specific semantics")
 up.free();manager.queue_free()
 eq.active_run_loadout_snapshot.clear();eq.equipped_item_ids["armament"]="celestial_returning_glaive"
 var book: Control=load("res://scripts/ui/skill_book_screen.gd").new();root.add_child(book);await process_frame
 check(book._display_name("spirit_sword")=="Celestial Returning Glaive","Skill Book title follows equipped armament")
 book._search.text="Celestial Returning Glaive";book._on_search(book._search.text)
 check(book._count.text.begins_with("1 "),"new weapon searchable in real Skill Book")
 book.queue_free();p.queue_free()
 for enemy: Node in get_nodes_in_group("enemy"):enemy.queue_free()
 await process_frame
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  var vp:=SubViewport.new();vp.size=dims;root.add_child(vp)
  var holder:=Control.new();holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);vp.add_child(holder)
  var preview: Control=load("res://scripts/ui/returning_glaive_preview.gd").new();holder.add_child(preview)
  for i in range(5):await process_frame
  var panel: Control=preview.get_child(1).get_child(0)
  check(panel.get_global_rect().position.x>=0 and panel.get_global_rect().end.x<=dims.x,"preview width "+str(dims))
  check(panel.get_global_rect().position.y>=0 and panel.get_global_rect().end.y<=dims.y,"preview height "+str(dims))
  preview._cycle_level();preview._cycle_level();preview._cycle_level();check(preview.level==7,"preview lets player inspect every milestone")
  preview.player_offset=60;check(preview.player_offset==60,"preview supports return-steering demonstration")
  vp.queue_free();await process_frame
 print("RETURNING_GLAIVE_CHECKS=",checks,";FAILURES=",failures)
 quit(1 if failures else 0)
