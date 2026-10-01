@tool
extends EditorPlugin

## Gate 4.2B candidate only; DISABLED by default in project.godot.
## No autoload, no callable at boot, no write/restore/purchase API.
var _android_export_plugin: AndroidExportPlugin = null


func _enter_tree() -> void:
	_android_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_android_export_plugin)


func _exit_tree() -> void:
	if _android_export_plugin != null:
		remove_export_plugin(_android_export_plugin)
		_android_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME: String = "JadeCloudNativeBridge"
	const DEPENDENCIES := [
		"com.google.firebase:firebase-auth:24.2.0",
		"com.google.firebase:firebase-functions:22.1.1",
		"com.google.firebase:firebase-appcheck-playintegrity:19.4.1",
	]

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray([
				"JadeCloudNativeBridge/bin/debug/JadeCloudNativeBridge-debug.aar"
			])
		return PackedStringArray([
			"JadeCloudNativeBridge/bin/release/JadeCloudNativeBridge-release.aar"
		])

	func _get_android_dependencies(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var dependencies: PackedStringArray = PackedStringArray(DEPENDENCIES)
		if debug:
			dependencies.append("com.google.firebase:firebase-appcheck-debug:19.4.1")
		return dependencies

	func _get_name() -> String:
		return PLUGIN_NAME
