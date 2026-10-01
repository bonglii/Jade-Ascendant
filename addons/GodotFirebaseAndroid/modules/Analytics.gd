extends Node

signal app_instance_id_result(id: String)

var _plugin_singleton: Object

func _connect_signals():
	if not _plugin_singleton:
		return
	_plugin_singleton.connect("analytics_app_instance_id_result", app_instance_id_result.emit)

func log_event(name: String, parameters: Dictionary) -> void:
	if _plugin_singleton:
		_plugin_singleton.analyticsLogEvent(name, parameters)

func set_user_property(name: String, value: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.analyticsSetUserProperty(name, value)

func set_user_id(id: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.analyticsSetUserId(id)

func set_analytics_collection_enabled(enabled: bool) -> void:
	if _plugin_singleton:
		_plugin_singleton.analyticsSetAnalyticsCollectionEnabled(enabled)

func reset_analytics_data() -> void:
	if _plugin_singleton:
		_plugin_singleton.analyticsResetAnalyticsData()

func set_default_event_parameters(parameters: Dictionary) -> void:
	if _plugin_singleton:
		_plugin_singleton.analyticsSetDefaultEventParameters(parameters)

func get_app_instance_id() -> void:
	if _plugin_singleton:
		_plugin_singleton.analyticsGetAppInstanceId()

func set_consent(ad_storage: bool, analytics_storage: bool, ad_user_data: bool, ad_personalization: bool) -> void:
	if _plugin_singleton:
		_plugin_singleton.analyticsSetConsent(ad_storage, analytics_storage, ad_user_data, ad_personalization)

func set_session_timeout(seconds: int) -> void:
	if _plugin_singleton:
		_plugin_singleton.analyticsSetSessionTimeout(seconds)
