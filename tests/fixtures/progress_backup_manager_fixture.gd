extends "res://scripts/managers/progress_backup_manager.gd"
var test_owner: String = "a".repeat(64)
func _ready() -> void: pass
func _setup() -> void: pass
func _live() -> String: return test_owner
func _idle_safe() -> bool: return not restore_committed
