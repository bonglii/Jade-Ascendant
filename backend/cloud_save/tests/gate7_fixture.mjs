/** Minimal synthetic eight-domain fixtures, never read from user://. */
import { PERMANENT_DOMAIN_IDS, hashFullDraftForQa } from "../functions/src/snapshot/full_permanent_draft_v2.mjs";

export function makeGate7SyntheticDraft(uid = "gate7_synthetic_owner", jade = 0) {
  return {
    draft_snapshot_version: 2,
    owner_uid: uid,
    captured_at_unix: 1700000000,
    domain_schema_versions: Object.fromEntries(PERMANENT_DOMAIN_IDS.map(k => [k, 1])),
    domains: {
      achievements: { version: 1, progress: {}, unlocked: [], claimed: [] },
      daily_quests: { version: 1, date_key: "", progress: {}, completed: [], claimed: [] },
      equipment: { version: 1, equipped_item_ids: {
        armament: "", robe: "", bracer: "", boots: "", pendant: "",
      } },
      inventory: { version: 1, item_counts: {} },
      journey: { version: 1, selected_chapter_id: 1, selected_stage_id: 1,
        active_run_chapter_id: 0, active_run_stage_id: 0,
        unlocked_stage_keys: [], cleared_stage_keys: [] },
      progression: { version: 1, spirit_stone: 0, vitality_level: 0,
        sword_power_level: 0, swift_qi_level: 0 },
      pavilion: { version: 1, meditation_date: "", cosmetic_id: "plain",
        owned_cosmetics: ["plain"], celestial_jade: jade,
        pavilion_seals: 0, processed_grant_ids: [],
      },
      idle_cultivation: { version: 1, last_claim_unix: 1000,
        last_observed_unix: 1000, lifetime_claim_seconds: 0,
        shard_progress_units: 0, processed_rewarded_grant_ids: [] },
    },
  };
}

export function makeGate7SyntheticReadOnlyRecord(uid, revision, jade) {
  const draft = makeGate7SyntheticDraft(uid, jade);
  return { qaOnly: true, ownerUid: uid, revision,
    digest: hashFullDraftForQa(draft), draft };
}
