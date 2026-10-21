extends "res://scripts/monetization/heavenly_trials_client.gd"
var simulated_binding: String="alice".sha256_text()
var test_bridge: Node
func _binding() -> String:return simulated_binding
func _bridge() -> Object:return test_bridge
