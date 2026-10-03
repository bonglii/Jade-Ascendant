import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import {
  PERMANENT_DOMAIN_IDS,
  inspectFullPermanentDraft,
  hashFullDraftForQa,
} from "../functions/src/snapshot/full_permanent_draft_v2.mjs";

const fixtureUrl = new URL(
  "../android_bridge/bridge/src/debug/assets/jade_account_bound_transport_device_record.json",
  import.meta.url,
);
const kotlinUrl = new URL(
  "../android_bridge/bridge/src/debug/java/com/yungdevstudio/jadeascendant/cloudbridge/JadeAccountBoundTransportDebugBridge.kt",
  import.meta.url,
);
const raw = readFileSync(fixtureUrl);
const record = JSON.parse(raw.toString("utf8"));
const kotlin = readFileSync(kotlinUrl, "utf8");


test("Android device fixture is valid under the current full permanent v2 contract", () => {
  assert.equal(record.ownerUid, "account_bound_android_debug_owner");
  assert.equal(record.draft.owner_uid, record.ownerUid);
  assert.equal(record.domain_count, PERMANENT_DOMAIN_IDS.length);
  assert.deepEqual(record.domain_ids, PERMANENT_DOMAIN_IDS);
  const inspected = inspectFullPermanentDraft(record.draft, record.ownerUid);
  assert.equal(inspected.valid, true, inspected.reason);
  assert.equal(hashFullDraftForQa(record.draft), record.digest);
});


test("Android device fixture preserves trusted-read evidence but never authorizes mutation or restore", () => {
  assert.equal(record.ok, true);
  assert.equal(record.code, "QA_ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY");
  assert.equal(record.transport_contract_version, 1);
  assert.equal(record.qaOnly, true);
  assert.equal(record.revision, 2);
  assert.equal(record.server_revision_verified, true);
  assert.equal(record.server_freshness_verified, true);
  assert.equal(record.explicit_restore_decision_required, true);
  assert.equal(record.restore_allowed, false);
  assert.equal(record.cloud_mutation_enabled, false);
  assert.equal(record.draft.domains.pavilion.celestial_jade, 144);
});


test("debug native bridge pins the exact fixture bytes by SHA-256", () => {
  const digest = createHash("sha256").update(raw).digest("hex");
  assert.match(kotlin, new RegExp(`ASSET_SHA256 = "${digest}"`));
  assert.match(kotlin, /requestQaAccountBoundTransport\(\)/);
});
