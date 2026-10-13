# Popup polish lessons

- Inspect native screenshots before claiming popup polish. A full-rect PanelContainer reserves the whole screen even when the description is short: use measured content size with a maximum height.
- Keep header and action controls outside the scrollable body. Move long explanations into the body, not into action text that forces minimum width.
- Stats should keep their own modal mode when inventory refresh or resize rebuilds the surface.
- Style OptionButton.get_popup() separately: button styling alone leaves the gray default menu visible.
- Do not reuse a panel StyleBox with 12px content margins for a scrollbar; it becomes an oversized rail. Author slim track/thumb styles.
- Keep new lesson and publisher files separate; do not append shared LESSONS.md in the incremental patch.
