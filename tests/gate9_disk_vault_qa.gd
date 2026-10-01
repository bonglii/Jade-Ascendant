extends SceneTree

## Real Godot disk I/O tests, synthetic user://jade_gate9_qa/ only.
## Run on an ephemeral GitHub Actions Windows runner, never against a user save.
const SCRIPT_PATH: String = "res://scripts/managers/cloud_local_backup_vault.gd"
const QA_ROOT: String = "user://jade_gate9_qa/"
var assertions: int = 0
var failures: int = 0
var guard: RefCounted
var sources: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_environment("JADE_GATE9_TEST_ONLY") != "1":
		push_error("Gate 9 disk QA requires the isolated CI environment.")
		quit(2)
		return
	if root.get_node_or_null("SaveManager") == null:
		push_error("SaveManager autoload is required by the file-vault QA.")
		quit(2)
		return
	if DirAccess.dir_exists_absolute(QA_ROOT):
		push_error("Refusing to reuse an existing Gate 9 QA directory.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(QA_ROOT + "source") != OK:
		push_error("Cannot create isolated Gate 9 QA fixtures.")
		quit(2)
		return
	var script: Script = load(SCRIPT_PATH) as Script
	if script == null:
		quit(2)
		return
	guard = script.new() as RefCounted
	var ids: Array[String] = SaveManager.get_save_domain_ids_for_scope(
		SaveManager.SCOPE_PERMANENT
	)
	ids.sort()
	_expect(ids.size() == 8 and "checkpoint" not in ids,
		"Registry contains eight permanent domains and excludes checkpoint")
	var expected: Dictionary = {}
	for id in ids:
		var path: String = QA_ROOT + "source/" + id + ".save"
		sources[id] = path
		var payload: Dictionary = _fixture(id)
		_expect(_write_var(path, payload), "Write synthetic " + id)
		expected[path] = FileAccess.get_sha256(path)
		if id in ["pavilion", "progression"]:
			_expect(_write_var(path + ".backup", payload), "Write synthetic prior backup " + id)
			expected[path + ".backup"] = FileAccess.get_sha256(path + ".backup")
	_test_guards(ids)
	var result: Dictionary = guard.call("prepare_sandbox_backup_for_qa", sources, "gate9_qa")
	_expect(result.get("ok") == true and result.get("code") == "LOCAL_BACKUP_READY",
		"Complete eight-domain vault backup committed")
	if not bool(result.get("ok", false)):
		_end()
		return
	var ready: String = str(result["ready_path"])
	_expect(result.get("file_count") == 10, "Both .backup sidecars preserved in addition to eight primaries")
	_expect(DirAccess.dir_exists_absolute(ready), "Ready directory issued")
	_expect(not FileAccess.file_exists(ready + "/checkpoint.primary.bin"),
		"Active-run checkpoint excluded")
	_expect(guard.call("inspect_sandbox_backup_for_qa", ready).get("ok") == true,
		"Fresh vault integrity verified using actual file SHA-256")
	_expect(not bool(result.get("upload_allowed", true)) and not bool(result.get("restore_allowed", true)),
		"Valid backup never grants upload or restore permission")
	for path in expected:
		_expect(FileAccess.get_sha256(path) == expected[path], "Source remains untouched: " + str(path).get_file())

	var manifest_file: FileAccess = FileAccess.open(ready + "/manifest.bin", FileAccess.READ)
	var manifest: Dictionary = manifest_file.get_var(false)
	manifest_file.close()
	_expect(manifest["domain_files"]["pavilion"].has("backup"),
		"Local Pavilion backup sidecar recorded in manifest")
	_expect(manifest["domain_files"]["progression"].has("backup"),
		"Local progression backup sidecar recorded in manifest")
	_expect(not manifest["domain_files"].has("checkpoint"), "Manifest contains no checkpoint")

	# A separate instance mimics reopening a vault after a process restart.
	var reopened: RefCounted = script.new() as RefCounted
	_expect(reopened.call("inspect_sandbox_backup_for_qa", ready).get("ok") == true,
		"Independent inspector can reopen a durable ready backup")

	# A synthetic local source evolves; the older backup is retained and valid.
	var altered: Dictionary = _fixture("progression")
	altered["spirit_stone"] = 99123
	_expect(_write_var(str(sources["progression"]), altered), "Simulate subsequent local progression")
	_expect(reopened.call("inspect_sandbox_backup_for_qa", ready).get("ok") == true,
		"Existing backup remains valid after newer local progress")
	_expect(FileAccess.get_sha256(str(sources["progression"])) != expected[sources["progression"]],
		"Newer live progression was not overwritten by vault inspection")

	# An interrupted pending-directory write MUST NOT issue a ready backup.
	for fault_at in range(1, 11):
		var injected: Dictionary = guard.call("prepare_sandbox_backup_for_qa", sources, "gate9_qa", fault_at)
		_expect(injected.get("code") == "QA_FAULT_INJECTED", "Injected interruption after copy " + str(fault_at))
		_expect(not bool(injected.get("ok", true)), "Interrupted copy is never authorized")
	_expect(reopened.call("inspect_sandbox_backup_for_qa", ready).get("ok") == true,
		"Previous committed backup survives every interrupted attempt")
	_expect(_ready_dir_count() == 1, "Incomplete attempts never become ready directories")

	# Tamper with one finished copy; inspector fails closed but never repairs
	# or deletes any source save or the previous backup sidecar.
	var pavilion_copy: String = ready + "/pavilion.primary.bin"
	var corrupt_reader: FileAccess = FileAccess.open(pavilion_copy, FileAccess.READ)
	var raw: PackedByteArray = corrupt_reader.get_buffer(corrupt_reader.get_length())
	corrupt_reader.close()
	raw[0] = raw[0] ^ 1
	_expect(_write_bytes(pavilion_copy, raw),
		"Inject equal-size content corruption into committed vault file")
	_expect(reopened.call("inspect_sandbox_backup_for_qa", ready).get("code") == "BACKUP_TAMPERED",
		"SHA-256 detects equal-size tampering")
	_expect(FileAccess.get_sha256(str(sources["pavilion"])) == expected[sources["pavilion"]],
		"Local Pavilion primary intact after backup tamper")
	_expect(FileAccess.get_sha256(str(sources["pavilion"]) + ".backup") == expected[str(sources["pavilion"]) + ".backup"],
		"Local Pavilion previous backup intact")
	var second: Dictionary = guard.call("prepare_sandbox_backup_for_qa", sources, "gate9_qa")
	_expect(second.get("ok") == true, "A fresh backup can succeed after a prior vault was corrupted")
	if bool(second.get("ok", false)):
		_expect(str(second["ready_path"]) != ready, "Unique backup never overwrites the earlier vault")
		_expect(reopened.call("inspect_sandbox_backup_for_qa", str(second["ready_path"])).get("ok") == true,
			"New vault is independently complete")
		_expect(_ready_dir_count() == 2, "Both historical ready directories retained")
	_end()


func _test_guards(ids: Array[String]) -> void:
	_expect(guard.call("prepare_local_pre_restore_backup", "gate9_qa", false).get("code") == "CONSENT_REQUIRED",
		"Production entry point refuses missing explicit consent")
	var rogue: Dictionary = sources.duplicate(true)
	rogue["pavilion"] = "user://pavilion.save"
	_expect(guard.call("prepare_sandbox_backup_for_qa", rogue, "gate9_qa").get("code") == "QA_SOURCE_SCOPE",
		"Test-only path injection cannot reach real Pavilion save")
	rogue = sources.duplicate(true)
	rogue.erase("inventory")
	_expect(guard.call("prepare_sandbox_backup_for_qa", rogue, "gate9_qa").get("code") == "INCOMPLETE_DOMAIN_SET",
		"Missing permanent domain fails closed")
	rogue = sources.duplicate(true)
	rogue["checkpoint"] = QA_ROOT + "source/checkpoint.save"
	_expect(guard.call("prepare_sandbox_backup_for_qa", rogue, "gate9_qa").get("code") == "INCOMPLETE_DOMAIN_SET",
		"Checkpoint injection fails closed")
	var modified: String = str(sources["journey"]) + ".tmp"
	_expect(_write_var(modified, {"version": 1}), "Create uncommitted local staging artifact")
	_expect(guard.call("prepare_sandbox_backup_for_qa", sources, "gate9_qa").get("code") == "UNSETTLED_DOMAIN_ARTIFACT",
		"Pre-restore copy rejects unfinished SaveManager staging")
	_expect(DirAccess.remove_absolute(modified) == OK, "Remove own synthetic pending artifact")
	var source: String = str(sources["equipment"])
	var original: Dictionary = _fixture("equipment")
	_expect(_write_var(source, {"version": 2, "equipped_item_ids": {}}), "Create synthetic future save schema")
	_expect(guard.call("prepare_sandbox_backup_for_qa", sources, "gate9_qa").get("code") == "PRIMARY_SCHEMA_UNSUPPORTED",
		"Future-schema primary is never backed up as restorable")
	_expect(_write_var(source, original), "Restore own synthetic fixture")


func _fixture(id: String) -> Dictionary:
	var data: Dictionary = {"version": SaveManager.get_save_schema_version(id)}
	for key in SaveManager.get_save_required_keys(id):
		if key in ["unlocked", "claimed", "completed", "unlocked_stage_keys", "cleared_stage_keys", "owned_cosmetics"]:
			data[key] = ["plain"] if key == "owned_cosmetics" else []
		elif key in ["progress", "item_counts", "equipped_item_ids"]:
			data[key] = {}
		elif key in ["date_key", "meditation_date", "cosmetic_id"]:
			data[key] = "plain" if key == "cosmetic_id" else ""
		elif key in ["selected_chapter_id", "selected_stage_id"]:
			data[key] = 1
		else:
			data[key] = 0
	if id == "pavilion":
		# Simulate the existing local-only sensitive token storage. This may
		# stay on the device in the protected vault; never print or upload it.
		data["processed_grant_ids"] = ["iap:jade_pouch_100:QA_PRIVATE_TOKEN_NO_TRANSPORT"]
	return data


func _write_var(path: String, value: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(value)
	file.flush()
	file.close()
	return FileAccess.file_exists(path)


func _write_bytes(path: String, data: PackedByteArray) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var ok: bool = file.store_buffer(data)
	file.flush()
	file.close()
	return ok


func _ready_dir_count() -> int:
	var root_path: String = QA_ROOT + "vault"
	var count: int = 0
	for dir_name in DirAccess.get_directories_at(root_path):
		if dir_name.begins_with("ready_"):
			count += 1
	return count


func _expect(yes: bool, note: String) -> void:
	assertions += 1
	if not yes:
		failures += 1
		push_error("GATE9_QA_FAIL | " + note)


func _end() -> void:
	print("JADE_GATE9_DISK_QA_TOTAL: ", assertions, " checks; ", failures, " failures")
	if failures == 0:
		print("JADE_GATE9_DISK_VAULT_PASS")
	quit(0 if failures == 0 else 1)
