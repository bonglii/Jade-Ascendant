extends RefCounted
## Personal records, never reward authority. Integer-only values survive cloud snapshots.
const SOURCES: Array[String]=["heavenweaver_compass","phoenix_war_fan","void_piercer_spear","astral_resonance_bell","spirit_sword","jade_binding_chain","celestial_returning_glaive","fire_orb","thunder_talisman","yin_yang_blades","heavenly_sword_rain","eight_trigrams_formation","heavenly_tribulation","set_bleed","set_poison","set_burn"]
const MAX_TIME: int=86400000
static func whole(value: Variant, low: int, high: int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func valid_run(value: Variant) -> bool:
 if not value is Dictionary or not whole(value.get("time_ms"),1,MAX_TIME) or not value.get("complete") is bool or not value.get("damage_complete") is bool:return false
 if not whole(value.get("hits"),0,1000000) or not whole(value.get("deaths"),0,1000000):return false
 if not value.get("skills") is Array or value.skills.size()>32 or not value.get("damage") is Dictionary or value.damage.size()>16:return false
 var catalog=preload("res://scripts/data/skill_catalog.gd")
 for skill: Variant in value.skills:
  if not skill is Dictionary or not skill.get("id") is String or skill.id not in catalog.UPGRADE_IDS or not whole(skill.get("level"),1,100):return false
  if not skill.get("armament_id","") is String or skill.get("armament_id","").length()>64:return false
 for source: Variant in value.damage:
  if source not in SOURCES or not whole(value.damage[source],0,1000000000000):return false
 return true
static func clean(value: Variant, known_keys: Array) -> Dictionary:
 var result: Dictionary={}
 if not value is Dictionary or value.size()>32:return result
 for key: Variant in value:
  if key not in known_keys:continue
  var row: Variant=value[key]
  if not row is Dictionary or not whole(row.get("clears"),1,1000000) or not whole(row.get("best_ms"),1,MAX_TIME):continue
  if not row.get("survivor") is bool or not row.get("untouched") is bool or not valid_run(row.get("last")):continue
  if not row.get("last_id") is String or row.last_id.length()!=32 or not row.last_id.is_valid_hex_number(false):continue
  var normalized: Dictionary=row.duplicate(true)
  normalized.clears=int(row.clears);normalized.best_ms=int(row.best_ms)
  for field: String in ["time_ms","hits","deaths"]:normalized.last[field]=int(row.last[field])
  for skill: Dictionary in normalized.last.skills:skill.level=int(skill.level)
  for source: String in normalized.last.damage:normalized.last.damage[source]=int(normalized.last.damage[source])
  result[key]=normalized
 return result
static func merge(records: Dictionary, key: String, run_id: String, run: Dictionary) -> Dictionary:
 if run_id.length()!=32 or not run_id.is_valid_hex_number(false) or not valid_run(run):return {}
 var next: Dictionary=records.duplicate(true);var old: Dictionary=next.get(key,{})
 if old.get("last_id","")==run_id:return {}
 next[key]={"clears":mini(1000000,int(old.get("clears",0))+1),"best_ms":mini(int(old.get("best_ms",MAX_TIME)),int(run.time_ms)),"survivor":bool(old.get("survivor",false)) or (run.complete and run.deaths==0),"untouched":bool(old.get("untouched",false)) or (run.complete and run.deaths==0 and run.hits==0),"last":run.duplicate(true),"last_id":run_id}
 return next
static func clock(milliseconds: int) -> String:
 var seconds: int=int(float(maxi(0,milliseconds))/1000.0)
 return "%02d:%02d.%01d"%[int(float(seconds)/60.0),seconds%60,int(float(milliseconds%1000)/100.0)]
