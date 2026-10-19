extends "res://scripts/monetization/admob_provider.gd"
var loads: int=0
var clock: int=4000000
func _ad_clock_ms()->int: return clock
func _load_rewarded_ad()->void:
 loads+=1;_rewarded_loading=true
func rewarded_available(_placement: String)->bool:
 return _consent_gate_open and not _privacy_form_open and _rewarded_ad!=null and _active_request_id<0
func _trace_state()->void: pass
