extends "res://scripts/companion/companion_network.gd"
## Only the isolated native QA project.godot selects this service.
## Keep the real service interface; UI/combat tests do not exercise live agenda/metrics.
func _ready() -> void:
 if not OS.get_user_data_dir().contains("jade_aura_live_qa_jade_six_fixes_qa_"):
  push_error("Six fixes offline service requires its isolated QA profile")
  get_tree().quit(2)
  return
 status="qa_offline"
 _setup()
 _tick()
 refresh_agenda()
 if _agenda_http!=null or _http!=null:
  push_error("Six fixes offline service started HTTP")
  get_tree().quit(2)
  return
 print("SIX_FIXES_OFFLINE_SERVICES=READY")
func _setup() -> void:pass
func _tick() -> void:pass
func refresh_agenda() -> void:pass
