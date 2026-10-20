extends "res://scripts/monetization/admob_provider.gd"
## Desktop simulation only; callbacks/invalidations under test are production methods.
var required: bool = false
func _ready() -> void:
 _consent_retry_timer = Timer.new(); add_child(_consent_retry_timer)
func privacy_options_required() -> bool: return required
