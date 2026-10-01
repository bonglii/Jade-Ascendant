import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { Gate7InMemoryRestoreSandbox } from "../functions/src/restore/reversible_restore_sandbox.mjs";
import { makeGate7SyntheticDraft as draft, makeGate7SyntheticReadOnlyRecord as record } from "./gate7_fixture.mjs";
import { hashFullDraftForQa, PERMANENT_DOMAIN_IDS } from "../functions/src/snapshot/full_permanent_draft_v2.mjs";

const UID = "gate7_synthetic_owner";
const REPO_ROOT = fileURLToPath(new URL("../../../", import.meta.url));
const source = p => readFileSync(resolve(REPO_ROOT, p), "utf8");
const sandbox = (jade = 10) => new Gate7InMemoryRestoreSandbox(UID, draft(UID, jade));
const preview = (s, r = record(UID, 1, 20), extra = {}) => s.prepare({
  authenticatedUid: UID, consent: true, serverReadOnlyRecord: r, ...extra,
});
const apply = (s, r = record(UID, 1, 20), extra = {}) => s.apply({
  authenticatedUid: UID, currentServerRevision: r.revision,
  currentServerDigest: r.digest, ...extra,
});

test("Gate 7 exact source boundary: 8 permanent domains; checkpoint always excluded", () => {
  const s = source("scripts/managers/save_manager.gd");
  const domains = [...s.matchAll(/\n\t"([a-z_]+)": \{([\s\S]*?)\n\t\},?/g)]
    .filter(m => m[2].includes('"schema_version":'));
  const permanent = domains.filter(m => m[2].includes("SCOPE_PERMANENT"));
  assert.deepEqual(permanent.map(m => m[1]).sort(), PERMANENT_DOMAIN_IDS);
  assert.deepEqual(domains.filter(m => m[2].includes("SCOPE_ACTIVE_RUN")).map(m => m[1]), ["checkpoint"]);
});

test("Gate 7 review alone never changes a device or authorizes a real restore", () => {
  const s = sandbox();
  const before = s.inspectLocalForQa();
  assert.deepEqual(preview(s), { ok: true, code: "SANDBOX_REVIEW_PREPARED",
    revision: 1, domain_count: 8, restore_allowed: false });
  assert.equal(s.phase, "PREPARED");
  assert.deepEqual(s.inspectLocalForQa(), before);
  assert.equal(s.hasInMemoryBackup, false);
});

test("Gate 7 explicit opt-in required; no background, offline, or automatic restore", () => {
  for (const flag of [false, undefined, "yes"]) {
    const s = sandbox();
    assert.equal(s.prepare({ authenticatedUid: UID, consent: flag,
      serverReadOnlyRecord: record(UID, 1, 20) }).code, "EXPLICIT_CONSENT_REQUIRED");
    assert.deepEqual(s.inspectLocalForQa(), draft(UID, 10));
  }
  assert.equal(preview(sandbox(), record(UID, 1, 20), { online: false }).code, "OFFLINE_NOT_SUPPORTED");
});

test("Gate 7 refuses active run, active checkpoint, save journal and mutation toggles", () => {
  for (const k of ["pendingJournal", "activeRun", "checkpointPresent"]) {
    const s = sandbox();
    assert.equal(preview(s, record(UID, 1, 20), { [k]: true }).code, "UNSAFE_LOCAL_SAVE_BOUNDARY");
  }
  assert.equal(preview(sandbox(), record(UID, 1, 20),
    { cloudMutationEnabled: true }).code, "CLOUD_MUTATION_MUST_REMAIN_DISABLED");
});

test("Gate 7 refuses cross-account and fake remote revision or metadata", () => {
  const s = sandbox();
  assert.equal(preview(s, record(UID, 1, 20), { authenticatedUid: "foreign_user" }).code,
    "ACCOUNT_CHANGED");
  for (const change of [
    { revision: 0 }, { qaOnly: false }, { ownerUid: "foreign_user" },
    { digest: "arbitrary" }, { ownerUid: null },
  ]) {
    const r = { ...record(UID, 1, 20), ...change };
    assert.equal(preview(s, r).code, "SERVER_RECORD_NOT_VERIFIED");
  }
});

test("Gate 7 refuses tampered/unbound, truncated, six-domain or checkpoint-leaking remote", () => {
  const s = sandbox();
  const tamper = record(UID, 1, 20);
  tamper.draft.domains.pavilion.celestial_jade += 999999;
  assert.equal(preview(s, tamper).code, "SERVER_DIGEST_MISMATCH");
  const missing = record(UID, 1, 20);
  delete missing.draft.domains.idle_cultivation;
  assert.equal(preview(s, missing).code, "SERVER_SNAPSHOT_INVALID");
  const checkpoint = record(UID, 1, 20);
  checkpoint.draft.domains.checkpoint = { wave: 50 };
  assert.equal(preview(s, checkpoint).code, "SERVER_SNAPSHOT_INVALID");
  const raw = record(UID, 1, 20);
  raw.draft.domains.pavilion.processed_grant_ids = ["iap:jade_pouch_100:PRIVATE_SYNTHETIC_TOKEN"];
  assert.equal(preview(s, raw).code, "SERVER_SNAPSHOT_INVALID");
});

test("Gate 7 valid synthetic restore stages all 8 domains and keeps an in-memory rollback", () => {
  const s = sandbox(10), r = record(UID, 2, 40);
  assert.equal(preview(s, r).ok, true);
  assert.deepEqual(apply(s, r), { ok: true, code: "SANDBOX_RESTORE_STAGED",
    revision: 2, domain_count: 8, durable_backup: false, restore_allowed: false });
  assert.equal(s.inspectLocalForQa().domains.pavilion.celestial_jade, 40);
  assert.deepEqual(s.inspectLocalForQa(), r.draft);
  assert.equal(s.hasInMemoryBackup, true);
  assert.equal(s.phase, "APPLIED_PENDING_CONFIRMATION");
});

test("Gate 7 rejects device account change between review and promotion", () => {
  const s = sandbox(), r = record(UID, 1, 20);
  preview(s, r);
  assert.equal(apply(s, r, { authenticatedUid: "foreign_user" }).code, "ACCOUNT_CHANGED");
  assert.equal(s.phase, "IDLE");
  assert.equal(s.inspectLocalForQa().domains.pavilion.celestial_jade, 10);
});

test("Gate 7 enforces fresh server revision and digest CAS at restore time", () => {
  for (const option of [{ currentServerRevision: 2 }, { currentServerDigest: "a".repeat(64) }]) {
    const s = sandbox(), r = record(UID, 1, 20);
    preview(s, r);
    assert.equal(apply(s, r, option).code, "SERVER_REVISION_CHANGED");
    assert.equal(s.inspectLocalForQa().domains.pavilion.celestial_jade, 10);
  }
});

test("Gate 7 refuses a local gameplay change after review rather than overwriting it", () => {
  const s = sandbox(), r = record(UID, 1, 20);
  preview(s, r);
  assert.equal(s.mutateSyntheticLocalForQa(d => { d.domains.progression.spirit_stone += 99; }).ok, true);
  assert.equal(apply(s, r).code, "LOCAL_PROGRESS_CHANGED");
  assert.equal(s.inspectLocalForQa().domains.progression.spirit_stone, 99);
});

test("Gate 7 rejects expired local guards after review", () => {
  for (const opts of [{ online: false }, { activeRun: true },
    { pendingJournal: true }, { checkpointPresent: true }]) {
    const s = sandbox(), r = record(UID, 1, 20);
    preview(s, r);
    assert.equal(apply(s, r, opts).code, "UNSAFE_RESTORE_BOUNDARY");
    assert.equal(s.inspectLocalForQa().domains.pavilion.celestial_jade, 10);
  }
});

test("Gate 7 all 10 injected partial/promoted failures rollback the ENTIRE device state", () => {
  for (let faultAfterDomains = 0; faultAfterDomains <= 9; faultAfterDomains++) {
    const s = sandbox(10), r = record(UID, 1, 20);
    const pristine = s.inspectLocalForQa();
    preview(s, r);
    assert.equal(apply(s, r, { faultAfterDomains }).code, "SANDBOX_ROLLED_BACK");
    assert.deepEqual(s.inspectLocalForQa(), pristine);
    assert.equal(s.phase, "IDLE");
    assert.equal(s.hasInMemoryBackup, false);
  }
});

test("Gate 7 manual rollback after staged restore exactly restores the original 8 domains", () => {
  const s = sandbox(15), r = record(UID, 1, 25);
  const initial = s.inspectLocalForQa();
  preview(s, r);
  apply(s, r);
  assert.equal(s.rollback({ authenticatedUid: "foreign_user" }).code, "ACCOUNT_CHANGED");
  assert.equal(s.inspectLocalForQa().domains.pavilion.celestial_jade, 25);
  assert.deepEqual(s.rollback({ authenticatedUid: UID }), {
    ok: true, code: "SANDBOX_ROLLBACK_COMPLETE", durable_backup: false });
  assert.deepEqual(s.inspectLocalForQa(), initial);
  assert.equal(s.hasInMemoryBackup, false);
});

test("Gate 7 cannot discard backup before explicit same-account confirmation", () => {
  const s = sandbox(), r = record(UID, 1, 20);
  assert.equal(s.confirm({ authenticatedUid: UID }).code, "NO_PENDING_RESTORE");
  preview(s, r);
  apply(s, r);
  assert.equal(s.confirm({ authenticatedUid: "other" }).code, "ACCOUNT_CHANGED");
  assert.equal(s.hasInMemoryBackup, true);
  assert.equal(s.confirm({ authenticatedUid: UID }).code, "SANDBOX_CONFIRMED");
  assert.equal(s.hasInMemoryBackup, false);
  assert.equal(s.rollback({ authenticatedUid: UID }).code, "NO_IN_MEMORY_BACKUP");
});

test("Gate 7 rollback state is never lost to a second preview/commit", () => {
  const s = sandbox(), r = record(UID, 1, 20);
  preview(s, r); apply(s, r);
  assert.equal(preview(s, record(UID, 2, 30)).code, "BACKUP_NOT_CONFIRMED");
  assert.equal(apply(s, r).code, "NO_PREPARED_RESTORE");
  assert.equal(s.mutateSyntheticLocalForQa(d => { d.domains.pavilion.celestial_jade = 0; }).code,
    "BACKUP_NOT_CONFIRMED");
  assert.equal(s.hasInMemoryBackup, true);
});

test("Gate 7 staged candidate detached from mutable caller payload and fail-closed flags", () => {
  const s = sandbox(), r = record(UID, 1, 20);
  preview(s, r);
  r.draft.domains.pavilion.celestial_jade = 99999;
  assert.equal(apply(s, { ...r, digest: hashFullDraftForQa(draft(UID, 20)) }).code, "SANDBOX_RESTORE_STAGED");
  assert.equal(s.inspectLocalForQa().domains.pavilion.celestial_jade, 20);
});

test("Gate 7 refuses legacy local saves that still embed raw Play purchase tokens", () => {
  const local = draft(UID, 10);
  local.domains.pavilion.processed_grant_ids = ["iap:jade_pouch_100:SYNTHETIC_SECRET_NEVER_UPLOADED"];
  assert.throws(() => new Gate7InMemoryRestoreSandbox(UID, local),
    /GATE7_INVALID_SYNTHETIC_LOCAL_STATE/);
});

test("Gate 7 source imports remain OFF deployed Functions and local save runtime", () => {
  const entry = source("backend/cloud_save/functions/index.mjs");
  const gate = JSON.parse(source("backend/cloud_save/predeploy_gate.json"));
  assert.match(entry, /export const \{ jadeCloudSaveCapabilities \}/);
  assert.doesNotMatch(entry, /gate7|reversible_restore|firestore_gate7|restoreSandbox/i);
  assert.equal(gate.state, "PRE_DEPLOYMENT_ONLY");
  assert.equal(gate.deployment_approved, false);
  assert.equal(gate.cloud_mutations_approved, false);
  const provider = source("scripts/managers/cloud_save_snapshot_contract.gd");
  assert.match(provider, /Pavilion, idle_cultivation and checkpoint MUST NOT enter a draft snapshot/);
});
