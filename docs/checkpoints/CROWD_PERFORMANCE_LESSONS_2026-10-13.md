# Crowd performance lessons — 2026-10-13

- Inspect existing optimizations first: main targeting already caches for 0.12s and spawners already apply stage population caps. Adding another stale cache or reducing enemies would change gameplay without identifying the bottleneck.
- Reject geometric impossibilities before dynamic status/method checks; preserve a current-position narrow phase, order, radius and per-phase hit identity. Differential tests against the previous algorithm are required for collision optimizations.
- A faster synthetic sweep is not a measured game FPS gain. Record phone wall-frame tails plus CPU process/physics and rendering counters, and distinguish draw calls from GPU time.
- Exclude deliberate pause intervals from wall-frame samples. Bound retained storage and describe P95 behavior when the cap is exceeded.
- The first native crowd probe paused on a real level-up after kills, so it could not produce a full 12-active-second performance window. A separate isolated probe freezes auto-attack timers and prevents player death while leaving enemy movement/collision/rendering active; production gameplay remains untouched.
