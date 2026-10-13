# Cultivation Mastery and Golden Core — 2026-10-13

## Player flow
- Existing three cultivation paths retain Lv.10 caps, prices and all purchased bonuses. Hero Lv.50 remains separate.
- MAX opens Mastery. Each Lv.10 path offers two specializations; select one freely. Selection is frozen per new Journey run, including checkpoint safety for older saves.
- Vitality: Jade Renewal (1 HP/20 kills; no revive) or Iron Meridian (6% incoming damage reduction).
- Sword Power: Still Sword (+5% damage at >=80% HP) or Dao Pulse (15% splash to up to three nearby enemies, 80-unit radius, three-second pause-aware cooldown; no recursive or set-passive triggers).
- Swift Qi: Cloud Stride (+8% movement) or Quiet Qi (starting attack cooldown x0.96; existing floor).
- All three MAX, all three selected, Stage 1-5 unlocked and no active checkpoint unlock Heavenly Tribulation.
- This first trial uses the actual Stage 1-5 boss. Complete in one session with at most three HP-loss events and no death/revive. Shields that prevent HP loss do not count; healing cannot undo a hit.
- A live counter shows readiness/failure. Actual VictoryManager completion grants Golden Core once; replay improves a personal record. Normal stage rewards remain normal stage rewards; no additional farmable currency.
- Only Foundation -> Golden Core is implemented in this patch. Further realms and full balance audit remain future work.

## Persistence and presentation
- Additive schema-v1 cultivation_mastery permanent domain, separate from old progression/equipment. Atomic Journey/trial start and rollback. Corrupt/future mastery data fails closed instead of resetting other saves.
- Deferred existing GameSession helper bootstrap, no new autoload entry or project.godot changes.
- Existing approved cultivation background, meridian art, Dao core, ceremonial FX and ornate SVG skins reused after inspection.
- Responsive Mastery choices, narrow-screen focus layout, refinement result scroll with fixed return action. Drag/spam guards; stale selections rejected.

## Validation
- Godot 4.7.2: 65 mastery/UI/combat/transaction checks, zero failures.
- Separate restart: two persistence checks, zero failures.
- Existing HERO progression/equipment regression: 125 checks, zero failures.
- Native X11 renders inspected at 648x1152 and 320x568; no script errors. Golden Core screenshot uses state earned by the actual QA victory test.
- Static Phase0 scan is NOT a release pass: this restored workspace lacks pre-existing Android/export/cloud-contract artifacts; dynamic resource-prefix strings also produce scanner false positives. New literal mastery resource references resolve. Android export/device QA must be performed in the user's complete Windows project.

## Apply and publish on Windows
Download Jade-Ascendant-Cultivation-Mastery.patch to D:\Godot\tools, then from the project folder:

```bat
git apply --check "D:\Godot\tools\Jade-Ascendant-Cultivation-Mastery.patch" && git apply "D:\Godot\tools\Jade-Ascendant-Cultivation-Mastery.patch"
backend\player_identity\publish_cultivation.cmd
```

Open Godot so resources import, then re-export Android. No Worker or database deployment is needed.
Publisher verifies the authorized checkpoint branch and remote, rejects unrelated staged/outbound changes, never force-pushes, and prints a real commit link only after remote verification. It permits the previously authorized Pavilion/HERO prerequisite paths if still unpublished. GitHub connector write access in this session remains unavailable (403); no remote publication is claimed here.
