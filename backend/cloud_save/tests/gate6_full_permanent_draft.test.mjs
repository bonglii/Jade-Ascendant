import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import {
  inspectFullPermanentDraft,
  hashFullDraftForQa,
  PERMANENT_DOMAIN_IDS,
  PERMANENT_DOMAIN_REQUIRED,
  PERMANENT_DOMAIN_ALLOWED,
  FULL_DRAFT_VERSION,
} from "../functions/src/snapshot/full_permanent_draft_v2.mjs";

const root = fileURLToPath(new URL("../../../", import.meta.url));
const REPO = p => readFileSync(resolve(root, p), "utf8");
const UID = "synthetic_qa_account";
const clone = x => structuredClone(x);

export function makeGate6EightDomainFixture(uid = UID) {
  const domains = {
    achievements: { version: 1, progress: {}, unlocked: [], claimed: [] },
    daily_quests: { version: 1, date_key: "", progress: {}, completed: [], claimed: [] },
    equipment: { version: 1, equipped_item_ids: {
      armament: "", robe: "", bracer: "", boots: "", pendant: "",
    } },
    inventory: { version: 1, item_counts: {} },
    journey: { version: 1, selected_chapter_id: 1, selected_stage_id: 1,
      active_run_chapter_id: 0, active_run_stage_id: 0,
      unlocked_stage_keys: [], cleared_stage_keys: [] },
    progression: { version: 1, spirit_stone: 0, vitality_level: 0, sword_power_level: 0, swift_qi_level: 0 },
    pavilion: { version: 1, meditation_date: "", cosmetic_id: "plain", owned_cosmetics: ["plain"],
      celestial_jade: 0, pavilion_seals: 0, pity_rare_plus: 0,
      pity_epic_plus: 0, pity_legendary: 0, processed_grant_ids: [] },
    idle_cultivation: { version: 1, last_claim_unix: 1000, last_observed_unix: 1000,
      lifetime_claim_seconds: 0, shard_progress_units: 0,
      processed_rewarded_grant_ids: [] },
  };
  return {
    draft_snapshot_version: FULL_DRAFT_VERSION,
    owner_uid: uid,
    captured_at_unix: 1000,
    domain_schema_versions: Object.fromEntries(PERMANENT_DOMAIN_IDS.map(id => [id, 1])),
    domains,
  };
}
const inspect = x => inspectFullPermanentDraft(x, UID);
const deny = (d, code) => assert.deepEqual(inspect(d), {
  valid: false, reason: code, domain_count: 0,
  economy_verified: false, server_revision_verified: false,
  upload_allowed: false, restore_allowed: false,
});

// The actual Godot registry is authoritative for names, required fields and scopes.
test("Gate 6 source audit: exact eight SaveManager permanent domains and v1 required keys", () => {
  const source = REPO("scripts/managers/save_manager.gd");
  const entries = [...source.matchAll(/\n\t"([a-z_]+)": \{([\s\S]*?)\n\t\},?/g)]
    .filter(m => m[2].includes('"schema_version":'));
  assert.equal(entries.length, 9);
  const permanent = entries.filter(m => m[2].includes("SCOPE_PERMANENT"));
  assert.equal(permanent.length, 8);
  assert.deepEqual(permanent.map(m => m[1]).sort(), PERMANENT_DOMAIN_IDS);
  const active = entries.filter(m => m[2].includes("SCOPE_ACTIVE_RUN"));
  assert.deepEqual(active.map(m => m[1]), ["checkpoint"]);
  for (const m of permanent) {
    assert.match(m[2], /"schema_version": 1/);
    const keys = m[2].match(/"required_keys": \[([\s\S]*?)\]/);
    assert.ok(keys, `Missing real registry required keys for ${m[1]}`);
    assert.deepEqual([...keys[1].matchAll(/"([^"]+)"/g)].map(x => x[1]), PERMANENT_DOMAIN_REQUIRED[m[1]]);
    assert.ok(PERMANENT_DOMAIN_REQUIRED[m[1]].every(k => PERMANENT_DOMAIN_ALLOWED[m[1]].includes(k)));
  }
});

test("Gate 6 source audit: Pavilion and Idle source fields match the validated v1 model", () => {
  const pavilion = REPO("scripts/managers/pavilion_manager.gd");
  const block = pavilion.match(/const DEFAULT_STATE: Dictionary = \{([\s\S]*?)\n\}/);
  assert.ok(block);
  const fields = [...block[1].matchAll(/\n\t"([a-z_]+)":/g)].map(m => m[1]).sort();
  assert.deepEqual(fields, [...PERMANENT_DOMAIN_ALLOWED.pavilion].sort());
  const idle = REPO("scripts/managers/idle_cultivation_manager.gd");
  const idleBody = idle.match(/func _default_state\(now_unix: int\) -> Dictionary:\s*\n\treturn \{([\s\S]*?)\n\t\}/);
  assert.ok(idleBody);
  const idleKeys = [...idleBody[1].matchAll(/\n\t\t"([a-z_]+)":/g)].map(m => m[1]).sort();
  assert.deepEqual(idleKeys, [...PERMANENT_DOMAIN_ALLOWED.idle_cultivation].sort());
});

test("Gate 6 eight-domain draft structurally valid yet NEVER authorizes Cloud Save", () => {
  assert.deepEqual(inspect(makeGate6EightDomainFixture()), {
    valid: true, reason: "STRUCTURAL_PREVIEW_ONLY", domain_count: 8,
    economy_verified: false, server_revision_verified: false,
    upload_allowed: false, restore_allowed: false,
  });
});

test("Gate 6 missing Pavilion/Idle and checkpoint injection fail closed", () => {
  for (const id of ["pavilion", "idle_cultivation"]) {
    const d = makeGate6EightDomainFixture(); delete d.domains[id];
    deny(d, "INCOMPLETE_PERMANENT_DOMAINS");
  }
  const d = makeGate6EightDomainFixture(); d.domains.checkpoint = { wave: 999 };
  deny(d, "INCOMPLETE_PERMANENT_DOMAINS");
});

test("Gate 6 rejects six-domain v1 draft, owner spoofing and arbitrary revision field", () => {
  const d = makeGate6EightDomainFixture(); d.draft_snapshot_version = 1;
  deny(d, "INVALID_DRAFT_VERSION");
  const cross = makeGate6EightDomainFixture("different_user");
  deny(cross, "OWNER_MISMATCH");
  const fake = makeGate6EightDomainFixture(); fake.revision = 900000;
  deny(fake, "INVALID_ENVELOPE");
});

test("Gate 6 rejects unknown schema, missing required fields, and unknown Pavilion fields", () => {
  const wrong = makeGate6EightDomainFixture(); wrong.domain_schema_versions.idle_cultivation = 3;
  deny(wrong, "SCHEMA_VERSION_MISMATCH");
  const missing = makeGate6EightDomainFixture(); delete missing.domains.pavilion.owned_cosmetics;
  deny(missing, "MISSING_DOMAIN_FIELD");
  const malicious = makeGate6EightDomainFixture(); malicious.domains.pavilion.purchase_token = "forged";
  deny(malicious, "UNEXPECTED_DOMAIN_FIELD");
});

test("Gate 6 rejects negative/inflated numeric shapes and non-finite numbers", () => {
  const negatives = [
    ["pavilion", "celestial_jade", -1],
    ["pavilion", "pity_legendary", 50],
    ["progression", "spirit_stone", "999"],
    ["idle_cultivation", "shard_progress_units", -5],
    ["idle_cultivation", "last_observed_unix", 999],
  ];
  for (const [domain, field, value] of negatives) {
    const d = makeGate6EightDomainFixture(); d.domains[domain][field] = value;
    deny(d, "INVALID_DOMAIN_FIELDS");
  }
  const nan = makeGate6EightDomainFixture(); nan.domains.pavilion.celestial_jade = Number.POSITIVE_INFINITY;
  deny(nan, "UNSAFE_JSON_STRUCTURE");
});

test("Gate 6 rejects active-run leakage even with eight domains present", () => {
  const d = makeGate6EightDomainFixture(); d.domains.journey.active_run_stage_id = 3;
  deny(d, "INVALID_DOMAIN_FIELDS");
  const fromRun = makeGate6EightDomainFixture(); fromRun.domains.equipment.active_run_loadout_snapshot = {};
  deny(fromRun, "UNEXPECTED_DOMAIN_FIELD");
});

test("Gate 6 rejects forged equipment counts, duplicate slots and ascension without inventory", () => {
  const d = makeGate6EightDomainFixture(); d.domains.equipment.equipped_item_ids.armament = "test_sword";
  deny(d, "EQUIPMENT_INVENTORY_MISMATCH");
  d.domains.inventory.item_counts.test_sword = 1;
  assert.equal(inspect(d).valid, true);
  d.domains.equipment.equipped_item_ids.robe = "test_sword";
  deny(d, "EQUIPMENT_INVENTORY_MISMATCH");
});

test("Gate 6 rejects unsafe prototype keys, getters, cycles and oversize", () => {
  const proto = makeGate6EightDomainFixture();
  Object.defineProperty(proto.domains.inventory.item_counts, "__proto__", { value: 1, enumerable: true });
  deny(proto, "UNSAFE_JSON_STRUCTURE");
  const getter = makeGate6EightDomainFixture();
  Object.defineProperty(getter.domains.pavilion, "celestial_jade", { get() { throw Error("MUST_NOT_READ"); }, enumerable: true });
  deny(getter, "UNSAFE_JSON_STRUCTURE");
  const cyclic = makeGate6EightDomainFixture(); cyclic.domains.inventory.item_counts.loop = cyclic;
  deny(cyclic, "UNSAFE_JSON_STRUCTURE");
  const large = makeGate6EightDomainFixture(); large.domains.inventory.item_counts.fill = "x".repeat(525000);
  deny(large, "UNSAFE_JSON_STRUCTURE");
});

test("Gate 6 bounds total valid JSON byte size before inspecting domain semantics", () => {
  const d = makeGate6EightDomainFixture();
  d.domains.pavilion.owned_cosmetics = ["plain", ...Array.from({ length: 1200 }, (_, i) =>
    `cosmetic_${i}_` + "a".repeat(230))];
  d.domains.pavilion.processed_grant_ids = Array.from({ length: 1000 }, (_, i) =>
    `grant_${i}_` + "b".repeat(230));
  deny(d, "DRAFT_TOO_LARGE");
});

test("Gate 6 rejects replay of locally-claimed premium flags as authority", () => {
  const d = makeGate6EightDomainFixture();
  d.domains.pavilion.celestial_jade = 100000;
  d.domains.pavilion.processed_grant_ids = ["local_claim_fixture" ];
  const r = inspect(d);
  assert.equal(r.valid, true); // shape only, NOT verified balance or grants
  assert.equal(r.economy_verified, false);
  assert.equal(r.upload_allowed, false);
  assert.equal(r.server_revision_verified, false);
});

test("Gate 6 never serializes legacy IAP grant IDs containing a raw Play token", () => {
  const d = makeGate6EightDomainFixture();
  d.domains.pavilion.processed_grant_ids = ["iap:jade_pouch_100:FAKE_PRIVATE_TOKEN_DO_NOT_UPLOAD"];
  deny(d, "INVALID_DOMAIN_FIELDS");
  assert.ok(!JSON.stringify(inspect(d)).includes("FAKE_PRIVATE_TOKEN"));
});

test("Gate 6 QA digest is order-insensitive for object keys, NEVER an authenticity proof", () => {
  const a = makeGate6EightDomainFixture(); const b = clone(a);
  b.domains.pavilion = Object.fromEntries(Object.entries(a.domains.pavilion).reverse());
  assert.equal(hashFullDraftForQa(a), hashFullDraftForQa(b));
  b.domains.pavilion.celestial_jade += 1;
  assert.notEqual(hashFullDraftForQa(a), hashFullDraftForQa(b));
});

test("Gate 6 cannot become a deployed callable or alter actual six-domain preview", () => {
  const entry = REPO("backend/cloud_save/functions/index.mjs");
  assert.match(entry, /export const \{ jadeCloudSaveCapabilities \}/);
  assert.doesNotMatch(entry, /gate6|full_permanent|snapshot/);
  const gate = JSON.parse(REPO("backend/cloud_save/predeploy_gate.json"));
  assert.equal(gate.state, "PRE_DEPLOYMENT_ONLY");
  assert.equal(gate.deployment_approved, false);
  assert.equal(gate.cloud_mutations_approved, false);
  const existing = REPO("scripts/managers/cloud_save_snapshot_contract.gd");
  assert.match(existing, /SNAPSHOT_FORMAT_VERSION: int = 1/);
  assert.match(existing, /Pavilion, idle_cultivation and checkpoint MUST NOT enter a draft snapshot/);
  const six = existing.match(/const DOMAIN_IDS = \[([\s\S]*?)\]/);
  assert.ok(six);
  assert.deepEqual([...six[1].matchAll(/"([a-z_]+)"/g)].map(m => m[1]), [
    "achievements", "daily_quests", "equipment", "inventory", "journey", "progression",
  ]);
});
