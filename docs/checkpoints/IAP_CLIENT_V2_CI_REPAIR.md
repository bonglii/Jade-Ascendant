# Verified CI repair, 2026-10-15

Base: e48945710e947893756c9d04d92e16f6bd5aa9ec.
Run: https://github.com/bonglii/Jade-Ascendant/actions/runs/38738864296

Completed evidence:
- Backend job: SUCCESS (404 tests).
- SDK setup: SUCCESS.
- Native build, debug/release JVM tests and compiled JNI inventory: PASS.
- Actual uploaded XML: debug 88, release 88, zero failures/errors.
- Downloaded artifact SHA-256 matches GitHub's artifact digest. Inner AAR hashes
  match the real build receipts. All receipt source-input hashes match this tree.
- BuildConfig.class independently inspected: debug target staging with V2/sandbox
  enabled; release target locked with both flags false and iap-disabled.invalid.

Repairs:
- SceneTree test resolves manager nodes after boot. Its entry script no longer
  references unavailable autoload identifiers while compiling.
- Negative Git staging test explicitly returns exit 0 after all six assertions
  pass, preventing inheritance of the expected failure's LASTEXITCODE=1.
- Ship the actual CI-built AARs and separate new provenance document; existing
  historical build-proof documents remain unchanged. Readiness checks recognize
  the new evidence. No native source changed after this verified compilation.

Not yet verified: corrected Godot test execution, rerun CI gate completion,
Android Keystore/process death and real device delivery, deployment, production,
and any real charged purchase. Do not export or activate production yet.

Four remaining gates: complete client/native CI; finish restart/Continue recovery;
prove deployed staging delivery/spending/combat; prepare production and prove a
real charged transaction. Test harness repairs do not complete gameplay QA.
