extends RefCounted
## Locked world snapshots. Each entry is a real timed danger zone, with an escape route.
const IDS: Dictionary = {
 "glacier_stitches":4, "rime_fault":4, "frost_pincer":4,
 "mirror_shutters":4, "glass_reversal":4, "mirror_labyrinth":4,
 "lotus_opening":4, "stillwater_tide":4, "lotus_undertow":4,
 "frozen_echoes":4, "rime_bell_path":4, "whiteout_chimes":4,
 "sovereign_lattice":4, "winter_verdict":4, "absolute_zero_procession":4,
 "ember_spear_run":5, "sunstep_hammers":5, "solar_cascade":5,
 "crucible_slam":5, "furnace_shear":5, "molten_anvil":5,
 "ashwing_pass":5, "phoenix_feathers":5, "rebirth_dive":5,
 "eclipse_split":5, "umbra_scissors":5, "eclipse_procession":5,
 "imperial_sunfall":5, "dawn_cleave":5, "solar_coronation":5,
 "rime_corridor":4, "cinder_trail":5, "oracle_mirrors":4, "oracle_sunfall":5
}
static func build(id: String, origin: Vector2, target: Vector2) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 var aim: Vector2 = origin.direction_to(target)
 if aim.length_squared() < .001: aim = Vector2.RIGHT
 var side: Vector2 = aim.orthogonal()
 match id:
  "glacier_stitches":
   for i: int in 3: result.append(lane(origin+side*(i-1)*88,aim,.56*i,360,24))
  "rime_fault":
   result.append(lane(origin,aim,0,420,27))
   for sign_v: float in [-1.0,1.0]:result.append(disc(origin+aim*210+side*sign_v*98,.70,45))
  "frost_pincer":
   for i: int in 4:result.append(lane(origin,aim.rotated(-.48 if i%2==0 else .48),i*.55,390,24))
  "mirror_shutters":
   for sign_v: float in [-1.0,1.0]:result.append(lane(origin+side*sign_v*102,aim,0,370,26))
   result.append(lane(origin+aim*185-side*180,side,.85,360,24))
  "glass_reversal":
   result.append(lane(target+side*160,-side,0,320,26))
   result.append(lane(target-aim*180,aim,.80,360,25))
  "mirror_labyrinth":
   for i: int in 3:
    for sign_v: float in [-1.0,1.0]:result.append(lane(origin+side*(sign_v*92+float(i-1)*48),aim,.70*i,380,21))
  "lotus_opening":
   for i: int in 4:result.append(disc(target+aim.rotated(i*PI*.5)*104,.55*(i%2),42))
  "stillwater_tide":
   result.append(ring(target,0,62,108,0));result.append(ring(target,.75,148,194,0))
  "lotus_undertow":
   for i: int in 4:result.append(disc(target+aim.rotated(i*PI*.5)*112,0,43))
   result.append(disc(target,.95,61))
  "frozen_echoes":
   for i: int in 3:result.append(ring(origin,.62*i,56+i*58,80+i*58,0))
  "rime_bell_path":
   for i: int in 3:result.append(disc(origin+aim*(120+i*100),.60*i,44))
  "whiteout_chimes":
   for i: int in 3:result.append(lane(origin-aim*80+side*(i-1)*94,aim.rotated((i-1)*.12),.67*i,420,25))
  "sovereign_lattice":
   for i: int in 3:result.append(lane(origin,aim.rotated(i*TAU/3),0,325,25))
   for i: int in 3:result.append(lane(origin,aim.rotated(i*TAU/3+PI/3),.90,325,25))
  "winter_verdict":
   result.append(ring(origin,0,90,185,aim.angle()));result.append(disc(target,.90,55))
  "absolute_zero_procession":
   for i: int in 3:result.append(ring(origin,.80*i,70+i*44,108+i*44,aim.angle()+i*.75))
  "ember_spear_run":
   result.append(lane(origin,aim,0,430,29));result.append(disc(target,.75,59))
  "sunstep_hammers":
   for i: int in 3:result.append(disc(target+aim*(i-1)*95,.56*i,48))
  "solar_cascade":
   for i: int in 3:result.append(lane(origin,aim.rotated((i-1)*.32),.60*i,410,29))
  "crucible_slam":
   result.append(disc(target,0,70))
   for sign_v: float in [-1.0,1.0]:result.append(disc(target+side*sign_v*120,.85,48))
  "furnace_shear":
   result.append(sector(origin,aim,0,240,.48));result.append(lane(origin,side,.90,300,30))
  "molten_anvil":
   result.append(lane(origin,aim,0,360,35));result.append(ring(target,.95,80,156,0))
  "ashwing_pass":
   for sign_v: float in [-1.0,1.0]:result.append(sector(origin,aim.rotated(sign_v*.62),0,280,.20))
   result.append(lane(origin,aim,.90,365,25))
  "phoenix_feathers":
   for i: int in 5:result.append(disc(origin+aim.rotated((i-2)*.28)*245,.24*i,38))
  "rebirth_dive":
   result.append(disc(target,0,68));result.append(ring(target,.90,96,173,aim.angle()))
  "eclipse_split":
   result.append(ring(origin,0,94,205,aim.angle()));result.append(ring(origin,.95,94,205,aim.angle()+PI*.5))
  "umbra_scissors":
   for i: int in 2:result.append(lane(target+side*(170 if i==0 else -170),-side if i==0 else side,.70*i,340,27))
  "eclipse_procession":
   for i: int in 3:result.append(ring(origin,.80*i,86,178,aim.angle()+i*PI*.5))
  "imperial_sunfall":
   for i: int in 3:result.append(disc(target+side*(i-1)*105,.60*i,55))
   result.append(lane(origin,aim,1.85,420,25))
  "dawn_cleave":
   for i: int in 3:result.append(sector(origin,aim.rotated((i-1)*.72),.70*i,285,.28))
  "solar_coronation":
   for i: int in 3:result.append(ring(origin,.90*i,72+i*48,108+i*48,aim.angle()+i*.85))
   result.append(disc(target,2.70,54))
  "rime_corridor":
   for sign_v: float in [-1.0,1.0]:result.append(lane(target-aim*110+side*sign_v*66,aim,0,220,18))
  "cinder_trail":
   for i: int in 3:result.append(disc(target+aim*(i-1)*72,.55*i,33))
  "oracle_mirrors":
   for sign_v: float in [-1.0,1.0]:result.append(lane(target+side*sign_v*95-aim*145,aim,0,290,25))
   result.append(lane(target-side*145,side,.85,290,23))
  "oracle_sunfall":
   for i: int in 3:result.append(disc(target+side*(i-1)*90,.62*i,42))
 return result

static func base_zone(kind: String, at: Vector2, delay: float) -> Dictionary:
 return {"kind":kind,"at":at,"delay":delay,"warning":1.0,"hit":false}
static func lane(at: Vector2, aim: Vector2, delay: float, reach: float, half_width: float) -> Dictionary:
 var z: Dictionary=base_zone("lane",at,delay);z.merge({"aim":aim,"reach":reach,"width":half_width});return z
static func disc(at: Vector2, delay: float, radius: float) -> Dictionary:
 var z: Dictionary=base_zone("disc",at,delay);z["radius"]=radius;return z
static func sector(at: Vector2, aim: Vector2, delay: float, reach: float, half_angle: float) -> Dictionary:
 var z: Dictionary=base_zone("sector",at,delay);z.merge({"aim":aim,"reach":reach,"angle":half_angle});return z
static func ring(at: Vector2, delay: float, inner: float, outer: float, gap_angle: float) -> Dictionary:
 var z: Dictionary=base_zone("ring",at,delay);z.merge({"inner":inner,"outer":outer,"gap":gap_angle,"gap_half":.40});return z
static func contains(zone: Dictionary, point: Vector2) -> bool:
 var p: Vector2=point-Vector2(zone.at)
 match zone.kind:
  "disc":return p.length_squared()<=float(zone.radius)*float(zone.radius)
  "lane":return p.dot(zone.aim)>=0 and p.dot(zone.aim)<=float(zone.reach) and absf(p.cross(zone.aim))<=float(zone.width)
  "sector":return p.length()<=float(zone.reach) and absf(wrapf(p.angle()-Vector2(zone.aim).angle(),-PI,PI))<=float(zone.angle)
  "ring":return p.length()>=float(zone.inner) and p.length()<=float(zone.outer) and absf(wrapf(p.angle()-float(zone.gap),-PI,PI))>float(zone.gap_half)
 return false
