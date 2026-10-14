# Reward delivery, retired fragments and Hero refine guide

Scope: authorized checkpoint only. No combat stats, gacha rates, paid/IAP contracts,
server player records or database schemas changed.

## Player experience

- Reward flights use existing authored resource/equipment art, a small jade seal,
  tapered trail and a 3.5% landing pulse. Multi-claims merge matching item art only;
  visual population is bounded. Reduced effects remain supported.
- Result popup uses one seal, inset rarity-colored reward tiles and the established
  faceted jade button. Height is content-driven, capped to 72% of the viewport;
  long content clips and scrolls. Forging now has an explicit saved-item result.
- Red dots appear at the top right of owned/equipped cards only when an identical
  duplicate can raise stars or an affordable weapon level can be purchased.
  Caps, retired items, pending transactions and active-run locking use the existing
  EquipmentManager rules. Updates preserve the backpack and open item sheet.
- After clear 1-1, a three-step guide leads from Home to Hero and explains red dots,
  duplicate stars and permanent weapon levels. It waits for other modals, replaces
  the old generic Hero guide after that clear, rejects stale/double presses and
  saves completion. It grants no item, spends no currency and owns no gameplay pause.

## Fragment retirement and compatibility

Exchange rate: 1 legacy fragment = 20 Spirit Stones.

- Existing inventory balance is moved by one atomic inventory+progression save.
  The fragment balance is removed only after success; retries cannot double credit.
  A blocked save preserves both old balances for recovery.
- Existing immutable rewards/mail/checkpoints remain readable. A pure conversion
  is used for previews and grants; old payloads are not rewritten. Receipt and
  claim ownership remain in existing managers, so old claim IDs still deduplicate.
- Current LiveOps/milestone rewards, repeat clears, idle cadence and the verified
  daily ad placement deliver Stones. Idle fractional cadence state is preserved.
  Ad placement IDs/caps and paid contracts stay intact.
- Forging costs use the same 20:1 rate. Aura costs add converted fragments to their
  existing Stone fee: Astral Crown is 3,300, Ascendant Halo 6,800 Stones.
  Common/Rare purchase retains its existing Stone price; duplicate currency options
  were removed. Stars still require identical equipment duplicates.
- Active wallets have three currencies. Flight destinations were remapped together.
  Backpack excludes the retired material. New dashboard sends reject fragments;
  historical mail remains immutable/readable. Loading an old draft into the editor
  converts its attachment into Stones before a fresh preview.

This preserves the nominal replacement value and forging costs, not the old
restriction on what fragment income could buy: Stones can also fund cultivation.
No claim is made that every progression choice is economically identical.

## Validation

- Targeted Godot fixture: 53 checks, including failed-save preservation, idempotence,
  immutable legacy payloads, converted actual grants, real forging/aura purchases,
  dot/cap refresh, viewport fit at 320x568, 390x844, 648x1152 and 896x504,
  real long-content scrolling, modal close races and stage gating.
- Existing Hero burst regression: 734 checks, zero failures.
- Node server regression: 68 tests, zero failures (identity, mail, banner,
  announcements, retirement and dashboard script syntax).
- Actual Godot OpenGL UI captures: 36 reward animation frames plus Hero/claim/guide.
  This is an isolated desktop render, not phone FPS or deployed-server evidence.
- Windows launchers derive from the existing working .cmd/.ps1 wrappers. A
  Windows PowerShell parser CI job is supplied; Windows execution is not available
  in this Linux workspace. No claim of an already executed Windows/deploy test.
- Patch application and publishing are scoped, reversible and never force push.
  User must re-export the Android client and deploy the updated existing Worker.
  No D1 migration is required. Live deployment cannot be claimed from this workspace.

## Lessons recorded

- Follow the production scene's bound script; the older EquipmentScreen script
  is archived and is not evidence of current Hero layout or eligibility handling.
- Decorative children of Container nodes inherit container layout. Put a thin
  decorative line inside a plain Control so it cannot become a full-card fill.
- Coroutine guards must accept Variant references before checking validity;
  typed arguments can fail conversion after a popup is freed, before the guard runs.
- Match the existing indentation style in Godot scripts; mixed spaces/tabs fail
  parsing. Parse/runtime logs matter even when the fixture reports zero failures.
- Gacha grants must not reveal real item art through generic reward delivery.
  Guard the synchronous summon emission window separately from saved forge results.
- Cosmetic assertions compare against the existing overlay population after actual
  purchases; they must not assume a legitimately running flight means stale delivery.
