extends Logger
## No text, rationale, backtrace, identifiers or credentials are persisted.
var _mutex := Mutex.new()
var _events: Array[Dictionary] = []
func _log_message(_message: String, _error: bool) -> void: pass
func _log_error(_function: String, file: String, line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == Logger.ERROR_TYPE_WARNING: return
	var source: String = file.get_file().left(80)
	var safe: String = ""
	for character: String in source:
		if "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-".contains(character): safe += character
	_mutex.lock()
	_events.append({"source": safe, "line": maxi(0, line), "kind": error_type})
	while _events.size() > 32: _events.pop_front()
	_mutex.unlock()
func drain() -> Array[Dictionary]:
	_mutex.lock(); var result: Array[Dictionary] = _events.duplicate(true); _events.clear(); _mutex.unlock()
	return result
