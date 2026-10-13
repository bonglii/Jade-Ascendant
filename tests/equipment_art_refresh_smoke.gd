extends SceneTree
var checks: int=0
var failures: int=0
class Victim extends Node2D:
 var amount: float=0
 func take_damage(value: float) -> void:amount+=value
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("EQUIPMENT_ART_FAILURE "+label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_equipment_qa"):quit(2);return
 await create_timer(.3).timeout
 var visuals: Script=load("res://scripts/ui/equipment_visual_catalog.gd")
 var combat: Script=load("res://scripts/data/armament_combat_catalog.gd")
 var art: Script=load("res://scripts/weapon/equipment_weapon_art.gd")
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/equipment/imperial_v3/asset_sources.json"))
 var mail: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://backend/player_identity/mail_reward_catalog.json"))
 check(manifest.assets.size()==40 and art.ENTRIES.size()==8,"exact40 old items and8 old armaments")
 for item: Dictionary in manifest.assets:
  var path: String=visuals.get_icon_path(item.id)
  check(path==item.ui_path,"canonical UI texture "+item.id)
  var texture: Texture2D=load(path)
  check(texture!=null and texture.get_width()<=256 and texture.get_height()<=256,"bounded compiled UI texture "+item.id)
  var matched: bool=false
  for entry: Dictionary in mail.equipment:
   if entry.id==item.id:matched=entry.icon_source==path
  check(matched,"admin and client use identical art "+item.id)
 for id: String in ["jade_binding_chain","celestial_returning_glaive"]:
  check(not art.ENTRIES.has(id) and visuals.get_icon_path(id)=="res://assets/ui/equipment/final/"+id+".png","new weapon excluded "+id)
 var scene: PackedScene=load("res://scenes/weapons/spirit_sword.tscn")
 for id: String in art.ENTRIES:
  var p: Area2D=scene.instantiate();p.configure_combat_profile(combat.get_profile(id));root.add_child(p);p.set_physics_process(false)
  var sprite: Sprite2D=p.get_node_or_null("EquipmentArt")
  check(p.has_equipment_art and sprite!=null and sprite.texture.resource_path==art.ENTRIES[id].path,"actual equipped projectile renders correct raw weapon "+id)
  check(not p.get_node("AnimatedSprite2D").visible and sprite.modulate==Color.WHITE,"legacy generic sword hidden, new art retains authored color")
  check(p.speed==500 and p.damage==10 and p.lifetime==4 and p.pierce==0,"base attack properties unchanged")
  var collision: CollisionShape2D=p.get_node("CollisionShape2D")
  check(collision.shape.size==Vector2(52,19.5) and collision.position==Vector2(8,1) and p.collision_layer==4 and p.collision_mask==2,"hitbox and collision layers unchanged")
  p.position=Vector2(100,100);p.direction=Vector2.RIGHT;p._physics_process(.02)
  check(p.position==Vector2(110,100) and is_equal_approx(p.lifetime,3.98),"actual motion and lifetime unchanged")
  p.damage=17;p.pierce=1
  var a:=Victim.new();root.add_child(a);a.add_to_group("enemy")
  var b:=Victim.new();root.add_child(b);b.add_to_group("enemy")
  p._on_body_entered(a);p._on_body_entered(a)
  check(a.amount==17 and p.pierce==0 and not p.consumed,"piercing and repeated-hit guard unchanged")
  p._on_body_entered(b);check(b.amount==17 and p.consumed,"second hit consumes projectile exactly as before")
  a.queue_free();b.queue_free();await process_frame
 # Default/unbound old projectile retains its existing presentation fallback.
 var fallback: Area2D=scene.instantiate();root.add_child(fallback);fallback.set_physics_process(false)
 check(not fallback.has_equipment_art and fallback.get_node("AnimatedSprite2D").visible,"unknown/default armament keeps legacy fallback")
 fallback.queue_free();await process_frame
 print("EQUIPMENT_ART_CHECKS=",checks,";FAILURES=",failures)
 quit(1 if failures else 0)
