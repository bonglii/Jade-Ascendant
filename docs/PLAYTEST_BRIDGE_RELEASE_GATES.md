# Release gates — Playtest Bridge

- [x] Purchase wallet -> canonical onboarding source-only path implemented and tested locally
- [x] Preserve canonical revision, pity, stages and equipment on verified Play replay
- [x] Fail closed if canonical D1 schema, signed identity or onboarding gate unavailable
- [x] One candidate Worker entrypoint for credit, signed RTDN, refund cron, recovery, paid loadout and progression read
- [ ] Genuine remote server battle adjudicator; LOCAL victory screen remains non-authoritative
- [ ] Native Kotlin + Godot gameplay integrated to working Android build and local working tree
- [ ] Real Play sandbox purchase/refund/replay/2-device QA and Cloudflare signed RTDN setup
- [ ] D1 production backup/migrations + monitoring + controlled enablement after approval

Do not flip `JADE_CANONICAL_ONBOARDING_RC12_ENABLED` or any other monetization gate during source-only development.
