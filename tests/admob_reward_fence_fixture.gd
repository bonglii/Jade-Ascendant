extends "res://scripts/monetization/admob_provider.gd"
## Only native transport/platform are doubled; real routing/loading/fences execute.
func _ready() -> void:
	_consent_gate_open = true
	_ads_initialized = true
func _ads_platform_supported() -> bool: return true
func _request_ad(_id: String, _request: AdRequest, _callback: RewardedAdLoadCallback) -> void: pass
