import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const url = new URL("../functions/src/transport/account_bound_read_transport_qa.mjs", import.meta.url);
const source = readFileSync(url, "utf8");
const entrypoint = readFileSync(new URL("../functions/index.mjs", import.meta.url), "utf8");

test("transport remains emulator-only, read-only and unexported from production callable entrypoint", () => {
  assert.match(source, /assertGate5EmulatorOnly\(\)/);
  assert.doesNotMatch(source, /\btx\.(?:create|set|update|delete)\s*\(/);
  assert.doesNotMatch(source, /\.(?:create|set|update|delete)\s*\(/);
  assert.doesNotMatch(source, /from\s+["\']firebase-functions|require\(["\']firebase-functions|\bon(?:Call|Request)\s*\(/);
  assert.doesNotMatch(entrypoint, /account_bound_read_transport_qa|AccountBound|jadeCloudSaveSnapshot/i);
});

test("transport source cannot accept client owner/revision/digest as API parameters", () => {
  assert.match(source, /emptyClientPayload\(request\.data\)/);
  assert.match(source, /const authenticatedUid = deriveGoogleLinkedUid\(request\)/);
  assert.match(source, /const currentRevision = head\.revision/);
  assert.doesNotMatch(source, /expectedRevision|ownerUid\s*[,}]/);
  assert.match(source, /CURRENT_SNAPSHOT_NOT_FOUND/);
});

test("transport response remains explicitly non-mutating and restore-decision-gated", () => {
  assert.match(source, /explicit_restore_decision_required:\s*true/);
  assert.match(source, /restore_allowed:\s*false/);
  assert.match(source, /cloud_mutation_enabled:\s*false/);
});
