# Player Features — regression lessons (appended batch)

- Never mark a CI smoke test PASS merely because it was authored. CI only becomes a pass after the exact tested Git SHA has a green run, and phone swipes / native ad flow are separate evidence.
- Agenda caching must be bounded by the nearest public event start/end boundary, not just a fixed TTL, or upcoming/live/expired labels can be stale even with correct source data.
- 30-day telemetry retention cannot depend only on future player POSTs. A player who stops uploading must not block deletion of old rows. Schedule Profile-only cleanup independently of mail, and tolerate a database where the optional metrics table has not yet been created.
- Exclude killed training dummies from the ordinary enemy targeting group while preserving the no-XP/no-grant/no-kill-signal boundary. Test with production scripts in a disposable user-data directory.
- Run real SQLite tests from the committed source tree in GitHub Actions. Portable tests with stubbed dependencies are useful before the full project is available, but they cannot replace exact-SHA integration tests.
- Use a strict branch/HEAD/dirty preflight, source checksum verification, reversible local overlay and backups. Never leave a silently half-written checkpoint when one file copy fails.
- GitHub write 403 is an actual authorization blocker; never fabricate a commit link or claim source has been pushed. Keep changes in a verifiable package and avoid main/production until the existing release gates pass.
