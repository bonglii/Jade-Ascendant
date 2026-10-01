/**
 * Gate 7 — IN-MEMORY RESTORE SIMULATOR ONLY. NEVER IMPORT INTO GAMEPLAY.
 * There is no disk I/O, SaveManager, Firebase account access, or actual restore.
 * This tests consent, CAS, local backup, crash/fault rollback invariants before
 * any separately reviewed real local-save implementation is considered.
 */
import {
  inspectFullPermanentDraft, hashFullDraftForQa, PERMANENT_DOMAIN_IDS,
} from "../snapshot/full_permanent_draft_v2.mjs";

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const HEX = /^[a-f0-9]{64}$/;
const ok = (code, fields = {}) => Object.freeze({ ok: true, code, ...fields });
const no = code => Object.freeze({ ok: false, code });
const goodUid = uid => typeof uid === "string" && UID.test(uid);
const validRev = revision => Number.isSafeInteger(revision) && revision > 0;

/**
 * Each instance owns an independent fake device's in-memory draft. "backup"
 * here means an ephemeral structuredClone, NOT a durable user:// backup.
 * A production implementation must use SaveManager atomic journal/backups.
 */
export class Gate7InMemoryRestoreSandbox {
  #ownerUid;
  #live;
  #prepared = null;
  #backup = null;
  #generation = 0;
  #phase = "IDLE";

  constructor(ownerUid, initialDraft) {
    if (!goodUid(ownerUid) || !inspectFullPermanentDraft(initialDraft, ownerUid).valid) {
      throw new TypeError("GATE7_INVALID_SYNTHETIC_LOCAL_STATE");
    }
    this.#ownerUid = ownerUid;
    this.#live = structuredClone(initialDraft);
  }

  get phase() { return this.#phase; }
  get hasInMemoryBackup() { return this.#backup !== null; }
  /** The complete state is visible ONLY to a synthetic test, never a UI/log. */
  inspectLocalForQa() { return structuredClone(this.#live); }

  /** Simulate local player progress changing between preview and restore. */
  mutateSyntheticLocalForQa(mutator) {
    if (this.#phase === "APPLIED_PENDING_CONFIRMATION") return no("BACKUP_NOT_CONFIRMED");
    if (typeof mutator !== "function") return no("INVALID_TEST_MUTATOR");
    const candidate = structuredClone(this.#live);
    mutator(candidate);
    if (!inspectFullPermanentDraft(candidate, this.#ownerUid).valid) return no("INVALID_LOCAL_CHANGE");
    this.#live = candidate;
    this.#generation += 1;
    // Keep the previous plan to prove the generation fence rejects it.
    return ok("QA_LOCAL_STATE_CHANGED");
  }

  prepare({ authenticatedUid, serverReadOnlyRecord, consent, online = true,
    pendingJournal = false, activeRun = false, checkpointPresent = false,
    cloudMutationEnabled = false } = {}) {
    this.#prepared = null;
    if (this.#phase === "APPLIED_PENDING_CONFIRMATION") return no("BACKUP_NOT_CONFIRMED");
    this.#phase = "IDLE";
    if (!goodUid(authenticatedUid) || authenticatedUid !== this.#ownerUid) return no("ACCOUNT_CHANGED");
    if (consent !== true) return no("EXPLICIT_CONSENT_REQUIRED");
    if (online !== true) return no("OFFLINE_NOT_SUPPORTED");
    if (pendingJournal || activeRun || checkpointPresent) return no("UNSAFE_LOCAL_SAVE_BOUNDARY");
    if (cloudMutationEnabled !== false) return no("CLOUD_MUTATION_MUST_REMAIN_DISABLED");
    if (!inspectFullPermanentDraft(this.#live, authenticatedUid).valid) {
      return no("LOCAL_BACKUP_NOT_VALIDATABLE");
    }
    const s = serverReadOnlyRecord;
    // qaOnly is NOT server authentication; records come solely from synthetic
    // fixtures in our tests. A real service must authenticate/supply the record.
    if (!s || s.qaOnly !== true || s.ownerUid !== authenticatedUid
      || !validRev(s.revision) || typeof s.digest !== "string" || !HEX.test(s.digest)) {
      return no("SERVER_RECORD_NOT_VERIFIED");
    }
    if (!s.draft || !inspectFullPermanentDraft(s.draft, authenticatedUid).valid) {
      return no("SERVER_SNAPSHOT_INVALID");
    }
    if (hashFullDraftForQa(s.draft) !== s.digest) return no("SERVER_DIGEST_MISMATCH");
    this.#prepared = Object.freeze({
      revision: s.revision, digest: s.digest, generation: this.#generation,
      localDigest: hashFullDraftForQa(this.#live),
      candidate: structuredClone(s.draft),
    });
    this.#phase = "PREPARED";
    return ok("SANDBOX_REVIEW_PREPARED", { revision: s.revision,
      domain_count: PERMANENT_DOMAIN_IDS.length, restore_allowed: false });
  }

  /**
   * Simulate progressive writes to a fake in-memory device and rollback.
   * Preconditions mirror the handoff a future real adapter must re-validate.
   * faultAfterDomains: 0..8 inject an exception after N staged domains; 9
   * injects AFTER promotion to test restoration from an earlier backup.
   */
  apply({ authenticatedUid, currentServerRevision, currentServerDigest,
    online = true, pendingJournal = false, activeRun = false,
    checkpointPresent = false, faultAfterDomains = null } = {}) {
    if (this.#phase !== "PREPARED" || !this.#prepared) return no("NO_PREPARED_RESTORE");
    if (!goodUid(authenticatedUid) || authenticatedUid !== this.#ownerUid) {
      this.#prepared = null;
      this.#phase = "IDLE";
      return no("ACCOUNT_CHANGED");
    }
    if (online !== true || pendingJournal || activeRun || checkpointPresent) {
      this.#prepared = null;
      this.#phase = "IDLE";
      return no("UNSAFE_RESTORE_BOUNDARY");
    }
    const p = this.#prepared;
    if (currentServerRevision !== p.revision || currentServerDigest !== p.digest) {
      this.#prepared = null;
      this.#phase = "IDLE";
      return no("SERVER_REVISION_CHANGED");
    }
    if (this.#generation !== p.generation
      || hashFullDraftForQa(this.#live) !== p.localDigest) {
      this.#prepared = null;
      this.#phase = "IDLE";
      return no("LOCAL_PROGRESS_CHANGED");
    }
    if (!inspectFullPermanentDraft(p.candidate, authenticatedUid).valid
      || hashFullDraftForQa(p.candidate) !== p.digest) {
      this.#prepared = null;
      this.#phase = "IDLE";
      return no("CANDIDATE_CHANGED");
    }
    const original = structuredClone(this.#live);
    const staging = structuredClone(this.#live);
    try {
      if (faultAfterDomains === 0) throw new Error("synthetic_failure");
      for (let index = 0; index < PERMANENT_DOMAIN_IDS.length; index++) {
        const id = PERMANENT_DOMAIN_IDS[index];
        staging.domains[id] = structuredClone(p.candidate.domains[id]);
        staging.domain_schema_versions[id] = p.candidate.domain_schema_versions[id];
        if (faultAfterDomains === index + 1) throw new Error("synthetic_failure");
      }
      staging.captured_at_unix = p.candidate.captured_at_unix;
      if (hashFullDraftForQa(staging) !== p.digest
        || !inspectFullPermanentDraft(staging, authenticatedUid).valid) {
        throw new Error("synthetic_integrity_failure");
      }
      this.#backup = original;
      this.#live = staging;
      this.#generation += 1;
      if (faultAfterDomains === 9) throw new Error("synthetic_post_promotion_failure");
      this.#phase = "APPLIED_PENDING_CONFIRMATION";
      this.#prepared = null;
      return ok("SANDBOX_RESTORE_STAGED", {
        revision: p.revision, domain_count: PERMANENT_DOMAIN_IDS.length,
        durable_backup: false, restore_allowed: false,
      });
    } catch {
      // Fail closed even for a simulated error *after* promotion.
      this.#live = original;
      this.#backup = null;
      this.#prepared = null;
      this.#phase = "IDLE";
      return no("SANDBOX_ROLLED_BACK");
    }
  }

  rollback({ authenticatedUid } = {}) {
    if (!goodUid(authenticatedUid) || authenticatedUid !== this.#ownerUid) return no("ACCOUNT_CHANGED");
    if (this.#phase !== "APPLIED_PENDING_CONFIRMATION" || !this.#backup) {
      return no("NO_IN_MEMORY_BACKUP");
    }
    this.#live = structuredClone(this.#backup);
    this.#backup = null;
    this.#phase = "IDLE";
    this.#generation += 1;
    return ok("SANDBOX_ROLLBACK_COMPLETE", { durable_backup: false });
  }

  confirm({ authenticatedUid } = {}) {
    if (!goodUid(authenticatedUid) || authenticatedUid !== this.#ownerUid) return no("ACCOUNT_CHANGED");
    if (this.#phase !== "APPLIED_PENDING_CONFIRMATION" || !this.#backup) {
      return no("NO_PENDING_RESTORE");
    }
    this.#backup = null;
    this.#phase = "IDLE";
    return ok("SANDBOX_CONFIRMED", { durable_backup: false });
  }
}
