extends RefCounted
## Strict display DTO. Never accepts account, receipt, reward or session identity.
const Book = preload("res://scripts/data/stage_record_book.gd")
static func journey(chapter: int, stage: int, title: String, raw: Variant) -> Dictionary:
	if chapter < 1 or chapter > 5 or stage < 1 or stage > 6 or not Book.valid_run(raw):
		return {}
	var skills: Array = []
	for skill: Dictionary in raw.skills:
		skills.append({"id":str(skill.id),"level":int(skill.level),"armament_id":str(skill.get("armament_id",""))})
	var damage: Dictionary = {}
	for source: String in raw.damage:
		damage[source] = int(raw.damage[source])
	return {"version":1,"oath_completed":bool(raw.get("oath_completed",false)),"mode":"journey","chapter":chapter,"stage":stage,"title":title.left(72),"time_ms":int(raw.time_ms),"hits":int(raw.hits),"deaths":int(raw.deaths),"complete":bool(raw.complete),"damage_complete":bool(raw.damage_complete),"skills":skills,"damage":damage}
static func alias_text(value: String) -> String:
	var output := ""
	for character: String in value.strip_edges().left(24):
		var code := character.unicode_at(0)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or character in [" ","_","-","."]:
			output += character
	return output.strip_edges()
static func skill_name(skill: Dictionary) -> String:
	var name: String = preload("res://scripts/data/skill_catalog.gd").get_upgrade_display_name(str(skill.id))
	if skill.id == "spirit_sword" and not str(skill.get("armament_id","")).is_empty():
		name = str(preload("res://scripts/data/equipment_catalog.gd").ITEMS.get(skill.armament_id,{}).get("display_name",name))
	return name

static func trials(raw: Dictionary) -> Dictionary:
	if not raw.get("won",false) or not raw.get("committed",false) or not Book.whole(raw.get("tier"),1,3):return {}
	var display: Dictionary = raw.get("display",{})
	if display.is_empty():
		display={"time_ms":raw.get("time_ms",0),"hits":raw.get("hits",0),"deaths":raw.get("deaths",0),"complete":false,"damage_complete":false,"skills":[],"damage":{}}
	var clean: Dictionary = journey(int(raw.tier),1,"Heavenly Trials · Tier %d"%int(raw.tier),display)
	if not clean.is_empty():clean.mode="trials";clean.tier=int(raw.tier)
	return clean
