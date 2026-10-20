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
		var proof_path: String = "res://docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json"
		var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(proof_path)) if FileAccess.file_exists(proof_path) else null
		var expected: String = str(proof.get("aar_sha256", "")) if proof is Dictionary and proof.get("target") == "production-candidate" else ""
		var target: String = "production" if expected.length() == 64 and digest == expected and not is_debug else "staging" if digest == "76de4e993a01180aafd2cbd8be0cbec160a5ddc63a980bc5eddd02ad981a8622" and is_debug else "locked_or_unverified"
		var revision: String = OS.get_environment("JADE_BUILD_SOURCE_REVISION").strip_edges()
		if revision.length() != 40 or not revision.is_valid_hex_number(false): revision = "unreported"
		var metadata: Dictionary = {"format": 1, "version_name": version, "version_code": code, "debug": is_debug, "iap_target": target, "native_sha256": digest, "source_revision": revision, "built_at_utc": Time.get_datetime_string_from_system(true)}
		var has_premium: bool = FileAccess.file_exists("res://scripts/ui/liveops/odyssey_art.gd") and FileAccess.get_file_as_string("res://scripts/monetization/odyssey_client.gd").contains("static func canonical_command")
		var has_mobile_board: bool = FileAccess.file_exists("res://assets/ui/liveops/odyssey/imperial_v2/tile_mobile.png") and FileAccess.get_file_as_string("res://scripts/ui/liveops/odyssey_board.gd").contains("const PRESENTATION_REVISION: int=3")
		metadata["odyssey_presentation"] = 3 if has_premium and has_mobile_board else 2 if has_premium else 0
		metadata["update_notifications"] = 1 if proof is Dictionary and int(proof.get("update_notifications",0)) == 1 and FileAccess.file_exists("res://scripts/managers/update_notifications.gd") else 0
		metadata["odyssey_shop_protocol"] = 4 if proof is Dictionary and int(proof.get("odyssey_shop_protocol",0)) == 4 and FileAccess.get_file_as_string("res://scripts/ui/odyssey_screen.gd").contains("const Flow=preload") else 0
		metadata["odyssey_flow_revision"] = 4 if metadata.odyssey_shop_protocol == 4 and FileAccess.file_exists("res://assets/ui/liveops/odyssey/flow/flow_atlas.png") and FileAccess.file_exists("res://scripts/ui/liveops/odyssey_arena_sim.gd") else 0
		metadata["odyssey_reliability_revision"] = 1 if FileAccess.get_file_as_string("res://scripts/monetization/odyssey_client.gd").contains("func _save_ad_wait") and FileAccess.get_file_as_string("res://scripts/ui/odyssey_screen.gd").contains("func _mutating") else 0
		metadata["odyssey_ad_feedback_revision"] = 1 if FileAccess.file_exists("res://scripts/ui/liveops/odyssey_ad_reward_notice.gd") and FileAccess.get_file_as_string("res://scripts/monetization/odyssey_client.gd").contains("func _ad_earned") else 0
		metadata["premium_reliability_revision"] = 1 if FileAccess.file_exists("res://scripts/data/earned_reward_catalog.gd") and FileAccess.file_exists("res://assets/ui/results/ascendant_v3/victory_backdrop.png") and FileAccess.get_file_as_string("res://scripts/managers/server_mail_manager.gd").contains("claim_batch") else 0
		metadata["rewarded_units_revision"] = 1 if FileAccess.file_exists("res://scripts/monetization/rewarded_unit_catalog.gd") and FileAccess.get_file_as_string("res://scripts/monetization/admob_provider.gd").contains("var _units: Dictionary") else 0
		add_file("res://release/build_metadata.json", JSON.stringify(metadata).to_utf8_buffer(), false)
		if features.has("android") and not is_debug and target == "production" and metadata.odyssey_presentation >= 2:
			var receipt_dir: String = ProjectSettings.globalize_path("res://.local/odyssey_export")
			if DirAccess.make_dir_recursive_absolute(receipt_dir) == OK:
				var receipt := FileAccess.open(receipt_dir.path_join("last.json"), FileAccess.WRITE)
				if receipt != null:
					receipt.store_string(JSON.stringify({"path": ProjectSettings.globalize_path(_path), "started_ms": int(Time.get_unix_time_from_system()*1000), "source_revision": revision}))
					receipt.close()
