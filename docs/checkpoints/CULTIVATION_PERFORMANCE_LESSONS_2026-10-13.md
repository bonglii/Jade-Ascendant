# Cultivation performance lessons — 2026-10-13

- The previous idle scene prewarm omitted Cultivation. Include heavy destinations in the retained PackedScene list and test path membership, rather than assuming asset prewarm also warms every scene.
- A Container resize is a layout event, not a data change. Update responsive columns in place; never rebuild the entire mastery tree for height changes.
- Timers labeled load-ready can be cumulative. Split scene construction from total transition, and do not attribute all post-load time to UI construction without a stage measurement.
- Entry must hide initial layout and reveal at final font size/geometry. Test the first visible frame and later frames, not only a settled screenshot.
- A deferred intro can be invoked after the scene has detached. Guard tree ownership before calling get_tree and after awaited frames. An initial QA attempt exposed this; rapid departure now tests both intro and first result.
- Normal baseline entry did not show repeated mastery identity changes. Keep hypotheses separate from measured evidence; do not promise phone improvements from one desktop ready-time sample.
