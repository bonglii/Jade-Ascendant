extends SceneTree
## Event inventory/authorization boundary using the current persistent-courier API.
## The broad production DPS/report matrix remains in compass_pursuit_smoke.gd.
var Cast: GDScript
var WeaponScript: GDScript
var failed: int=0
var checks: int=0
class Stats extends Node:
 func calculate_damage_result(damage: float) -> Dictionary:return {"damage":damage,"is_critical":false}
 func has_sword_dao_resonance() -> bool:return false
class Enemy extends Node2D:
 var current_hp: float=10000.0
 var is_dead: bool=false
 func take_damage(damage: float) -> void:
  current_hp=maxf(0,current_hp-damage);is_dead=current_hp<=0
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failed+=1;push_error("ODYSSEY_COMBAT "+message)
func _initialize() -> void:run.call_deferred()
func enemy(parent: Node,at: Vector2,boss: bool=false) -> Node2D:
 var actor:=Enemy.new();parent.add_child(actor);actor.position=at;actor.add_to_group("enemy")
 if boss:actor.add_to_group("boss")
 return actor
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_warning_cleanup_qa"):quit(2);return
 # A regression must fail promptly, never hang the entire player-journey job.
 create_timer(30).timeout.connect(func():push_error("ODYSSEY_COMBAT_TIMEOUT");quit(1))
 await process_frame
 # This fixture measures combat/inventory authority. Audio has its own runtime
 # suite; bulk duplicate ascension must not enqueue an unrelated upgrade WAV.
 var audio: Node=root.get_node("AudioManager")
 audio.set_process(false)
 audio.release_runtime_audio()
 audio.backgrounded=true
 Cast=load("res://scripts/weapon/heavenweaver_compass_cast.gd")
 WeaponScript=load("res://scripts/weapon/heavenweaver_compass_weapon.gd")
 var world:=Node2D.new();root.add_child(world)
 var player:=Node2D.new();world.add_child(player)
 var stats:=Stats.new();stats.name="PlayerStats";player.add_child(stats)
 var weapon: Node=WeaponScript.new();player.add_child(weapon);weapon.set_process(false)
 var client: Node=root.get_node("OdysseyClient");client.run_authorized=true
 for combat_level: int in [1,3,5,7]:
  var target: Node2D=enemy(world,Vector2(120,0),true)
  var courier: Node2D=Cast.new();world.add_child(courier);courier.configure(player,weapon);courier.set_physics_process(false)
  for frame: int in 120:
   if frame%27==0:courier.strike_tick(10.0,combat_level)
   # Deliberately moving boss: the courier must follow its actual location.
   target.position=Vector2.from_angle(float(frame)*0.025)*120.0
   courier._physics_process(1.0/60.0)
  check(target.current_hp<10000,"moving boss takes damage at level "+str(combat_level))
  check(is_equal_approx(courier.applied_total,10000-target.current_hp),"applied HP loss accounts for every hit/echo")
  check(courier.heads.size()==(2 if combat_level==7 else 1),"dragon milestone "+str(combat_level))
  check(courier.echoes.size()<=2 and courier.impacts.size()<=8,"bounded delayed effects")
  target.position=Vector2(301,0)
  var hp: float=target.current_hp
  for frame: int in 60:
   courier.strike_tick(10.0,combat_level);courier._physics_process(1.0/60.0)
  check(is_equal_approx(target.current_hp,hp),"boss beyond300px receives no hit or afterimage")
  client.run_authorized=false;courier._physics_process(.016)
  check(courier.is_queued_for_deletion(),"revoked authorization removes persistent courier")
  courier.free();target.free();client.run_authorized=true
 var paid: Node=root.get_node("PavilionManager/PaidGameplayV2")
 check(paid.local_catalog_hash()==paid.HASH,"event item does not alter pinned paid catalog")
 var inventory: Node=root.get_node("InventoryManager");var equipment: Node=root.get_node("EquipmentManager")
 inventory.item_counts.erase("heavenweaver_compass");equipment.ascension_stars.erase("heavenweaver_compass")
 check(inventory.add_item("heavenweaver_compass",2),"existing inventory accepts event attachment")
 check(equipment.get_weapon_level_cap("heavenweaver_compass")==10,"one-star permanent cap10")
 check(equipment.ascend_item("heavenweaver_compass"),"identical duplicate ascension")
 check(inventory.get_item_count("heavenweaver_compass")==1 and equipment.get_weapon_level_cap("heavenweaver_compass")==20,"duplicate consumed once; cap becomes20")
 check(not root.get_node("PavilionManager").is_item_unlocked("heavenweaver_compass"),"event Compass is not forgeable or directly purchasable")
 client.run_authorized=false;world.free()
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("ODYSSEY_COMBAT checks=",checks," failed=",failed)
 quit(0 if failed==0 else 1)
