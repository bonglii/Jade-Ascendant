extends Node

var continue_game: bool = false


func start_new_game() -> void:
	continue_game = false


func continue_saved_game() -> void:
	continue_game = true


func consume_continue_request() -> bool:
	if continue_game:
		continue_game = false
		return true

	return false
