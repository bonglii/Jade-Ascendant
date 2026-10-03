extends RefCounted

## LOCAL, copy-only pre-restore vault with a global SaveManager write barrier.
## Never overwrites a SaveManager primary, backup, transaction journal, or
## active-run checkpoint. No network. This is a disconnected safety primitive
## for a future explicitly approved restore flow, NOT an authorized restore API.

const VAULT_VERSION: int = 1
const VAULT_ROOT: String = "user://jade_cloud_pre_restore_vault_v1"
const MAX_DOMAIN_BYTES: int = 1048576
const MAX_ALL_BYTES: int = 8388608
const DOMAIN_COUNT: int = 8


## Manual future entry point: reads existing SaveManager files only. Never
## invoked automatically; no live UI or restore callsite is wired.
func prepare_local_pre_restore_backup(owner_uid: String, explicit_consent: bool) -> Dictionary:
	if not explicit_consent:
		return _no("CONSENT_REQUIRED")
	var issue: String = _live_issue(owner_uid)
	if not issue.is_empty():
		return _no(issue)
	# One runtime-only owner token freezes every SaveManager mutation while the
	# eight physical primaries are hashed and copied. The token is never stored
	# in the vault and naturally disappears if the process dies.
	var barrier_owner := "cloud_backup_" + Crypto.new().generate_random_bytes(16).hex_encode()
	var acquired: Dictionary = SaveManager.begin_save_write_barrier(
		barrier_owner, "cloud_local_pre_restore_backup"
	)
	if not bool(acquired.get("success", false)):
		return _no("SAVE_WRITE_BARRIER_UNAVAILABLE")
	issue = _live_issue(owner_uid, barrier_owner)
	var result: Dictionary
	if not issue.is_empty():
		result = _no(issue)
	else:
		var paths: Dictionary = {}
		for domain_id in SaveManager.get_save_domain_ids_for_scope(SaveManager.SCOPE_PERMANENT):
			paths[domain_id] = SaveManager.get_save_path(domain_id)
		result = _copy_snapshot(paths, VAULT_ROOT, owner_uid, true, barrier_owner)
	var released: Dictionary = SaveManager.end_save_write_barrier(barrier_owner)
	if not bool(released.get("success", false)):
		return _no("SAVE_WRITE_BARRIER_RELEASE_FAILED")
	result["write_barrier_used"] = true
	return result


func _live_issue(owner_uid: String, allowed_barrier_owner: String = "") -> String:
	if not _safe_uid(owner_uid) or owner_uid != GoogleAccountManager.get_authenticated_uid():
		return "IDENTITY_NOT_VERIFIED"
	if SaveManager.has_pending_transaction():
		return "SAVE_TRANSACTION_UNSAFE"
	if SaveManager.is_save_write_barrier_active():
		if (
			allowed_barrier_owner.is_empty()
			or SaveManager.get_save_write_barrier_owner() != allowed_barrier_owner
		):
			return "SAVE_WRITE_BARRIER_BUSY"
	else:
		# Existing integrity/write blocks remain a hard stop.
		if SaveManager.is_progress_read_only():
			return "SAVE_TRANSACTION_UNSAFE"
	for domain_id in SaveManager.get_save_domain_ids_for_scope(SaveManager.SCOPE_PERMANENT):
		if SaveManager.is_save_write_blocked(domain_id):
			return "SAVE_TRANSACTION_UNSAFE"
	if SceneTransitionManager.is_transitioning or JourneyManager.has_active_run():
		return "ACTIVE_GAMEPLAY_UNSAFE"
	if SaveManager.has_save_file("checkpoint"):
		return "ACTIVE_CHECKPOINT_UNSAFE"
	if not EquipmentManager.active_run_loadout_snapshot.is_empty():
		return "ACTIVE_LOADOUT_UNSAFE"
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree and not (loop as SceneTree).get_nodes_in_group("player").is_empty():
		return "GAMEPLAY_SCENE_UNSAFE"
	for suffix in [".rollback", ".tmp"]:
		if FileAccess.file_exists(SaveManager.TRANSACTION_PATH + suffix):
			return "UNSETTLED_JOURNAL_ARTIFACT"
	return ""


func _copy_snapshot(
	source_paths: Dictionary, vault_root: String, owner_uid: String,
	live_source: bool = false, barrier_owner: String = ""
) -> Dictionary:
	if not _safe_uid(owner_uid):
		return _no("INVALID_OWNER")
	var domain_ids: Array[String] = SaveManager.get_save_domain_ids_for_scope(
		SaveManager.SCOPE_PERMANENT
	)
	domain_ids.sort()
	if domain_ids.size() != DOMAIN_COUNT or source_paths.size() != DOMAIN_COUNT:
		return _no("INCOMPLETE_DOMAIN_SET")
	for raw_id in source_paths:
		if not raw_id is String or raw_id not in domain_ids:
			return _no("UNSAFE_DOMAIN_SET")
		if not source_paths[raw_id] is String:
			return _no("INVALID_SOURCE_PATH")
		if not str(source_paths[raw_id]).begins_with("user://"):
			return _no("INVALID_SOURCE_PATH")
		if not str(source_paths[raw_id]).ends_with(".save"):
			return _no("INVALID_SOURCE_PATH")
		if ".." in str(source_paths[raw_id]):
			return _no("INVALID_SOURCE_PATH")

	# Never enter the directory for an already-issued backup. Pending dirs
	# from a previous crash remain untouched for later diagnostic inspection.
	if DirAccess.make_dir_recursive_absolute(vault_root) != OK:
		return _no("VAULT_DIRECTORY_UNAVAILABLE")
	var nonce: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var pending: String = vault_root + "/pending_" + nonce
	var ready: String = vault_root + "/ready_" + nonce
	if DirAccess.dir_exists_absolute(pending) or DirAccess.dir_exists_absolute(ready):
		return _no("BACKUP_ID_COLLISION")
	if DirAccess.make_dir_absolute(pending) != OK:
		return _no("PENDING_DIRECTORY_UNAVAILABLE")
	var recorded: Dictionary = {}
	var total_size: int = 0
	var copied: int = 0
	var origin_hashes: Dictionary = {}
	for domain_id in domain_ids:
		var primary: String = str(source_paths[domain_id])
		# Avoid the SaveManager recovery-enabled read API: it can REPAIR primaries.
		# Refuse interrupted local writes and every missing permanent primary.
		for suffix in [".tmp", ".rollback"]:
			if FileAccess.file_exists(primary + suffix):
				return _no("UNSETTLED_DOMAIN_ARTIFACT")
		if not FileAccess.file_exists(primary):
			return _no("MISSING_DOMAIN")
		var primary_validation: Dictionary = _check_primary(primary, domain_id)
		if not bool(primary_validation.get("ok", false)):
			return primary_validation
		var entry: Dictionary = {"schema": SaveManager.get_save_schema_version(domain_id)}
		for suffix in ["", ".backup"]:
			var source: String = primary + suffix
			if suffix != "" and not FileAccess.file_exists(source):
				continue
			var size: int = FileAccess.get_size(source)
			if size <= 0 or size > MAX_DOMAIN_BYTES or total_size + size > MAX_ALL_BYTES:
				return _no("DOMAIN_SIZE_UNSAFE")
			var before: String = FileAccess.get_sha256(source)
			if before.length() != 64:
				return _no("SOURCE_HASH_UNAVAILABLE")
			var source_file: FileAccess = FileAccess.open(source, FileAccess.READ)
			if source_file == null:
				return _no("SOURCE_READ_FAILED")
			var raw_bytes: PackedByteArray = source_file.get_buffer(size)
			source_file.close()
			if raw_bytes.size() != size or FileAccess.get_sha256(source) != before:
				return _no("SOURCE_CHANGED_DURING_READ")
			var name: String = domain_id + (".primary" if suffix == "" else ".backup") + ".bin"
			var dest: String = pending + "/" + name
			var out: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
			if out == null:
				return _no("BACKUP_WRITE_FAILED")
			var wrote: bool = out.store_buffer(raw_bytes)
			out.flush()
			out.close()
			if not wrote or FileAccess.get_size(dest) != size or FileAccess.get_sha256(dest) != before:
				return _no("BACKUP_VERIFY_FAILED")
			entry["primary" if suffix == "" else "backup"] = {"name": name, "bytes": size, "sha256": before}
			origin_hashes[source] = before
			total_size += size
			copied += 1
		recorded[domain_id] = entry
	if recorded.size() != DOMAIN_COUNT:
		return _no("INCOMPLETE_COPY")
	# Second read catches concurrent local changes across the eight files.
	for source in origin_hashes:
		if not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != origin_hashes[source]:
			return _no("SOURCE_CHANGED_BEFORE_SEAL")
	var manifest: Dictionary = {
		"version": VAULT_VERSION,
		"owner_uid": owner_uid,
		"domain_ids": domain_ids,
		"domain_files": recorded,
		"total_bytes": total_size
	}
	var mf: FileAccess = FileAccess.open(pending + "/manifest.bin", FileAccess.WRITE)
	if mf == null:
		return _no("MANIFEST_WRITE_FAILED")
	mf.store_var(manifest)
	mf.flush()
	mf.close()
	var verify: Dictionary = _inspect_candidate(pending)
	if not bool(verify.get("ok", false)):
		return verify
	# Recheck the live account and all transient SaveManager guards just before
	# issuing a ready record. A future restore still needs a write barrier.
	if live_source:
		if (
			barrier_owner.is_empty()
			or not SaveManager.is_save_write_barrier_active()
			or SaveManager.get_save_write_barrier_owner() != barrier_owner
		):
			return _no("SAVE_WRITE_BARRIER_LOST")
		var issue: String = _live_issue(owner_uid, barrier_owner)
		if not issue.is_empty():
			return _no(issue)
	# Rename of a completed pending DIRECTORY is the sole commit marker.
	# No code touches the source files, SaveManager journal, or checkpoint.
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(pending),
		ProjectSettings.globalize_path(ready)
	) != OK:
		return _no("READY_RENAME_FAILED")
	var sealed: Dictionary = _inspect_ready(ready)
	if not bool(sealed.get("ok", false)):
		return sealed
	return {"ok": true, "code": "LOCAL_BACKUP_READY", "ready_path": ready,
		"domain_count": DOMAIN_COUNT, "file_count": copied,
		"upload_allowed": false, "restore_allowed": false}


func _check_primary(path: String, domain_id: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _no("PRIMARY_UNREADABLE")
	var data: Variant = file.get_var(false)
	file.close()
	if not data is Dictionary:
		return _no("PRIMARY_NOT_DICTIONARY")
	var expected: int = SaveManager.get_save_schema_version(domain_id)
	if not data.get("version") is int or int(data["version"]) != expected:
		return _no("PRIMARY_SCHEMA_UNSUPPORTED")
	for key in SaveManager.get_save_required_keys(domain_id):
		if not data.has(key):
			return _no("PRIMARY_INCOMPLETE")
	return {"ok": true}


func _inspect_ready(ready_path: String) -> Dictionary:
	if not ready_path.get_file().begins_with("ready_"):
		return _no("NOT_COMMITTED")
	return _inspect_candidate(ready_path)


func _inspect_candidate(dir_path: String) -> Dictionary:
	var path: String = dir_path + "/manifest.bin"
	if not FileAccess.file_exists(path):
		return _no("MANIFEST_MISSING")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _no("MANIFEST_UNREADABLE")
	var manifest: Variant = file.get_var(false)
	file.close()
	if not manifest is Dictionary or manifest.get("version") != VAULT_VERSION:
		return _no("MANIFEST_INVALID")
	if not manifest.get("owner_uid") is String or not _safe_uid(str(manifest["owner_uid"])):
		return _no("MANIFEST_OWNER_INVALID")
	var ids: Array[String] = SaveManager.get_save_domain_ids_for_scope(SaveManager.SCOPE_PERMANENT)
	ids.sort()
	if manifest.get("domain_ids") != ids or not manifest.get("domain_files") is Dictionary:
		return _no("MANIFEST_DOMAINS_INVALID")
	var files: Dictionary = manifest["domain_files"]
	if files.size() != DOMAIN_COUNT:
		return _no("MANIFEST_INCOMPLETE")
	var bytes: int = 0
	for id in ids:
		if not files.get(id) is Dictionary:
			return _no("MANIFEST_INCOMPLETE")
		var entry: Dictionary = files[id]
		if not entry.get("schema") is int or entry["schema"] != SaveManager.get_save_schema_version(id):
			return _no("MANIFEST_SCHEMA_INVALID")
		if not entry.get("primary") is Dictionary:
			return _no("MANIFEST_INCOMPLETE")
		for key in ["primary", "backup"]:
			if not entry.has(key):
				continue
			if not entry[key] is Dictionary:
				return _no("MANIFEST_FILE_INVALID")
			var f: Dictionary = entry[key]
			var want_name: String = id + (".primary" if key == "primary" else ".backup") + ".bin"
			if f.get("name") != want_name:
				return _no("MANIFEST_PATH_INVALID")
			if not f.get("bytes") is int or int(f["bytes"]) <= 0:
				return _no("MANIFEST_SIZE_INVALID")
			var hash: String = str(f.get("sha256", ""))
			if hash.length() != 64:
				return _no("MANIFEST_DIGEST_INVALID")
			for character in hash:
				if not "0123456789abcdef".contains(character):
					return _no("MANIFEST_DIGEST_INVALID")
			var saved: String = dir_path + "/" + want_name
			if not FileAccess.file_exists(saved) or FileAccess.get_size(saved) != int(f["bytes"]):
				return _no("BACKUP_MISSING_OR_TRUNCATED")
			if FileAccess.get_sha256(saved) != hash:
				return _no("BACKUP_TAMPERED")
			bytes += int(f["bytes"])
	if not manifest.get("total_bytes") is int or bytes != int(manifest["total_bytes"]) or bytes > MAX_ALL_BYTES:
		return _no("MANIFEST_TOTAL_MISMATCH")
	return {"ok": true, "code": "LOCAL_BACKUP_INTEGRITY_OK",
		"upload_allowed": false, "restore_allowed": false,
		"domain_count": DOMAIN_COUNT}


func _safe_uid(uid: String) -> bool:
	if uid.is_empty() or uid.length() > 128:
		return false
	for c in uid:
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-".contains(c):
			return false
	return true


func _no(code: String) -> Dictionary:
	return {"ok": false, "code": code,
		"upload_allowed": false, "restore_allowed": false}
