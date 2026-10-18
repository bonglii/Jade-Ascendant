# Jade Dragon Odyssey checkpoint
Base: 08569aa85e8a46720e301b9b828a6f3c2cc0fe98. Worktree: jade-dragon-odyssey.

Implemented source: 20-tile server-driven board, six daily free dice via login/missions, two signed-SSV ad dice/day, fixed Purchased Jade packs (1/25 and 5/100), caps 10/day and 40/season, atomic IAP wallet debit, idempotent recovery, deterministic milestone Mail outbox, admin scheduling/pause, event-only Heavenweaver Compass and its bounded dragon attack. Existing IAP protocol/catalog and production gates retained.

All generated art recovered from the approved originals. The earlier lost draft's test counts are not evidence for this revision. See ODYSSEY_DELIVERY.md for current checks and external steps.

Remaining external execution: Windows native AAR build/JNI gates using the user's SDK, GitHub push using the user's credentials, Worker deployment using their Cloudflare account, AdMob existing rewarded-unit SSV setup, then Play-installed event smoke. No live deployment, payment, device test or push is claimed from this container.
