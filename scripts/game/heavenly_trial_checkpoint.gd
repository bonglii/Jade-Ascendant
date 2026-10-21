extends "res://scripts/managers/checkpoint_manager.gd"
## Instance I/O hooks isolate Trials from the permanent Journey checkpoint.
func _client() -> Node:return get_node_or_null("/root/HeavenlyTrialsClient")
func _ready() -> void:
 if GameSession.consume_continue_request():call_deferred("_load_continue")
func has_checkpoint() -> bool:
 var client: Node=_client()
 return client!=null and not client.call("checkpoint_data").is_empty()
func _write_checkpoint_data(save_data: Dictionary) -> bool:
 var normalized: Dictionary=normalize_checkpoint_save_data(save_data)
 if normalized.is_empty():return false
 var arena: Node=get_parent();var client: Node=_client()
 if client==null or bool(arena.get("ended")):return false
 normalized.chapter_id=int(client.launch_session.tier);normalized.stage_id=int(arena.get("stage_id"))
 normalized.trials_session=str(client.launch_session.id)
 normalized.trials_elapsed=float(arena.get("elapsed"))
 normalized.trials_boss_hp=float(arena.call("boss_health"))
 normalized.trials_boss_phase=bool(arena.call("boss_phase"))
 normalized.trials_loadout=EquipmentManager.active_run_loadout_snapshot.duplicate(true)
 return bool(client.call("write_checkpoint",normalized))
func _read_runtime_checkpoint() -> Dictionary:
 var client: Node=_client();var data: Dictionary=client.call("checkpoint_data") if client!=null else {}
 return {"success":not data.is_empty(),"data":data,"source_version":SAVE_VERSION}
func _restore_journey_identity(save_data: Dictionary) -> bool:
 var client: Node=_client()
 return client!=null and save_data.get("trials_session")==client.launch_session.get("id")
func delete_checkpoint() -> bool:
 var client: Node=_client()
 return client!=null and bool(client.call("delete_trial_checkpoint"))
