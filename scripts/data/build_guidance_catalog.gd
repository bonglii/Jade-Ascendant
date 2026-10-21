extends RefCounted
## Advice describes production catalog behavior; it never equips, upgrades or modifies damage.
const Sets=preload("res://scripts/data/equipment_set_catalog.gd")
const ADVICE: Dictionary={
 "bleed":["BLEED PRESSURE","Keep landing direct hits. Bleed does not stack; stronger hits improve remaining ticks. Bosses take half the DoT."],
 "poison":["POISON PRESSURE","Maintain contact while repositioning. Poison does not stack or extend its duration on every hit. Bosses take half the DoT."],
 "burn":["HIGH-HP OFFENSE","Preserve high HP for the set's damage bonus. Burn adds pressure; bosses take half the DoT."],
 "armor":["DEFENSIVE PRECISION","Use safe attack windows to benefit from stationary damage. Mirror Armor reduces incoming damage; it does not prevent every hit."],
 "frost":["CROWD CONTROL","Direct hits slow ordinary enemies more strongly than bosses. The strongest slow applies; slows do not add together."],
 "verdict":["FINISHER","Attack enemies already at 35% HP or less. The bonus is smaller against bosses and does not amplify DoT."],
 "aegis":["HIT-FREE DEFENSE","Avoid both damage and blocks for eight seconds to recover one empty Qi Shield charge. Continue starts a fresh delay."]
}
const WEAPON_ROLES: Dictionary={"jade_binding_chain":"CONTROL · DELAYED BURST","celestial_returning_glaive":"OUTBOUND · RETURN PATH","phoenix_war_fan":"MULTI-LANE SWEEP","void_piercer_spear":"AIMED LINE · CHARGE","heavenweaver_compass":"LOCKED MARKS · DRAGON PATH","nine_heavens_star_sword":"SWORD ART"}
static func set_advice(id: String) -> Dictionary:
 var passive: Dictionary=Sets.get_four_piece_passive(id)
 var text: Array=ADVICE.get(str(passive.get("kind","")),["SURVIVAL FOUNDATION","Lower-rarity full sets supply HP. Choose useful individual stats while collecting a matching four-piece set."])
 return {"role":text[0],"advice":text[1],"passive":passive,"set":id}
static func loadout(ids: Array[String]) -> Dictionary:
 var dominant: Dictionary=Sets.get_dominant_set_state(ids)
 var result: Dictionary=set_advice(str(dominant.set_id));result.merge(dominant,true)
 result.active=bool(dominant.full_resonance) and not result.passive.is_empty()
 return result
