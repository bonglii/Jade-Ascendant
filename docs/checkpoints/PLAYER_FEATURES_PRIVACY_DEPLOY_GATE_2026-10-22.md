# Player Features — Profile-only migration and privacy release gate

Status: **HOLD**. No remote D1 schema was changed and no production Worker was deployed by this batch.

## Optional analytics: disclosure draft for owner/legal review

English proposal: “With your separate, off-by-default choice, Jade Ascendant can send limited gameplay events (app session start, tutorial completion, stage entry, completion, defeat, and exit), stage/chapter numbers, an event identifier and duration to our player-profile service. Reports are linked to your authenticated game account to prevent duplicates and apply a 200-event-per-UTC-day limit. Reports are retained for up to 30 days; the operator dashboard shows 7-day aggregate counts and averages. They are self-reported client events, not proof of rewards, purchases, achievements, retention or all players. Turning off the option stops new uploads and clears the local queue; already uploaded records may remain until deletion/expiry. Account deletion requests also delete the account's associated gameplay-event rows. This is optional and is not required to play.”

Proposed Indonesian: “Dengan pilihan terpisah yang secara bawaan nonaktif, Jade Ascendant dapat mengirim peristiwa permainan terbatas (mulai sesi, tutorial selesai, masuk stage, menang, kalah, keluar stage), nomor chapter/stage, ID peristiwa dan durasi ke layanan profil pemain. Laporan terikat ke akun game yang sudah terautentikasi untuk mencegah duplikasi dan membatasi 200 peristiwa per hari UTC. Penyimpanan paling lama 30 hari; dashboard operator hanya menampilkan hitungan serta rata-rata agregat selama 7 hari. Laporan berasal dari klien, bukan bukti pemberian hadiah, pembelian, prestasi, retensi pemain, atau keseluruhan pemain. Mematikan pilihan menghentikan pengiriman baru dan mengosongkan antrean lokal; laporan yang sudah diterima dapat tetap tersimpan sampai dihapus/kedaluwarsa. Permintaan penghapusan akun juga mencakup baris statistik gameplay akun tersebut. Fitur ini opsional dan tidak wajib untuk bermain.”

These are **draft paragraphs only**, not a claim that pages or Play Data safety have been updated. Align `backend/player_identity/public_trust_pages.mjs` generator, `docs/privacy-policy.html`, `docs/account-deletion.html`, `release/privacy-policy.html`, `release/account-deletion.html`, `release/privacy-policy.template.html`, and Play Data safety after publisher review. Keep generated pages and tracked copies byte-identical; the existing base branch already has one privacy-page mismatch CI failure.

## Profile-only migration preflight (do not perform without approved rollout)

1. Check exact repository SHA and current full-branch validation, with a durable backup of the existing `jade-player-identities` D1 database.
2. Read `backend/player_identity/companion_schema.sql`; verify FK to existing `player_identities(owner_binding)` and existing table names with a staging SQLite/D1 migration first.
3. Test live account access and opt-in PUT/DELETE behavior in **Profile staging**, with separate account A/B and two devices; no IAP tables or monetization Worker migrations.
4. Review same-release privacy pages and Play Data safety prior to activating remote collection. Anonymous agenda remains read-only and includes only approved published events.
5. Require human approval for Profile Worker deployment and Play Console release. Use established --keep-vars deployment commands, preserve all existing service keys, confirm dashboard login/CSRF and no logs with identity or tokens.
6. Export a signed new AAB with a new version code, test narrow-phone GUI swipes, live Firebase refresh/opt-out, account switching, zero-grant practice, and clean install/update preserving existing saves.

Do not use this file as a deployment script or release approval.

### Retention implementation addition (not deployed)
The opt-in metrics batch now includes an hourly Profile-only cleanup of records older than 30 days, independent of future uploads, executed from the Profile Worker existing minute-level cron. It first verifies the optional metrics table exists and runs independently from the established mail job. Validate this in Profile staging *after* schema migration, then re-check Cloudflare cron metrics and access permissions; it is not active in production as delivered.
