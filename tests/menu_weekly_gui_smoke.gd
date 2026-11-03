extends "res://tests/heavenly_trials_smoke.gd"
## Native-only inherited suite; request the same touchscreen hint as other GUI fixtures.
func _initialize() -> void:
 Input.set_emulate_touch_from_mouse(true)
 super._initialize()
