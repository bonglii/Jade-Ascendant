extends Node

## Save Manager
## Registry pusat untuk ownership, scope, path, versi schema, dan shared I/O.
## Setiap manager tetap menjadi pemilik data save domain miliknya.
## Penulisan memakai atomic commit dan mempertahankan satu backup valid.

signal save_architecture_audited(audit_result: Dictionary)
signal save_write_completed(domain_id: String, io_result: Dictionary)
signal save_read_completed(domain_id: String, io_result: Dictionary)
signal save_recovery_completed(domain_id: String, io_result: Dictionary)
signal save_delete_completed(domain_id: String, io_result: Dictionary)

const SAVE_ARCHITECTURE_VERSION: int = 1

const SCOPE_PERMANENT: String = "permanent"
const SCOPE_ACTIVE_RUN: String = "active_run"

const SCHEMA_LEGACY_UNVERSIONED: int = 0

const SAVE_DOMAINS: Dictionary = {
	"pavilion": {
		"owner": "PavilionManager", "scope": SCOPE_PERMANENT,
		"path": "user://pavilion.save", "schema_version": 1,
		"required_keys": ["meditation_date", "cosmetic_id", "owned_cosmetics"]
	},
	"progression": {
		"owner": "ProgressionManager",
		"scope": SCOPE_PERMANENT,
		"path": "user://progression.save",
		"schema_version": 1,
		"required_keys": [
			"spirit_stone",
			"vitality_level",
			"sword_power_level",
			"swift_qi_level"
		]
	},
	"journey": {
		"owner": "JourneyManager",
		"scope": SCOPE_PERMANENT,
		"path": "user://journey.save",
		"schema_version": 1,
		"required_keys": [
			"selected_chapter_id",
			"selected_stage_id",
			"active_run_chapter_id",
			"active_run_stage_id",
			"unlocked_stage_keys",
			"cleared_stage_keys"
		]
	},
	"achievements": {
		"owner": "AchievementManager",
		"scope": SCOPE_PERMANENT,
		"path": "user://achievements.save",
		"schema_version": 1,
		"required_keys": ["progress", "unlocked", "claimed"]
	},
	"daily_quests": {
		"owner": "DailyQuestManager",
		"scope": SCOPE_PERMANENT,
		"path": "user://daily_quests.save",
		"schema_version": 1,
		"required_keys": [
			"date_key",
			"progress",
			"completed",
			"claimed"
		]
	},
	"equipment": {
		"owner": "EquipmentManager",
		"scope": SCOPE_PERMANENT,
		"path": "user://equipment.save",
		"schema_version": 1,
		"required_keys": ["equipped_item_ids"]
	},
	"inventory": {
		"owner": "InventoryManager",
		"scope": SCOPE_PERMANENT,
		"path": "user://inventory.save",
		"schema_version": 1,
		"required_keys": ["item_counts"]
	},
	"checkpoint": {
		"owner": "CheckpointManager",
		"scope": SCOPE_ACTIVE_RUN,
		"path": "user://checkpoint.save",
		"schema_version": 1,
		"required_keys": [
			"survival_time",
			"wave",
			"wave_timer",
			"difficulty_level",
			"player_level",
			"experience",
			"experience_to_next_level"
		]
	}
}

var _write_blocked_domains: Dictionary = {}
const TRANSACTION_PATH: String = "user://transaction.journal"
var _pending_targets: Dictionary = {}
var _committing_batch: bool = false
var _transaction_fault: bool = false

func _ready() -> void:
	_recover_pending_transaction()
	var audit_result := audit_save_architecture()
	print_save_architecture_status(audit_result)
	save_architecture_audited.emit(audit_result.duplicate(true))

func get_save_domain_ids() -> Array[String]:
	var domain_ids: Array[String] = []
	for raw_domain_id in SAVE_DOMAINS.keys():
		domain_ids.append(str(raw_domain_id))
	domain_ids.sort()
	return domain_ids

func has_save_domain(domain_id: String) -> bool:
	return SAVE_DOMAINS.has(domain_id)

func get_save_definition(domain_id: String) -> Dictionary:
	if not has_save_domain(domain_id):
		return {}
	var definition: Dictionary = SAVE_DOMAINS[domain_id]
	return definition.duplicate(true)

func get_save_path(domain_id: String) -> String:
	return str(get_save_definition(domain_id).get("path", ""))

func get_save_scope(domain_id: String) -> String:
	return str(get_save_definition(domain_id).get("scope", ""))

func get_save_schema_version(domain_id: String) -> int:
	return int(
		get_save_definition(domain_id).get(
			"schema_version",
			SCHEMA_LEGACY_UNVERSIONED
		)
	)

func get_save_required_keys(domain_id: String) -> Array[String]:
	var required_keys: Array[String] = []
	var raw_keys = get_save_definition(domain_id).get("required_keys", [])
	if not raw_keys is Array:
		return required_keys
	for raw_key in raw_keys:
		var required_key: String = str(raw_key)
		if required_key.is_empty() or required_key in required_keys:
			continue
		required_keys.append(required_key)
	return required_keys

func is_save_write_blocked(domain_id: String) -> bool:
	return _write_blocked_domains.has(domain_id)

func get_save_write_block_reason(domain_id: String) -> String:
	return str(_write_blocked_domains.get(domain_id, ""))

func clear_save_write_block(domain_id: String) -> void:
	_write_blocked_domains.erase(domain_id)

func has_save_file(domain_id: String) -> bool:
	var save_path := get_save_path(domain_id)
	if save_path.is_empty():
		return false
	return FileAccess.file_exists(save_path)

func get_save_backup_path(domain_id: String) -> String:
	var save_path := get_save_path(domain_id)
	if save_path.is_empty():
		return ""
	return save_path + ".backup"

func has_save_backup(domain_id: String) -> bool:
	var backup_path := get_save_backup_path(domain_id)
	if backup_path.is_empty():
		return false
	return FileAccess.file_exists(backup_path)

func get_save_domain_ids_for_scope(scope_id: String) -> Array[String]:
	var matching_ids: Array[String] = []
	for domain_id in get_save_domain_ids():
		if get_save_scope(domain_id) == scope_id:
			matching_ids.append(domain_id)
	return matching_ids

func get_existing_save_domain_ids() -> Array[String]:
	var existing_ids: Array[String] = []
	for domain_id in get_save_domain_ids():
		if has_save_file(domain_id):
			existing_ids.append(domain_id)
	return existing_ids

func get_legacy_save_domain_ids() -> Array[String]:
	var legacy_ids: Array[String] = []
	for domain_id in get_save_domain_ids():
		if get_save_schema_version(domain_id) <= (
			SCHEMA_LEGACY_UNVERSIONED
		):
			legacy_ids.append(domain_id)
	return legacy_ids

## Menghapus satu domain active-run beserta backup dan artefak atomic-nya.
## Domain permanent sengaja ditolak oleh API ini.
func delete_active_run_save(domain_id: String) -> Dictionary:
	if has_pending_transaction():
		return _build_delete_result(false, has_save_file(domain_id), 0, "Pending save transaction; restart before resetting a run.")
	if not has_save_domain(domain_id):
		var invalid_result := _build_delete_result(
			false,
			false,
			0,
			"domain save tidak terdaftar: " + domain_id
		)
		invalid_result["domain_id"] = domain_id
		save_delete_completed.emit(
			domain_id,
			invalid_result.duplicate(true)
		)
		return invalid_result
	if get_save_scope(domain_id) != SCOPE_ACTIVE_RUN:
		var protected_result := _build_delete_result(
			false,
			has_save_file(domain_id),
			0,
			"domain permanent dilindungi dari active-run reset"
		)
		protected_result["domain_id"] = domain_id
		protected_result["scope_protected"] = true
		save_delete_completed.emit(
			domain_id,
			protected_result.duplicate(true)
		)
		return protected_result
	var delete_result := _delete_save_path_artifacts(
		get_save_path(domain_id),
		true
	)
	delete_result["domain_id"] = domain_id
	delete_result["scope"] = SCOPE_ACTIVE_RUN
	if bool(delete_result.get("success", false)):
		clear_save_write_block(domain_id)
	save_delete_completed.emit(
		domain_id,
		delete_result.duplicate(true)
	)
	return delete_result

## Reset New Game hanya menargetkan seluruh domain active-run terdaftar.
func reset_active_run_saves() -> Dictionary:
	var domain_ids := get_save_domain_ids_for_scope(SCOPE_ACTIVE_RUN)
	var domain_results: Dictionary = {}
	var failed_domain_ids: Array[String] = []
	var deleted_domain_count: int = 0
	for domain_id in domain_ids:
		var delete_result := delete_active_run_save(domain_id)
		domain_results[domain_id] = delete_result.duplicate(true)
		if bool(delete_result.get("success", false)):
			deleted_domain_count += 1
		else:
			failed_domain_ids.append(domain_id)
	return {
		"success": failed_domain_ids.is_empty(),
		"domain_ids": domain_ids.duplicate(),
		"domain_results": domain_results,
		"deleted_domain_count": deleted_domain_count,
		"failed_domain_ids": failed_domain_ids
	}

## Menulis Dictionary ke domain terdaftar melalui staged atomic commit.
## Owner data tetap manager domain; SaveManager hanya menangani I/O bersama.
func write_save_data(
	domain_id: String,
	save_data: Dictionary
) -> Dictionary:
	if has_pending_transaction() and not _committing_batch:
		return _build_io_result(false, has_save_file(domain_id), {}, "Pending save transaction; restart to recover safely.")
	if not has_save_domain(domain_id):
		var invalid_result := _build_io_result(
			false,
			false,
			{},
			"domain save tidak terdaftar: " + domain_id
		)
		invalid_result["domain_id"] = domain_id
		save_write_completed.emit(
			domain_id,
			invalid_result.duplicate(true)
		)
		return invalid_result
	if is_save_write_blocked(domain_id):
		var blocked_result := _build_io_result(
			false,
			has_save_file(domain_id),
			{},
			"write diblokir untuk melindungi save: "
			+ get_save_write_block_reason(domain_id)
		)
		blocked_result["domain_id"] = domain_id
		blocked_result["write_blocked"] = true
		save_write_completed.emit(
			domain_id,
			blocked_result.duplicate(true)
		)
		return blocked_result
	var io_result := _write_dictionary_to_path_atomic(
		get_save_path(domain_id),
		save_data,
		true
	)
	io_result["domain_id"] = domain_id
	save_write_completed.emit(domain_id, io_result.duplicate(true))
	return io_result

## Journal final values before touching domains. Replay assigns snapshots rather
## than adding currency again. The journal deliberately has no historical backup:
## an obsolete completed transaction must never be replayed over newer progress.
func write_save_batch(targets: Dictionary) -> bool:
	if targets.is_empty() or has_pending_transaction():
		return false
	if not _validate_batch_targets(targets):
		return false
	for domain_id in targets:
		read_save_data(str(domain_id))
		if is_save_write_blocked(str(domain_id)):
			return false
	var journal_result: Dictionary = _write_dictionary_to_path_atomic(TRANSACTION_PATH, {"version": 1, "targets": targets.duplicate(true)}, false)
	if not bool(journal_result.get("success", false)):
		_transaction_fault = true
		return false
	_pending_targets = targets.duplicate(true)
	return _finish_pending_transaction()

func has_pending_transaction() -> bool:
	return _transaction_fault or not _pending_targets.is_empty()

func _validate_batch_targets(targets: Dictionary) -> bool:
	for raw_id in targets:
		var domain_id: String = str(raw_id)
		if not has_save_domain(domain_id) or not targets[raw_id] is Dictionary:
			return false
		var payload: Dictionary = targets[raw_id]
		if payload.get("version", -1) != get_save_schema_version(domain_id):
			return false
		for key in get_save_required_keys(domain_id):
			if not payload.has(key):
				return false
		if not _domain_value_types_valid(get_save_path(domain_id), payload):
			return false
	return true

func _recover_pending_transaction() -> void:
	var path: String = TRANSACTION_PATH
	# Interrupted rename while replacing the journal: rollback is the last
	# committed intent. A .tmp alone precedes intent commit and is safe to ignore.
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".rollback"):
		path += ".rollback"
	if not FileAccess.file_exists(path):
		return
	var io_result: Dictionary = _read_dictionary_from_path(path)
	var data: Dictionary = io_result.get("data", {})
	if not bool(io_result.get("success", false)) or data.get("version", -1) != 1 or not data.get("targets") is Dictionary:
		_transaction_fault = true
		return
	_pending_targets = data["targets"].duplicate(true)
	if not _pending_targets.is_empty():
		if not _validate_batch_targets(_pending_targets):
			_transaction_fault = true
			return
		_finish_pending_transaction()

func _finish_pending_transaction() -> bool:
	_committing_batch = true
	for domain_id in _pending_targets:
		read_save_data(str(domain_id))
		var result: Dictionary = write_save_data(str(domain_id), _pending_targets[domain_id])
		if not bool(result.get("success", false)):
			_committing_batch = false
			return false
	var cleared: Dictionary = _write_dictionary_to_path_atomic(TRANSACTION_PATH, {"version": 1, "targets": {}}, false)
	_committing_batch = false
	if not bool(cleared.get("success", false)):
		return false
	_pending_targets.clear()
	return true

## Membaca domain dan memulihkan primary rusak dari backup valid bila aman.
## Primary yang hilang atau memakai schema masa depan tidak dipulihkan otomatis.
func read_save_data(domain_id: String) -> Dictionary:
	if not has_save_domain(domain_id):
		var invalid_result := _build_io_result(
			false,
			false,
			{},
			"domain save tidak terdaftar: " + domain_id
		)
		invalid_result["domain_id"] = domain_id
		save_read_completed.emit(
			domain_id,
			invalid_result.duplicate(true)
		)
		return invalid_result
	var io_result := _read_dictionary_with_recovery(
		get_save_path(domain_id),
		get_save_schema_version(domain_id),
		get_save_required_keys(domain_id)
	)
	io_result["domain_id"] = domain_id
	if bool(io_result.get("success", false)):
		clear_save_write_block(domain_id)
	elif not bool(io_result.get("exists", false)):
		clear_save_write_block(domain_id)
	else:
		_write_blocked_domains[domain_id] = str(
			io_result.get("error", "integrity check gagal")
		)
	if bool(io_result.get("recovered", false)):
		DebugLogger.system(str("Save recovered from backup | Domain: ", domain_id))
		save_recovery_completed.emit(
			domain_id,
			io_result.duplicate(true)
		)
	save_read_completed.emit(domain_id, io_result.duplicate(true))
	return io_result

## Membaca backup terakhir tanpa mengubah primary save.
func read_save_backup(domain_id: String) -> Dictionary:
	if not has_save_domain(domain_id):
		var invalid_result := _build_io_result(
			false,
			false,
			{},
			"domain save tidak terdaftar: " + domain_id
		)
		invalid_result["domain_id"] = domain_id
		return invalid_result
	var io_result := _read_dictionary_with_schema_limit(
		get_save_backup_path(domain_id),
		get_save_schema_version(domain_id),
		get_save_required_keys(domain_id)
	)
	io_result["domain_id"] = domain_id
	io_result["source"] = "backup"
	return io_result

## Memulihkan primary save dari backup valid melalui atomic commit.
func recover_save_from_backup(domain_id: String) -> Dictionary:
	if not has_save_domain(domain_id):
		var invalid_result := _build_io_result(
			false,
			false,
			{},
			"domain save tidak terdaftar: " + domain_id
		)
		invalid_result["domain_id"] = domain_id
		save_recovery_completed.emit(
			domain_id,
			invalid_result.duplicate(true)
		)
		return invalid_result
	var io_result := _recover_dictionary_from_backup(
		get_save_path(domain_id),
		get_save_schema_version(domain_id),
		get_save_required_keys(domain_id)
	)
	io_result["domain_id"] = domain_id
	if bool(io_result.get("success", false)):
		clear_save_write_block(domain_id)
	elif has_save_file(domain_id):
		_write_blocked_domains[domain_id] = str(
			io_result.get("error", "recovery gagal")
		)
	save_recovery_completed.emit(domain_id, io_result.duplicate(true))
	return io_result

func audit_save_architecture() -> Dictionary:
	var errors: Array[String] = []
	var registered_paths: Dictionary = {}
	for domain_id in get_save_domain_ids():
		var definition := get_save_definition(domain_id)
		var owner_name := str(definition.get("owner", ""))
		var scope_id := str(definition.get("scope", ""))
		var save_path := str(definition.get("path", ""))
		var schema_version := int(
			definition.get("schema_version", -1)
		)
		var raw_required_keys = definition.get("required_keys", [])
		if domain_id.strip_edges().is_empty():
			errors.append("domain id tidak boleh kosong")
		if owner_name.strip_edges().is_empty():
			errors.append(domain_id + ": owner tidak valid")
		if scope_id not in [SCOPE_PERMANENT, SCOPE_ACTIVE_RUN]:
			errors.append(domain_id + ": scope tidak valid")
		if not save_path.begins_with("user://"):
			errors.append(domain_id + ": path harus menggunakan user://")
		if not save_path.ends_with(".save"):
			errors.append(domain_id + ": ekstensi harus .save")
		if registered_paths.has(save_path):
			errors.append(
				domain_id
				+ ": path duplikat dengan "
				+ str(registered_paths[save_path])
			)
		else:
			registered_paths[save_path] = domain_id
		if schema_version < SCHEMA_LEGACY_UNVERSIONED:
			errors.append(domain_id + ": schema version tidak valid")
		if (
			not raw_required_keys is Array
			or get_save_required_keys(domain_id).is_empty()
		):
			errors.append(domain_id + ": required keys tidak valid")

	return {
		"valid": errors.is_empty(),
		"architecture_version": SAVE_ARCHITECTURE_VERSION,
		"domain_count": SAVE_DOMAINS.size(),
		"permanent_domain_count": get_save_domain_ids_for_scope(
			SCOPE_PERMANENT
		).size(),
		"active_run_domain_count": get_save_domain_ids_for_scope(
			SCOPE_ACTIVE_RUN
		).size(),
		"existing_save_count": get_existing_save_domain_ids().size(),
		"legacy_domain_count": get_legacy_save_domain_ids().size(),
		"errors": errors
	}

func _write_dictionary_to_path_atomic(
	save_path: String,
	save_data: Dictionary,
	preserve_previous_as_backup: bool = false
) -> Dictionary:
	var staging_path := save_path + ".tmp"
	var rollback_path := save_path + ".rollback"
	var backup_path := save_path + ".backup"
	if not _remove_save_path_if_present(staging_path):
		return _build_io_result(
			false,
			FileAccess.file_exists(save_path),
			{},
			"file staging lama tidak dapat dibersihkan"
		)
	if not _remove_save_path_if_present(rollback_path):
		return _build_io_result(
			false,
			FileAccess.file_exists(save_path),
			{},
			"file rollback lama tidak dapat dibersihkan"
		)

	var staging_file := FileAccess.open(
		staging_path,
		FileAccess.WRITE
	)
	if staging_file == null:
		return _build_io_result(
			false,
			FileAccess.file_exists(save_path),
			{},
			"file staging tidak dapat dibuat"
		)
	staging_file.store_var(save_data)
	staging_file.flush()
	staging_file.close()

	var staging_read := _read_dictionary_from_path(staging_path)
	if (
		not bool(staging_read.get("success", false))
		or staging_read.get("data", {}) != save_data
	):
		_remove_save_path_if_present(staging_path)
		return _build_io_result(
			false,
			FileAccess.file_exists(save_path),
			{},
			"validasi file staging gagal"
		)

	var had_existing_save: bool = FileAccess.file_exists(save_path)
	var previous_read := _read_dictionary_from_path(save_path)
	var should_backup_previous: bool = (
		preserve_previous_as_backup
		and had_existing_save
		and bool(previous_read.get("success", false))
	)
	if had_existing_save:
		var rollback_error := _rename_save_path(
			save_path,
			rollback_path
		)
		if rollback_error != OK:
			_remove_save_path_if_present(staging_path)
			return _build_io_result(
				false,
				true,
				{},
				"save lama tidak dapat dipindahkan untuk commit"
			)

	var commit_error := _rename_save_path(staging_path, save_path)
	if commit_error != OK:
		if had_existing_save:
			_rename_save_path(rollback_path, save_path)
		_remove_save_path_if_present(staging_path)
		return _build_io_result(
			false,
			FileAccess.file_exists(save_path),
			{},
			"commit file staging gagal"
		)

	var committed_read := _read_dictionary_from_path(save_path)
	if (
		not bool(committed_read.get("success", false))
		or committed_read.get("data", {}) != save_data
	):
		_remove_save_path_if_present(save_path)
		if had_existing_save:
			_rename_save_path(rollback_path, save_path)
		return _build_io_result(
			false,
			FileAccess.file_exists(save_path),
			{},
			"validasi hasil commit gagal"
		)

	var cleanup_warning := ""
	var backup_created: bool = false
	if had_existing_save and should_backup_previous:
		if not _remove_save_path_if_present(backup_path):
			cleanup_warning = "backup lama tidak dapat diganti"
		else:
			var backup_error := _rename_save_path(
				rollback_path,
				backup_path
			)
			if backup_error == OK:
				backup_created = true
			else:
				cleanup_warning = "rollback tidak dapat dipromosikan menjadi backup"
	elif (
		had_existing_save
		and not _remove_save_path_if_present(rollback_path)
	):
		cleanup_warning = "file rollback belum dapat dibersihkan"
	if not cleanup_warning.is_empty():
		push_warning("SaveManager: " + cleanup_warning)
	var success_result := _build_io_result(
		true,
		true,
		save_data,
		""
	)
	success_result["warning"] = cleanup_warning
	success_result["backup_created"] = backup_created
	return success_result

func _recover_dictionary_from_backup(
	save_path: String,
	maximum_schema_version: int = -1,
	required_keys: Array[String] = []
) -> Dictionary:
	var backup_path := save_path + ".backup"
	var backup_read := _read_dictionary_with_schema_limit(
		backup_path,
		maximum_schema_version,
		required_keys
	)
	if not bool(backup_read.get("success", false)):
		var failed_result := _build_io_result(
			false,
			FileAccess.file_exists(save_path),
			{},
			"backup tidak valid: " + str(backup_read.get("error", ""))
		)
		failed_result["recovered"] = false
		failed_result["source"] = "backup"
		return failed_result
	var backup_data: Dictionary = backup_read.get("data", {})
	var recovery_result := _write_dictionary_to_path_atomic(
		save_path,
		backup_data,
		false
	)
	recovery_result["recovered"] = bool(
		recovery_result.get("success", false)
	)
	recovery_result["source"] = "backup"
	return recovery_result

func _read_dictionary_with_recovery(
	save_path: String,
	maximum_schema_version: int,
	required_keys: Array[String] = []
) -> Dictionary:
	var primary_read := _read_dictionary_with_schema_limit(
		save_path,
		maximum_schema_version,
		required_keys
	)
	primary_read["source"] = "primary"
	primary_read["recovered"] = false
	primary_read["recovery_attempted"] = false
	if bool(primary_read.get("success", false)):
		return primary_read
	if not bool(primary_read.get("exists", false)):
		return primary_read
	if str(primary_read.get("integrity_issue", "")) == (
		"unsupported_schema"
	):
		return primary_read

	var primary_error: String = str(primary_read.get("error", ""))
	var recovery_result := _recover_dictionary_from_backup(
		save_path,
		maximum_schema_version,
		required_keys
	)
	recovery_result["recovery_attempted"] = true
	recovery_result["primary_error"] = primary_error
	if bool(recovery_result.get("success", false)):
		return recovery_result
	primary_read["recovery_attempted"] = true
	primary_read["recovery_error"] = str(
		recovery_result.get("error", "")
	)
	return primary_read

func _read_dictionary_with_schema_limit(
	save_path: String,
	maximum_schema_version: int,
	required_keys: Array[String] = []
) -> Dictionary:
	var read_result := _read_dictionary_from_path(save_path)
	if not bool(read_result.get("success", false)):
		return read_result
	var save_data: Dictionary = read_result.get("data", {})
	var raw_version: Variant = save_data.get("version", SCHEMA_LEGACY_UNVERSIONED)
	if not raw_version is int:
		var invalid_version_result := _build_io_result(
			false, true, {}, "tipe versi schema save harus integer"
		)
		# An unreadable version must not be guessed or downgraded from backup.
		invalid_version_result["integrity_issue"] = "unsupported_schema"
		return invalid_version_result
	var source_version: int = int(raw_version)
	if (
		maximum_schema_version >= SCHEMA_LEGACY_UNVERSIONED
		and (
			source_version < SCHEMA_LEGACY_UNVERSIONED
			or source_version > maximum_schema_version
		)
	):
		var unsupported_result := _build_io_result(
			false,
			true,
			{},
			"versi schema save tidak didukung: v%d" % source_version
		)
		unsupported_result["integrity_issue"] = "unsupported_schema"
		return unsupported_result
	for required_key in required_keys:
		if save_data.has(required_key):
			continue
		var incomplete_result := _build_io_result(
			false,
			true,
			{},
			"payload save tidak lengkap; key hilang: " + required_key
		)
		incomplete_result["integrity_issue"] = "incomplete_payload"
		return incomplete_result
	if not _domain_value_types_valid(save_path, save_data):
		var invalid_values: Dictionary = _build_io_result(false, true, {}, "save payload contains invalid value types")
		invalid_values["integrity_issue"] = "invalid_payload"
		return invalid_values
	return read_result

func _read_dictionary_from_path(save_path: String) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return _build_io_result(
			false,
			false,
			{},
			"file save tidak ditemukan"
		)
	var save_file := FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		return _build_io_result(
			false,
			true,
			{},
			"file save tidak dapat dibuka"
		)
	var loaded_data = save_file.get_var()
	save_file.close()
	if not loaded_data is Dictionary:
		return _build_io_result(
			false,
			true,
			{},
			"isi file save bukan Dictionary"
		)
	var validated_data: Dictionary = loaded_data
	return _build_io_result(
		true,
		true,
		validated_data,
		""
	)

func _build_io_result(
	success: bool,
	file_exists: bool,
	loaded_data: Dictionary,
	error_message: String
) -> Dictionary:
	return {
		"success": success,
		"exists": file_exists,
		"data": loaded_data.duplicate(true),
		"error": error_message
	}

func _build_delete_result(
	success: bool,
	had_artifacts: bool,
	deleted_count: int,
	error_message: String
) -> Dictionary:
	return {
		"success": success,
		"existed": had_artifacts,
		"deleted_count": deleted_count,
		"error": error_message
	}

func _rename_save_path(source_path: String, target_path: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(target_path)
	)

func _remove_save_path_if_present(save_path: String) -> bool:
	if not FileAccess.file_exists(save_path):
		return true
	return DirAccess.remove_absolute(
		ProjectSettings.globalize_path(save_path)
	) == OK

## Artefak pendamping dibersihkan lebih dahulu; primary dihapus terakhir.
## Dengan begitu kegagalan cleanup tidak menghilangkan checkpoint utama.
func _delete_save_path_artifacts(
	save_path: String,
	include_backup: bool
) -> Dictionary:
	if save_path.is_empty():
		return _build_delete_result(
			false,
			false,
			0,
			"path save tidak valid"
		)
	var delete_paths: Array[String] = [
		save_path + ".tmp",
		save_path + ".rollback"
	]
	if include_backup:
		delete_paths.append(save_path + ".backup")
	delete_paths.append(save_path)
	var had_artifacts: bool = false
	var deleted_count: int = 0
	for delete_path in delete_paths:
		if not FileAccess.file_exists(delete_path):
			continue
		had_artifacts = true
		if not _remove_save_path_if_present(delete_path):
			return _build_delete_result(
				false,
				had_artifacts,
				deleted_count,
				"gagal menghapus artefak save: " + delete_path
			)
		deleted_count += 1
	for delete_path in delete_paths:
		if FileAccess.file_exists(delete_path):
			return _build_delete_result(
				false,
				had_artifacts,
				deleted_count,
				"artefak save masih tersisa: " + delete_path
			)
	var success_result := _build_delete_result(
		true,
		had_artifacts,
		deleted_count,
		""
	)
	success_result["artifacts_clean"] = true
	return success_result


func print_save_architecture_status(audit_result: Dictionary) -> void:
	DebugLogger.system(str("SaveManager aktif!"))
	DebugLogger.system(str(
		"Save Architecture Version: ",
		SAVE_ARCHITECTURE_VERSION
	))
	DebugLogger.system(str("Save Catalog Valid: ", audit_result.get("valid", false)))
	DebugLogger.system(str("Save Domain Count: ", audit_result.get("domain_count", 0)))
	DebugLogger.system(str(
		"Permanent Save Domains: ",
		audit_result.get("permanent_domain_count", 0)
	))
	DebugLogger.system(str(
		"Active Run Save Domains: ",
		audit_result.get("active_run_domain_count", 0)
	))
	DebugLogger.system(str(
		"Existing Save Files: ",
		audit_result.get("existing_save_count", 0)
	))
	DebugLogger.system(str(
		"Legacy Save Domains: ",
		audit_result.get("legacy_domain_count", 0)
	))
	for domain_id in get_save_domain_ids():
		var definition := get_save_definition(domain_id)
		DebugLogger.system(str(
			"Save Domain ",
			domain_id,
			": ",
			definition.get("scope", "unknown"),
			" | Schema: ",
			_get_schema_label(get_save_schema_version(domain_id)),
			" | Exists: ",
			has_save_file(domain_id),
			" | Owner: ",
			definition.get("owner", "unknown")
		))
	var errors = audit_result.get("errors", [])
	if errors is Array:
		for raw_error in errors:
			push_warning("SaveManager: " + str(raw_error))

func _get_schema_label(schema_version: int) -> String:
	if schema_version <= SCHEMA_LEGACY_UNVERSIONED:
		return "legacy_unversioned"
	return "v%d" % schema_version

## Validate before owner code converts numeric values. Corrupt primaries use the
## existing validated-backup route; unsupported versions remain write-protected.
func _domain_value_types_valid(path: String, data: Dictionary) -> bool:
	var domain: String = ""
	for raw_id in SAVE_DOMAINS:
		var candidate: String = get_save_path(str(raw_id))
		if path in [candidate, candidate + ".backup", candidate + ".tmp", candidate + ".rollback"]:
			domain = str(raw_id)
			break
	var number_keys: Array[String] = []
	var array_keys: Array[String] = []
	var string_keys: Array[String] = []
	var count_map: String = ""
	match domain:
		"progression":
			number_keys = ["spirit_stone", "vitality_level", "sword_power_level", "swift_qi_level"]
		"journey":
			number_keys = ["selected_chapter_id", "selected_stage_id", "active_run_chapter_id", "active_run_stage_id"]
			array_keys = ["unlocked_stage_keys", "cleared_stage_keys"]
		"achievements":
			array_keys = ["unlocked", "claimed"]
			count_map = "progress"
		"daily_quests":
			array_keys = ["completed", "claimed", "active_quest_ids"]
			string_keys = ["date_key"]
			count_map = "progress"
		"inventory":
			count_map = "item_counts"
		"equipment":
			if not data.get("equipped_item_ids") is Dictionary:
				return false
			for key in data["equipped_item_ids"]:
				if not key is String or not data["equipped_item_ids"][key] is String:
					return false
			# Gate 1.5 is an additive v1 payload extension. Old v1 saves do not
			# contain ascension_stars and therefore remain valid at 1★.
			if data.has("ascension_stars"):
				if not data["ascension_stars"] is Dictionary:
					return false
				for key in data["ascension_stars"]:
					if not key is String or not _is_integral_number(data["ascension_stars"][key]):
						return false
					var star: int = int(data["ascension_stars"][key])
					if star < 1 or star > 5:
						return false
		"pavilion":
			array_keys = ["owned_cosmetics"]
			string_keys = ["meditation_date", "cosmetic_id"]
	for key in number_keys:
		if not _is_integral_number(data.get(key)):
			return false
	for key in string_keys:
		if not data.get(key) is String:
			return false
	for key in array_keys:
		# active_quest_ids is additive; old v1 saves need not contain it.
		if not data.has(key):
			continue
		if not data[key] is Array:
			return false
		for value in data[key]:
			if not value is String:
				return false
	if not count_map.is_empty():
		if not data.get(count_map) is Dictionary:
			return false
		for key in data[count_map]:
			if not key is String or not _is_integral_number(data[count_map][key]):
				return false
	return true

func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(float(value)) and absf(float(value)) < 9007199254740992.0 and floorf(float(value)) == float(value)

func is_progress_read_only() -> bool:
	if has_pending_transaction():
		return true
	for domain_id in get_save_domain_ids_for_scope(SCOPE_PERMANENT):
		if is_save_write_blocked(domain_id):
			return true
	return false
