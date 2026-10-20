extends "res://scripts/managers/server_mail_manager.gd"
var fixture_owner: String = "mail_transport_fixture".sha256_text()
var wire: Array[Dictionary] = []
func _current_owner() -> String: return fixture_owner
func _on_token(_token: String) -> void: wire.append(_pending.payload.duplicate(true))
