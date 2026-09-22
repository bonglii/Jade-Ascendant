# Audio Identity V2 — QA Report

Source authority audited before this pass:

- Repository: `bonglii/Jade-Ascendant`
- Checkpoint: `checkpoint/billing-runtime-pass-20260922`
- Commit: `7f3199a0c7d3f86cb64cb17f425a78a8a28fa6f8`

## Scope

This pass replaces the **active runtime audio routing** while preserving existing gameplay cue names and call sites. Legacy files in `assets/audio/` remain untouched for rollback; `AudioManager` now loads the V2 assets under `assets/audio/presentation_v2/`.

The pass also adds central semantic hooks for:

- permanent Cultivation upgrades → `upgrade`;
- successful Google Play purchase delivery → `purchase_success`.

`stage_unlock` is authored but intentionally not auto-fired yet because the current Victory path already owns a major result cue; stacking both without the later unlock ceremony would create double-fanfare feedback.

## Static / technical checks completed

- 69/69 V2 audio resources referenced by `AudioManager` exist.
- 65 WAV SFX validated as stereo, 48 kHz, PCM16.
- 4 OGG music loops validated as stereo, 48 kHz Vorbis.
- No WAV reaches digital clipping; measured maximum sample peak is below 0 dBFS.
- No exact duplicate audio binaries are present in the V2 folder.
- All 27 cue names used by the previous `AudioManager` remain available.
- New semantic cues: `upgrade`, `stage_unlock`, `purchase_success`.
- `AudioManager` preload paths: 69 unique references, 0 missing.
- GDScript structural check: balanced delimiters, no duplicate function names, tab indentation, no trailing whitespace.
- No downloaded source archives, `__MACOSX`, `.DS_Store`, or raw sound-library folders are shipped in this patch.
- Source/license notices are retained under `docs/audio_licenses/` and `assets/audio/presentation_v2/THIRD_PARTY_AUDIO_NOTICES.md`.

## Runtime design checks

- Existing cue API remains compatible: game code can keep calling names such as `sword`, `fire`, `claim`, `victory`, and summon cues.
- Frequent combat and tactile sounds use multiple variants and deterministic micro-pitch rotation.
- Semantic actions suppress the deferred generic button tap to avoid double playback.
- Normal browsing receives a deliberately quiet tactile cue instead of being completely silent.
- Major result sounds duck music automatically.
- No stock character grunt/voice asset is used.

## Must still be verified on the user's Windows/device build

This environment cannot execute the user's Windows Godot 4.7.2 build or hear the final result through the target phone speakers. Before the pass is locked, run `PERIKSA_GAME.bat` locally and perform device listening QA.

Focused device sequence:

1. Home / menu: tap several tabs, back buttons and normal cards for 2–3 minutes. Confirm tactile feedback is present but not noisy.
2. Cultivation: perform one real permanent refinement. Confirm the dedicated breakthrough cue replaces the generic tap.
3. Stage 1-1+: listen to Spirit Sword, Fire Orb, enemy hit/death, player hurt, pickup and shield in a crowded wave.
4. Thunder Talisman / lightning chain: confirm primary thunder and chain remain distinguishable.
5. Defeat and Victory: confirm result cues read clearly over music and do not clip.
6. Pavilion: test rare/epic/legendary summon reveal and duplicate/new-result feedback.
7. Treasury license-test purchase: confirm the opening tap is subtle and successful delivery gets the separate purchase-success cue.
8. Check phone volume around 30%, 60%, and 100% for harshness or buried cues.

Do not delete the old audio files until these checks pass.
