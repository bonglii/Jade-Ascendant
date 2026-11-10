extends RefCounted
## Optional run specializations. Pure, bounded, no paid/quest authority.
const ARTS := ["spirit_sword","fire_orb","thunder_talisman","yin_yang_blades","heavenly_sword_rain","eight_trigrams_formation"]
const NAMES := ["Spirit Sword","Fire Orb","Thunder Talisman","Yin-Yang Blades","Heavenly Sword Rain","Eight Trigrams Formation"]
const STARTERS := ["gale_parasol","heavenweaver_compass","jade_binding_chain","celestial_returning_glaive","phoenix_war_fan","void_piercer_spear","astral_resonance_bell"]
static func clean(raw: Variant) -> Dictionary:
	var result := {"arts":{},"boon":""}
	if not raw is Dictionary: return result
	var arts: Variant = raw.get("arts",{})
	if arts is Dictionary:
		for key: String in ARTS:
			if arts.get(key) in ["focus","sweep","balanced"]: result.arts[key] = arts[key]
	if raw.get("boon") in ["ember","wind","none"]: result.boon = raw.boon
	return result
static func multiplier(raw: Dictionary, source: String, boss: bool) -> float:
	var state: Dictionary = raw
	var id: String = "spirit_sword" if source in STARTERS else source
	var path: String = str(state.get("arts",{}).get(id,"balanced")) if state.get("arts") is Dictionary else "balanced"
	var result: float = 1.0
	if path == "focus": result = 1.20 if boss else 0.90
	elif path == "sweep": result = 0.90 if boss else 1.15
	# Set DoT keeps its existing balance. Only direct art sources receive boons.
	if id in ARTS or id == "heavenly_tribulation":
		if state.get("boon","") == "ember": result *= 1.12
		elif state.get("boon","") == "wind": result *= 0.92
	return result
static func movement(raw: Dictionary) -> float:
	var boon: String = str(raw.get("boon",""))
	return 0.90 if boon == "ember" else 1.10 if boon == "wind" else 1.0
