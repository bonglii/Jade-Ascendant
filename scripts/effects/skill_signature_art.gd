extends RefCounted
## The same visual vocabulary is used in the Codex and real spell instances.
## Draws only ornament; damage, aim and lifetime stay with each existing skill.
const COLORS: Dictionary = {
 "spirit_sword":Color(0.35,0.95,0.8), "fire_orb":Color(1,0.48,0.15),
 "thunder_talisman":Color(0.38,0.78,1), "yin_yang_blades":Color(0.9,0.78,0.4),
 "heavenly_sword_rain":Color(0.63,0.91,1), "eight_trigrams_formation":Color(0.49,0.89,0.5),
 "power":Color(1,0.68,0.34),"attack_speed":Color(0.84,0.79,1),"movement_speed":Color(0.36,0.93,0.87),
 "body_refinement":Color(0.93,0.69,0.33),"qi_shield":Color(0.47,0.78,1),
 "spiritual_insight":Color(0.62,0.96,0.76),"iron_body":Color(0.85,0.77,0.6),
 "blood_qi":Color(1,0.41,0.37),"sword_intent":Color(0.85,0.98,0.7),
 "sword_dao_resonance":Color(0.64,1,0.83),"yin_yang_reversal":Color(0.97,0.77,0.43),
 "heavenly_tribulation":Color(0.83,0.79,1)
}
static func color_for(id: String) -> Color: return COLORS.get(id, Color(0.6,0.95,0.8))
static func draw_emblem(c: CanvasItem, id: String, center: Vector2, radius: float, clock: float, strength: float = 1.0) -> void:
 var ink: Color = color_for(id);ink.a = strength
 var glow := Color(ink, strength * 0.13)
 var pulse: float = 0.5+0.5*sin(clock*2.2)
 c.draw_set_transform(center)
 match id:
  "spirit_sword", "sword_intent", "sword_dao_resonance":
   var count: int = 3 if id == "sword_dao_resonance" else 1
   for i: int in range(count):
    var angle: float = (i-1)*0.38 if count > 1 else sin(clock)*0.12
    var tip: Vector2 = Vector2(0,-radius).rotated(angle)
    var hilt: Vector2 = Vector2(0,radius*0.55).rotated(angle)
    c.draw_line(hilt,tip,glow,11,true);c.draw_line(hilt,tip,ink,2.2,true)
    c.draw_line(Vector2(-radius*0.2,radius*0.35).rotated(angle),Vector2(radius*0.2,radius*0.35).rotated(angle),ink,2,true)
  "fire_orb", "blood_qi":
   c.draw_circle(Vector2.ZERO,radius*0.44,glow)
   for i: int in range(6):
    var angle: float = TAU*i/6.0+clock*0.35
    c.draw_arc(Vector2.ZERO,radius*(0.5+0.08*pulse),angle,angle+0.62,9,ink,2.3,true)
    var ray: Vector2 = Vector2.RIGHT.rotated(angle)
    c.draw_line(ray*radius*0.7,ray*radius*(0.84+0.12*pulse),ink,1.5,true)
  "thunder_talisman", "heavenly_tribulation":
   var bolt := PackedVector2Array([Vector2(8,-radius),Vector2(-12,-3),Vector2(9,-3),Vector2(-7,radius)])
   c.draw_polyline(bolt,glow,12,true);c.draw_polyline(bolt,ink,2.5,true)
   if id == "heavenly_tribulation":
    c.draw_arc(Vector2.ZERO,radius*0.8,-PI*0.2,PI*1.2,24,ink,1.5,true)
  "yin_yang_blades", "yin_yang_reversal":
   for side: int in [-1,1]:
    var angle: float = clock*0.8+(PI if side < 0 else 0.0)
    c.draw_arc(Vector2.ZERO,radius*0.72,angle,angle+PI*0.75,22,ink if side==1 else Color(0.4,0.82,1,strength),2.4,true)
    c.draw_circle(Vector2.RIGHT.rotated(angle)*radius*0.7,3,ink)
  "heavenly_sword_rain":
   for i: int in range(5):
    var x: float = (i-2)*radius*0.3
    var drop: float = fmod(clock*25+i*9,radius*1.7)-radius*0.85
    c.draw_line(Vector2(x,drop-11),Vector2(x,drop+12),ink,2,true)
    c.draw_line(Vector2(x-3,drop+7),Vector2(x,drop+12),ink,1.4,true)
  "eight_trigrams_formation":
   c.draw_arc(Vector2.ZERO,radius*0.6,0,TAU,32,ink,1.5,true)
   for i: int in range(8):
    var ray: Vector2 = Vector2.RIGHT.rotated(TAU*i/8.0)
    for line_index: int in range(3):
     var at: Vector2 = ray*radius*(0.75+line_index*0.08)
     var tangent: Vector2 = ray.orthogonal()*radius*0.09
     c.draw_line(at-tangent,at+tangent,ink,1.5,true)
  "qi_shield", "iron_body", "body_refinement":
   var plate := PackedVector2Array([Vector2(-radius*.65,-radius*.65),Vector2(radius*.65,-radius*.65),Vector2(radius*.52,radius*.25),Vector2(0,radius*.8),Vector2(-radius*.52,radius*.25),Vector2(-radius*.65,-radius*.65)])
   c.draw_colored_polygon(plate,glow);c.draw_polyline(plate,ink,2,true)
   c.draw_line(Vector2(0,-radius*.42),Vector2(0,radius*.42),ink,1.5,true)
  "movement_speed", "attack_speed":
   for i: int in range(3):
    var x: float = (i-1)*radius*.55+sin(clock*3)*3
    c.draw_polyline(PackedVector2Array([Vector2(x-8,-radius*.45),Vector2(x+8,0),Vector2(x-8,radius*.45)]),ink,2,true)
  "spiritual_insight":
   for i: int in range(5):
    var tip: Vector2 = Vector2.RIGHT.rotated(-PI/2+TAU*i/5.0)*radius*.8
    c.draw_line(Vector2.ZERO,tip,ink,1.5,true);c.draw_circle(tip,3,ink)
   c.draw_arc(Vector2.ZERO,radius*.35,0,TAU,24,ink,1.5,true)
  "power":
   c.draw_polyline(PackedVector2Array([Vector2(-radius*.5,radius*.6),Vector2(0,-radius*.75),Vector2(radius*.5,radius*.6)]),ink,3,true)
   c.draw_line(Vector2(-radius*.7,radius*.15),Vector2(radius*.7,radius*.15),ink,2,true)
 c.draw_set_transform(Vector2.ZERO)
