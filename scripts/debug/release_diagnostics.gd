extends Node
const ErrorLogger = preload("res://scripts/debug/release_error_logger.gd")
const Metadata = preload("res://scripts/debug/build_metadata.gd")
const PATH: String = "user://release_diagnostics_v1.json"
var previous_phase: String = "unknown"
var errors: Array[Dictionary] = []
var error_count: int = 0
var _logger: Logger
var _phase: String = "active"
var _tick: float = 0.0
func _init() -> void:
	_logger = ErrorLogger.new(); OS.add_logger(_logger)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(PATH):
		var file := FileAccess.open(PATH, FileAccess.READ)
		var parser := JSON.new()
		if file != null and file.get_length() <= 8192 and parser.parse(file.get_as_text()) == OK and parser.data is Dictionary:
			var old: Dictionary = parser.data
			if old.get("phase") in ["active", "suspended", "closed"]: previous_phase = old.phase
	_persist()
func _process(delta: float) -> void:
	_tick += delta
	if _tick < 5.0: return
	_tick = 0.0
	var events: Array = _logger.call("drain")
	if events.is_empty(): return
	error_count += events.size()
	for event: Dictionary in events: errors.append(event)
	while errors.size() > 12: errors.pop_front()
	_persist()
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED: _phase = "suspended"; _persist()
	elif what == NOTIFICATION_APPLICATION_RESUMED: _phase = "active"; _persist()
func _exit_tree() -> void:
	_phase = "closed"; _persist()
	if _logger != null: OS.remove_logger(_logger)
func _persist() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"format": 1, "phase": _phase, "previous_phase": previous_phase, "error_count": error_count, "errors": errors, "build": Metadata.read()}))
	file.close()
func support_lines() -> String:
	var last: String = "none"
	if not errors.is_empty(): last = "%s:%d kind=%d" % [str(errors[-1].source), int(errors[-1].line), int(errors[-1].kind)]
	return "Previous session phase=%s\nRuntime errors=%d\nLast error location=%s" % [previous_phase, error_count, last]
