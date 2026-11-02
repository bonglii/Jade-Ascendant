extends SceneTree
## Same target, production controllers/physics. Counts actual HP loss, not trails.
const CONTROLLERS: Array[String]=["spirit_sword_weapon","fire_orb_weapon","thunder_talisman_weapon","heavenly_sword_rain_weapon","eight_trigrams_formation_weapon","jade_binding_chain_weapon","celestial_returning_glaive_weapon","heavenweaver_compass_weapon","void_piercer_spear_weapon","astral_resonance_bell_weapon","phoenix_war_fan_weapon"]
var checks: int=0
var failures: int=0
var rows: Array[Dictionary]=[]
var player: Node2D
var stats: Node
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("PROJECTILE_ACCOUNTING "+label)
func frames(count: int) -> void:
 for i: int in count:await physics_frame
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_connection_combat_qa"):quit(2);return
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 root.get_node("GameSession").start_new_game();change_scene_to_file("res://scenes/levels/level_1.tscn");await create_timer(.4,true).timeout
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
 for name_value: String in ["EnemySpawner","WaveManager","DifficultyManager"]:current_scene.get_node(name_value).process_mode=Node.PROCESS_MODE_DISABLED
 player=current_scene.get_node("player_1");player.set_physics_process(false);player.get_node("WeaponManager").set_process(false)
 stats=player.get_node("PlayerStats");stats.sword_intent_level=0
 var equipment: Node=root.get_node("EquipmentManager");equipment.active_run_loadout_snapshot={};equipment.equipped_item_ids={"armament":"","robe":"","bracer":"","boots":"","pendant":""}
 check(stats.get_critical_chance()==0,"controlled no-critical fixture")
 var only_compass: bool="--only-compass" in OS.get_cmdline_user_args()
 var controller_ids: Array[String]=[]
 if only_compass:controller_ids.append("heavenweaver_compass_weapon")
 else:controller_ids.assign(CONTROLLERS)
 for id: String in controller_ids:
  var samples: Array[Dictionary]=[]
  for casts: int in [1,2]:
   var boss: Node2D=load("res://scenes/enemy/boss_1.tscn").instantiate();boss.max_hp=1000000;boss.position=player.position+Vector2(80,0)
   current_scene.add_child(boss);boss.set_physics_process(false);boss.set_process(false)
   var shape:=CircleShape2D.new();shape.radius=240;boss.get_node("CollisionShape2D").shape=shape;boss.get_node("CollisionShape2D").position=Vector2.ZERO
   var changes: Array[float]=[];boss.health_changed.connect(func(hp: float,_max: float):changes.append(hp))
   var w: Node=load("res://scripts/weapon/"+id+".gd").new();player.get_node("WeaponManager").add_child(w)
   for i: int in 4:w.upgrade()
   if id=="heavenweaver_compass_weapon":
    root.get_node("OdysseyClient").run_authorized=false;w.attack(player,boss)
    check(not is_instance_valid(w.pursuit),"Compass cannot attack without an event-run authorization")
    # Stand-in for the event arena's verified run context; never a live server claim.
    root.get_node("OdysseyClient").run_authorized=true
   var before_nodes: Array[int]=[]
   for node: Node in current_scene.get_children():before_nodes.append(node.get_instance_id())
   seed(6457)
   var before: float=boss.current_hp
   for i: int in casts:w.attack(player,boss)
   var spawned: int=0
   for node: Node in current_scene.get_children():
    if node.get_instance_id() not in before_nodes:spawned+=1
   await frames(240)
   var loss: float=before-boss.current_hp
   samples.append({"casts":casts,"spawned_nodes":spawned,"actual_hp_events":changes.size(),"hp_loss":loss})
   check(loss>0 and not changes.is_empty(),id+" reaches the real boss; casts="+str(casts))
   for node: Node in current_scene.get_children():
    if node.get_instance_id() not in before_nodes:node.queue_free()
   w.queue_free();boss.queue_free();await process_frame;await frames(3)
  if samples[1].spawned_nodes==samples[0].spawned_nodes*2:
   check(absf(samples[1].hp_loss-samples[0].hp_loss*2)<=maxf(.01,samples[0].hp_loss*.02),id+" independently spawned projectiles retain all damage")
   check(samples[1].actual_hp_events==samples[0].actual_hp_events*2,id+" independent projectile hit events double")
  else:
   check(samples[1].spawned_nodes==samples[0].spawned_nodes,id+" explicit persistent-cast cap, not a discarded projectile hit")
  rows.append({"controller":id,"samples":samples})
 # At level seven both real dragon heads can contact the same boss. Their
 # authored shared-target coefficient remains unchanged, with a separate echo each.
 var compass: Node=load("res://scripts/weapon/heavenweaver_compass_weapon.gd").new();player.get_node("WeaponManager").add_child(compass)
 for i: int in 6:compass.upgrade()
 root.get_node("OdysseyClient").run_authorized=true
 var compass_boss: Node2D=load("res://scenes/enemy/boss_1.tscn").instantiate();compass_boss.max_hp=1000000;compass_boss.position=player.position+Vector2(80,0);current_scene.add_child(compass_boss);compass_boss.set_physics_process(false)
 var compass_changes: Array[float]=[];compass_boss.health_changed.connect(func(hp: float,_max: float):compass_changes.append(hp))
 var compass_before: float=compass_boss.current_hp;compass.attack(player,compass_boss);await frames(60)
 check(is_instance_valid(compass.pursuit) and compass.pursuit.heads.size()==2,"two real Compass dragon heads at level seven")
 check(compass_changes.size()==4,"both dragon contacts and both echoes apply HP loss")
 rows.append({"controller":"heavenweaver_compass_weapon","level":7,"heads":compass.pursuit.heads.size(),"actual_hp_events":compass_changes.size(),"hp_loss":compass_before-compass_boss.current_hp,"scope":"controlled authorized event arena"})
 compass.queue_free();compass_boss.queue_free();root.get_node("OdysseyClient").run_authorized=false;await process_frame;await frames(3)
 # Yin-Yang's persistent blades have one controller but separate contact owners.
 for level: int in ([] if only_compass else [1,3,5,7]):
  var w: Node=load("res://scripts/weapon/yin_yang_blades_weapon.gd").new();player.get_node("WeaponManager").add_child(w);w.level=level;w.apply_level_stats();w.activate(player);w.set_process(false)
  var boss: Node2D=load("res://scenes/enemy/boss_1.tscn").instantiate();boss.max_hp=1000000;boss.position=player.get_node("CombatOrigin").global_position;current_scene.add_child(boss);boss.set_physics_process(false)
  var shape:=CircleShape2D.new();shape.radius=240;boss.get_node("CollisionShape2D").shape=shape;boss.get_node("CollisionShape2D").position=Vector2.ZERO
  var changes: Array[float]=[];boss.health_changed.connect(func(hp: float,_max: float):changes.append(hp))
  var before: float=boss.current_hp;await frames(5)
  check(changes.size()==w.blade_count,"each persistent blade lands exactly once level "+str(level))
  check(is_equal_approx(before-boss.current_hp,w.get_current_damage()*w.blade_count),"per-blade HP loss agrees with actual blade count level "+str(level))
  rows.append({"controller":"yin_yang_blades_weapon","level":level,"blade_count":w.blade_count,"actual_hp_events":changes.size(),"hp_loss":before-boss.current_hp})
  w.queue_free();boss.queue_free();await process_frame;await frames(3)
 var file:=FileAccess.open("user://weapon-projectile-accounting.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"two production casts, same large collider; four seconds per sample; no critical/set effects; not balance DPS","rows":rows},"\t"));file.close()
 print("PROJECTILE_ACCOUNTING checks=%d failures=%d; rows=%s"%[checks,failures,JSON.stringify(rows)])
 current_scene.queue_free();current_scene=null;await process_frame;await process_frame
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0)
