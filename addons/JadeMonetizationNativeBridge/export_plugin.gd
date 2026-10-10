@tool
extends EditorPlugin

## IAP native transport QA candidate.
## Disabled by default. No production checkout activation.

var android_export_plugin: AndroidExportPlugin = null

func _enter_tree() -> void:
    android_export_plugin = AndroidExportPlugin.new()
    add_export_plugin(android_export_plugin)

func _exit_tree() -> void:
    if android_export_plugin != null:
        remove_export_plugin(android_export_plugin)
        android_export_plugin = null

class AndroidExportPlugin extends EditorExportPlugin:
    const PLUGIN_NAME: String = "JadeMonetizationNativeBridge"

    const DEPENDENCIES := [
        "com.google.firebase:firebase-auth:24.2.0",
        "com.google.firebase:firebase-appcheck-playintegrity:19.4.1",
    ]

    func _supports_platform(platform: EditorExportPlatform) -> bool:
        return platform is EditorExportPlatformAndroid

    func _get_android_libraries(
        _platform: EditorExportPlatform,
        debug: bool
    ) -> PackedStringArray:
        var variant := "debug" if debug else "release"
        var path := (
            "JadeMonetizationNativeBridge/bin/"
            + variant
            + "/JadeMonetizationNativeBridge-"
            + variant
            + ".aar"
        )
        return PackedStringArray([path])

    func _get_android_dependencies(
        _platform: EditorExportPlatform,
        debug: bool
    ) -> PackedStringArray:
        var dependencies := PackedStringArray(DEPENDENCIES)
        if debug:
            dependencies.append(
                "com.google.firebase:firebase-appcheck-debug:19.4.1"
            )
        return dependencies

    func _get_name() -> String:
        return PLUGIN_NAME