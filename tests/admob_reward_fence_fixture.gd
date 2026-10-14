extends "res://scripts/monetization/admob_provider.gd"
## Test-only availability seam; show_rewarded and installed callbacks remain production.
func rewarded_available(_placement: String) -> bool:
 return _rewarded_ad != null and _active_request_id < 0
