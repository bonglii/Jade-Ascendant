# Combat notice lessons — 2026-10-13

1. The previous cultivation patch applied autowrap to DAO FOUNDATION inside an HBox while its expanding counter took nearly all space. Reserve width for prose and give the numeric counter its natural minimum; test the intro header as well as the newly added panel.
2. Do not write anchored Control.position=(0,0) during reveal/hide. Animate alpha/scale while one shared helper owns viewport-safe position, clearing old offsets whenever it repositions.
3. PanelContainer lays out its direct children. A separately anchored stage badge directly inside it covered the main warning. Put the badge in content flow; use plain overlay Controls only for border ornaments.
4. chain().set_parallel(true) can make fade-out start alongside the hold interval. Build explicit sequential steps with parallel() only for simultaneous enter/exit properties. Assert opacity at elapsed times, not only node visibility or active flags.
5. The first duration test covered only reduced effects and missed the standard animation bug. Both branches now have independent elapsed-opacity and completion checks; native capture also confirms full-opacity reading time.
6. Keep HUD-safe geometry tests scoped honestly: pre-existing narrow top-HUD minimum widths do not become a claimed full-HUD fix merely because notice rectangles fit.
