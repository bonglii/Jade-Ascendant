import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve, join } from "node:path";

import {
  PERMANENT_DOMAIN_IDS, inspectFullPermanentDraft, hashFullDraftForQa,
} from "../functions/src/snapshot/full_permanent_draft_v2.mjs";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = p => readFileSync(resolve(repo, p), "utf8");
const contract = read("scripts/managers/cloud_full_permanent_snapshot_contract.gd");
const stager = read("scripts/managers/cloud_transfer_candidate_stager_qa.gd");
const runner = read("tests/controlled_transfer_candidate_qa.gd");
const restore = read("scripts/managers/cloud_registered_path_restore_qa.gd");
const project = read("project.godot");
const workflow = read(".github/workflows/cloud-controlled-transfer-qa.yml");

const EXPECTED_CROSS_LANGUAGE_DIGEST = "9700dd8cc68cc0f02c05f7f365976b8891f3b2c158a37abdff58d542de8c804e";

function crossLanguageDraft() {
  return {
    draft_snapshot_version: 2,
    owner_uid: "controlled_transfer_disposable_owner",
    captured_at_unix: 1700001234,
    domain_schema_versions: Object.fromEntries(PERMANENT_DOMAIN_IDS.map(id => [id, 1])),
    domains: {
      achievements: { version: 1, progress: { controlled_transfer: 5 }, unlocked: [], claimed: [] },
      daily_quests: { version: 1, date_key: "2099-03-03", progress: {}, completed: [], claimed: [] },
      equipment: { version: 1, equipped_item_ids: {
        armament: "", robe: "", bracer: "", boots: "", pendant: "",
      }, ascension_stars: {} },
      idle_cultivation: { version: 1, last_claim_unix: 300, last_observed_unix: 350,
        lifetime_claim_seconds: 50, shard_progress_units: 9, processed_rewarded_grant_ids: [] },
      inventory: { version: 1, item_counts: {} },
      journey: { version: 1, selected_chapter_id: 1, selected_stage_id: 1,
        active_run_chapter_id: 0, active_run_stage_id: 0, unlocked_stage_keys: [], cleared_stage_keys: [] },
      pavilion: { version: 1, meditation_date: "", cosmetic_id: "plain", owned_cosmetics: ["plain"],
        celestial_jade: 88, pavilion_seals: 0, processed_grant_ids: [] },
      progression: { version: 1, spirit_stone: 1234, vitality_level: 2,
        sword_power_level: 3, swift_qi_level: 1 },
    },
  };
}

function filesRecursive(root, suffix) {
  const result = [];
  for (const item of readdirSync(root, { withFileTypes: true })) {
    const p = join(root, item.name);
    if (item.isDirectory()) result.push(...filesRecursive(p, suffix));
    else if (item.isFile() && p.endsWith(suffix)) result.push(p);
  }
  return result;
}

test("backend v2 fixture pins the cross-language canonical digest", () => {
  const draft = crossLanguageDraft();
  assert.deepEqual(PERMANENT_DOMAIN_IDS, [
    "achievements", "daily_quests", "equipment", "idle_cultivation",
    "inventory", "journey", "pavilion", "progression",
  ]);
  assert.equal(inspectFullPermanentDraft(draft, draft.owner_uid).valid, true);
  assert.equal(hashFullDraftForQa(draft), EXPECTED_CROSS_LANGUAGE_DIGEST);
  assert.match(runner, new RegExp(EXPECTED_CROSS_LANGUAGE_DIGEST));
});

test("controlled transfer staging is disconnected from production runtime", () => {
  assert.doesNotMatch(project, /cloud_transfer_candidate_stager_qa|cloud_full_permanent_snapshot_contract/);
  const refs = filesRecursive(resolve(repo, "scripts"), ".gd")
    .filter(p => !p.endsWith("cloud_transfer_candidate_stager_qa.gd"))
    .filter(p => !p.endsWith("cloud_full_permanent_snapshot_contract.gd"))
    .filter(p => /cloud_transfer_candidate_stager_qa|stage_reviewed_snapshot_for_qa/.test(readFileSync(p, "utf8")));
  assert.deepEqual(refs, []);
  assert.match(stager, /OS\.has_feature\("editor"\)/);
  assert.match(stager, /GITHUB_ACTIONS/);
  assert.match(stager, /JADE_CONTROLLED_TRANSFER_TEST_ONLY/);
  assert.match(stager, /DISPOSABLE_RUNNER_ONLY/);
});

test("full permanent contract is exact eight-domain v2 and rejects unsafe payloads", () => {
  for (const id of [
    "achievements", "daily_quests", "equipment", "idle_cultivation",
    "inventory", "journey", "pavilion", "progression",
  ]) assert.match(contract, new RegExp(`"${id}"`));
  assert.match(contract, /DRAFT_SNAPSHOT_VERSION:\s*int\s*=\s*2/);
  assert.match(contract, /DOMAIN_COUNT:\s*int\s*=\s*8/);
  assert.match(contract, /MAX_SNAPSHOT_BYTES:\s*int\s*=\s*524288/);
  assert.match(contract, /SaveManager\.get_save_domain_ids_for_scope/);
  assert.match(contract, /processed_grant_ids/);
  assert.match(contract, /begins_with\("iap:"\)/);
  assert.match(contract, /InventoryManager\.is_known_item/);
  assert.match(contract, /EquipmentManager\.has_item_definition/);
  assert.match(contract, /HashingContext\.HASH_SHA256/);
  const validationBlock = contract.slice(
    contract.indexOf("func _validate_domain_fields"),
    contract.indexOf("func _validate_pavilion"),
  );
  assert.match(validationBlock, /"progression":[\s\S]*?return true\s*\n\t\t"journey":/);
  assert.match(validationBlock, /"journey":[\s\S]*?return true\s*\n\t\t"achievements":/);
  assert.doesNotMatch(contract, /Firebase|firestore|https?:\/\//i);
  assert.doesNotMatch(contract, /SaveManager\.(?:write_save_data|write_save_batch|recover_save_from_backup)\s*\(/);
});

test("candidate stager writes only isolated QA files and cannot self-authorize restore", () => {
  assert.match(stager, /user:\/\/jade_controlled_transfer_qa\//);
  assert.match(stager, /QA_LATEST_SNAPSHOT_REVIEWED/);
  assert.match(stager, /SNAPSHOT_DIGEST_MISMATCH/);
  assert.match(stager, /explicit_decision_required/);
  assert.match(stager, /restore_allowed/);
  assert.match(stager, /cloud_mutation_enabled/);
  assert.match(stager, /store_var/);
  assert.match(stager, /flush\(\)/);
  assert.match(stager, /get_var\(false\)/);
  assert.match(stager, /FileAccess\.get_sha256/);
  assert.match(stager, /pending_/);
  assert.match(stager, /ready_/);
  assert.doesNotMatch(stager, /"restore_allowed"\s*:\s*true/);
  assert.doesNotMatch(stager, /"upload_allowed"\s*:\s*true/);
  assert.doesNotMatch(stager, /Firebase|firestore|https?:\/\//i);
  assert.doesNotMatch(stager, /GoogleAccountManager/);
  assert.doesNotMatch(stager, /SaveManager\.(?:write_save_data|write_save_batch|recover_save_from_backup)\s*\(/);
  assert.doesNotMatch(stager, /user:\/\/(?:achievements|daily_quests|equipment|idle_cultivation|inventory|journey|pavilion|progression)\.save/);
  assert.doesNotMatch(stager, /begin_registered_restore_for_qa|rollback_registered_restore_for_qa/);
});

test("integration runner requires explicit decision before locked restore engine mutation", () => {
  assert.match(runner, /GITHUB_ACTIONS/);
  assert.match(runner, /stage_reviewed_snapshot_for_qa/);
  assert.match(runner, /9700dd8cc68cc0f02c05f7f365976b8891f3b2c158a37abdff58d542de8c804e/);
  assert.match(runner, /Godot canonical digest matches reviewed backend JavaScript fixture/);
  assert.match(runner, /mutates zero registered primary files/);
  assert.match(runner, /prepare_registered_preimage_for_qa/);
  assert.match(runner, /begin_registered_restore_for_qa/);
  assert.match(runner, /rollback_registered_restore_for_qa/);
  assert.match(runner, /explicit restore decision/);
  assert.match(runner, /write_barrier_retained/);
  assert.match(runner, /\.backup sidecars remain byte-identical/);
  assert.match(runner, /JADE_CONTROLLED_TRANSFER_CANDIDATE_QA_PASS/);
  assert.match(restore, /DOMAIN_COUNT:\s*int\s*=\s*8/);
  assert.match(restore, /begin_save_write_barrier/);
});

test("workflow is CI-only QA and never deploys or performs cloud mutation", () => {
  assert.match(workflow, /Controlled Cloud Transfer QA/);
  assert.match(workflow, /windows-2022/);
  assert.match(workflow, /Godot_v4\.7\.2-stable_win64_console\.exe/);
  assert.match(workflow, /controlled_transfer_source_boundary\.test\.mjs/);
  assert.match(workflow, /controlled_transfer_candidate_qa\.gd/);
  assert.match(workflow, /JADE_CONTROLLED_TRANSFER_TEST_ONLY:\s*'1'/);
  assert.match(workflow, /JADE_REGISTERED_RESTORE_TEST_ONLY:\s*'1'/);
  assert.doesNotMatch(workflow, /firebase deploy|service\.account|firebase login/i);
});
