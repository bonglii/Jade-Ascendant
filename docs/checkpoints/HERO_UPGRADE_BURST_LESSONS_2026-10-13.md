# HERO upgrade burst lessons — 2026-10-13

- The previous rapid-equip repair did not audit star/level actions that shared its refresh pattern. For each input/state-lifecycle bug, search all sibling action handlers and their inventory/progression signals before marking the fix complete. This change covers all active HERO mutation entry points.
- Share a short action guard across equip, ascension and level. Bind upgrade callbacks to the displayed item/progression key/modal generation, so stale buttons cannot silently buy a second upgrade.
- Incremental UI updates must include stats, stars, copies, affordability, MAX states, filtered inventory membership and star sorting; retaining a popup while leaving stale costs is not a complete fix.
- Rebinding by disconnecting every pressed connection can remove sound/FX listeners. Track and replace only the callback owned by HERO. Verify preservation with an unrelated-listener fixture.
- A first-connection Demo test hit an unrelated listener rather than the gameplay callback. Name the action control and test the tracked HERO-owned callback; do not infer callback ownership from signal-list order.
- Preserve rarity identity underneath equipped decoration. Use multiple visible cues and inspect actual 320px/648px native renders; a tiny corner tick was insufficient.
- Keep shared lesson/publisher files out of incremental patches. A new publisher can include the authorized prior prerequisite paths without adding unrelated gameplay/backend/IAP changes.
