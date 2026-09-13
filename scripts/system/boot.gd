extends Control

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"


func _ready() -> void:
	call_deferred("_open_main_menu")


func _open_main_menu() -> void:
	var transition_error: Error = SceneTransitionManager.transition_to(
		MAIN_MENU_SCENE,
		{
			"title": "Jade Ascendant",
			"subtitle": "Awakening the immortal path",
			"tip": (
				"Every ascendant begins with a single breath of Qi."
			),
			"minimum_display_time": 0.8
		}
	)
	if transition_error != OK:
		push_error(
			"Boot: Celestial Gate gagal dimulai. Error code: "
			+ str(transition_error)
		)
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
