extends Node

## Device-level presentation preferences.
## Deliberately stored outside gameplay SaveManager domains so reset/new-run flows
## cannot mutate device audio preferences.

signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SCHEMA_VERSION: int = 1
const MASTER_BUS: StringName = &"Master"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_MUSIC_VOLUME: float = 0.80
const DEFAULT_SFX_VOLUME: float = 1.0

var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var screen_shake: bool = true
var reduced_effects: bool = false
var damage_numbers: bool = true
var haptics: bool = false
var frame_limit: int = 60
var language: String = "en"

func _ready() -> void:
	_ensure_audio_routing()
	_load_settings()
	_apply_all_audio()
	_apply_presentation()
	DebugLogger.system(str("SettingsManager aktif!"))
	DebugLogger.system(str(
		"Audio Preferences | Master: ",
		_round_percent(master_volume),
		"% | Music: ",
		_round_percent(music_volume),
		"% | SFX: ",
		_round_percent(sfx_volume),
		"%"
	))

func get_master_volume() -> float:
	return master_volume

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume

func set_master_volume(value: float) -> void:
	var normalized_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(master_volume, normalized_value):
		return
	master_volume = normalized_value
	_apply_bus_volume(MASTER_BUS, master_volume)
	_save_settings()
	settings_changed.emit()

func set_music_volume(value: float) -> void:
	var normalized_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(music_volume, normalized_value):
		return
	music_volume = normalized_value
	_apply_bus_volume(MUSIC_BUS, music_volume)
	_save_settings()
	settings_changed.emit()

func set_sfx_volume(value: float) -> void:
	var normalized_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(sfx_volume, normalized_value):
		return
	sfx_volume = normalized_value
	_apply_bus_volume(SFX_BUS, sfx_volume)
	_save_settings()
	settings_changed.emit()

func reset_audio_defaults() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	_apply_all_audio()
	_save_settings()
	settings_changed.emit()

func are_audio_buses_ready() -> bool:
	return (
		AudioServer.get_bus_index(MASTER_BUS) >= 0
		and AudioServer.get_bus_index(MUSIC_BUS) >= 0
		and AudioServer.get_bus_index(SFX_BUS) >= 0
	)

func get_audio_routing_summary() -> String:
	if are_audio_buses_ready():
		return "MASTER • MUSIC • SFX ROUTING ACTIVE"
	return "AUDIO ROUTING DEGRADED"

func _ensure_audio_routing() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_idx, bus_name)

func _apply_all_audio() -> void:
	_apply_bus_volume(MASTER_BUS, master_volume)
	_apply_bus_volume(MUSIC_BUS, music_volume)
	_apply_bus_volume(SFX_BUS, sfx_volume)

func _apply_bus_volume(bus_name: StringName, linear_value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		push_warning("SettingsManager: audio bus tidak ditemukan: " + str(bus_name))
		return
	var clamped_value: float = clampf(linear_value, 0.0, 1.0)
	var should_mute: bool = clamped_value <= 0.0001
	AudioServer.set_bus_mute(bus_idx, should_mute)
	AudioServer.set_bus_volume_db(
		bus_idx,
		-80.0 if should_mute else linear_to_db(clamped_value)
	)

func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(SETTINGS_PATH)
	if load_error == ERR_FILE_NOT_FOUND:
		_save_settings()
		return
	if load_error != OK:
		push_warning(
			"SettingsManager: settings.cfg gagal dibaca. Menggunakan default. Error: "
			+ str(load_error)
		)
		_save_settings()
		return

	master_volume = _read_volume(config, "master_volume", DEFAULT_MASTER_VOLUME)
	music_volume = _read_volume(config, "music_volume", DEFAULT_MUSIC_VOLUME)
	sfx_volume = _read_volume(config, "sfx_volume", DEFAULT_SFX_VOLUME)
	screen_shake = _read_bool(config, "screen_shake", true)
	reduced_effects = _read_bool(config, "reduced_effects", false)
	damage_numbers = _read_bool(config, "damage_numbers", true)
	haptics = _read_bool(config, "haptics", false)
	var saved_fps: Variant = config.get_value("presentation", "frame_limit", 60)
	frame_limit = 30 if str(saved_fps) == "30" else 60
	var saved_language: String = str(config.get_value("presentation", "language", "en"))
	language = saved_language if saved_language in ["en", "id"] else "en"

func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("meta", "schema_version", SETTINGS_SCHEMA_VERSION)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	for key: String in ["screen_shake", "reduced_effects", "damage_numbers", "haptics", "frame_limit", "language"]:
		config.set_value("presentation", key, get(key))
	var save_error: Error = config.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning(
			"SettingsManager: settings.cfg gagal disimpan. Error: "
			+ str(save_error)
		)

func _round_percent(value: float) -> int:
	return int(round(clampf(value, 0.0, 1.0) * 100.0))

func set_presentation(key: String, value: Variant) -> void:
	if key in ["screen_shake", "reduced_effects", "damage_numbers", "haptics"]:
		if not value is bool:
			return
	elif key == "frame_limit":
		if not value is int or value not in [30, 60]:
			return
	elif key == "language":
		if not value is String or value not in ["en", "id"]:
			return
	else:
		return
	set(key, value)
	_apply_presentation()
	_save_settings()
	settings_changed.emit()

func _apply_presentation() -> void:
	Engine.max_fps = frame_limit
	TranslationServer.set_locale(language)

func _read_bool(config: ConfigFile, key: String, fallback: bool) -> bool:
	var value: Variant = config.get_value("presentation", key, fallback)
	return value if value is bool else fallback

func _read_volume(config: ConfigFile, key: String, fallback: float) -> float:
	var value: Variant = config.get_value("audio", key, fallback)
	if not (value is int or value is float):
		return fallback
	var numeric: float = float(value)
	return clampf(numeric, 0.0, 1.0) if is_finite(numeric) else fallback
