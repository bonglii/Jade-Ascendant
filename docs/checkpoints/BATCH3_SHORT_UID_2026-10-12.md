# Batch 3 addendum: compact public UID

Requested shorter UID after the profile patch. Apply this incremental patch after Batch 3 (`43bd6bf`).

- Visible/copyable UID is now `JA-XXXX-XXXX-XXXX-XXXX`: 22 characters instead of 38. The 16 payload characters encode 80 random bits with an alphabet excluding I, L, O, and U.
- New profiles still generate a full random 128-bit reference; existing profiles deterministically derive the same compact UID from their original reference. The full original value is retained in `legacy_player_uid` for future server mapping. It is not exposed by the public snapshot.
- Migration commits atomically before displaying the compact UID. If saving is blocked, the UI continues showing the previously persisted long UID; retrying profile load after writes are available completes migration. Names and gameplay progress are preserved.
- Load supports both old and new formats. Compact UID/reference mismatches are rejected. Backup recovery, future-version protection, and interrupted-write protection remain active.
- UID remains local-profile identity, never an authentication or reward credential. Batch 4 server registration must enforce public-UID uniqueness and bind it to authenticated ownership; client-generated randomness does not replace that check.

Validation: 537 real runtime checks and 9 restart checks passed. The runtime suite includes an independent base32 vector, blocked migration, deterministic conversion, retained original reference, unchanged name, idempotence, mismatch rejection, all previous profile/save cases, and byte-identical gameplay saves during profile operations. Seven real-render checks passed including exact short-UID clipboard content and label fit. Android native keyboard/touch validation remains pending. Baseline UI shutdown diagnostics remain unchanged.
