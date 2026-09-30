extends Node2D
class_name LinYuePavilionAuraPresentation

## Pavilion Aura is intentionally parked for the current release.
##
## Keep this class/path alive because player_1.tscn already owns this
## presentation node and future updates can restore the visual system without
## touching player scene structure or save schema.
##
## Current release contract:
## - no aura drawing
## - no per-frame processing
## - no Pavilion state mutation
## - no combat/stat/collision behavior


func _ready() -> void:
	visible = false
	set_process(false)
	set_physics_process(false)
