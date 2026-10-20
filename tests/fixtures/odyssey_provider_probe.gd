extends "res://scripts/monetization/admob_provider.gd"
var debug_inventory: bool = true
func _uses_test_ads() -> bool: return debug_inventory
var loads: int = 0
var clock: int = 4000000
var requests: Array[Dictionary] = []
func _ready() -> void: pass
func _ads_platform_supported() -> bool: return true
func _ad_clock_ms() -> int: return clock
func _request_ad(id: String, request: AdRequest, callback: RewardedAdLoadCallback) -> void:
	loads += 1
	requests.append({"id": id, "request": request, "callback": callback})
func _trace_state() -> void: pass
