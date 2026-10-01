extends RefCounted

## Gate 3: deterministic, LOCAL-ONLY integrity diagnostics for structural
## snapshot previews. SHA-256 detects accidental content changes; it is NOT
## authentication, purchase evidence, an HMAC, or a server revision.
## This object has no persistence, networking, or auto-execution paths.

const SnapshotContractScript = preload(
	"res://scripts/managers/cloud_save_snapshot_contract.gd"
)
const ManifestInspectorScript = preload(
	"res://scripts/managers/cloud_save_manifest_inspector.gd"
)

const INTEGRITY_FORMAT_VERSION: int = 1
const ALGORITHM: String = "SHA-256"
const ENCODING: String = "godot_4_7_sorted_json_v1"
const PROOF_KEYS = [
	"integrity_format_version", "digest_algorithm", "canonical_encoding",
	"snapshot_format_version", "owner_uid", "draft_revision",
	"snapshot_sha256", "domain_sha256"
]


## Produces an ephemeral digest of an already valid SIX-domain local preview.
## A successful result does NOT imply that any part of the economy is earned.
func build_local_proof(snapshot: Dictionary, expected_uid: String) -> Dictionary:
	var inspector: RefCounted = SnapshotContractScript.new() as RefCounted
	var report: Dictionary = inspector.call("inspect_draft", snapshot, expected_uid)
	if not bool(report.get("valid", false)):
		return _reject("invalid_snapshot")

	var versions: Dictionary = snapshot["domain_schema_versions"]
	var domains: Dictionary = snapshot["domains"]
	var domain_sha256: Dictionary = {}
	for domain_id in SnapshotContractScript.DOMAIN_IDS:
		domain_sha256[domain_id] = _digest(_domain_binding(
			str(domain_id), int(versions[domain_id]), domains[domain_id]
		))

	var proof: Dictionary = {
		"integrity_format_version": INTEGRITY_FORMAT_VERSION,
		"digest_algorithm": ALGORITHM,
		"canonical_encoding": ENCODING,
		"snapshot_format_version": SnapshotContractScript.SNAPSHOT_FORMAT_VERSION,
		"owner_uid": expected_uid,
		"draft_revision": int(snapshot["revision"]),
		"snapshot_sha256": _digest(snapshot),
		"domain_sha256": domain_sha256
	}
	return {
		"valid": true,
		"reason": "local_integrity_preview_only",
		"proof": proof,
		"server_verified": false,
		"economy_verified": false,
		"trusted_revision": false,
		"upload_allowed": false,
		"restore_allowed": false
	}


## Must revalidate the snapshot BEFORE hashing, including its exact domain
## and schema sets. A recomputed proof is still entirely client-controlled.
func inspect_local_proof(
	snapshot: Dictionary, expected_uid: String, proof: Dictionary
) -> Dictionary:
	var inspector: RefCounted = SnapshotContractScript.new() as RefCounted
	var report: Dictionary = inspector.call("inspect_draft", snapshot, expected_uid)
	if not bool(report.get("valid", false)):
		return _reject("invalid_snapshot")
	if not _exact_keys(proof, PROOF_KEYS):
		return _reject("invalid_proof_shape")
	if typeof(proof["integrity_format_version"]) != TYPE_INT or (
		int(proof["integrity_format_version"]) != INTEGRITY_FORMAT_VERSION
	):
		return _reject("unsupported_integrity_version")
	if typeof(proof["snapshot_format_version"]) != TYPE_INT or (
		int(proof["snapshot_format_version"]) != SnapshotContractScript.SNAPSHOT_FORMAT_VERSION
	):
		return _reject("unsupported_snapshot_version")
	if typeof(proof["digest_algorithm"]) != TYPE_STRING or (
		str(proof["digest_algorithm"]) != ALGORITHM
	):
		return _reject("unsupported_digest_algorithm")
	if typeof(proof["canonical_encoding"]) != TYPE_STRING or (
		str(proof["canonical_encoding"]) != ENCODING
	):
		return _reject("unsupported_encoding")
	if typeof(proof["owner_uid"]) != TYPE_STRING or (
		str(proof["owner_uid"]) != expected_uid
	):
		return _reject("proof_owner_mismatch")
	if typeof(proof["draft_revision"]) != TYPE_INT or (
		int(proof["draft_revision"]) != int(snapshot["revision"])
	):
		return _reject("draft_revision_mismatch")
	if not _hex256(proof["snapshot_sha256"]):
		return _reject("invalid_snapshot_digest")
	if not (proof["domain_sha256"] is Dictionary):
		return _reject("invalid_domain_digests")
	var domain_hashes: Dictionary = proof["domain_sha256"]
	if not _exact_keys(domain_hashes, SnapshotContractScript.DOMAIN_IDS):
		return _reject("invalid_domain_set")
	var versions: Dictionary = snapshot["domain_schema_versions"]
	var domains: Dictionary = snapshot["domains"]
	for domain_id in SnapshotContractScript.DOMAIN_IDS:
		if not _hex256(domain_hashes[domain_id]):
			return _reject("invalid_domain_digest")
		if str(domain_hashes[domain_id]) != _digest(_domain_binding(
			str(domain_id), int(versions[domain_id]), domains[domain_id]
		)):
			return _reject("domain_digest_mismatch")
	if str(proof["snapshot_sha256"]) != _digest(snapshot):
		return _reject("snapshot_digest_mismatch")
	return {
		"valid": true,
		"reason": "local_digest_match_not_authenticity",
		"server_verified": false,
		"economy_verified": false,
		"trusted_revision": false,
		"upload_allowed": false,
		"restore_allowed": false
	}


## Compares a local candidate to an untrusted read-only manifest. Agreement
## does NOT prove the manifest is fresh, server-signed, or restorable.
func inspect_manifest_alignment(
	snapshot: Dictionary, expected_uid: String,
	proof: Dictionary, manifest: Dictionary
) -> Dictionary:
	var local: Dictionary = inspect_local_proof(snapshot, expected_uid, proof)
	if not bool(local.get("valid", false)):
		return _reject("invalid_local_proof")
	var manifest_inspector: RefCounted = ManifestInspectorScript.new() as RefCounted
	var cloud_report: Dictionary = manifest_inspector.call(
		"inspect_document", manifest, expected_uid
	)
	if not bool(cloud_report.get("valid", false)):
		return _reject("invalid_manifest")
	var versions: Dictionary = manifest["domain_schema_versions"]
	if not _exact_keys(versions, SnapshotContractScript.DOMAIN_IDS):
		return _reject("manifest_domain_set_mismatch")
	var local_versions: Dictionary = snapshot["domain_schema_versions"]
	for domain_id in SnapshotContractScript.DOMAIN_IDS:
		if typeof(versions[domain_id]) != TYPE_INT or (
			int(versions[domain_id]) != int(local_versions[domain_id])
		):
			return _reject("manifest_schema_mismatch")
	if int(manifest["revision"]) != int(snapshot["revision"]):
		return _reject("manifest_revision_mismatch")
	if int(manifest["saved_at_unix"]) != int(snapshot["saved_at_unix"]):
		return _reject("manifest_timestamp_mismatch")
	return {
		"valid": true,
		"reason": "metadata_aligned_but_not_authorized",
		"server_verified": false,
		"server_freshness_verified": false,
		"economy_verified": false,
		"trusted_revision": false,
		"upload_allowed": false,
		"restore_allowed": false
	}


func _domain_binding(domain_id: String, schema_version: int, payload: Dictionary) -> Dictionary:
	return {
		"domain_id": domain_id,
		"schema_version": schema_version,
		"payload": payload
	}


func _digest(value: Variant) -> String:
	# sort_keys=true sorts nested dictionary keys; full_precision=true avoids
	# truncation of any accepted finite floats. The encoder is version-pinned
	# to Godot 4.7; a backend MUST NOT assume another runtime emits same bytes.
	return JSON.stringify(value, "", true, true).sha256_text()


func _hex256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var digest: String = value
	if digest.length() != 64:
		return false
	for character in digest:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _exact_keys(values: Dictionary, expected: Array) -> bool:
	if values.size() != expected.size():
		return false
	for key in values:
		if typeof(key) != TYPE_STRING or key not in expected:
			return false
	return true


func _reject(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"proof": {},
		"server_verified": false,
		"server_freshness_verified": false,
		"economy_verified": false,
		"trusted_revision": false,
		"upload_allowed": false,
		"restore_allowed": false
	}
