extends RefCounted
const IDS: Array[String]=["heavenweaver_compass","phoenix_war_fan","void_piercer_spear","astral_resonance_bell"]
const NAMES: Dictionary={"heavenweaver_compass":"Heavenweaver Compass","phoenix_war_fan":"Phoenix War Fan","void_piercer_spear":"Void Piercer Spear","astral_resonance_bell":"Astral Resonance Bell"}
const DESCRIPTIONS: Dictionary={
 "heavenweaver_compass":"Mark 2/3/4/5 targets at combat Lv.1/3/5/7, then send a jade dragon along their locked positions. Lv.5: return at 35% damage. Moving targets can dodge. Cooldown 2.4s, minimum 1.5s. Extra tempo increases potency.",
 "phoenix_war_fan":"Aim a spread of fiery feathers. One central feather always follows your aim; other lanes punish crowds. Lv.3/5/7:4/5/7 feathers; Lv.5 pierces two targets. Max two feather hits per enemy/cast. Cooldown1.9s, minimum0.9s; extra tempo becomes potency. Range320px, bosses230px.",
 "void_piercer_spear":"Snapshot an aim line, charge0.30s, then thrust through up to8 enemies. Moving targets can dodge the visible line. Lv.3 widens the cut, Lv.5 adds30% aftershock, Lv.7 widens it again. Cooldown2.2s, minimum1.35s; extra tempo becomes potency. Range320px, bosses230px from cast origin.",
 "astral_resonance_bell":"Place a bell at your position. The whole marked disc pulses; outgoing rings are the fading aftermath. Lv.1/3/5/7:2/3/3/4 pulses in75/95/115/135px. Up to12 targets per pulse. Slow15% for0.40s; bosses5%. Cooldown3s, minimum2.4s; extra tempo becomes potency. The zone stays at the original location while you move."}
static func description(id: String) -> String:return str(DESCRIPTIONS.get(id,""))
static func effect(id: String,next_level: int) -> String:
 if id=="heavenweaver_compass":return "+5 DMG • "+("3 MARKS" if next_level==3 else "4 MARKS • RETURN 35%" if next_level==5 else "5 MARKS • WIDER DRAGON" if next_level==7 else "DRAGON THREAD")
 if id=="phoenix_war_fan":return "+5 DMG • "+("4 FEATHERS" if next_level==3 else "5 FEATHERS • PIERCE" if next_level==5 else "7 FEATHERS" if next_level==7 else "FIRE FAN")
 if id=="void_piercer_spear":return "+5 DMG • "+("WIDER THRUST" if next_level==3 else "30% AFTERSHOCK" if next_level==5 else "VOIDLINE IMPALE" if next_level==7 else "CHARGED THRUST")
 return "+5 DMG • "+("3 PULSES • 95px" if next_level==3 else "115px ZONE" if next_level==5 else "4 PULSES • 135px" if next_level==7 else "REVERBERATION")
static func resonance(id: String) -> String:
 if id=="heavenweaver_compass":return "One critical dragon hit gains 40% damage per cast. Weak marks do not consume resonance."
 return "One central critical feather gains40% damage per cast." if id=="phoenix_war_fan" else "One critical thrust gains40% damage per cast." if id=="void_piercer_spear" else "The final pulse may empower one critical hit by40%, once per placement."

static func summary(id: String) -> String:
 if id=="heavenweaver_compass":return "Mark enemies, then weave a jade dragon through their locked positions. Lv.5 sends it back along the same path."
 return "Sweep separate lanes with fiery feathers. Extra feathers widen crowd coverage; enemies take at most two hits per cast." if id=="phoenix_war_fan" else "Charge a visible aim line, then impale enemies along it. Targets can escape before the thrust lands." if id=="void_piercer_spear" else "Leave a ringing bell where you cast. Stay mobile while its marked disc pulses and briefly slows nearby enemies."
