extends RefCounted
## Local training/reader policy. No grant, ownership, telemetry or backend authority.
const REVISION: int=1
const MODES: Array[String]=["dummy","boss","seal","technique","standard","priority","gauntlet","pattern","rotation"]
const ITINERARIES: Array[Dictionary]=[
 {"mode":"standard","pattern":0,"title_en":"Flowing Footwork","title_id":"Langkah Mengalir","goal_en":"Survive the equal-footing court for 60 seconds.","goal_id":"Bertahan 60 detik di pelataran setara."},
 {"mode":"seal","pattern":0,"title_en":"Jade Oath","title_id":"Sumpah Giok","goal_en":"Defend three seals while keeping an escape route.","goal_id":"Pertahankan tiga segel sambil menjaga jalur keluar."},
 {"mode":"pattern","pattern":0,"title_en":"Between the Petals","title_id":"Di Antara Kelopak","goal_en":"Read a known guardian's projectile lane for 45 seconds.","goal_id":"Baca jalur proyektil penjaga yang dikenal selama 45 detik."},
 {"mode":"priority","pattern":0,"title_en":"Break the Jade Ward","title_id":"Pecahkan Pelindung Giok","goal_en":"Defeat the ward bearer before the 60-second limit.","goal_id":"Kalahkan pembawa pelindung sebelum batas 60 detik."}]
static func week(timestamp: int) -> int:return maxi(0,floori(float(timestamp+25200-345600)/604800.0))
static func itinerary(timestamp: int) -> Dictionary:
 var index: int=week(timestamp)
 var result: Dictionary=ITINERARIES[index%ITINERARIES.size()].duplicate(true)
 result.week=index;result.revision=REVISION;return result
static func record_key(context: Dictionary) -> String:return JSON.stringify(context).sha256_text()
static func clean_records(raw: Variant) -> Dictionary:
 var result: Dictionary={}
 if not raw is Dictionary:return result
 for key: Variant in raw.keys().slice(0,64):
  var row: Variant=raw[key]
  if not key is String or key.length()!=64 or not key.is_valid_hex_number(false) or not row is Dictionary:continue
  if not row.get("label") is String or row.label.length()>120:continue
  if not preload("res://scripts/data/hit_timeline.gd").number(row.get("time_ms"),1,180000) or not preload("res://scripts/data/hit_timeline.gd").number(row.get("damage"),0,1.0e12) or not preload("res://scripts/data/hit_timeline.gd").number(row.get("hits"),0,1000000):continue
  if row.get("score") not in ["time","damage"]:continue
  result[key]={"label":row.label,"time_ms":int(row.time_ms),"damage":float(row.damage),"hits":int(row.hits),"score":row.score}
 return result
static func better(candidate: Dictionary,previous: Dictionary) -> bool:
 if previous.is_empty():return true
 if candidate.score=="damage":return float(candidate.damage)>float(previous.damage)
 return int(candidate.time_ms)<int(previous.time_ms) or (candidate.time_ms==previous.time_ms and candidate.hits<previous.hits)
static func realm_arc(realm: int,wave: int,index: int,fallback: float) -> float:
 match clampi(realm,1,5):
  2:return float(index%2)*PI+sin(float(index)*1.7)*.35
  3:return float((index+wave)%4)*PI*.5+.18
  4:return float(index)*2.39996+float(wave)*.2
  5:return float(index%3)*TAU/3.0+sin(float(wave))*.25
 return fallback
