extends RefCounted
static func read() -> Dictionary:
	var metadata: Dictionary = {}
	var path: String = "res://release/build_metadata.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		var parser := JSON.new()
		if file != null and file.get_length() < 4096 and parser.parse(file.get_as_text()) == OK and parser.data is Dictionary and parser.data.get("format") == 1: metadata = parser.data
	var version: String = str(metadata.get("version_name", ProjectSettings.get_setting("application/config/version", ""))).strip_edges().replace("\r", "").replace("\n", "").left(64)
	metadata.version_name = version if not version.is_empty() else "unreported"
	metadata.version_code = int(metadata.get("version_code", 0))
	metadata.source_revision = str(metadata.get("source_revision", "unreported")).left(40)
	metadata.iap_target = str(metadata.get("iap_target", "unreported")).left(32)
	return metadata
