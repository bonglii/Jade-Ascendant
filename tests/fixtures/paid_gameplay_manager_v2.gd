extends "res://scripts/monetization/paid_gameplay_v2.gd"
var test_binding: String = "a".repeat(64)
var test_bridge: Object
func _ready() -> void: set_process(false)
func _live_binding() -> String: return test_binding
func _bridge() -> Object: return test_bridge
