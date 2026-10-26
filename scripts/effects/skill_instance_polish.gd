extends Node2D
const Art = preload("res://scripts/effects/skill_signature_art.gd")
const MAX_INSTANCES: int = 40
static var active_instances: int = 0
var skill_id: String = ""
var age: float = 0.0
var refresh_left: float = 0.0
var registered: bool = false
static func install(instance: Node2D, id: String) -> void:
 if id in ["yin_yang_blades","heavenly_sword_rain"]: return # Dedicated authored cels already own all visuals.
 if active_instances >= MAX_INSTANCES or instance.has_node("SkillInstancePolish"): return
 var fx: Node2D = (load("res://scripts/effects/skill_instance_polish.gd") as GDScript).new()
 fx.name = "SkillInstancePolish";fx.skill_id = id
 instance.add_child(fx)
func _ready() -> void:
 registered = true;active_instances += 1
 z_index = 1
func _exit_tree() -> void:
 if registered: active_instances = maxi(0,active_instances-1)
func _process(delta: float) -> void:
 age += delta;refresh_left -= delta
 if refresh_left > 0: return
 refresh_left = 1.0/18.0 if SettingsManager.reduced_effects else 1.0/30.0
 queue_redraw()
func _draw() -> void:
 if SettingsManager.reduced_effects: return
 if skill_id in ["yin_yang_blades","heavenly_sword_rain"]: return # Authored cels own these effects.
 var instance: Node2D = get_parent()
 var ink: Color = Art.color_for(skill_id)
 if skill_id == "spirit_sword" and bool(instance.is_resonance_projectile):
  ink = Art.color_for("sword_dao_resonance")
  Art.draw_emblem(self,"sword_dao_resonance",Vector2(-8,0),12,age,.5)
 if skill_id == "yin_yang_blades" and bool(instance.reversal_visual_active):
  ink = Art.color_for("yin_yang_reversal")
  draw_arc(Vector2.ZERO,18,-PI*.7,PI*.1,16,Color(ink,.7),1.8,true)
 match skill_id:
  "fire_orb", "spirit_sword", "yin_yang_blades":
   # Local -X follows the actual projectile flight/orbit rotation.
   var flame: bool = skill_id == "fire_orb"
   for index: int in range(3):
    var length: float = 17.0+index*8.0
    var offset_y: float = (index-1)*3.5+sin(age*18+index)*2.2
    draw_line(Vector2(-5,offset_y),Vector2(-length,offset_y*.6),Color(ink,0.26-index*.06),3.5-index,true)
   if flame:
    draw_circle(Vector2.ZERO,9.5+sin(age*19)*1.5,Color(ink,0.12))
  "eight_trigrams_formation":
   var radius: float = float(instance.radius)*.82
   for index: int in range(8):
    var ray: Vector2 = Vector2.RIGHT.rotated(TAU*index/8.0)
    draw_line(ray*(radius-5),ray*radius,Color(ink,.5),1.8,true)
  "heavenly_sword_rain":
   if bool(instance.has_impacted):
    var radius: float = float(instance.strike_radius)*.82
    for index: int in range(6):
     var ray: Vector2 = Vector2.RIGHT.rotated(TAU*index/6.0)
     draw_line(ray*radius*.55,ray*radius,Color(ink,.5),1.5,true)
  "thunder_talisman":
   if instance._effect_active:
    var target: Vector2 = instance._target_local
    var fade: float = maxf(0.0,1.0-float(instance._elapsed)/float(instance.EFFECT_DURATION))
    for index: int in range(3):
     var at: Vector2 = target*float(index+2)/5.0
     var branch := PackedVector2Array([at,at+Vector2(9,-12),at+Vector2(3,-22)])
     draw_polyline(branch,Color(ink,fade*.65),1.4,true)
  "heavenly_tribulation":
   if bool(instance.has_impacted):
    var radius: float = float(instance.lightning_radius)*.72
    Art.draw_emblem(self,"heavenly_tribulation",Vector2(0,-25),minf(25,radius),age,.75)
