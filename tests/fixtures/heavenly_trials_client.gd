extends "res://scripts/monetization/heavenly_trials_client.gd"
var commands: Array[Dictionary]=[]
func _binding() -> String:return "alice".sha256_text()
func refresh() -> bool:return true
func action(kind: String,args: Dictionary={},week_id: String="") -> bool:
 commands.append({"kind":kind,"args":args,"week":week_id});return true
