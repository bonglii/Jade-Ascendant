# Delivery publisher staging fix

The reported `Cannot stage package` is a wrapper failure, not enough evidence to
identify the underlying Git error. The old publisher obscured the failed path and
could stop when a package asset is ignored by a user's repository/global rules.

Staging now uses literal per-file pathspecs and reports the exact failing path and
Git stderr. Only explicitly listed approved binary/import/UID assets can bypass
ignore rules; ignored source remains blocked. No global Git configuration, ignore
rules, branch protection, unrelated staging or payment settings are changed.
Existing index locks are reported, never deleted automatically.

Regression: exact production staging function run in PowerShell 7 on Linux, six
checks passed: approved ignored assets, unrelated-file exclusion, repeat staging,
ignored-source refusal, traversal refusal and real index.lock diagnostic. This is
not a Windows PowerShell 5.1 execution claim. No gameplay tests repeated.

GitHub: publisher retry is authorized via CMD; print commit link only after remote
SHA verification. No completed push is claimed by installing this fix.
