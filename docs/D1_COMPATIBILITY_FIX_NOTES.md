# D1 production-shape mismatch, fixed at source

**Bug:** RC3 `readTrustedProgressionRC3` and `listSummonRequestIdsRC3` called `.all()` and assumed return type `Array`. D1 actually returns `{results: Array, success: Boolean, meta: Object}`. Prior mocks returned arrays, masking the bug. RC10 additionally accepted both direct-array and D1-object replies; strict provider contract now uses `.results`.

**Failure without fix:** honest players could see unavailable trusted progress or lose the ability to find request IDs on a second device, even if the backend tables held correct records. The code was fail-closed, not a credit exploit, but it blocked core IAP functionality.

**Fix:** extract `.results`; validate arrays, lengths, and required row attributes; reject malformed or partial envelopes. Update mocked `.all()` in the related test files to return D1-shaped objects. Add regression tests for both malformed old array mocks and legitimate HTTP paths.

**Validation:** 30/30 targeted tests in local SQLite + simulated D1 adapter. No production Worker test, no Android build, no live Google Play and no deployment. No changes to gameplay save or all IAP gates.

**Release rule:** tests must run again **once** in the complete integrated Worker after all source overlay dependencies are merged. Do not count these tests as a substitute for the final Play sandbox end-to-end test.
