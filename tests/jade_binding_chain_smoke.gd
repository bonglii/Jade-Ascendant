extends SceneTree
var Chain: Script
var Cast: Script
var Slow: Script
var checks: int = 0
var failures: int = 0
class Stats extends Node:
 var critical: bool = false
 var resonance: bool = false
 var attack_cooldown: float = 1.0
 func calculate_damage_result(amount: float) -> Dictionary: return {"damage":amount * (2.0 if critical else 1.0), "is_critical":critical}
 func has_sword_dao_resonance() -> bool: return resonance
class Player extends CharacterBody2D:
 var player_stats: Node
class Victim extends CharacterBody2D:
 var is_dead: bool = false
 var received: float = 0.0
 var hits: int = 0
 func take_damage(amount: float) -> void: received += amount; hits += 1
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error("JADE_CHAIN_FAILURE "+label)
func victim(pos: Vector2, boss: bool = false) -> Victim:
 var v := Victim.new();v.position=pos;root.add_child(v);v.add_to_group("enemy")
 if boss: v.add_to_group("boss")
 return v
func last_cast() -> Node:
 return get_nodes_in_group("jade_binding_cast").back()
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_chain_qa"): quit(2); return
 await create_timer(.3).timeout
 Chain=load("res://scripts/weapon/jade_binding_chain_weapon.gd");Cast=load("res://scripts/weapon/jade_binding_cast.gd");Slow=load("res://scripts/weapon/jade_binding_slow.gd")
 var p := Player.new();p.name="player_1"
 var stats := Stats.new();stats.name="PlayerStats";p.player_stats=stats;p.add_child(stats);root.add_child(p)
 var w: Node = Chain.new();w.configure_armament("jade_binding_chain");p.add_child(w)
 check(w.weapon_name=="Spirit Sword","legacy checkpoint key retained")
 check(w.get_combat_display_name()=="Jade Binding Chain","public identity is chain")
 check(w.cooldown==1.8,"deliberate casting cadence")
 var a := victim(Vector2(100,0));var b := victim(Vector2(120,20));var far := victim(Vector2(190,0));var boss := victim(Vector2(250,0),true)
 w.attack(p,a)
 var cast: Node=last_cast();cast.set_process(false)
 check(cast.targets.size()==2,"Lv.1 selects exactly two nearby valid enemies")
 cast._process(.21);check(a.hits==0 and b.hits==0,"seal never deals premature damage")
 cast._process(.02);check(is_equal_approx(a.received,3.0) and is_equal_approx(b.received,2.0),"binding chip uses actual stats")
 check(Slow.movement_factor(a)==.6,"normal target slows by40 percent")
 check(far.hits==0 and boss.hits==0,"outside cluster and boss reach excluded")
 cast._process(.60);check(is_equal_approx(a.received,18.0) and is_equal_approx(b.received,2.0),"primary knot detonates first")
 cast._process(.10);check(is_equal_approx(b.received,10.0),"secondary detonation follows, no splash multiplication")
 cast._process(.10);check(a.hits==2 and b.hits==2,"each target hit at most once per phase")
 cast.queue_free();await process_frame
 for lv: int in range(1,8):
  w.level=lv;check(w.get_binding_target_count()==2+int(lv>=3)+int(lv>=5)+int(lv>=7),"target milestones Lv."+str(lv))
  check(w.get_binding_radius()==80+12*(w.get_binding_target_count()-2),"radius milestones Lv."+str(lv))
 w.level=7
 for i: int in range(3): victim(Vector2(110+i*10,-20-i*10))
 w.attack(p,a);cast=last_cast();cast.set_process(false)
 check(cast.targets.size()==5,"Lv.7 caps five targets")
 a.is_dead=true;b.position=Vector2(500,0)
 cast._process(.23)
 check(a.hits==2 and b.hits==2,"dead and escaped targets receive no delayed hit")
 cast.queue_free();await process_frame
 a.is_dead=false;b.position=Vector2(120,20)
 Slow.apply(boss);check(Slow.movement_factor(boss)==.88,"boss gets12 percent slow, never root")
 var saved: float=a.get_node("JadeBindingSlow").remaining
 paused=true
 await create_timer(.12,true).timeout
 check(is_equal_approx(a.get_node("JadeBindingSlow").remaining,saved),"pause freezes status clock")
 paused=false
 await create_timer(.85).timeout
 check(Slow.movement_factor(a)==1.0,"expired slow restores factor without editing base stats")
 Slow.apply(a);check(Slow.movement_factor(a)==.6 and a.get_node("JadeBindingSlow").is_physics_processing(),"expired component reactivates on later cast")
 Slow.apply(a);check(a.get_node("JadeBindingSlow").multiplier==.6 and a.get_node("JadeBindingSlow").remaining<=.72,"overlapping slows never multiply or add durations")
 var c := victim(Vector2(118,40))
 w.level=1;stats.critical=true;stats.resonance=true
 w.attack(p,a);cast=last_cast();cast.set_process(false)
 cast._process(.23)
 check(cast.resonance_used,"critical knot honors existing resonance unlock")
 var total_hits: int=0
 for n: Node in get_nodes_in_group("enemy"): total_hits+=int(n.hits)
 cast._process(.72)
 var after_hits: int=0
 for n: Node in get_nodes_in_group("enemy"): after_hits+=int(n.hits)
 check(after_hits-total_hits==2,"resonance cannot recurse on detonation")
 cast.queue_free();await process_frame
 w.attack(p,a);cast=last_cast();cast.set_process(false)
 a.queue_free();await process_frame
 cast._process(.23);check(is_instance_valid(cast),"freed weak target is safe")
 cast.queue_free();await process_frame
 stats.critical=false;stats.resonance=false
 # Exercise the real collision/movement script, not only the modifier lookup.
 p.position=Vector2(500,0)
 var real_enemy: CharacterBody2D=load("res://scenes/enemy/enemy_1.tscn").instantiate()
 real_enemy.position=Vector2(-200,0);root.add_child(real_enemy);real_enemy.set_physics_process(false)
 real_enemy._physics_process(.016);check(is_equal_approx(real_enemy.velocity.length(),80.0),"authored enemy movement unchanged without binding")
 Slow.apply(real_enemy);real_enemy._physics_process(.016)
 check(is_equal_approx(real_enemy.velocity.length(),48.0) and real_enemy.speed==80.0,"real enemy slows movement without rewriting base speed")
 real_enemy.get_node("JadeBindingSlow").remaining=0.0;real_enemy._physics_process(.016)
 check(is_equal_approx(real_enemy.velocity.length(),80.0),"real movement recovers after expiry")
 real_enemy.queue_free();p.position=Vector2.ZERO
 var eq: Node=root.get_node("EquipmentManager")
 eq.active_run_loadout_snapshot={"equipped_item_ids":{"armament":"jade_binding_chain"},"ascension_stars":{"jade_binding_chain":1}}
 var manager: Node=load("res://scripts/weapon/weapon_manager.gd").new();p.add_child(manager);manager.set_process(false)
 var starter: Variant=manager.get_weapon_by_name("Spirit Sword")
 check(starter.get_script()==Chain,"equipped armament selects actual new attack")
 eq.equipped_item_ids["armament"]="wanderer_jade_jian"
 check(starter.armament_id=="jade_binding_chain" and eq.get_runtime_equipped_item_id("armament")=="jade_binding_chain","hub changes cannot mutate active run identity")
 starter.level=5;starter.base_damage=30
 check(starter.get_binding_target_count()==4 and starter.base_damage==30,"legacy checkpoint level and damage restore chain progression")
 check(manager.get_weapon_cooldown(starter)>=1.25,"bounded cadence")
 stats.attack_cooldown=.1;check(manager.get_weapon_cooldown(starter)==1.25,"high attack speed caps cast overlap")
 var up: Node=load("res://scripts/ui/level_up.gd").new();up.weapon_manager=manager
 check(up.get_upgrade_display_name("spirit_sword")=="Jade Binding Chain","refinement card names equipped attack")
 check(up.get_upgrade_display_name("sword_dao_resonance")=="Binding Dao Resonance","resonance card is weapon specific")
 starter.level=2;check(up._get_weapon_upgrade_effect("spirit_sword").contains("+1 BINDING"),"Lv.3 card describes real target milestone")
 up.free()
 var catalog: Dictionary=load("res://scripts/data/equipment_catalog.gd").ITEMS
 check(catalog.jade_binding_chain.rarity=="legendary" and catalog.jade_binding_chain.slot=="armament","permanent Legendary armament")
 check(eq.MAX_ASCENSION_STAR==5,"existing star progression unchanged")
 var journey: Node=root.get_node("JourneyManager")
 for chapter: int in journey.get_chapter_ids():
  for stage: int in journey.get_stage_ids(chapter): journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
 var pavilion: Node=root.get_node("PavilionManager")
 check("jade_binding_chain" in pavilion.get_summon_pool_by_rarity().legendary,"new armament enters existing unlocked Legendary pool")
 eq.active_run_loadout_snapshot.clear()
 eq.equipped_item_ids["armament"]="jade_binding_chain"
 var book: Control=load("res://scripts/ui/skill_book_screen.gd").new();root.add_child(book)
 await process_frame
 check(book._display_name("spirit_sword")=="Jade Binding Chain","actual Skill Book renders selected armament identity")
 check(book._description("sword_dao_resonance").contains("40%"),"Skill Book explains actual resonance")
 book._search.text="Jade Binding Chain";book._on_search("Jade Binding Chain")
 check(book._count.text.begins_with("1 "),"Skill Book can search new weapon by public name")
 book.queue_free()
 var stat_script: Script=load("res://scripts/ui/in_run_stats_overlay.gd")
 check(stat_script.can_instantiate(),"runtime stats overlay compiles after weapon-name integration")
 manager.queue_free();p.queue_free()
 for n: Node in get_nodes_in_group("enemy"): n.queue_free()
 await process_frame
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  var vp:=SubViewport.new();vp.size=dims;root.add_child(vp)
  var holder:=Control.new();holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);vp.add_child(holder)
  var preview: Control=load("res://scripts/ui/jade_binding_preview.gd").new();holder.add_child(preview)
  for i in range(5): await process_frame
  var panel: Control=preview.get_child(1).get_child(0)
  check(panel.get_global_rect().position.x>=0 and panel.get_global_rect().end.x<=dims.x,"preview width "+str(dims))
  check(panel.get_global_rect().position.y>=0 and panel.get_global_rect().end.y<=dims.y,"preview height "+str(dims))
  vp.queue_free();await process_frame
 print("JADE_BINDING_CHAIN_CHECKS=",checks,"; FAILURES=",failures)
 quit(0 if failures==0 else 1)
