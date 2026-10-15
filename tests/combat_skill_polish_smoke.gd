extends SceneTree
const Skills = preload("res://scripts/data/skill_catalog.gd")
const Art = preload("res://scripts/effects/skill_signature_art.gd")
var InstanceFx: Variant
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures += 1;push_error("COMBAT_SKILL_POLISH_FAIL " + label)
func _initialize() -> void: run.call_deferred()
func settle() -> void:
 for index: int in range(3): await process_frame
func projectiles() -> Array[Node]:
 var result: Array[Node] = []
 for node: Node in current_scene.get_children():
  if node.scene_file_path == "res://scenes/enemy/boss_projectile.tscn": result.append(node)
 return result
func clear_projectiles() -> void:
 for node: Node in projectiles(): node.free()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_combat_pass_qa"): quit(2);return
 root.size=Vector2i(648,1152);root.content_scale_size=Vector2i(648,1152)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 await create_timer(.4).timeout
 InstanceFx = load("res://scripts/effects/skill_instance_polish.gd")
 root.get_node("SettingsManager").reduced_effects = OS.get_environment("JADE_QA_REDUCED") == "1"
 check(change_scene_to_file("res://scenes/levels/level_1.tscn")==OK,"real stage loads")
 await create_timer(.4).timeout
 current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED
 var player: Node2D=current_scene.get_node("player_1")
 player.set_physics_process(false);player.get_node("WeaponManager").set_process(false)
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed()
 var body: Node=player.get_node("PremiumBodyPresentation")
 body.set_process(false)
 var collider: CollisionShape2D=player.get_node("CollisionShape2D")
 var before: Transform2D=collider.transform
 player.velocity=Vector2(180,0)
 for index: int in range(20):player.position.x+=2;body._process(.02)
 check(body.stride_strength > .8 and body.stride_phase > 0,"gait follows actual travel")
 for index: int in range(12):body._process(.1)
 check(is_zero_approx(body.stride_strength),"blocked motion settles despite velocity intent")
 check(collider.transform==before,"player footprint stable")
 var panel: Control=current_scene.get_node("HUD").level_up_panel
 var inventory_before: Dictionary=root.get_node("InventoryManager").item_counts.duplicate(true)
 check(Skills.UPGRADE_IDS.size()==18 and Art.COLORS.size()==18,"18 exact catalog arts covered")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.size=dims;await settle();panel.show_level_up()
  for id: String in Skills.UPGRADE_IDS:
   panel._update_choice_card(panel.upgrade_buttons[0],id)
   var card: Button=panel.upgrade_buttons[0]
   check(card.get_node("CardVisual/SkillEngraving").skill_id==id,"choice engraving "+id)
   check(card.get_theme_stylebox("normal") is StyleBoxTexture,"textured choice "+id)
   load("res://scripts/player/skill_ascension_feedback.gd").show_applied(player,id,panel.get_upgrade_display_name(id),panel.get_upgrade_effect(id))
   check(player.get_node_or_null("SkillAscensionFeedback")==null,"selection feedback removed "+id)
  var viewport_rect: Rect2=root.get_visible_rect()
  var cards_fit: bool=true
  for card: Button in panel.upgrade_buttons:
   var rect: Rect2=card.get_global_rect()
   cards_fit=cards_fit and rect.position.x>=viewport_rect.position.x and rect.end.x<=viewport_rect.end.x+1 and rect.end.y<=viewport_rect.end.y+1
  check(cards_fit,"choice bounds respect production canvas scaling")
  panel.close_level_up()
 check(root.get_node("InventoryManager").item_counts==inventory_before,"visual study creates no rewards")
 var before_power: int=player.get_node("PlayerStats").power_level
 panel.apply_upgrade("power")
 check(player.get_node("PlayerStats").power_level==before_power+1 and player.get_node_or_null("SkillAscensionFeedback")==null,"one real upgrade without character popup")
 var health: Node=player.get_node("PlayerHealth")
 health.qi_shield_charges=1;health.consume_qi_shield()
 check(health.qi_shield_charges==0 and player.get_node("SkillAscensionFeedback").proc_id=="qi_shield","actual shield block proc")
 health.blood_qi_level=1;health.current_health=health.max_health-5
 health.blood_qi_kill_progress=health.get_blood_qi_kills_required()-1;health._on_enemy_killed()
 check(player.get_node("SkillAscensionFeedback").proc_id=="blood_qi" and health.current_health>health.max_health-5,"actual blood qi recovery proc")
 player.get_node("SkillAscensionFeedback").proc_left=0
 health.current_health=health.max_health
 health.blood_qi_kill_progress=health.get_blood_qi_kills_required()-1;health._on_enemy_killed()
 check(is_zero_approx(player.get_node("SkillAscensionFeedback").proc_left),"no fake recovery proc at full health")
 for enemy_name: String in ["enemy_1","enemy_2","enemy_3","enemy_4","enemy_5","enemy_6","elite_enemy_1","elite_enemy_2"]:
  var enemy: Node2D=load("res://scenes/enemy/"+enemy_name+".tscn").instantiate()
  current_scene.add_child(enemy);enemy.set_physics_process(false)
  var enemy_collider: CollisionShape2D=enemy.get_node("CollisionShape2D")
  var enemy_transform: Transform2D=enemy_collider.transform
  var enemy_body: Node=enemy.get_node("QiPresentation")
  enemy.position.x+=4;enemy_body._process(.05)
  check(enemy_body.travel_strength>0,"common/elite real travel "+enemy_name)
  check(enemy_collider.transform==enemy_transform,"common/elite footprint stable "+enemy_name)
  enemy.free()
 var roster: int=0
 for catalog_path: String in ["res://scripts/data/chapter_one_catalog.gd","res://scripts/data/chapter_two_catalog.gd","res://scripts/data/chapter_three_catalog.gd","res://scripts/data/chapter_four_catalog.gd","res://scripts/data/chapter_five_catalog.gd"]:
  var catalog: GDScript=load(catalog_path)
  for stage_id: int in catalog.STAGES:
   var boss: Node2D=load("res://scenes/enemy/boss_1.tscn").instantiate()
   if catalog_path.contains("four") or catalog_path.contains("five"):boss.set_script(load("res://scripts/enemy/realm_boss.gd"))
   boss.configure_encounter(catalog.STAGES[stage_id]);current_scene.add_child(boss);boss.set_physics_process(false)
   var boss_collider: CollisionShape2D=boss.get_node("CollisionShape2D")
   var transform_before: Transform2D=boss_collider.transform
   var presentation: Node=boss.get_node("QiPresentation")
   for index: int in range(3):boss.position.x+=4;presentation._process(.05)
   check(boss_collider.transform==transform_before,"boss motion footprint stable")
   check(presentation.travel_strength>0,"boss travel readable")
   boss.free();roster+=1
 check(roster==26,"26 boss encounters across all 5 realms")
 var boss: Node2D=load("res://scenes/enemy/boss_1.tscn").instantiate()
 current_scene.add_child(boss);boss.set_physics_process(false);boss.position=player.position+Vector2(150,0)
 clear_projectiles()
 var target_snapshot: Vector2=player.global_position
 boss.shoot_projectile();boss.shoot_projectile()
 check(boss._ranged_cast_pending and projectiles().is_empty(),"single shot has visible windup and duplicate lock")
 paused=true;await create_timer(.3,true).timeout
 check(projectiles().is_empty(),"windup respects combat pause")
 paused=false;player.position.y+=50
 await create_timer(.28).timeout
 check(projectiles().size()==1,"one actual shot after windup")
 if projectiles().size()==1:check(projectiles()[0].direction.is_equal_approx(projectiles()[0].global_position.direction_to(target_snapshot)),"aim locks before release")
 clear_projectiles();boss.shoot_radial_projectiles();await create_timer(.34).timeout
 check(projectiles().size()==boss.get_current_radial_projectile_count(),"radial count unchanged")
 var first_direction: Vector2=projectiles()[0].direction if not projectiles().is_empty() else Vector2.ZERO
 clear_projectiles();boss.shoot_radial_projectiles();await create_timer(.34).timeout
 check(not projectiles().is_empty() and not projectiles()[0].direction.is_equal_approx(first_direction),"next radial volley rotates existing gaps")
 clear_projectiles();boss.shoot_projectile();boss.current_phase=2;await create_timer(.28).timeout
 check(projectiles().is_empty(),"phase change cancels old pending release")
 boss.shoot_projectile();boss.is_dead=true;await create_timer(.28).timeout
 check(projectiles().is_empty(),"dead boss cannot release pending shot")
 boss.free()
 var wrappers: Array[Node]=[]
 for index: int in range(60):
  var fake:=Node2D.new();current_scene.add_child(fake);wrappers.append(fake);InstanceFx.install(fake,"spirit_sword")
 check(InstanceFx.active_instances<=40,"global spell ornament budget")
 for wrapper: Node in wrappers:wrapper.free()
 check(InstanceFx.active_instances==0,"budget released when parent freed")
 for scene_name: String in ["spirit_sword","fire_orb","yin_yang_blade","heavenly_sword_rain","eight_trigrams_formation","thunder_talisman_strike","heavenly_lightning"]:
  var spell: Node2D=load("res://scenes/weapons/"+scene_name+".tscn").instantiate()
  current_scene.add_child(spell)
  check(spell.has_node("SkillInstancePolish"),"actual spell wrapper "+scene_name)
  spell.free()
 print("COMBAT_SKILL_POLISH_QA checks=%d failures=%d" % [checks,failures])
 quit(0 if failures==0 else 1)
