extends SceneTree
var Compass: Script
var Cast: Script
const Arena=preload("res://scripts/game/boss_combat_arena.gd")
const Ledger=preload("res://scripts/weapon/run_combat_ledger.gd")
var checks: int=0
var failures: int=0
var player: Node2D
var manager: Node
var stats: Node
var weapon: Node
var targets: Array[Node2D]=[]
var measurements: Array[Dictionary]=[]
class Target extends Node2D:
 var current_hp: float=1000000
 var max_hp: float=1000000
 var is_dead: bool=false
 var hits: int=0
 func take_damage(amount: float) -> void:
  current_hp=maxf(0,current_hp-amount);is_dead=current_hp<=0;hits+=1
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("COMPASS_PURSUIT_FAIL "+label)
func frames(n: int=3) -> void:
 for i: int in n:await process_frame
func _initialize() -> void:run.call_deferred()
func target(offset: Vector2,boss: bool=false) -> Node2D:
 var t:=Target.new();current_scene.add_child(t);t.add_to_group("enemy")
 if boss:t.add_to_group("boss")
 t.global_position=player.global_position+offset;targets.append(t);return t
func clear_case() -> void:
 if is_instance_valid(weapon):weapon.free()
 for actor: Node in get_nodes_in_group("heavenweaver_cast"):actor.free()
 for t: Node2D in targets:
  if is_instance_valid(t):t.free()
 targets.clear()
 manager.weapons.clear();manager.attack_timers.clear();manager._cached_target=null;manager._target_refresh_remaining=0
 manager.get_node("RunCombatLedger").totals.clear()
func make_weapon(lv: int=1) -> void:
 weapon=Compass.new();weapon.configure_armament("heavenweaver_compass");manager.add_child(weapon);weapon.set_process(false)
 for i: int in range(lv-1):weapon.upgrade()
 manager.add_weapon(weapon);manager.attack_timers[weapon]=0.0
func tick(delta: float=1.0/60.0) -> void:
 manager._process(delta)
 if is_instance_valid(weapon.pursuit):
  weapon.pursuit.set_physics_process(false);weapon.pursuit._physics_process(delta)
func total_loss() -> float:
 var loss: float=0
 for t: Node2D in targets:loss+=t.max_hp-t.current_hp
 return loss
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 # This fixture measures hits/authority, not playback. Prevent incidental SFX
 # before simulated casts; the dedicated audio runtime suite stays enabled.
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 await frames(4)
 Compass=load("res://scripts/weapon/heavenweaver_compass_weapon.gd");Cast=load("res://scripts/weapon/heavenweaver_compass_cast.gd")
 root.get_node("GameSession").start_new_game();change_scene_to_file("res://scenes/levels/level_1.tscn");await frames(18)
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
 current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED
 current_scene.get_node("EnemySpawner").clear_normal_enemies();current_scene.get_node("WaveManager").set_process(false)
 player=current_scene.get_node("player_1");player.set_physics_process(false);manager=player.get_node("WeaponManager");manager.set_process(false)
 stats=player.get_node("PlayerStats");stats.power_multiplier=1;stats.sword_intent_level=0
 for node: Node in manager.weapons:node.free()
 manager.weapons.clear();manager.attack_timers.clear()
 root.get_node("OdysseyClient").run_authorized=true
 for lv: int in [1,3,5,7]:
  for speed: float in [1.0,0.2]:
   for mode: String in ["boss","moving","crowd"]:
    clear_case();make_weapon(lv);stats.attack_cooldown=speed
    target(Vector2(160,0),mode=="boss")
    if mode=="crowd":
     for offset: Vector2 in [Vector2(-160,35),Vector2(80,145),Vector2(-100,-135)]:target(offset)
    for i: int in 600:
     if mode=="moving":targets[0].global_position=player.global_position+Vector2.from_angle(float(i)/60.0*1.7)*160.0
     tick()
    var loss: float=total_loss()
    var ledger: Node=manager.get_node("RunCombatLedger")
    check(loss>0,"actual HP loss "+mode+str(lv)+str(speed))
    check(is_equal_approx(loss,float(ledger.totals.get("heavenweaver_compass",0))),"exact applied damage ledger")
    check(get_nodes_in_group("heavenweaver_cast").size()==1,"one persistent actor")
    check(weapon.pursuit.heads.size()==(2 if lv==7 else 1),"dragon milestone")
    check(weapon.pursuit.echoes.size()<=2 and weapon.pursuit.impacts.size()<=8,"bounded echo/impact buffers")
    measurements.append({"level":lv,"speed":speed,"mode":mode,"damage_10s":snappedf(loss,.001),"dps":snappedf(loss/10,.001)})
    var saved: Dictionary=ledger.snapshot();ledger.restore(saved)
    check(is_equal_approx(float(ledger.totals.get("heavenweaver_compass",0)),loss),"Continue keeps damage total")
    check(ledger.skills().any(func(row: Dictionary) -> bool:return row.id=="spirit_sword" and row.armament_id=="heavenweaver_compass"),"Compass report skill identity")
 for boss_case: bool in [false,true]:
  clear_case();make_weapon(7);stats.attack_cooldown=1
  var extended_target: Node2D=target(Vector2(295 if boss_case else 390,0),boss_case)
  check(manager._is_target_attackable(extended_target),"manager reaches extended target")
  for frame: int in 180:
   extended_target.global_position=player.global_position+Vector2.from_angle(float(frame)*.002)*(295 if boss_case else 390)
   tick()
  check(total_loss()>0,"pursuit actually hits moving target at extended reach")
  extended_target.global_position=player.global_position+Vector2(301 if boss_case else 401,0)
  check(not manager._is_target_attackable(extended_target),"shared manager boundary remains bounded")
 clear_case();make_weapon(7);stats.attack_cooldown=1
 var first: Node2D=target(Vector2(160,0));var closer: Node2D=target(Vector2(-280,0))
 for i: int in 80:tick()
 check(weapon.pursuit._target(weapon.pursuit.heads[0])==first,"nearest primary")
 check(weapon.pursuit._target(weapon.pursuit.heads[1])==closer,"twin distributes target")
 closer.global_position=player.global_position+Vector2(-70,0)
 for i: int in 20:tick()
 check(weapon.pursuit._target(weapon.pursuit.heads[0])==closer,"new closer threat retargeted")
 closer.is_dead=true
 for i: int in 20:tick()
 check(weapon.pursuit._target(weapon.pursuit.heads[0])==first,"dead target reacquired")
 first.global_position=player.global_position+Vector2(500,0);var before: float=total_loss()
 for i: int in 60:tick()
 check(total_loss()==before,"no off-range damage or banked damage")
 first.is_dead=false;first.current_hp=1;first.global_position=player.global_position+Vector2(90,0)
 var ledger: Node=manager.get_node("RunCombatLedger");var prior: float=float(ledger.totals.get("heavenweaver_compass",0))
 for i: int in 80:tick()
 check(first.current_hp==0 and is_equal_approx(float(ledger.totals.get("heavenweaver_compass",0))-prior,1),"last killing hit capped to HP")
 var stale: Node=weapon.pursuit;root.get_node("OdysseyClient").run_authorized=false;stale._physics_process(.016)
 check(stale.is_queued_for_deletion(),"authorization loss removes persistent damage")
 await frames();root.get_node("OdysseyClient").run_authorized=true
 clear_case();make_weapon(1);target(Vector2(100,0));tick()
 var actor: Node=weapon.pursuit;var age_before: float=actor.age
 paused=true;await frames(4)
 check(actor.age==age_before,"pause freezes pursuit")
 paused=false;weapon.free();weapon=null
 check(actor.is_queued_for_deletion(),"weapon teardown removes courier")
 await frames()
 var comparison: Dictionary={}
 var equipment: Node=root.get_node("EquipmentManager")
 for mode: String in ["normal","critical","resonance","reduced","permanent50"]:
  clear_case();make_weapon(5);stats.attack_cooldown=1;stats.sword_intent_level=20 if mode in ["critical","resonance"] else 0;stats.sword_dao_resonance_unlocked=mode=="resonance"
  root.get_node("SettingsManager").reduced_effects=mode=="reduced"
  current_scene.set_meta("companion_practice",true);equipment.practice_levels["heavenweaver_compass"]=50 if mode=="permanent50" else 1
  target(Vector2(100,0),true)
  for i: int in 100:tick()
  comparison[mode]=total_loss()
 check(is_equal_approx(float(comparison.critical),float(comparison.normal)*2),"critical uses production multiplier")
 check(float(comparison.resonance)>float(comparison.critical) and float(comparison.resonance)<float(comparison.critical)*1.4,"resonance bounded; afterimage never recursively resonates")
 check(is_equal_approx(float(comparison.normal),float(comparison.reduced)),"Reduced Effects preserves actual damage")
 check(is_equal_approx(float(comparison.permanent50),float(comparison.normal)*1.49),"permanent level50 production multiplier")
 check(equipment.get_weapon_level_cap("heavenweaver_compass",1)==10 and equipment.get_weapon_level_cap("heavenweaver_compass",5)==50,"unchanged star-dependent permanent caps")
 current_scene.remove_meta("companion_practice");equipment.practice_levels.clear();stats.sword_intent_level=0;stats.sword_dao_resonance_unlocked=false
 clear_case()
 # Exact walls, clamp, first-paint fade, no boss AI/health changes.
 var boss: Node2D=target(Vector2(100,0),true)
 var arena: Node2D=Arena.new();arena.player_actor=player;arena.boss_actor=boss;arena.global_position=player.global_position;current_scene.add_child(arena);arena.set_physics_process(false)
 check(arena.get_node("JadeBoundary").get_child_count()==48,"48 physical wall segments retained")
 check(arena.get_node("RitualDais").texture!=null and arena.get_node("RitualDais").modulate.a==0,"painted floor fades from transparent")
 var hp: float=boss.current_hp;player.global_position=arena.global_position+Vector2(800,0);boss.global_position=arena.global_position+Vector2(-900,0);arena._physics_process(.8)
 check(player.global_position.distance_to(arena.global_position)<=408.01 and boss.global_position.distance_to(arena.global_position)<=408.01,"player/boss remain inside430px arena")
 check(boss.current_hp==hp,"arena does not change boss damage/HP")
 boss.free();check(arena.is_queued_for_deletion(),"boss exit releases arena")
 for texture: Texture2D in [Cast.DRAGON,Arena.FLOOR]:
  var image: Image=texture.get_image();check(image.get_pixel(0,0).a<.01 and image.get_pixel(image.get_width()-1,image.get_height()-1).a<.01,"true alpha corners; no black square")
 print("COMPASS_BALANCE ",JSON.stringify(measurements))
 print("COMPASS_PURSUIT checks=",checks," failures=",failures)
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0)
