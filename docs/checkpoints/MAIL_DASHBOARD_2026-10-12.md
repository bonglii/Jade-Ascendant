# Mail dashboard checkpoint — 2026-10-12

Scope: existing player identity Worker + PROFILE_DB; admin mail studio and Godot mailbox integration. Existing IAP and cloud-save sources remain unchanged.

Delivered: authenticated administrator session, CSRF/origin checks, bounded login attempts, recipient preview, UID/all recipient snapshot, immutable send and idempotent retry, expiry/cancellation, recipient history, owner-bound player inbox/read/delete/claim/ack, durable local reward marker and recovery.

Asset review: reused the actual mailbox scene, frames and reward presentation. Added sync/status controls to the existing layout; dashboard is a new self-contained emerald/gold/parchment UI with no external asset dependencies.

Verification: Node 28 tests; browser login/preview/send/history/recipient detail/logout and mobile overflow checks; Godot mailbox/Skill Book regression 153 checks; server-mail 26 checks; restart 10 checks; intentional interrupted multi-domain journal fixture 6 checks and recovery 10 checks. No real player messages sent during QA. Browser SQL database and player identities are disposable fixtures.

Limits: local gameplay wallet, ordinary Stone/Shard rewards only, broadcasts to currently registered recipients only; unfinished claims remain installation-bound. No automatic reinstall transfer, global wallet authority or premium purchase grant. Windows scripts reviewed, not run here. Live deployment and Android export still required.

Lessons: inspect full HTTP transport and edge runtime before diagnosing auth; never loosen TLS or bypass JWT verification. Route laptop hotspot DNS inside the dashboard browser process. Bound stale token responses to the current signed account context. UTF-8 body byte budgets must allow documented character limits. Godot dictionaries reject duplicate localization keys: reuse existing keys and run import after localization changes. QA expiry fixtures must use integer server timestamps. Source tests do not substitute for Windows deployment or live Android acceptance.
