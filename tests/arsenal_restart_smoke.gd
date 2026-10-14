extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error("ARSENAL_RESTART_FAILURE "+label)
func _initialize() -> void: run.call_deferred()
func settle_scene() -> void:
 await create_timer(.4,true).timeout
 var nodes: Array[Node]=[current_scene]
 while not nodes.is_empty():
  var node: Node=nodes.pop_back()
  if node.has_method("_on_skip_pressed"): node._on_skip_pressed()
  if node.name in ["EnemySpawner","WaveManager"]: node.set_process(false);node.set_physics_process(false)
  nodes.append_array(node.get_children())
 paused=false
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_arsenal_qa_restart"): quit(2);return
 var args: PackedStringArray=OS.get_cmdline_user_args()
 var id: String=args[args.find("--armament")+1]
 if id not in ["phoenix_war_fan","void_piercer_spear","astral_resonance_bell"]:quit(2);return
 await create_timer(.3).timeout
 var eq: Node=root.get_node("EquipmentManager")
 var inv: Node=root.get_node("InventoryManager")
 var session: Node=root.get_node("GameSession")
 if "--resume" in OS.get_cmdline_user_args():
  check(eq.get_loadout_equipped_item_id("armament")=="mistveil_jian","hub choice persisted for next run")
  check(eq.get_runtime_equipped_item_id("armament")==id,"restart retains frozen armament loadout")
  session.continue_saved_game()
  change_scene_to_file("res://scenes/levels/level_1.tscn");await settle_scene()
  var w: Node=current_scene.get_node("player_1/WeaponManager").get_weapon_by_name("Spirit Sword")
  check(w.armament_id==id and w.get_script()==load("res://scripts/weapon/"+id+"_weapon.gd"),"Continue instantiates armament despite changed hub armament")
  var guard: Node=current_scene.get_node("player_1/PlayerHealth/CelestialAegisGuard")
  check(guard.enabled and guard.quiet<1.0 and guard.get_parent().qi_shield_charges==0,"Continue restarts full shield wait without free charge")
  check(is_equal_approx(current_scene.get_node("player_1/WeaponManager/RunCombatLedger").totals.get(id,0),123.5),"own damage bucket survives process restart")
  check(w.level==5 and w.base_damage==30.0 and is_equal_approx(w.cooldown,{"phoenix_war_fan":1.9,"void_piercer_spear":2.2,"astral_resonance_bell":3.0}[id]),"real checkpoint restores armament level, damage and target count")
 else:
  inv.add_item(id,1);inv.add_item("mistveil_jian",1)
  for armor: String in load("res://scripts/data/equipment_set_catalog.gd").get_piece_ids("celestial_aegis"):
   inv.add_item(armor,1);eq.equip_item(armor)
  check(eq.equip_item(id),"equip new armament")
  session.start_new_game();change_scene_to_file("res://scenes/levels/level_1.tscn");await settle_scene()
  var w: Node=current_scene.get_node("player_1/WeaponManager").get_weapon_by_name("Spirit Sword")
  for i in range(4): w.upgrade()
  current_scene.get_node("player_1/WeaponManager/RunCombatLedger").record(id,123.5)
  var guard: Node=current_scene.get_node("player_1/PlayerHealth/CelestialAegisGuard")
  guard.set_physics_process(false);guard.quiet=7.0
  check(w.level==5 and w.base_damage==30.0,"refinement uses existing damage progression")
  check(current_scene.get_node("CheckPointManager").save_checkpoint(),"real checkpoint write succeeds")
  await process_frame
  change_scene_to_file("res://scenes/ui/main_menu.tscn");await create_timer(.3).timeout
  inv.add_item("mistveil_jian",1)
  check(eq.equip_item("mistveil_jian"),"hub may prepare different armament")
  check(eq.get_runtime_equipped_item_id("armament")==id,"prepared hub armament does not replace saved run")
 print("ARSENAL_RESTART_CHECKS=",checks,"; FAILURES=",failures)
 if current_scene!=null: current_scene.queue_free();await process_frame
 quit(1 if failures else 0)
