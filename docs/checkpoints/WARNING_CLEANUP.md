# Warning cleanup — 2026-10-18

Base: 73072e1ed2e5df63842eca8c0450307d1601c711, checkpoint/iap-fasttrack-20261010.

Changed: locals/parameters that shadow Node owner/name/ready or Node2D rotation; duplicate nested flash local; explicit int(4*unit) for account-entry theme separation. The integer conversion preserves the former implicit truncation. JSON dictionary keys, Node properties, save fields, callback argument order, auth ownership checks, wallet verification, balances and native/server endpoints remain identical.

Validation: Godot 4.7.2 loaded all 301 production scripts with shadowed_variable, shadowed_variable_base_class and narrowing_conversion promoted to errors in a disposable project. Result: 301 loaded, 0 failed, no script errors. Production project warning settings are untouched. Existing paid-gameplay regression suite also passed: 56 checks, 0 failures. No live purchase, deployment or player save used.

Install/publish: apply_and_publish.cmd uses Node/Git, validates every payload/original file before mutation, retains backups, preserves unrelated work and appends the lesson section. It uses the current checkpoint branch, never deletes index.lock and never force-pushes. No Android export, version/signing change, or backend deploy.

R2 preserves the user-verified LiveOps variant b1326b9 (ready_count / claim_available). Preflight accepts either the original baseline or that exact corrected payload; unknown source edits still stop before writing.
