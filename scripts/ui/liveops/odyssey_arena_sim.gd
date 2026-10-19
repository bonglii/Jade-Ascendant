extends RefCounted
## Integer fixed-step rules mirrored by odyssey_arena.mjs and cross-language fixtures.
const TPS: int=20
const MAX_TICKS: int=600
const VECTORS: Array[Vector2i]=[Vector2i(0,0),Vector2i(0,-12),Vector2i(9,-9),Vector2i(12,0),Vector2i(9,9),Vector2i(0,12),Vector2i(-9,9),Vector2i(-12,0),Vector2i(-9,-9)]
static func initial(seed_value: int)->Dictionary:
 return {"seed":seed_value,"t":0,"x":512,"y":820,"bx":512,"by":250,"aim_x":512,"aim_y":820,"hp":5,"boss_hp":16,"last_hit":-1,"done":false,"won":false}
static func step(s: Dictionary,direction: int)->void:
 assert(not s.done and direction>=0 and direction<=8)
 var v: Vector2i=VECTORS[direction];s.t+=1;s.x=clampi(int(s.x)+v.x,48,976);s.y=clampi(int(s.y)+v.y,80,944)
 s.bx=clampi(int(s.bx)+signi(int(s.x)-int(s.bx))*2,100,924);s.by=clampi(int(s.by)+signi(int(s.y)-int(s.by))*2,100,720)
 var phase: int=(int(s.t)-1)%60;var round_value: int=floori(float(int(s.t)-1)/60.0);var pattern: int=(int(s.seed)+round_value)%3
 if phase==0: s.aim_x=s.x;s.aim_y=s.y
 var dx: int=int(s.x)-int(s.bx);var dy: int=int(s.y)-int(s.by)
 if int(s.t)%15==0 and dx*dx+dy*dy<=420*420: s.boss_hp-=1
 var hit: bool=false
 if pattern==0 and phase==30: hit=pow(float(int(s.x)-int(s.aim_x)),2)+pow(float(int(s.y)-int(s.aim_y)),2)<=115.0*115.0
 if pattern==1 and phase==30: hit=absi(int(s.y)-int(s.aim_y))<=72
 if pattern==2 and phase>=30 and phase<=50:
  var distance: float=sqrt(float(dx*dx+dy*dy));var radius: int=(phase-29)*32;hit=absf(distance-float(radius))<=48.0
 if hit and int(s.last_hit)!=round_value: s.hp-=1;s.last_hit=round_value
 if int(s.hp)<=0 or int(s.boss_hp)<=0 or int(s.t)>=MAX_TICKS: s.done=true;s.won=int(s.boss_hp)<=0 and int(s.hp)>0
