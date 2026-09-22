# Jade Ascendant — Audio Cleanup Manifest

## Cleanup status

- Audio V2.1 runtime listening QA: **PASS** (user-confirmed).
- Source baseline audited before cleanup: `checkpoint/billing-runtime-pass-20260922` @ `7d82cdb30f8c48d6f3dc96f065d7c3560c02b07b`, plus the locally applied Audio V2.1 semantic patch that passed `PERIKSA_GAME` and runtime listening QA.
- Input archive integrity: **PASS** (`audio.zip`, ZIP CRC test clean).
- Kept under `assets/audio/presentation_v2/`: **140 files**.
- Legacy entries removed from `assets/audio/`: **69 files**.
- `audio_manifest_v2.json` and `THIRD_PARTY_AUDIO_NOTICES.md`: **KEPT**.
- Project-level `docs/audio_licenses/`: **DO NOT DELETE**; it remains outside this replacement audio folder.

## Installation rule

A ZIP overwrite cannot remove legacy files. Before extracting this cleanup package, move or delete the existing `jade-ascendant/assets/audio` directory. Then extract this package so the resulting audio tree contains only `presentation_v2`.

## SAFE TO DELETE — legacy audio

- `assets/audio/ambience_crimson_moon.ogg`
- `assets/audio/ambience_crimson_moon.ogg.import`
- `assets/audio/ambience_nine_heavens.ogg`
- `assets/audio/ambience_nine_heavens.ogg.import`
- `assets/audio/ambience_verdant_valley.ogg`
- `assets/audio/ambience_verdant_valley.ogg.import`
- `assets/audio/audio_manifest.json`
- `assets/audio/boss_defeat.wav`
- `assets/audio/boss_defeat.wav.import`
- `assets/audio/celestial_gate.ogg`
- `assets/audio/celestial_gate.ogg.import`
- `assets/audio/chain.wav`
- `assets/audio/chain.wav.import`
- `assets/audio/claim.wav`
- `assets/audio/claim.wav.import`
- `assets/audio/death.wav`
- `assets/audio/death.wav.import`
- `assets/audio/defeat.wav`
- `assets/audio/defeat.wav.import`
- `assets/audio/equip.wav`
- `assets/audio/equip.wav.import`
- `assets/audio/fire.wav`
- `assets/audio/fire.wav.import`
- `assets/audio/hit.wav`
- `assets/audio/hit.wav.import`
- `assets/audio/hurt.wav`
- `assets/audio/hurt.wav.import`
- `assets/audio/level.wav`
- `assets/audio/level.wav.import`
- `assets/audio/pavilion_celestial_ritual.ogg`
- `assets/audio/pavilion_celestial_ritual.ogg.import`
- `assets/audio/pickup.wav`
- `assets/audio/pickup.wav.import`
- `assets/audio/shield.wav`
- `assets/audio/shield.wav.import`
- `assets/audio/sovereign_ritual.ogg`
- `assets/audio/sovereign_ritual.ogg.import`
- `assets/audio/summon_charge.wav`
- `assets/audio/summon_charge.wav.import`
- `assets/audio/summon_duplicate.wav`
- `assets/audio/summon_duplicate.wav.import`
- `assets/audio/summon_epic.wav`
- `assets/audio/summon_epic.wav.import`
- `assets/audio/summon_legendary_omen.wav`
- `assets/audio/summon_legendary_omen.wav.import`
- `assets/audio/summon_legendary_reveal.wav`
- `assets/audio/summon_legendary_reveal.wav.import`
- `assets/audio/summon_new.wav`
- `assets/audio/summon_new.wav.import`
- `assets/audio/summon_rare.wav`
- `assets/audio/summon_rare.wav.import`
- `assets/audio/sword.wav`
- `assets/audio/sword.wav.import`
- `assets/audio/thunder.wav`
- `assets/audio/thunder.wav.import`
- `assets/audio/ui.wav`
- `assets/audio/ui.wav.import`
- `assets/audio/ui_back.wav`
- `assets/audio/ui_back.wav.import`
- `assets/audio/ui_confirm.wav`
- `assets/audio/ui_confirm.wav.import`
- `assets/audio/ui_locked.wav`
- `assets/audio/ui_locked.wav.import`
- `assets/audio/ui_tab.wav`
- `assets/audio/ui_tab.wav.import`
- `assets/audio/verdant_journey.ogg`
- `assets/audio/verdant_journey.ogg.import`
- `assets/audio/victory.wav`
- `assets/audio/victory.wav.import`

## Retained audio root

After cleanup, the intended runtime audio root is:

```text
assets/audio/
└── presentation_v2/
```

Do not delete anything inside `presentation_v2` unless a later source audit explicitly marks it safe.
