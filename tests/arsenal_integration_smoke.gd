extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("ARSENAL_INTEGRATION_FAIL "+label)
func _initialize() -> void:run.call_deferred()
func settle() -> void:
 await create_timer(.3,true).timeout
 var nodes: Array[Node]=[current_scene]
 while not nodes.is_empty():
  var node: Node=nodes.pop_back()
  if node.has_method("_on_skip_pressed"):node._on_skip_pressed()
  if node.name in ["EnemySpawner","WaveManager"]:node.set_process(false);node.set_physics_process(false)
  nodes.append_array(node.get_children())
 paused=false
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_arsenal_qa_integration"):quit(2);return
 await process_frame
 var eq: Node=root.get_node("EquipmentManager")
 var inv: Node=root.get_node("InventoryManager")
 var progress: Node=root.get_node("ProgressionManager")
 progress.spirit_stone=99999
 for id: String in ["phoenix_war_fan","void_piercer_spear","astral_resonance_bell"]:
  eq.active_run_loadout_snapshot={};root.get_node("SaveManager").delete_active_run_save("checkpoint")
  inv.item_counts[id]=1
  check(not eq.can_ascend_item(id),"one copy cannot ascend "+id)
  inv.item_counts[id]=2
  check(eq.ascend_item(id) and eq.get_item_star(id)==2 and inv.get_item_count(id)==1,"identical duplicate only "+id)
  check(eq.get_weapon_level_cap(id)==20,"two-star cap20 "+id)
  check(eq.level_weapon(id) and eq.get_item_weapon_level(id)==2,"independent permanent level "+id)
  check(eq.equip_item(id),"equip "+id)
  root.get_node("GameSession").start_new_game()
  change_scene_to_file("res://scenes/levels/level_1.tscn");await settle()
  var player: Node2D=current_scene.get_node("player_1")
  player.set_physics_process(false)
  var manager: Node=player.get_node("WeaponManager");manager.set_process(false)
  var w: Node=manager.get_weapon_by_name("Spirit Sword")
  check(w.armament_id==id and w.get_script()==load("res://scripts/weapon/"+id+"_weapon.gd"),"production starter dispatch "+id)
  check(w.weapon_name=="Spirit Sword" and w.get_combat_display_name()!="Spirit Sword","checkpoint internal / public display "+id)
  var stats: Node=player.get_node("PlayerStats")
  stats.attack_cooldown=0.01
  check(is_equal_approx(manager.get_weapon_cooldown(w),manager.CAST_COOLDOWN_FLOORS[id]),"tempo floor "+id)
  check(manager.get_cast_tempo_damage_multiplier(w)==5.0,"tempo potency capped "+id)
  stats.attack_cooldown=1.0
  var target: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate()
  target.max_hp=100000;current_scene.add_child(target);target.set_physics_process(false)
  target.global_position=player.global_position+Vector2(45,0)
  var lvup: Node=current_scene.get_node("HUD/LevelUpPanel")
  check(lvup.get_upgrade_display_name("spirit_sword")==w.get_combat_display_name(),"refinement card identity "+id)
  check(lvup.get_upgrade_description("spirit_sword")!=load("res://scripts/data/skill_catalog.gd").get_upgrade_description("spirit_sword"),"distinct documented mechanics "+id)
  for lv: int in [1,3,5,7]:
   w.level=lv;w.base_damage=10+5*(lv-1)
   var start: float=target.current_hp
   w.attack(player,target)
   var c: Node=get_nodes_in_group("ascendant_armament_cast").back();c.set_physics_process(false)
   for tick: int in range(260):
    if c.is_queued_for_deletion():break
    c._physics_process(.01)
   check(target.current_hp<start,"production stats applied actual hits "+id+" Lv."+str(lv))
   check(manager.get_node("RunCombatLedger").totals.has(id),"victory damage bucket "+id)
   print("ARSENAL_PRODUCTION ",id," Lv.",lv," hp_damage=",start-target.current_hp," cooldown=",manager.get_weapon_cooldown(w))
   c.queue_free();await process_frame
  check(manager.get_node("RunCombatLedger").damage_rows().any(func(row: Dictionary):return row.id==id and row.name==w.get_combat_display_name()),"report public identity "+id)
  current_scene.queue_free();await process_frame;current_scene=null
  eq.active_run_loadout_snapshot={};root.get_node("SaveManager").delete_active_run_save("checkpoint")
 print("ARSENAL_INTEGRATION_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
