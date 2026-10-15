extends "res://scripts/managers/player_identity_server_client.gd"
var sent: int=0
var queries: int=0
func _send_profile_request(_headers: PackedStringArray) -> Error:
 sent+=1
 return OK
func _query_trusted_dns() -> void:queries+=1
