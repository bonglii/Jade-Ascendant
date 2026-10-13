extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error("GLAIVE_RESTART_FAILURE "+label)
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
 if not OS.get_user_data_dir().contains("jade_glaive_qa_restart"): quit(2);return
 await create_timer(.3).timeout
 var eq: Node=root.get_node("EquipmentManager")
 var inv: Node=root.get_node("InventoryManager")
 var session: Node=root.get_node("GameSession")
 if "--resume" in OS.get_cmdline_user_args():
  check(eq.get_loadout_equipped_item_id("armament")=="mistveil_jian","hub choice persisted for next run")
  check(eq.get_runtime_equipped_item_id("armament")=="celestial_returning_glaive","restart retains frozen glaive loadout")
  session.continue_saved_game()
  change_scene_to_file("res://scenes/levels/level_1.tscn");await settle_scene()
  var w: Node=current_scene.get_node("player_1/WeaponManager").get_weapon_by_name("Spirit Sword")
  check(w.armament_id=="celestial_returning_glaive" and w.get_script()==load("res://scripts/weapon/celestial_returning_glaive_weapon.gd"),"Continue instantiates glaive despite changed hub armament")
  check(w.level==5 and w.base_damage==30.0 and w.cooldown==2.1,"real checkpoint restores glaive level, damage and target count")
 else:
  inv.add_item("celestial_returning_glaive",1);inv.add_item("mistveil_jian",1)
  check(eq.equip_item("celestial_returning_glaive"),"equip new armament")
  session.start_new_game();change_scene_to_file("res://scenes/levels/level_1.tscn");await settle_scene()
  var w: Node=current_scene.get_node("player_1/WeaponManager").get_weapon_by_name("Spirit Sword")
  for i in range(4): w.upgrade()
  check(w.level==5 and w.base_damage==30.0,"refinement uses existing damage progression")
  check(current_scene.get_node("CheckPointManager").save_checkpoint(),"real checkpoint write succeeds")
  await process_frame
  change_scene_to_file("res://scenes/ui/main_menu.tscn");await create_timer(.3).timeout
  inv.add_item("mistveil_jian",1)
  check(eq.equip_item("mistveil_jian"),"hub may prepare different armament")
  check(eq.get_runtime_equipped_item_id("armament")=="celestial_returning_glaive","prepared hub armament does not replace saved run")
 print("JADE_GLAIVE_RESTART_CHECKS=",checks,"; FAILURES=",failures)
 if current_scene!=null: current_scene.queue_free();await process_frame
 quit(1 if failures else 0)
