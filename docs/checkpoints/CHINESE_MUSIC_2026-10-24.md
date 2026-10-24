# Approved Chinese music —24October2026

Owner chose the recommended BiteMe Games Chinese Game Music and supplied the
original v1.0 archive. All menus and Pavilion use Lotus Pond's authored loop;
Journey and boss use Dragon Dance's authored loop. Assets/provenance and credits
are under assets/audio/chinese_music. Runtime keeps the established quiet
-18.5dB mix, existing crossfade, reward ducking, music settings and background pause.
Switches between contexts sharing one stream preserve playback, including while
paused. V2 / arsenal weapon cues and the fixed quiet touch cue are unchanged.

Both Ogg files preserve original 48kHz stereo frame counts (64.000000s and
68.571354s); static gain only, no trim/fade/compression. Total2,500,411bytes.
Actual isolated AudioManager playback validates26checks: aliases, advancing
position, same-player continuity, duck retention, background freeze/resume,
crossfade, both real loop wraps, retained SFX and cleanup. Fixture teardown waits for the audio mixer to release the last Ogg playback;
final import/runtime logs contain no errors or warnings. Other autoloads expose
signal stubs only; this is engine evidence, not full gameplay or Android testing.
The existing nine live payment gates remain unchanged. Prior passing unrelated
combat/UI suites are reused. New exact-SHA audio CI runs only the focused scope.

The portable owner publisher includes all sync/guard dependencies, validates
binary Ogg hashes, keeps backups/resumable receipts and uses ordinary fast-forward
sync and normal push. No Worker deploy, migration, native rebuild, event activation
or push notification. New commit/push, exact-SHA CI, final AAB and phone checks are
separate owner stages. One final AAB via backend/player_identity/export_production.cmd
includes the previous PlayerComfort client changes plus this approved music.
