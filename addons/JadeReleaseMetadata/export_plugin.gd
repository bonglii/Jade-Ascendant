@tool
extends EditorPlugin
var exporter: EditorExportPlugin
func _enter_tree() -> void:
	exporter = MetadataExporter.new(); add_export_plugin(exporter)
func _exit_tree() -> void:
	if exporter != null: remove_export_plugin(exporter)
class MetadataExporter extends EditorExportPlugin:
	func _get_name() -> String: return "JadeReleaseMetadata"
	func _export_begin(features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
		var preset: EditorExportPreset = get_export_preset()
		var raw_version: Variant = preset.get("version/name") if preset != null and features.has("android") else null
		var version: String = str(raw_version).strip_edges() if raw_version != null else ""
		if version.is_empty(): version = str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
		if version.is_empty(): version = "unreported"
		var code: int = int(preset.get("version/code")) if preset != null and features.has("android") and preset.get("version/code") != null else 0
		var native_path: String = "res://addons/JadeMonetizationNativeBridge/bin/%s/JadeMonetizationNativeBridge-%s.aar" % ["debug" if is_debug else "release", "debug" if is_debug else "release"]
		var digest: String = FileAccess.get_sha256(native_path) if FileAccess.file_exists(native_path) else ""
		var target: String = "production" if digest == "5a3679d44a9d756ba8649ea41f20df775eabf26c4260297dba68e3c0c50a071d" and not is_debug else "staging" if digest == "76de4e993a01180aafd2cbd8be0cbec160a5ddc63a980bc5eddd02ad981a8622" and is_debug else "locked_or_unverified"
		var revision: String = OS.get_environment("JADE_BUILD_SOURCE_REVISION").strip_edges()
		if revision.length() != 40 or not revision.is_valid_hex_number(false): revision = "unreported"
		var metadata: Dictionary = {"format": 1, "version_name": version, "version_code": code, "debug": is_debug, "iap_target": target, "native_sha256": digest, "source_revision": revision, "built_at_utc": Time.get_datetime_string_from_system(true)}
		add_file("res://release/build_metadata.json", JSON.stringify(metadata).to_utf8_buffer(), false)
