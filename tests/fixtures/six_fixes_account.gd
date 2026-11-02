extends "res://scripts/managers/google_account_manager.gd"
## Installed only into isolated QA project.godot by check_player_six_fixes.cjs.
var test_account: String="a".repeat(64)
func _ready() -> void:pass
func get_monetization_account_binding() -> String:return test_account
func ensure_monetization_identity() -> bool:return false
