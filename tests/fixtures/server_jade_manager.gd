extends "res://scripts/managers/pavilion_manager.gd"
var test_owner: String=""
var test_bridge: Object
func _ready() -> void:pass
func _live_server_jade_owner() -> String:return test_owner
func _server_recovery_bridge() -> Object:return test_bridge
