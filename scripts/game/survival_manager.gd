extends Node

## Survival Manager
## Mengelola waktu survival selama run.

var survival_time: float = 0.0
var game_running: bool = true

func _process(delta: float) -> void:
	if not game_running:
		return

	survival_time += delta

## Mengubah survival time menjadi format MM:SS.
func format_time() -> String:
	var minutes := int(survival_time / 60.0)
	var seconds := int(survival_time) % 60

	return "%02d:%02d" % [
		minutes,
		seconds
	]
