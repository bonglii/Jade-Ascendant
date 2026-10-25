# Current save/account behavior

Verified against client/source checkpoint `06a7b39fba78b0fb1a3dfdfb31f549c8d222d5cc`; this follow-up does not migrate or repartition saves.

- Ordinary permanent progression is stored on the device. The existing nine-domain Google-owned backup contains progression, equipment, inventory, cultivation mastery, Journey, Pavilion, achievements, daily quests and idle cultivation. Signing out/changing Google identity does not automatically clear or load a different local progression directory.
- Backups are account-owned and revisioned. Automatic backup runs only after the existing owner/approval state matches the current account; it does not upload an approved account A save as account B. Recovery is explicit, requires a safe idle state, backs up the replaced local snapshot, and closes/restarts after a committed restore.
- The public server UID belongs to the verified Google/Firebase identity. Different accounts get distinct server UIDs; the database has a UNIQUE constraint and collision retry. The same account on another device intentionally gets the same account UID. A local/guest profile has a separate device UID. Nicknames are display data and can match; they are not account identity.
- Paid Jade, verified purchased equipment and event/receipt authority remain on the server and are account isolated. They are not copied merely because local free progression remains visible after changing login.
- Therefore this is **hybrid storage, not automatic full per-account local-save switching**. On one phone, changing from Google A to B can leave the ordinary local progress/name visible while the server UID and purchased wallet follow B. That is shared local progression, not a server UID collision. Full automatic local-save isolation per account would be a separate migration/UX change.

## Evidence

`backend/player_identity/identity.test.mjs` and `progress_backup.test.mjs`: 26 tests passed, including concurrent same-owner registration, distinct-owner UIDs, collision retry, account-isolated backup reads/writes, revision conflict protection and paid-ledger exclusion. These local tests do not assert a live database migration or a new phone test.
