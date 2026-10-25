extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FINAL_COMBAT_FAIL "+label)
func frames(count: int=4) -> void:
 for frame: int in count:await process_frame
func capture(label: String) -> void:
 if DisplayServer.get_name()=="headless" or OS.get_environment("JADE_FINAL_CAPTURE").is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("JADE_FINAL_CAPTURE")+"/"+label+".png")
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 await frames(8);await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 var prewarm: Node=root.get_node_or_null("MenuResourcePrewarm")
 if prewarm!=null:prewarm.free()
 root.get_node("GameSession").start_new_game();change_scene_to_file("res://scenes/levels/level_1.tscn");await frames(22)
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
 var spawner: Node=current_scene.get_node("EnemySpawner");spawner.process_mode=Node.PROCESS_MODE_DISABLED;spawner.clear_normal_enemies()
 current_scene.get_node("WaveManager").set_process(false)
 var player: Node2D=current_scene.get_node("player_1");player.set_physics_process(false)
 var manager: Node=player.get_node("WeaponManager");manager.set_process(false)
 for weapon: Node in manager.weapons:weapon.free()
 manager.weapons.clear();manager.attack_timers.clear()
 var stats: Node=player.get_node("PlayerStats");stats.power_multiplier=1;stats.sword_intent_level=0
 var health: Node=player.get_node("PlayerHealth");health.set_physics_process(false)
 var origin: Vector2=player.global_position
 var Hazard: Script=load("res://scripts/world/stage_hazard.gd")
 for kind: int in range(1,7):
  var h: Node2D=Hazard.new();h.hazard_kind=kind;current_scene.add_child(h);h.set_process(false);h.global_position=origin
  player.global_position=origin+Vector2(h.radius+.1,0)
  health.current_health=health.max_health;health.hit_guard_remaining=0
  var before: float=health.current_health
  h._process(h.warning_duration-.001)
  check(not h.impacted and health.current_health==before,"no early hazard hit "+str(kind))
  h._process(.002);check(h.impacted and health.current_health==before,"outside true radius remains safe "+str(kind));h.free()
  h=Hazard.new();h.hazard_kind=kind;current_scene.add_child(h);h.set_process(false);h.global_position=origin
  player.global_position=origin+Vector2(h.radius-.1,0);health.current_health=health.max_health;health.hit_guard_remaining=0
  before=health.current_health
  h._process(h.warning_duration+.001)
  check(is_equal_approx(before-health.current_health,h._get_impact_damage()),"painted hazard retains exact damage "+str(kind))
  var after: float=health.current_health;health.hit_guard_remaining=0;h._process(.01)
  check(health.current_health==after,"hazard still impacts once "+str(kind));h.free()
 player.global_position=origin;health.current_health=health.max_health;health.health_changed.emit(health.current_health,health.max_health)
 var paused_hazard: Node2D=Hazard.new();current_scene.add_child(paused_hazard);paused=true
 var elapsed: float=paused_hazard.elapsed;await create_timer(.05,true).timeout
 check(paused_hazard.elapsed==elapsed,"pause freezes hazard countdown");paused=false;paused_hazard.free()
 var display_hazards: Array[Node2D]=[]
 for kind: int in [1,2,4]:
  var h: Node2D=Hazard.new();h.hazard_kind=kind;current_scene.add_child(h);h.set_process(false)
  h.global_position=origin+Vector2(-110+kind*65,120 if kind<4 else 220);h.elapsed=h.warning_duration*.65;h.queue_redraw();display_hazards.append(h)
 root.size=Vector2i(720,1600);await frames(12);await capture("painted-danger-seals")
 for h: Node2D in display_hazards:h.free()
 var Weapon: Script=load("res://scripts/weapon/heavenweaver_compass_weapon.gd");var Cast: Script=load("res://scripts/weapon/heavenweaver_compass_cast.gd")
 var weapon: Node=Weapon.new();weapon.configure_armament("heavenweaver_compass");player.add_child(weapon);weapon.set_process(false)
 root.get_node("OdysseyClient").run_authorized=true
 var targets: Array[Node2D]=[]
 for offset: Vector2 in [Vector2(-90,80),Vector2(105,80)]:
  var enemy: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate();enemy.max_hp=100000;current_scene.add_child(enemy);enemy.global_position=origin+offset;enemy.set_physics_process(false);targets.append(enemy)
 var cast: Node2D=Cast.new();current_scene.add_child(cast);cast.configure(player,weapon);cast.set_physics_process(false)
 for frame: int in 80:
  if frame%20==0:cast.strike_tick(10,7)
  cast._physics_process(1.0/60.0)
  if frame in [25,55]:
   for head: Dictionary in cast.heads:
    var length: float=0
    for index: int in range(1,head.spine.size()):length+=head.spine[index-1].distance_to(head.spine[index])
    check(length>90 and length<115,"dragon body is visibly shorter in real mesh")
    check(cast.DRAGON_HALF_WIDTH*2<60 and not head.has("face"),"compact head/body share one seamless textured mesh")
   if frame==25:await capture("compact-compass-attack-a")
   else:await capture("compact-compass-attack-b")
  await frames(1)
 check(cast.applied_total>0 and cast.heads.size()==2,"compact presentation retains real hits and level7 twin")
 cast.free();weapon.free();root.get_node("OdysseyClient").run_authorized=false
 for target: Node2D in targets:target.free()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("FINAL_MOBILE_COMBAT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
