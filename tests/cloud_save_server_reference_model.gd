extends RefCounted

## SYNTHETIC SERVER REFERENCE MODEL -- QA ONLY.
## NEVER instantiate from production UI or client cloud code. This is not a
## backend, receipt verifier, Firebase admin SDK, or trustworthy authority.
## It models invariants for a future server implementation using fake inputs.
## The Android export preset excludes tests/*.

const MAX_SAFE_INTEGER: int = 9007199254740991
const PERMANENT_DOMAINS = [
	"pavilion", "progression", "journey", "achievements", "daily_quests",
	"equipment", "inventory", "idle_cultivation"
]
const ECONOMY_DEPENDENCY_DOMAINS = [
	"pavilion", "progression", "achievements", "daily_quests",
	"equipment", "inventory", "idle_cultivation"
]

var _accounts: Dictionary = {}
# A token fingerprint is globally unique across ALL test accounts, not just
# the most recent 1024 entries of one device's local Pavilion save.
var _purchase_owners: Dictionary = {}
var _voided_purchases: Dictionary = {}


func create_account(uid: String) -> Dictionary:
	if not _safe_key(uid):
		return _reject("invalid_account")
	if _accounts.has(uid):
		return _reject("already_registered")
	_accounts[uid] = {
		"revision": 0,
		"granted_units": 0,
		"reconciliation_required": false
	}
	return _result(true, "account_created", uid)


func get_summary(uid: String) -> Dictionary:
	if not _accounts.has(uid):
		return _reject("unknown_account")
	var entry: Dictionary = _accounts[uid]
	return {
		"revision": int(entry["revision"]),
		"granted_units": int(entry["granted_units"]),
		"reconciliation_required": bool(entry["reconciliation_required"])
	}


## The CLIENT may suggest a snapshot, never authorize/commit one. Even an
## apparently complete and current proposal has no server-side trust proof.
func propose_client_snapshot(
	authenticated_uid: String, owner_uid: String,
	expected_revision: int, proposed_domains: Dictionary
) -> Dictionary:
	var guard_issue: String = _guard(authenticated_uid, owner_uid)
	if not guard_issue.is_empty():
		return _reject(guard_issue)
	var state: Dictionary = _accounts[owner_uid]
	if expected_revision != int(state["revision"]):
		return _reject("stale_revision")
	if proposed_domains.is_empty():
		return _reject("empty_domain_proposal")
	for raw_domain in proposed_domains:
		if typeof(raw_domain) != TYPE_STRING:
			return _reject("invalid_domain")
		if raw_domain == "checkpoint":
			return _reject("active_run_is_device_only")
		if raw_domain not in PERMANENT_DOMAINS:
			return _reject("unknown_domain")
		if raw_domain in ECONOMY_DEPENDENCY_DOMAINS:
			return _reject("economy_requires_server_reconciliation")
	return _reject("no_trusted_snapshot_handler")


## A fake *server-verified* purchase fact is injected ONLY by this QA suite.
## A real backend must verify Google Play purchase token and product against
## Google's API before calling its own transactional ledger equivalent.
## `token_fingerprint` here is already a fake deduplication key, NEVER a
## raw token or an identifier accepted as authority from an Android client.
func simulate_server_verified_purchase(
	authenticated_uid: String, owner_uid: String, expected_revision: int,
	token_fingerprint: String, product_id: String,
	verified_purchase_state: String, granted_units: int
) -> Dictionary:
	var guard_issue: String = _guard(authenticated_uid, owner_uid)
	if not guard_issue.is_empty():
		return _reject(guard_issue)
	if not _safe_key(token_fingerprint) or not _safe_key(product_id):
		return _reject("invalid_purchase_identity")
	if _voided_purchases.has(token_fingerprint):
		return _reject("purchase_voided")
	# Check durable global dedup before CAS, so retry after a lost response is
	# idempotent even when the client still holds an old base revision.
	if _purchase_owners.has(token_fingerprint):
		if str(_purchase_owners[token_fingerprint]) != owner_uid:
			return _reject("purchase_bound_to_other_account")
		return _result(false, "duplicate_ignored", owner_uid, true)
	if verified_purchase_state != "PURCHASED":
		return _reject("not_purchased")
	if granted_units <= 0 or granted_units > MAX_SAFE_INTEGER:
		return _reject("invalid_grant_amount")
	var entry: Dictionary = _accounts[owner_uid]
	if bool(entry["reconciliation_required"]):
		return _reject("reconciliation_required")
	if expected_revision != int(entry["revision"]):
		return _reject("stale_revision")
	if int(entry["revision"]) >= MAX_SAFE_INTEGER:
		return _reject("revision_overflow")
	if int(entry["granted_units"]) > MAX_SAFE_INTEGER - granted_units:
		return _reject("currency_overflow")
	entry["revision"] = int(entry["revision"]) + 1
	entry["granted_units"] = int(entry["granted_units"]) + granted_units
	_accounts[owner_uid] = entry
	_purchase_owners[token_fingerprint] = owner_uid
	return _result(true, "verified_grant_applied", owner_uid)


## Real refunds/chargebacks must be reconciled with spent items/currency.
## This deliberately freezes future commits rather than guessing an amount
## to subtract and possibly generating negative/duplicated balances.
func simulate_server_verified_void(
	authenticated_uid: String, owner_uid: String,
	expected_revision: int, token_fingerprint: String
) -> Dictionary:
	var guard_issue: String = _guard(authenticated_uid, owner_uid)
	if not guard_issue.is_empty():
		return _reject(guard_issue)
	if not _purchase_owners.has(token_fingerprint):
		return _reject("unknown_purchase")
	if str(_purchase_owners[token_fingerprint]) != owner_uid:
		return _reject("purchase_bound_to_other_account")
	if _voided_purchases.has(token_fingerprint):
		return _result(false, "void_already_recorded", owner_uid, true)
	var entry: Dictionary = _accounts[owner_uid]
	if expected_revision != int(entry["revision"]):
		return _reject("stale_revision")
	if int(entry["revision"]) >= MAX_SAFE_INTEGER:
		return _reject("revision_overflow")
	entry["revision"] = int(entry["revision"]) + 1
	entry["reconciliation_required"] = true
	_accounts[owner_uid] = entry
	_voided_purchases[token_fingerprint] = true
	return _result(true, "manual_reconciliation_required", owner_uid)


## This models the server transaction's compare-and-swap only. The `true`
## value is a FAKE test fixture and may NEVER be supplied by a client as proof
## of trusted reconciliation. This method is NOT exported in a live game.
func simulate_server_snapshot_commit(
	authenticated_uid: String, owner_uid: String,
	expected_revision: int, proposed_domains: Array,
	synthetic_server_reconciled: bool
) -> Dictionary:
	var guard_issue: String = _guard(authenticated_uid, owner_uid)
	if not guard_issue.is_empty():
		return _reject(guard_issue)
	if not synthetic_server_reconciled:
		return _reject("trusted_reconciliation_missing")
	if not _has_exact_permanent_domains(proposed_domains):
		return _reject("incomplete_economy_boundary")
	var entry: Dictionary = _accounts[owner_uid]
	if bool(entry["reconciliation_required"]):
		return _reject("reconciliation_required")
	if expected_revision != int(entry["revision"]):
		return _reject("stale_revision")
	if int(entry["revision"]) >= MAX_SAFE_INTEGER:
		return _reject("revision_overflow")
	entry["revision"] = int(entry["revision"]) + 1
	_accounts[owner_uid] = entry
	return _result(true, "synthetic_server_snapshot_committed", owner_uid)


func _has_exact_permanent_domains(domain_ids: Array) -> bool:
	if domain_ids.size() != PERMANENT_DOMAINS.size():
		return false
	var seen: Dictionary = {}
	for raw_id in domain_ids:
		if typeof(raw_id) != TYPE_STRING or raw_id not in PERMANENT_DOMAINS:
			return false
		if seen.has(raw_id):
			return false
		seen[raw_id] = true
	return true


func _guard(authenticated_uid: String, owner_uid: String) -> String:
	if not _safe_key(authenticated_uid):
		return "unauthenticated"
	if not _safe_key(owner_uid) or not _accounts.has(owner_uid):
		return "unknown_account"
	if authenticated_uid != owner_uid:
		return "foreign_account"
	return ""


func _safe_key(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	for c in value:
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-.".contains(c):
			return false
	return true


func _result(applied: bool, reason: String, uid: String, idempotent: bool = false) -> Dictionary:
	var state: Dictionary = _accounts[uid]
	return {
		"applied": applied,
		"reason": reason,
		"idempotent": idempotent,
		"revision": int(state["revision"]),
		"cloud_write_allowed": false
	}


func _reject(reason: String) -> Dictionary:
	return {
		"applied": false,
		"reason": reason,
		"idempotent": false,
		"cloud_write_allowed": false
	}
