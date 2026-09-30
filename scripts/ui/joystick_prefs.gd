extends RefCounted

## Local device preference file, separate from permanent/run SaveManager domains.
## Does not migrate or change SettingsManager's existing schema.
const FILE_PATH: String = "user://joystick_prefs.cfg"
const SECTION: String = "controls"
const DEFAULT_SIZE: int = 1
const DEFAULT_OPACITY: float = 1.0

static func get_size_index() -> int:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(FILE_PATH) != OK:
		return DEFAULT_SIZE
	return clampi(int(cfg.get_value(SECTION, "size_index", DEFAULT_SIZE)), 0, 2)

static func get_size_factor() -> float:
	match get_size_index():
		0: return 0.82
		2: return 1.22
	return 1.0

static func get_opacity() -> float:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(FILE_PATH) != OK:
		return DEFAULT_OPACITY
	return clampf(float(cfg.get_value(SECTION, "opacity", DEFAULT_OPACITY)), 0.40, 1.0)

static func save_preferences(size_index: int, opacity: float) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(FILE_PATH)
	cfg.set_value(SECTION, "size_index", clampi(size_index, 0, 2))
	cfg.set_value(SECTION, "opacity", clampf(opacity, 0.40, 1.0))
	return cfg.save(FILE_PATH)
