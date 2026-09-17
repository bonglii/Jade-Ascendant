extends "res://scripts/managers/achievement_manager.gd"

## Thin runtime wrapper around the persistent achievement authority.
## The base manager remains untouched; this child only installs presentation
## after historical save synchronization has finished.
const AchievementUnlockPresenter = preload(
	"res://scripts/ui/achievement_unlock_presenter.gd"
)


func _ready() -> void:
	super._ready()
	var presenter: Node = AchievementUnlockPresenter.new()
	presenter.name = "AchievementUnlockPresenter"
	add_child(presenter)
