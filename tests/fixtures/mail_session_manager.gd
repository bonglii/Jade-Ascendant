extends "res://scripts/managers/server_mail_manager.gd"
var fixture_owner: String = "mail_session_owner".sha256_text()
func _current_owner() -> String: return fixture_owner
func _server_registered() -> bool: return true
