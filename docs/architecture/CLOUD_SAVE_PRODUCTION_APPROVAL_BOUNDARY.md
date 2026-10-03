# Jade Ascendant — E4 Production Approval Boundary

Status: **PASS / LOCKED — pre-activation only**.

E4 is the final safety fuse for the restore/cloud-save E-series. Passing E4 does **not** deploy Firebase, activate an account-bound snapshot endpoint, package the candidate native bridge into the production app, enable restore/write, upgrade billing, or merge the QA branch to `main`. It proves those actions remain impossible without a separately reviewed human approval change.

Exact locked E4 checkpoint: `8a6f7b82afc6cd741f3105ffca5325b97b20fabd`. The exact-SHA run completed 15/15 workflows successfully. E3C-B physical Android proof was already locked at `435fa5f54329dd57bd85c5bdf8e9557ae5fc007d` with 50 checks / 0 failures.

## Locked prerequisites

E4 assumes the following phases are already PASS / LOCKED:

- E1 — Restore Review Contract
- E2 — Explicit Restore Execution QA
- E3A — Restore UX Presenter
- E3B — Restore UX Integration
- E3C-A — Production-shaped Account-Bound Read Client Contract
- E3C-B — Native-to-client-contract Android physical proof

The E3C-B physical proof must show exact-HEAD Android DEBUG execution, 50 checks / 0 failures, the E3C-B one-shot marker, and the existing device PASS marker. E4 does not rerun destructive registered restore device QA because E3C-B does not alter that engine.

## What E4 locks

`backend/cloud_save/production_approval_boundary.json` is intentionally false-by-default. Before explicit approval:

- Firebase project ID remains unset in repository policy.
- Firebase deployment remains unapproved.
- Billing / Blaze upgrade remains unapproved.
- Production account-bound snapshot endpoint remains unapproved and unexported.
- Candidate release native bridge packaging remains unapproved and disabled in `project.godot`.
- Additional callable exports remain unapproved.
- Cloud write, production restore execution, automatic restore, cloud-wins, economy writes, and merge-to-main remain unapproved.
- The only pre-approval callable allowlisted by the legacy predeploy gate remains `jadeCloudSaveCapabilities`, which reports cloud save disabled.
- Permanent cloud snapshot scope remains exactly eight permanent domains; active-run checkpoint data remains outside the cross-device permanent snapshot.

## Spark / cost boundary

The project remains Spark-oriented. E4 forbids treating a Cloud Functions deployment or billing upgrade as implied by passing QA. Any Blaze upgrade, billing account link, paid deployment, or live Firebase target requires explicit owner approval with an accepted cost plan. Passing E4 is not a spend authorization.

## Human approvals required before any later activation

A separate reviewed change must identify and approve all of the following:

1. Exact Firebase project and environment.
2. Billing plan and accepted cost exposure.
3. Runtime service identity and least-privilege IAM.
4. Release App Check / Play Integrity and signing identity.
5. Live rules and runtime authorization readback.
6. Logging, monitoring, alerting, and manual rollback.
7. Exact callable export list.
8. Release native bridge packaging.
9. Named owner deploy approval.

No credentials, service-account keys, App Check debug tokens, or private Firebase configuration belong in this gate.

## Meaning of PASS / LOCKED

E4 **PASS / LOCKED** means the E-series architecture and its production activation boundary are complete and fail-closed. It does **not** mean cloud save is live in production.

After E4 is PASS / LOCKED, QA-file cleanup may begin as a separate change. Cleanup must preserve production source, locked save semantics, the eight-domain permanent contract, release configuration, and auditable evidence in git history. Cleanup itself must pass the production build/source regressions before being considered complete.
## Post-lock QA cleanup policy

After E4 lock, executable gate-era CI/device/test harnesses may be retired because their exact-SHA evidence remains auditable in git history. Cleanup does **not** authorize production cloud activation. A permanent `cloud-production-safety.yml` guard remains to enforce the false-by-default approval policy, one-callable server boundary, disabled candidate native bridge, eight-domain permanent snapshot scope, and absence of deployment credentials or commands.

Runtime/source cleanup is performed separately from evidence-harness cleanup so dangling references can be detected with normal production smoke checks before any additional QA-only script is removed.

