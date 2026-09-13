extends "res://scripts/monetization/offline_provider.gd"

## Test harness only. Never selected by project/export settings or release UI.
## Emitting twice deliberately exercises the manager's exact-once guard.
func rewarded_available(_placement: String) -> bool:
	return OS.is_debug_build()

func show_rewarded(request_id: int, _placement: String) -> void:
	if not OS.is_debug_build():
		request_finished.emit(request_id, "unavailable")
		return
	_emit_reward_confirmed(request_id)
	_emit_reward_confirmed(request_id)
	request_finished.emit(request_id, "completed")
