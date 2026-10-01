extends RefCounted

## Cloud Save Gate 1: manifest-only, no payload read, no write, no restore.
## Validates untrusted Firestore data before a preview is ever exposed to UI.
## The manifest is an INFORMATIONAL index, not proof that a usable backup exists.

const MANIFEST_VERSION: int = 1
const DOMAIN_SCHEMA_VERSION: int = 1
const MANIFEST_KEYS = [
	"manifest_version",
	"owner_uid",
	"revision",
	"saved_at_unix",
	"domain_schema_versions"
]
const SUPPORTED_DOMAIN_IDS = [
	"achievements",
	"daily_quests",
	"equipment",
	"inventory",
	"journey",
	"progression"
]


func is_safe_uid(uid: String) -> bool:
	if uid.length() < 1 or uid.length() > 128:
		return false
	var pattern: RegEx = RegEx.new()
	if pattern.compile("^[A-Za-z0-9_-]+$") != OK:
		return false
	return pattern.search(uid) != null


func inspect_document(document: Dictionary, expected_uid: String) -> Dictionary:
	var invalid: Dictionary = {
		"valid": false,
		"reason": "malformed",
		"domain_ids": [],
		"domain_count": 0,
		"revision": 0,
		"saved_at_unix": 0,
		"restore_available": false
	}
	if not is_safe_uid(expected_uid):
		return invalid
	if document.size() != MANIFEST_KEYS.size():
		return invalid
	for key: Variant in document.keys():
		if not (key is String) or key not in MANIFEST_KEYS:
			return invalid
	if not (document.get("owner_uid") is String):
		return invalid
	if str(document["owner_uid"]) != expected_uid:
		invalid["reason"] = "owner_mismatch"
		return invalid
	if typeof(document.get("manifest_version")) != TYPE_INT:
		return invalid
	if int(document["manifest_version"]) != MANIFEST_VERSION:
		invalid["reason"] = "unsupported_version"
		return invalid
	if typeof(document.get("revision")) != TYPE_INT:
		return invalid
	if int(document["revision"]) <= 0:
		return invalid
	if typeof(document.get("saved_at_unix")) != TYPE_INT:
		return invalid
	if int(document["saved_at_unix"]) < 0:
		return invalid
	var raw_versions: Variant = document.get("domain_schema_versions", null)
	if not (raw_versions is Dictionary):
		return invalid
	var versions: Dictionary = raw_versions as Dictionary
	if versions.is_empty() or versions.size() > SUPPORTED_DOMAIN_IDS.size():
		return invalid
	var names: Array[String] = []
	for raw_domain: Variant in versions.keys():
		if not (raw_domain is String):
			return invalid
		var domain_id: String = str(raw_domain)
		if domain_id not in SUPPORTED_DOMAIN_IDS:
			# Pavilion/purchases and active checkpoints are forbidden here.
			return invalid
		if typeof(versions[domain_id]) != TYPE_INT:
			return invalid
		if int(versions[domain_id]) != DOMAIN_SCHEMA_VERSION:
			invalid["reason"] = "unsupported_version"
			return invalid
		names.append(domain_id)
	names.sort()
	return {
		"valid": true,
		"reason": "manifest_only",
		"domain_ids": names,
		"domain_count": names.size(),
		"revision": int(document["revision"]),
		"saved_at_unix": int(document["saved_at_unix"]),
		"restore_available": false
	}
