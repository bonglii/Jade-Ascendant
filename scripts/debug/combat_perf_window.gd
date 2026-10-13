extends RefCounted

## Debug-only bounded wall-frame samples. No gameplay timers or state mutation.
const CAPACITY: int = 4096
var samples: PackedFloat64Array = PackedFloat64Array()
var cursor: int = 0
var count: int = 0
var total_ms: float = 0.0
var maximum_ms: float = 0.0
var process_total_ms: float = 0.0
var physics_total_ms: float = 0.0
var physics_max_ms: float = 0.0
var over_33: int = 0
var over_50: int = 0
func add(frame_ms: float,process_ms: float=0.0,physics_ms: float=0.0) -> void:
 if not is_finite(frame_ms) or frame_ms<=0.0:return
 count+=1;total_ms+=frame_ms;maximum_ms=maxf(maximum_ms,frame_ms)
 process_total_ms+=maxf(0.0,process_ms);physics_total_ms+=maxf(0.0,physics_ms);physics_max_ms=maxf(physics_max_ms,physics_ms)
 if frame_ms>33.33:over_33+=1
 if frame_ms>50.0:over_50+=1
 if samples.size()<CAPACITY:samples.append(frame_ms)
 else:samples[cursor]=frame_ms;cursor=(cursor+1)%CAPACITY
func snapshot() -> Dictionary:
 var sorted: PackedFloat64Array=samples.duplicate();sorted.sort()
 var percentile: float=0.0
 if not sorted.is_empty():percentile=sorted[maxi(0,int(ceil(sorted.size()*.95))-1)]
 return {"count":count,"retained":sorted.size(),"mean_ms":total_ms/maxi(count,1),"p95_ms":percentile,"max_ms":maximum_ms,"over_33":over_33,"over_50":over_50,"process_mean_ms":process_total_ms/maxi(count,1),"physics_mean_ms":physics_total_ms/maxi(count,1),"physics_max_ms":physics_max_ms}
func reset() -> void:
 samples.clear();cursor=0;count=0;total_ms=0.0;maximum_ms=0.0;process_total_ms=0.0;physics_total_ms=0.0;physics_max_ms=0.0;over_33=0;over_50=0
