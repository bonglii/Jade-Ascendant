# Jade Binding Chain — implementation lessons


- SceneTree tests must runtime-load scripts that depend on autoloads after deferred startup. Preloading those scripts at the test's top level compiles them before SettingsManager/AudioManager exist; an editor import or isolated parse result alone is insufficient. The final focused test exercises real runtime nodes.
- A reusable expired status component must re-enable physics processing when refreshed. Check expiry AND a second application, including pause behavior, rather than only checking the first slowdown.
- Native captures can be obscured by first-visit guides in a fresh QA save. Dismiss the real guide through its actual button before judging/exporting the preview. Do not alter production onboarding to obtain a clean screenshot.
- New equipment requires capability gating for existing exported APKs, not just adding it to an admin list. Filter before inbox pagination and reject reservation before creating a receipt; validate old and current clients against the same gift.

- Shared append-only documentation is not a safe precondition for an incremental gameplay patch. Package new lessons in a uniquely named file and verify application against a divergent shared LESSONS.md before delivery.
