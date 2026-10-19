extends "res://scripts/monetization/odyssey_client.gd"
var test_binding: String="e".repeat(64)
var native: RefCounted
func _live_binding() -> String: return test_binding
func _bridge() -> Object: return native
