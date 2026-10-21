extends RefCounted
static func compact(value: int) -> String:
 var safe: int=maxi(0,value)
 for tier: Array in [[1000000000000000000,"Qi"],[1000000000000000,"Qa"],[1000000000000,"T"],[1000000000,"B"],[1000000,"M"],[10000,"K"]]:
  var threshold: int=int(tier[0])
  if safe>=threshold:
   var divisor: float=1000.0 if threshold==10000 else float(threshold)
   return String.num(floorf(float(safe)/divisor*10.0)/10.0,1).trim_suffix(".0")+str(tier[1])
 return str(safe)
