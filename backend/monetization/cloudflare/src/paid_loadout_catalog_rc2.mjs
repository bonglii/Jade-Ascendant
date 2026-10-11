/** Pinned server-side SLOT mapping. Source: equipment_catalog.gd at
 * commit 54168ac936acfdde380336687ba307172e168659.
 * Any equipment-catalog change requires an independently reviewed repin.
 */
import { CATALOG_V1 } from './summon_catalog_pinned.mjs';

export const PAID_SLOTS_RC2 = Object.freeze(['armament','robe','bracer','boots','pendant']);
const PER_SLOT = Object.freeze({
  armament: ['wanderer_jade_jian','mistveil_jian','spirit_seal_fan','cinnabar_moon_saber','nine_heavens_star_sword','mountain_ward_jian','stillwater_mirror_blade','sunfire_dragon_jian'],
  robe: ['verdant_qi_robe','bamboo_weave_robe','moonthread_robe','ward_keeper_robe','sovereign_mantle','stone_meridian_robe','glassmoon_robe','dawn_meridian_robe'],
  bracer: ['jade_guard_bracer','jade_edge_bracer','mirror_edge_bracer','stormcall_bracer','tribulation_bracer','earthseal_bracer','reflection_bracer','solar_edict_bracer'],
  boots: ['cloudstep_boots','miststride_boots','shadowstep_boots','starstep_boots','cloudtreader_boots','rootstep_boots','silent_ripple_boots','sunstride_boots'],
  pendant: ['spirit_jade_pendant','qi_reservoir_pendant','shrine_seal_pendant','sword_heart_pendant','ascendant_heart','guardian_jade_pendant','mirror_heart_pendant','golden_core_pendant'],
});
export const PAID_SLOT_OF_ITEM_RC2 = Object.freeze(Object.fromEntries(
  Object.entries(PER_SLOT).flatMap(([slot,ids])=>ids.map(id=>[id,slot]))
));
const expected = CATALOG_V1.map(x=>x.id).sort();
const pinned = Object.keys(PAID_SLOT_OF_ITEM_RC2).sort();
if (expected.length !== 40 || expected.length !== pinned.length || expected.some((id,i)=>id!==pinned[i])) {
  throw new Error('paid_loadout_catalog_mismatch_fail_closed');
}
