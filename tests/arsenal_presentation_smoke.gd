extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("ARSENAL_PRESENTATION_FAIL "+label)
func _initialize() -> void:run.call_deferred()
func settle() -> void:
 for i: int in range(5):await process_frame
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_arsenal_qa"):quit(2);return
 await process_frame
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var eq: Node=root.get_node("EquipmentManager")
 var inv: Node=root.get_node("InventoryManager")
 var catalog: Script=load("res://scripts/data/equipment_set_catalog.gd")
 var ids: Array[String]=[]
 for set_id: String in ["frost_lotus","vermilion_verdict","celestial_aegis"]:ids.append_array(catalog.get_piece_ids(set_id))
 ids.append_array(["phoenix_war_fan","void_piercer_spear"])
 for id: String in ids:
  inv.item_counts[id]=2
  var path: String=load("res://scripts/ui/equipment_visual_catalog.gd").get_icon_path(id)
  var tex: Texture2D=load(path)
  check(tex!=null and tex.get_width()>=256,"real imported icon "+id)
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await settle();await settle()
 var skip: Button=current_scene.find_child("OnboardingSkipButton",true,false) as Button
 if skip!=null:skip.pressed.emit()
 await settle()
 var screen: Control=current_scene
 check(screen.header_count.text.ends_with("/56"),"collection total derives from expanded catalog")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504)]:
  root.size=dims;await settle();screen._layout();await settle()
  for id: String in ids:
   screen._show_detail(id);await settle()
   var r: Rect2=screen.sheet_panel.get_global_rect()
   check(r.size.y<screen.detail.size.y*.85,"compact popup "+id+str(dims))
   check(r.position.x>=-1 and r.end.x<=dims.x+1 and r.end.y<=dims.y+1,"bounds "+id+str(dims))
   if dims==Vector2i(648,1152) and id=="void_piercer_spear":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/jade-qa/arsenal-hero.png")
   screen._close_detail();await settle()
 screen.queue_free();await settle();current_scene=null
 root.size=Vector2i(648,900)
 var sets: Array[String]=["frost_lotus","vermilion_verdict","celestial_aegis"]
 var weapons: Array[String]=["phoenix_war_fan","void_piercer_spear"]
 for index: int in range(3):
  eq.active_run_loadout_snapshot={}
  eq.equipped_item_ids={"armament":weapons[index],"robe":"","bracer":"","boots":"","pendant":""}
  for id: String in catalog.get_piece_ids(sets[index]):eq.equipped_item_ids[eq.get_item_data(id).slot]=id
  root.get_node("GameSession").start_new_game()
  change_scene_to_file("res://scenes/levels/level_1.tscn");await create_timer(.35,true).timeout
  current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
  current_scene.get_node("HUD").hide()
  current_scene.get_node("EnemySpawner").set_process(false);current_scene.get_node("EnemySpawner").clear_normal_enemies()
  current_scene.get_node("WaveManager").set_process(false)
  var player: Node2D=current_scene.get_node("player_1");player.set_physics_process(false)
  var manager: Node=player.get_node("WeaponManager");manager.set_process(false)
  var aura: Node=player.find_child("*EquipmentSet*",true,false)
  check(aura!=null,"actual set presentation "+sets[index])
  var victim: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate();victim.max_hp=10000;current_scene.add_child(victim);victim.set_physics_process(false);victim.global_position=player.global_position+Vector2(85,0)
  var w: Node=manager.get_weapon_by_name("Spirit Sword");w.level=7;w.base_damage=40;w.attack(player,victim)
  var c: Node=get_nodes_in_group("ascendant_armament_cast").back();c.set_physics_process(false)
  c._physics_process(.24 if index!=1 else .35)
  check(c.icon!=null,"combat uses authored equipment icon "+weapons[index])
  var camera: Camera2D=player.find_child("Camera2D",true,false)
  camera.zoom=Vector2(1.7,1.7)
  var Status: Script=load("res://scripts/effects/equipment_set_status.gd")
  for kind: String in ["bleed","poison"]:
   var marked: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate();marked.max_hp=10000;current_scene.add_child(marked);marked.set_physics_process(false)
   marked.global_position=player.global_position+Vector2(-60 if kind=="bleed" else 50,-80)
   var status: Node2D=Status.new();status.name="EquipmentSetStatus";status.kind=kind;status.tint=Color(1,.23,.3) if kind=="bleed" else Color(.4,.95,.35);status.ticks_left=3;marked.add_child(status);status.set_physics_process(false);status.queue_redraw()
  await settle();await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/tmp/jade-qa/arsenal-combat-"+str(index)+".png")
  root.get_node("SettingsManager").reduced_effects=true
  for node: Node in get_nodes_in_group("enemy"):
   if node.has_node("EquipmentSetStatus"):node.get_node("EquipmentSetStatus").queue_redraw()
  await settle();await RenderingServer.frame_post_draw
  if index==2:root.get_texture().get_image().save_png("/tmp/jade-qa/arsenal-reduced-markers.png")
  root.get_node("SettingsManager").reduced_effects=false
  current_scene.queue_free();await settle();current_scene=null
 print("ARSENAL_PRESENTATION_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
