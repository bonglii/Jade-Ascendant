extends "res://scripts/ui/idle_cultivation_presenter.gd"
# Exercise production auto-open policy without claiming rewards or loading UI.
var opened: int = 0
func _ready() -> void: pass
func _process(_delta: float) -> void: pass
func _open_popup() -> void: opened += 1
