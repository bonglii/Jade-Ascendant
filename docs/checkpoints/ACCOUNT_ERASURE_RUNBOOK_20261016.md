# Account deletion — verified support operations

Do not run this on the owner's account to test a release. Runtime deletion was not exercised against real player data in this batch; the actual SQL is verified on isolated SQLite fixtures with two accounts, foreign keys, shared mail and unchanged financial records.

## Player path

In game: Settings → Privacy & Support → Request account deletion (public page) or Email a deletion request. Outside the app: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/account-deletion.html. The player sends a request to yungdevstudio@gmail.com from the Google email used for the game. Public UID is optional; possession of it alone does not prove ownership. No app installation, purchase, receipt, password, OTP or token is required to request deletion. A draft is not a submitted request.

## Owner steps for a real verified request

1. Monitor the inbox daily. Verify ownership against the correct `jade-ascendant` Firebase Authentication user/email; reply to the existing account email when needed. If the requester no longer controls that email, use an appropriate minimal ownership-verification support process. Do not demand a purchase receipt from a non-purchaser. Record the request and explain irreversible loss of account progress/items and any legitimate financial/security retention. A deletion request is not a refund request.
2. In Firebase Console → Authentication → Users, delete **that exact game Auth user only**. Copy its private Firebase UID before deletion into the private case notes; never put it in chat, Git, command arguments or public logs. Do not delete the Google account or project, disable unrelated users, or clear an entire database. This step requires the owner's Firebase permission; the processor cannot independently attest it.
3. Wait at least **65 minutes** after the Auth deletion. Existing Firebase ID tokens can remain valid for about one hour even after refresh credentials are invalidated. Do not purge first and allow an old signed session to recreate the profile/backup during that window. If a trusted in-flight token remains possible or ownership/deletion is uncertain, stop and resolve that case rather than marking it complete.
4. From the project, prepare/check a case in read-only D1 mode:

```cmd
backend\player_identity\process_account_erasure.cmd
```

The prompts require ownership verification, the private Firebase UID and the UTC Auth deletion time. The local plan holds only the derived binding, fixed database identities and SQL/checksums; raw UID is not written into the plan. Review the displayed public UID, row counts and case against the verified request. Never use a public JA UID as a Firebase UID. `.local/account_erasure` is private and not staged.

5. Apply only after review, using the exact plan path printed by the tool:

```cmd
backend\player_identity\process_account_erasure.cmd -Apply -PlanPath "D:\Godot\project\jade-ascendant\.local\account_erasure\CASE-ID\plan.json"
```

Type the exact requested `ERASE CASE-ID` confirmation. This is intentionally a separate operator command and is never invoked by deployment, export, CI, install or publish. The processor pins the existing production databases and regenerates the expected SQL for the bound identity before allowing a write. It erases IAP **gameplay** rows first, then profile rows. D1 `--file` imports have database-scoped execution; the two services are **not one atomic transaction**. A partial failure retains the case and must be resumed/idempotently retried; no completion is reported until both post-checks are zero. Do not edit the SQL or weaken a foreign-key failure to erase another player's data.

6. Review completion.json plus your Firebase deletion evidence. Verify no old account exists in Firebase Auth, no account/profile rows remain, no server gameplay rows remain and no scheduled targeted message remains. The processor retains shared announcements, other accounts, admin credentials and the purchase/wallet/refund/security ledger. Review request correspondence, local incident exports and any data in other services actually used for that player; apply the same deletion/legitimate-retention decision. Remove unnecessary support attachments after resolution. Notify the requester of completion and the specific remaining retention reasons/period, within the policy's 30-day verified-request target.

## Retention and disaster recovery

The processor does not change purchased balances or rewrite financial ledger records. Restrict and review retained purchase/refund/security evidence at least annually; retain only for an actual fraud/dispute/legal need. A generic “fraud prevention” label is not permission to keep unrelated snapshots forever. Do not promise all data is instantly erased.

Cloudflare Time Travel may preserve erased rows in disaster-recovery history for up to 30 days according to the plan. Keep minimum completed erasure case plans securely outside a future database rollback; after disaster restoration, replay affected erasures before serving traffic. Never use a rollback to restore a deleted account for ordinary play. A new sign-in after a completed deletion can create a new Firebase identity; do not silently transfer retained old purchase ownership or old backups into it.

## Boundaries

- This is a support-operated request/fulfilment workflow, not automatic Firebase deletion and not a new unauthenticated erase endpoint.
- No live account was erased by this delivery. Firebase removal remains operator-attested, not machine-verified by this tool.
- Production IAP verification, credit/consume/refund logic and 31 native input hashes are preserved.
- Use the fixture tests for routine regression. Do not repeat a real top-up or delete a real player simply to validate installation.
