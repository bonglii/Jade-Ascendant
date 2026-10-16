extends Node

## Debug Logger
## Mengontrol output debug development berdasarkan kategori.
## Kategori existing dipertahankan; diagnostics hanya aktif di debug build.

const BuildMetadata = preload("res://scripts/debug/build_metadata.gd")

var combat_enabled: bool = false
var spawn_enabled: bool = false
var progression_enabled: bool = false

func _ready() -> void:
	var build: Dictionary = BuildMetadata.read()
	system("Build %s (%d) | Source %s | Godot %s" % [str(build.version_name), int(build.version_code), str(build.source_revision), Engine.get_version_info()["string"]])

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
