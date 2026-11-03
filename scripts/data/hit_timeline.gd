extends RefCounted
## Optional local facts; never changes damage, rewards or record medals.
const SOURCES: Array[String]=["unknown","melee","projectile","lightning","shockwave","area"]
const MAX_EVENTS: int=40
static func number(value: Variant,low: float,high: float) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high
static func clean(raw: Variant) -> Dictionary:
 if not raw is Dictionary or raw.get("version")!=1 or not number(raw.get("clock"),0,86400) or not raw.get("complete") is bool or not raw.get("events") is Array or raw.events.size()>MAX_EVENTS:return {}
 var events: Array[Dictionary]=[]
 var previous: float=-1.0
 for event: Variant in raw.events:
  if not event is Dictionary or not number(event.get("time"),0,float(raw.clock)) or float(event.time)<previous or not number(event.get("loss"),.000001,1.0e12) or not number(event.get("hp"),0,1.0e12) or event.get("source") not in SOURCES:return {}
  previous=float(event.time);events.append({"time":previous,"loss":float(event.loss),"hp":float(event.hp),"source":event.source})
 return {"version":1,"clock":float(raw.clock),"complete":raw.complete,"events":events}
static func recent(raw: Variant) -> Array[Dictionary]:
 var data: Dictionary=clean(raw)
 var result: Array[Dictionary]=[]
 if data.is_empty():return result
 for event: Dictionary in data.events:
  if event.time>=data.clock-10.0:result.append(event.duplicate())
 return result
