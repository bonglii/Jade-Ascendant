# Publisher JSON compatibility root cause

Windows PowerShell 5.1 ConvertFrom-Json emits a JSON array as one pipeline object.
Wrapping the pipeline in @() nests that array. The fix installer then compares
item.path (an array) against allowed scalar paths and rejects valid updates.
The same pattern in publishers can send nested/incorrect path arguments to Git.
The earlier PowerShell 7-only tests missed this difference; ignored assets were
only a potential secondary failure, not an established root cause.

Assign ConvertFrom-Json directly, without wrapping its pipeline output in @().
Corrected 13 publisher entrypoints and the R2 installer. Regression executes real
publisher path initializers under normal PowerShell 7 behavior and a non-enumerating
ConvertFrom-Json shim reproducing the relevant 5.1 behavior. R2 installer is also
tested under both behaviors, CRLF, repeat install and preserving custom edits.
Actual Windows PowerShell execution remains unavailable; no claim of full PS5.1
runtime validation. Branch/allowlist/hash checks stay enabled. No gameplay changes.

Rule: publisher/installer tests must cover both JSON pipeline behaviors; a PS7 pass
alone cannot establish Windows PowerShell 5.1 compatibility.

Recorded validation: compatibility smoke 113 assertions (including actual path
initializers for all 13 affected publishers in both modes); installer 12 scenarios
covering original/fixed preimages, CRLF, repeats and custom-edit refusal; six staging
checks; full staging/commit/push/SHA verification to a disposable LOCAL bare remote
passed in both JSON modes. No real GitHub push was performed by these tests.
