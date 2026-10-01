extends Node

signal fetch_completed(result: Dictionary)
signal activate_completed(result: Dictionary)
signal config_updated(updated_keys: Array)

var _plugin_singleton: Object

func _connect_signals():
	if not _plugin_singleton:
		return
	_plugin_singleton.connect("remote_config_fetch_completed", fetch_completed.emit)
	_plugin_singleton.connect("remote_config_activate_completed", activate_completed.emit)
	_plugin_singleton.connect("remote_config_updated", config_updated.emit)

func initialize() -> void:
	if _plugin_singleton:
		_plugin_singleton.remoteConfigInitialize()

func set_defaults(defaults: Dictionary) -> void:
	if _plugin_singleton:
		_plugin_singleton.remoteConfigSetDefaults(defaults)

func set_minimum_fetch_interval(seconds: int) -> void:
	if _plugin_singleton:
		_plugin_singleton.remoteConfigSetMinimumFetchInterval(seconds)

func set_fetch_timeout(seconds: int) -> void:
	if _plugin_singleton:
		_plugin_singleton.remoteConfigSetFetchTimeout(seconds)

func fetch() -> void:
	if _plugin_singleton:
		_plugin_singleton.remoteConfigFetch()

func activate() -> void:
	if _plugin_singleton:
		_plugin_singleton.remoteConfigActivate()

func fetch_and_activate() -> void:
	if _plugin_singleton:
		_plugin_singleton.remoteConfigFetchAndActivate()

func get_string(key: String) -> String:
	var value := ""
	if _plugin_singleton:
		value = _plugin_singleton.remoteConfigGetString(key)
	return value

func get_bool(key: String) -> bool:
	var value := false
	if _plugin_singleton:
		value = _plugin_singleton.remoteConfigGetBoolean(key)
	return value

func get_int(key: String) -> int:
	var value := 0
	if _plugin_singleton:
		value = _plugin_singleton.remoteConfigGetLong(key)
	return value

func get_float(key: String) -> float:
	var value := 0.0
	if _plugin_singleton:
		value = _plugin_singleton.remoteConfigGetDouble(key)
	return value

func get_all() -> Dictionary:
	var value := {}
	if _plugin_singleton:
		value = _plugin_singleton.remoteConfigGetAll()
	return value

func get_json(key: String) -> String:
	var value := ""
	if _plugin_singleton:
		value = _plugin_singleton.remoteConfigGetJson(key)
	return value

func get_value_source(key: String) -> int:
	var value := 0
	if _plugin_singleton:
		value = _plugin_singleton.remoteConfigGetValueSource(key)
	return value

func get_last_fetch_status() -> int:
	var value := 0
	if _plugin_singleton:
		value = _plugin_singleton.remoteConfigGetLastFetchStatus()
	return value

func get_last_fetch_time() -> String:
	var value := ""
	if _plugin_singleton:
		value = _plugin_singleton.remoteConfigGetLastFetchTime()
	return value

func listen_for_updates() -> void:
	if _plugin_singleton:
		_plugin_singleton.remoteConfigListenForUpdates()

func stop_listening_for_updates() -> void:
	if _plugin_singleton:
		_plugin_singleton.remoteConfigStopListeningForUpdates()
