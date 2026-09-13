# Jade Ascendant — Canonical Source Policy

Baseline ID: **JA-GATE0-BASELINE-20260913**  
Engine target: **Godot 4.7.2**

This document defines what counts as source authority before Equipment V2, Spirit Beasts, gacha, and monetization are added. The full split archive uploaded on 13 September 2026 is the gameplay/content authority; Gate 0 changes only QA/source-hygiene files and does not change gameplay balance, saves, scenes, or runtime systems.

## Keep as canonical source

- `project.godot` and `export_presets.cfg`.
- `scripts/`, `scenes/`, `assets/`, `tests/`, `tools/`, `docs/`, and public release templates under `release/`.
- The installed/custom Android Gradle template needed for reproducible builds: `android/.build_version`, Gradle wrapper/configuration, Android manifests/source/resources, template libraries, and future production plugin source under `android/build/`.

The Android template is intentionally **not** ignored wholesale. Future AdMob/Billing/plugin integration may add real source or dependencies below `android/build/`, so `/android/` must never be used as a blanket ignore rule.

## Generated or machine-local files — never source authority

Do not include these when making the next canonical audit/archive unless a specific diagnostic explicitly requires them:

- `.godot/` — import/editor cache and machine-local export state. In particular, `.godot/export_credentials.cfg` can contain release-keystore credential fields and must not be shared or committed.
- `.local/` — local helper configuration.
- `artifacts/` — logs, reports, screenshots, APK/AAB output.
- `android/build/.gradle/` — Gradle cache.
- `android/build/build/` — generated Android intermediates and bundle output.
- `android/build/assetPackInstallTime/build/` — generated asset-pack build output.
- `android/build/assetPackInstallTime/src/main/assets/` — generated exported Godot project payload.
- `android/build/local.properties` — machine-local Android SDK path if generated.
- `release/release_config.json` and generated `release/privacy-policy.html`.
- `*.apk`, `*.aab`, keystores/private keys (`*.jks`, `*.keystore`, `*.p12`, `*.pem`), temporary logs, and ad-hoc ZIPs.

The root `.gitignore` mirrors this policy. Ignoring a generated directory does not delete it from a developer machine; it only prevents that output from becoming canonical source.

## Gate 0 QA contract

Before this baseline is locked:

1. `python tools/validate_release.py --report-dir artifacts/source-check` must finish **PASS 27/27**. This is source/data/asset/package validation only.
2. `PERIKSA_GAME.bat` must be run locally with the exact Godot **4.7.2** executable and must reach `JADE_PHASE0_PASS` with no rejected engine error/warning.
3. Do not infer engine/runtime PASS from the Python validator. Do not infer source PASS from an older report.
4. Only after both checks are green is **Gate 0 — Canonical Baseline Repair** considered PASS/LOCK.

## Gate 0 repaired invariant

`tools/validate_release.py` uses a comment-aware constant extractor. GDScript comments inside catalog literals may contain apostrophes or bracket characters without breaking the validator. The Stage 1 production baseline is `wave_duration = 14.0`, first-clear Spirit Stones `100`, repeat-clear Spirit Stones `100`.

## Next gate

After Gate 0 is user-runtime verified and locked, development proceeds to **Gate 1 — Equipment V2 + permanent Dao Armament slot + 1★–5★ Ascension**.
