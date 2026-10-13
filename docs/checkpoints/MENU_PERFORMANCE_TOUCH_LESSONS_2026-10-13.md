# Menu performance / touch lessons — 2026-10-13

1. Hiding legacy UI does not prevent its ready/signal handlers constructing dozens of controls. Mark production ownership before parent-ready and retain a real fallback path.
2. Incremental UI needs both a generation guard and actual tree ownership. Initial headless tests passed but native navigation exposed get_tree()==null on a detached record builder. Add exit-tree invalidation and before/after-yield tree checks; test detached builders explicitly.
3. Touch hover is a presentation policy, not permission to disable all controls. Preserve pressed skin, eligibility and normal desktop hover; coalesce theme listeners to avoid creating another performance hotspot.
4. Do not interpret anonymous Firebase setup as a user Google login. Let local Guest play while preserving serialized real account operations, and measure safe durations before blaming a provider.
5. Report scene-ready desktop samples separately from complete incremental list assembly and Android provider/device latency. Two after samples varied from 100 to 165 ms; do not market one sample as a guaranteed speedup.
6. Existing regression scripts enforce their own isolated user:// prefix. The first login-cycle invocation stopped safely because the test prefix was wrong; use jade_login_cycle_qa for that suite and never weaken the safety guard.
