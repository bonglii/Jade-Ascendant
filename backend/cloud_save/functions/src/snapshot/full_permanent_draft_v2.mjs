/**
 * Gate 6A — strict, UNTRUSTED eight-domain structural preview contract.
 * This is NOT a Cloud Save upload route, server-authoritative reconciliation,
 * Google Play purchase proof, domain migration, or restorable snapshot.
 * It is independent of the existing SIX-domain Godot draft (v1).
 */
import { createHash } from "node:crypto";

export const FULL_DRAFT_VERSION = 2;
export const FULL_DRAFT_MAX_BYTES = 524288;
const MAX_SAFE = Number.MAX_SAFE_INTEGER;
const UID = /^[A-Za-z0-9_-]{1,128}$/;
const MAX_DEPTH = 12;
const MAX_CONTAINER_ENTRIES = 2048;
const slots = Object.freeze(["armament", "robe", "bracer", "boots", "pendant"]);
const FIELDS = Object.freeze({
  achievements: ["version", "progress", "unlocked", "claimed"],
  daily_quests: ["version", "date_key", "active_quest_ids", "progress", "completed", "claimed"],
  equipment: ["version", "equipped_item_ids", "ascension_stars"],
  inventory: ["version", "item_counts"],
  journey: ["version", "selected_chapter_id", "selected_stage_id", "active_run_chapter_id", "active_run_stage_id", "unlocked_stage_keys", "cleared_stage_keys"],
  progression: ["version", "spirit_stone", "vitality_level", "sword_power_level", "swift_qi_level", "hero_experience_total", "hero_milestones_claimed"],
  pavilion: [
    "version", "meditation_date", "cosmetic_id", "owned_cosmetics", "celestial_jade",
    "pavilion_seals", "starter_seals_claimed", "wish_item_id", "wish_fate_guaranteed",
    "pity_rare_plus", "pity_epic_plus", "pity_legendary", "lifetime_pulls",
    "cadence_last_daily_bonus_date", "cadence_active_days", "cadence_cycles_completed",
    "rewarded_ads_claimed_in_cycle", "claimed_milestone_ids", "claimed_one_time_product_ids",
    "monthly_blessing_expires_unix", "monthly_blessing_last_claim_date",
    "monthly_blessing_daily_claims_remaining", "monthly_blessing_purchase_count",
    "processed_grant_ids",
  ],
  idle_cultivation: [
    "version", "last_claim_unix", "last_observed_unix", "lifetime_claim_seconds",
    "shard_progress_units", "processed_rewarded_grant_ids",
  ],
});
const REQUIRED = Object.freeze({
  achievements: ["progress", "unlocked", "claimed"],
  daily_quests: ["date_key", "progress", "completed", "claimed"],
  equipment: ["equipped_item_ids"],
  inventory: ["item_counts"],
  journey: ["selected_chapter_id", "selected_stage_id", "active_run_chapter_id", "active_run_stage_id", "unlocked_stage_keys", "cleared_stage_keys"],
  progression: ["spirit_stone", "vitality_level", "sword_power_level", "swift_qi_level"],
  pavilion: ["meditation_date", "cosmetic_id", "owned_cosmetics"],
  idle_cultivation: ["last_claim_unix", "last_observed_unix", "lifetime_claim_seconds", "shard_progress_units"],
});
export const PERMANENT_DOMAIN_IDS = Object.freeze(Object.keys(FIELDS).sort());
export const PERMANENT_DOMAIN_REQUIRED = REQUIRED;
export const PERMANENT_DOMAIN_ALLOWED = FIELDS;

function plain(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v)
    && (Object.getPrototypeOf(v) === Object.prototype || Object.getPrototypeOf(v) === null);
}
const int = n => Number.isSafeInteger(n) && n >= 0;
const positive = n => int(n) && n > 0;
const bounded = (n, max) => int(n) && n <= max;
const exact = (v, keys) => plain(v)
  && Object.keys(v).length === keys.length
  && keys.every(k => Object.hasOwn(v, k));
const allowed = (v, keys) => Object.keys(v).every(k => keys.includes(k));
const strings = (v, max = 2048) => Array.isArray(v) && v.length <= max
  && v.every(s => typeof s === "string" && s.length > 0 && s.length <= 256)
  && new Set(v).size === v.length;
const counts = v => plain(v) && Object.values(v).every(int);
const safeStatus = (reason, valid = false) => Object.freeze({
  valid, reason, domain_count: valid ? 8 : 0,
  economy_verified: false, server_revision_verified: false,
  upload_allowed: false, restore_allowed: false,
});

function jsonTreeSafe(v, depth = 0, ancestors = new Set()) {
  if (depth > MAX_DEPTH) return false;
  if (v === null || typeof v === "boolean") return true;
  if (typeof v === "string") return v.length <= 4096;
  if (typeof v === "number") return Number.isFinite(v) && Math.abs(v) <= MAX_SAFE;
  if (!Array.isArray(v) && !plain(v)) return false;
  if (ancestors.has(v)) return false;
  const descriptors = Object.getOwnPropertyDescriptors(v);
  if (Reflect.ownKeys(v).length > MAX_CONTAINER_ENTRIES + (Array.isArray(v) ? 1 : 0)) return false;
  if (Array.isArray(v) && (v.length > MAX_CONTAINER_ENTRIES
      || Object.keys(v).length !== v.length)) return false;
  for (const key of Reflect.ownKeys(v)) {
    if (typeof key === "symbol") return false;
    if (key === "__proto__" || key === "prototype" || key === "constructor") return false;
    if (key.length > 256) return false;
    if (key !== "length" && !("value" in descriptors[key])) return false;
  }
  ancestors.add(v);
  const children = Array.isArray(v) ? v : Object.values(v);
  const result = children.every(item => jsonTreeSafe(item, depth + 1, ancestors));
  ancestors.delete(v);
  return result;
}

function validateSix(domain, p) {
  switch (domain) {
    case "progression":
      return int(p.spirit_stone) && ["vitality_level", "sword_power_level", "swift_qi_level"].every(k => bounded(p[k], 10))
        && (!Object.hasOwn(p, "hero_experience_total") || int(p.hero_experience_total))
        && (!Object.hasOwn(p, "hero_milestones_claimed") || Array.isArray(p.hero_milestones_claimed)
          && p.hero_milestones_claimed.every(int));
    case "journey":
      return positive(p.selected_chapter_id) && positive(p.selected_stage_id)
        && p.active_run_chapter_id === 0 && p.active_run_stage_id === 0
        && strings(p.unlocked_stage_keys) && strings(p.cleared_stage_keys);
    case "achievements":
      return counts(p.progress) && strings(p.unlocked) && strings(p.claimed);
    case "daily_quests":
      return typeof p.date_key === "string" && p.date_key.length <= 32
        && counts(p.progress) && strings(p.completed) && strings(p.claimed)
        && (!Object.hasOwn(p, "active_quest_ids") || strings(p.active_quest_ids));
    case "inventory":
      return counts(p.item_counts);
    case "equipment":
      if (!exact(p.equipped_item_ids, slots)
        || !slots.every(k => typeof p.equipped_item_ids[k] === "string"
          && p.equipped_item_ids[k].length <= 256)) return false;
      if (!Object.hasOwn(p, "ascension_stars")) return true;
      return plain(p.ascension_stars) && Object.values(p.ascension_stars).every(n => positive(n) && n <= 5);
    default: return false;
  }
}
function validatePavilion(p) {
  if (typeof p.meditation_date !== "string" || p.meditation_date.length > 32
    || typeof p.cosmetic_id !== "string" || p.cosmetic_id.length > 128
    || !strings(p.owned_cosmetics) || !p.owned_cosmetics.includes("plain")
    || !p.owned_cosmetics.includes(p.cosmetic_id)) return false;
  for (const k of ["celestial_jade", "pavilion_seals", "lifetime_pulls",
    "cadence_cycles_completed", "monthly_blessing_expires_unix",
    "monthly_blessing_daily_claims_remaining", "monthly_blessing_purchase_count"]) {
    if (Object.hasOwn(p, k) && !int(p[k])) return false;
  }
  for (const [k, max] of [["pity_rare_plus", 9], ["pity_epic_plus", 29],
    ["pity_legendary", 49], ["cadence_active_days", 6],
    ["rewarded_ads_claimed_in_cycle", 3]]) {
    if (Object.hasOwn(p, k) && !bounded(p[k], max)) return false;
  }
  for (const k of ["starter_seals_claimed", "wish_fate_guaranteed"]) {
    if (Object.hasOwn(p, k) && typeof p[k] !== "boolean") return false;
  }
  for (const k of ["wish_item_id", "cadence_last_daily_bonus_date", "monthly_blessing_last_claim_date"]) {
    if (Object.hasOwn(p, k) && (typeof p[k] !== "string" || p[k].length > 256)) return false;
  }
  for (const [k, max] of [["claimed_milestone_ids", 2048], ["claimed_one_time_product_ids", 1024],
    ["processed_grant_ids", 1024]]) {
    if (Object.hasOwn(p, k) && !strings(p[k], max)) return false;
  }
  // Current Pavilion save stores some IAP grant IDs as "iap:<sku>:<RAW_PLAY_TOKEN>".
  // They are PRIVATE and must never enter a future transferable cloud draft.
  // Refuse these drafts; do not strip silently or emit the offending token.
  if (Object.hasOwn(p, "processed_grant_ids")
      && p.processed_grant_ids.some(id => id.startsWith("iap:"))) return false;
  // A locally persisted grant history is NEVER authoritative anti-replay evidence.
  return true;
}
function validateIdle(p) {
  if (!["last_claim_unix", "last_observed_unix", "lifetime_claim_seconds", "shard_progress_units"]
    .every(k => int(p[k]))) return false;
  if (p.last_observed_unix < p.last_claim_unix) return false;
  if (Object.hasOwn(p, "processed_rewarded_grant_ids")
    && !strings(p.processed_rewarded_grant_ids, 32)) return false;
  // Wall-clock fields are device-generated. They DO NOT prove reward accrual.
  return true;
}
function equipmentInventoryConsistent(domains) {
  const countsMap = domains.inventory.item_counts;
  const equipped = Object.values(domains.equipment.equipped_item_ids).filter(Boolean);
  if (new Set(equipped).size !== equipped.length) return false;
  if (!equipped.every(id => positive(countsMap[id]))) return false;
  if (domains.equipment.ascension_stars
    && !Object.keys(domains.equipment.ascension_stars).every(id => positive(countsMap[id]))) return false;
  // Item catalogue/slot eligibility is intentionally NOT verified in this JS preview.
  return true;
}

/** expectedUid is a SYNTHETIC test bound, NOT a substitute for Firebase Auth. */
export function inspectFullPermanentDraft(draft, expectedUid) {
  if (typeof expectedUid !== "string" || !UID.test(expectedUid)) return safeStatus("INVALID_IDENTITY");
  const root = ["draft_snapshot_version", "owner_uid", "captured_at_unix", "domain_schema_versions", "domains"];
  if (!jsonTreeSafe(draft)) return safeStatus("UNSAFE_JSON_STRUCTURE");
  if (!exact(draft, root)) return safeStatus("INVALID_ENVELOPE");
  if (draft.draft_snapshot_version !== FULL_DRAFT_VERSION) return safeStatus("INVALID_DRAFT_VERSION");
  if (draft.owner_uid !== expectedUid) return safeStatus("OWNER_MISMATCH");
  if (!positive(draft.captured_at_unix)) return safeStatus("UNTRUSTED_TIMESTAMP_SHAPE");
  if (!exact(draft.domain_schema_versions, PERMANENT_DOMAIN_IDS)
    || !exact(draft.domains, PERMANENT_DOMAIN_IDS)) return safeStatus("INCOMPLETE_PERMANENT_DOMAINS");
  if (Buffer.byteLength(JSON.stringify(draft), "utf8") > FULL_DRAFT_MAX_BYTES) {
    return safeStatus("DRAFT_TOO_LARGE");
  }
  for (const domain of PERMANENT_DOMAIN_IDS) {
    if (draft.domain_schema_versions[domain] !== 1) return safeStatus("SCHEMA_VERSION_MISMATCH");
    const p = draft.domains[domain];
    if (!plain(p) || p.version !== 1) return safeStatus("DOMAIN_VERSION_MISMATCH");
    if (!allowed(p, FIELDS[domain])) return safeStatus("UNEXPECTED_DOMAIN_FIELD");
    if (!REQUIRED[domain].every(k => Object.hasOwn(p, k))) return safeStatus("MISSING_DOMAIN_FIELD");
    const valid = domain === "pavilion" ? validatePavilion(p)
      : domain === "idle_cultivation" ? validateIdle(p)
        : validateSix(domain, p);
    if (!valid) return safeStatus("INVALID_DOMAIN_FIELDS");
  }
  if (!equipmentInventoryConsistent(draft.domains)) return safeStatus("EQUIPMENT_INVENTORY_MISMATCH");
  return safeStatus("STRUCTURAL_PREVIEW_ONLY", true);
}

function canonicalJson(v) {
  if (Array.isArray(v)) return `[${v.map(canonicalJson).join(",")}]`;
  if (v && typeof v === "object") {
    return `{${Object.keys(v).sort().map(k => `${JSON.stringify(k)}:${canonicalJson(v[k])}`).join(",")}}`;
  }
  return JSON.stringify(v);
}

/** UNKEYED hash of an already-inspected test draft; NOT a server signature. */
export function hashFullDraftForQa(draft) {
  return createHash("sha256").update(canonicalJson(draft), "utf8").digest("hex");
}
