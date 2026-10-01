# Jade Ascendant — Cloud Save Gate 1: read-only identity / manifest foundation

**Source authority:** GitHub `bonglii/Jade-Ascendant`, `main` commit `7c9c5e7`.
**Scope:** Firebase UID boundary and optional read-only **manifest preview**. **This is NOT an active backup, upload, restore, or cross-device Cloud Save implementation.**

## Production boundaries

- `GoogleAccountManager.get_authenticated_uid()` rechecks the live native Android Firebase session, excludes anonymous/Guest accounts, and returns an empty string when unavailable, busy, or signed out. UID is never published through the existing account/UI snapshot.
- `GoogleAccountManager.get_cloud_save_probe()` lazily attaches a **separate child Node** named `CloudSaveReadOnlyManager`. This avoids adding a twentieth Autoload and leaves `project.godot`, boot order, and the 19-Autoload smoke contract unchanged.
- The probe does not run on boot or sign-in. It only reads when `request_preview()` is called explicitly. The existing Settings account card and gameplay are unchanged.
- A native Firestore `get_document()` response is accepted only for the requested UID, while the same live authenticated session still exists. Sign-out, account switching, timeout, and a mismatched `docID` fail closed. Timed-out reads reserve their native operation until its callback arrives or the application restarts, because the installed plugin does not return request IDs.
- The v1.1.0 Android plugin returns `status`, optional `docID`, `data` and `error` for its get operation, **not the full collection path or server/cache source**. For this reason the document ID is the UID, not a common document ID such as `main`, and this probe must not run concurrently with another Firestore get request using that same document ID. **Future Firestore uses must introduce a request-coordination layer or an upgraded native adapter before sharing this signal.**
- Android Firestore `.get()` uses the default source and can fall back to local cache. All read results set `server_freshness_verified=false`; no snapshot is considered current or restorably safe.
- No account email, auth token, raw UID, purchase token, or downloaded document is logged, copied to the local SaveManager, or sent in the emitted preview status. The only public fields are a simple status, count/list of permitted domain IDs, revision, and timestamp.
- There is **no Cloud Save write, delete, upload, restore, import, client-owned premium entitlement, or automatic merge** method.

## Firestore document contract (reserved, not automatically created)

Collection: `jade_cloud_manifests_v1`. Document ID: **the authenticated Firebase UID**. Example *schema only*:

```json
{
  "manifest_version": 1,
  "owner_uid": "<server-verified-firebase-uid>",
  "revision": 1,
  "saved_at_unix": 0,
  "domain_schema_versions": {
    "journey": 1,
    "achievements": 1
  }
}
```

This is **metadata**, not a save payload. A manifest existing is NOT proof that gameplay data was uploaded or can be restored. Supported informational domain IDs in the inspector: `progression`, `journey`, `achievements`, `daily_quests`, `equipment`, `inventory`. `pavilion`, `checkpoint`, and `idle_cultivation` are rejected in this phase. None of the supported domains can be restored yet, and economic cross-domain consistency is NOT certified by metadata.

### Firestore Security Rules fragment — read-only, UID-owned

**Do not blindly replace an existing Firestore ruleset.** Integrate and test the specific match into your existing rules before deployment. Leave all unrelated collections' existing protections intact. Until this read-only rule is explicitly deployed, the client can correctly show an unavailable/permission-denied state without affecting local saves.

```firebase
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /jade_cloud_manifests_v1/{userId} {
      allow get: if request.auth != null && request.auth.uid == userId;
      allow list, create, update, delete: if false;
    }
    // Preserve/reconcile the rest of the project's existing rules here.
    // Do NOT add a broad allow-read or allow-write wildcard.
  }
}
```

There is deliberately no client write permission. If a future trusted backend creates manifests, it must authenticate/authorize the UID separately (server libraries are governed by IAM, not mobile Firestore Security Rules). See Firebase official docs: https://firebase.google.com/docs/rules/rules-and-auth and https://firebase.google.com/docs/firestore/security/overview .

## QA acceptance

1. Extract only the changed/new files. Apply the small `cloud_gate1_smoke.patch` to the exact production `tests/phase0_smoke.gd`, then delete the patch file. No legacy QA patches from Realm 4/5 are involved.
2. `PERIKSA_GAME.bat` must pass and now prove: identity boundary still exists; Guest cannot read; read-only manager exists; metadata v1 accepted for synthetic UID; wrong UID / future version / Pavilion / checkpoint / path-like UID rejected; no Cloud write or restore enabled.
3. On Android, repeat the already-known Google sign-in, sign-out, Guest and relaunch flows, then check unchanged local progress. **Do not delete app data** to test.
4. On an explicitly configured Firebase test database with secure owner-only rules, a caller may request `GoogleAccountManager.get_cloud_save_probe().request_preview()`. No document is expected to exist yet. A result of `no_manifest` is correct; `unavailable` means inspect native SDK and access rules; `manifest_found` means metadata only. The app never performs this read automatically.
5. Verify Firestore console shows **no newly written Cloud Save document** from normal gameplay, and confirm no PII appears in logs. Do not enable account-linked restore or upload before the trusted-economy architecture gate.

**Release status:** Cloud Save OFF. Firebase Authentication PASS remains distinct from cloud data backup. The published Privacy Policy / Data Safety / account deletion flow must still be updated before release.
