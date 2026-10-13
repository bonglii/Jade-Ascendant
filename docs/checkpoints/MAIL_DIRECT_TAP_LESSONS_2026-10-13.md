# Mail direct tap lessons — 2026-10-13

- Responsive layout and tap navigation must share the same width threshold. The earlier paper reader redesign updated the layout boundary but left selection at 450px. Test opening via the actual card signals across both sides of the layout breakpoint, including an already selected card; checking visible geometry alone cannot catch this.
- Preserve swipe/post-scroll guards when making the whole card open the reader. A scroll gesture must not trigger navigation or rewards.
