extends RefCounted

## Gate 1 — manual, memory-only candidate capture. Not a cloud backup.
## NEVER save, restore, send to Firestore, or log the returned `draft`.
## Capture is synchronous (no await); no SaveManager.read_save_data() or save-file content I/O.

const SnapshotContractScript = preload(
	"res://scripts/managers/cloud_save_snapshot_contract.gd"
)
const ManifestInspectorScript = preload(
	"res://scripts/managers/cloud_save_manifest_inspector.gd"
)
const EconomyConsistencyScript = preload(
	"res://scripts/managers/cloud_save_economy_consistency.gd"
)


## Only called deliberately by a future integration; never from _ready or save signals.
## The returned draft contains the account UID and gameplay values: keep it private.
func capture_current_account_preview() -> Dictionary:
	var uid: String = GoogleAccountManager.get_authenticated_uid()
	if not _is_safe_uid(uid):
		return _reject("not_authenticated")
	var boundary_issue: String = _live_boundary_issue()
	if not boundary_issue.is_empty():
		return _reject(boundary_issue)

	# Owner manager methods only build dictionaries from existing runtime memory.
	# Do not call save_*(), load_*(), or SaveManager.read_save_data(): the
	# latter can automatically repair a corrupted primary from its backup.
	var source_domains: Dictionary = {
		"achievements": AchievementManager.build_save_data(),
		"daily_quests": DailyQuestManager.build_save_data(),
		"equipment": EquipmentManager.build_equipment_save_data(),
		"inventory": {
			"version": InventoryManager.SAVE_VERSION,
			"item_counts": InventoryManager.item_counts.duplicate(true)
		},
		"journey": JourneyManager.build_save_data(),
		"progression": ProgressionManager.build_progression_save_data()
	}
	var preview: Dictionary = build_from_memory_for_qa(
		uid, source_domains, int(Time.get_unix_time_from_system())
	)
	# Fail closed if a transition, account switch, or save guard appeared.
	if not bool(preview.get("valid", false)):
		return preview
	if uid != GoogleAccountManager.get_authenticated_uid():
		return _reject("account_changed")
	boundary_issue = _live_boundary_issue()
	if not boundary_issue.is_empty():
		return _reject(boundary_issue)
	return preview


## Pure synthetic-input QA seam; does NOT inspect the player's live save.
## Keep it unconnected to UI/network. No trusted revision is allocated here.
func build_from_memory_for_qa(
	uid: String, source_domains: Dictionary, local_unix: int
) -> Dictionary:
	if not _is_safe_uid(uid):
		return _reject("invalid_identity")
	if local_unix <= 0 or local_unix > SnapshotContractScript.MAX_SAFE_INTEGER:
		return _reject("invalid_local_timestamp")
	var domain_ids: Array = SnapshotContractScript.DOMAIN_IDS
	if source_domains.size() != domain_ids.size():
		return _reject("incomplete_or_extra_domains")
	for raw_domain in source_domains:
		if not (raw_domain is String) or raw_domain not in domain_ids:
			return _reject("unsafe_domain")

	var domain_versions: Dictionary = {}
	var domain_payloads: Dictionary = {}
	for domain_id in domain_ids:
		if not SaveManager.has_save_domain(domain_id):
			return _reject("unregistered_domain")
		if SaveManager.get_save_scope(domain_id) != SaveManager.SCOPE_PERMANENT:
			return _reject("unsafe_scope")
		if not (source_domains[domain_id] is Dictionary):
			return _reject("invalid_domain_payload")
		var payload: Dictionary = source_domains[domain_id]
		# No coercion, repair, legacy migration, or implicit strip of active-run
		# fields. An unexpected key must be rejected by the existing contract.
		domain_payloads[domain_id] = payload.duplicate(true)
		domain_versions[domain_id] = SaveManager.get_save_schema_version(domain_id)

	var draft: Dictionary = {
		"snapshot_format_version": SnapshotContractScript.SNAPSHOT_FORMAT_VERSION,
		"owner_uid": uid,
		# This is a structural placeholder, NOT an authoritative revision.
		"revision": 1,
		"saved_at_unix": local_unix,
		"domain_schema_versions": domain_versions,
		"domains": domain_payloads
	}
	var contract: RefCounted = SnapshotContractScript.new() as RefCounted
	var inspection: Dictionary = contract.call("inspect_draft", draft, uid)
	if not bool(inspection.get("valid", false)):
		return _reject(str(inspection.get("reason", "invalid_snapshot")))
	var economy_policy: RefCounted = EconomyConsistencyScript.new() as RefCounted
	var economy_report: Dictionary = economy_policy.call("inspect_domains", domain_ids)
	if not bool(economy_report.get("valid", false)):
		return _reject("economy_graph_audit_failed")
	return {
		"valid": true,
		"reason": "local_memory_preview_only",
		"domain_count": domain_ids.size(),
		"draft": draft,
		"upload_allowed": false,
		"restore_allowed": false,
		"server_verified": false,
		"economy_verified": false,
		"economy_transaction_closed": bool(economy_report.get("transaction_closed", false)),
		"economy_missing_domain_dependencies": (
			economy_report.get("missing_dependency_domains", []) as Array
		).duplicate(true),
		"server_freshness_verified": false,
		"local_time_untrusted": true
	}


func _live_boundary_issue() -> String:
	if SaveManager.has_pending_transaction():
		return "pending_transaction"
	if SaveManager.is_progress_read_only():
		return "save_write_blocked"
	if SceneTransitionManager.is_transitioning:
		return "scene_transition"
	if JourneyManager.has_active_run():
		return "active_run"
	if SaveManager.has_save_file("checkpoint"):
		return "active_checkpoint"
	if not EquipmentManager.active_run_loadout_snapshot.is_empty():
		return "active_run_loadout"
	# Additional guard for a gameplay scene that has not yet persisted a run.
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree and not (loop as SceneTree).get_nodes_in_group("player").is_empty():
		return "gameplay_scene"
	return ""


func _is_safe_uid(uid: String) -> bool:
	var inspector: RefCounted = ManifestInspectorScript.new() as RefCounted
	return bool(inspector.call("is_safe_uid", uid))


func _reject(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"draft": {},
		"upload_allowed": false,
		"restore_allowed": false,
		"server_verified": false,
		"economy_verified": false,
		"economy_transaction_closed": false,
		"economy_missing_domain_dependencies": [],
		"server_freshness_verified": false
	}
