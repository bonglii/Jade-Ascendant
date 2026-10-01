extends Control

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const ACCOUNT_ENTRY_SCENE: String = "res://scenes/ui/google_account_entry.tscn"


func _ready() -> void:
	call_deferred("_route_first_entry")


func _route_first_entry() -> void:
	# The existing Firebase autoload and GoogleAccountManager are already ready
	# before Boot. Refresh once to avoid showing a login screen for a session
	# restored by the native Firebase SDK.
	GoogleAccountManager.refresh_provider()
	var account: Dictionary = GoogleAccountManager.get_account_snapshot()
	if bool(account.get("signed_in", false)):
		# Only an active Google session bypasses the identity choice. The old
		# "entry completed" flag also covered Guest and survived sign-out, so
		# it must NOT control this startup route.
		_open_main_menu()
		return

	# Signed-out and Guest players must be able to choose Google again on
	# every fresh app launch; the previous choice is deliberately ignored.
	# This changes presentation only: local gameplay saves are untouched.

	# New/unsigned-in device: offer Google AND Guest, never force authentication.
	# Use a direct scene change here to avoid playing the heavy Celestial Gate
	# twice on the first launch. The entry screen uses the light menu transition.
	if ResourceLoader.exists(ACCOUNT_ENTRY_SCENE, "PackedScene"):
		var change_error: Error = get_tree().change_scene_to_file(ACCOUNT_ENTRY_SCENE)
		if change_error == OK:
			return
		push_warning(
			"Boot: account entry unavailable (error %d); continuing as Guest."
			% int(change_error)
		)
	else:
		push_warning("Boot: account entry scene missing; using existing Home flow.")
	_open_main_menu()


func _open_main_menu() -> void:
	# Retain the production startup transition for all returning players.
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
