extends "res://scripts/monetization/odyssey_client.gd"
var live_binding: String="prewarm_fixture".sha256_text()
var pending_command: Dictionary={}
var dispatches: Array[Dictionary]=[]
func _live_binding() -> String:return live_binding
func _pending() -> Dictionary:return pending_command.duplicate(true)
func _dispatch(command: Dictionary) -> bool:dispatches.append(command.duplicate(true));busy=true;return true
