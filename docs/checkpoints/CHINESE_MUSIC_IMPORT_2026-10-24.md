# First-import closure —24October2026

Owner published music as5fc8a6fd54becd0322d129cf9396f003f33e5ff1. Its dedicated
music CI passed (run40081952097), but four release jobs stopped at first import.
Exact-SHA artifact12555831453 identifies missing Ogg importer metadata as the
first cause, followed by dependent autoload compilation failures. The test had
prepared resources before enabling autoloads and therefore missed the packaging
omission. This was an author validation gap, not a phone/ISP/payment problem.

Two standard Godot4.7.2-generated .ogg.import sidecars are now shipped. The
isolated suite copies actual committed sidecars and performs a single strict
fresh-cache import with autoloads enabled from the start. Both music files and
all game/audio behavior remain byte-identical. Source QA rejects missing or
mismatched metadata. Existing music gains, loops and SFX are preserved.

Evidence: full shared3349-file fixture imported from an empty cache in24.6s,
then current PlayerComfort60checks passed. Isolated audio26checks passed with
clean import/runtime logs. Two child-process regressions verify that long normal
output cannot hide the first error and that omitted sidecars fail before engine
invocation. All nine existing production gates pass. No new economy/native/phone
claim; unchanged previously passing combat/UI suites are reused.

The small portable package includes all publishing/sync dependencies and backups.
For these two files only, an existing editor-generated sidecar can differ solely
in its valid UID line; all source/cache paths and import parameters must match.
It is backed up before canonical metadata is installed. Other local differences
stop before writes. Full local publisher/sync/retry evidence is in the package.
Owner exact-SHA CI follows the new push. No Worker/native deployment is needed;
one final AAB follows green CI using backend/player_identity/export_production.cmd.
