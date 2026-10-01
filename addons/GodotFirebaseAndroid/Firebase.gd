extends Node

var auth = preload("res://addons/GodotFirebaseAndroid/modules/Auth.gd").new()
var firestore = preload("res://addons/GodotFirebaseAndroid/modules/Firestore.gd").new()
var realtimeDB = preload("res://addons/GodotFirebaseAndroid/modules/RealtimeDB.gd").new()
var storage = preload("res://addons/GodotFirebaseAndroid/modules/Storage.gd").new()
var analytics = preload("res://addons/GodotFirebaseAndroid/modules/Analytics.gd").new()
var remote_config = preload("res://addons/GodotFirebaseAndroid/modules/RemoteConfig.gd").new()

func _ready() -> void:
	# These Firebase module wrappers extend Node. Keep them as children so
	# Godot frees them when the Firebase autoload exits (including headless QA).
	for module: Node in [auth, firestore, realtimeDB, storage, analytics, remote_config]:
		add_child(module)

	if Engine.has_singleton("GodotFirebaseAndroid"):
		var _plugin_singleton = Engine.get_singleton("GodotFirebaseAndroid")

		auth._plugin_singleton = _plugin_singleton
		auth._connect_signals()

		firestore._plugin_singleton = _plugin_singleton
		firestore._connect_signals()

		realtimeDB._plugin_singleton = _plugin_singleton
		realtimeDB._connect_signals()

		storage._plugin_singleton = _plugin_singleton
		storage._connect_signals()

		analytics._plugin_singleton = _plugin_singleton
		analytics._connect_signals()

		remote_config._plugin_singleton = _plugin_singleton
		remote_config._connect_signals()
	else:
		if not OS.has_feature("editor"):
			printerr("GodotFirebaseAndroid singleton not found!")
		return
