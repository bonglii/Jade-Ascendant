extends Node

## Debug Logger
## Mengontrol output debug development berdasarkan kategori.
## Kategori existing dipertahankan; diagnostics hanya aktif di debug build.

const BUILD_ID: String = "JA-RELEASE-CANDIDATE-20260909"

var combat_enabled: bool = false
var spawn_enabled: bool = false
var progression_enabled: bool = false

func _ready() -> void:
	system("Build %s | Godot %s" % [BUILD_ID, Engine.get_version_info()["string"]])

func system(message: String) -> void:
	if OS.is_debug_build():
		print("[SYSTEM] ", message)

func combat(message: String) -> void:
	if not OS.is_debug_build() or not combat_enabled:
		return

	print("[COMBAT] ", message)

func spawn(message: String) -> void:
	if not OS.is_debug_build() or not spawn_enabled:
		return

	print("[SPAWN] ", message)

func progression(message: String) -> void:
	if not OS.is_debug_build() or not progression_enabled:
		return

	print("[PROGRESSION] ", message)
