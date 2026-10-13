# HERO loadout/profile lessons — 2026-10-13

- Avoid rebuilding a whole screen for a local equipment toggle. Preserve the popup/backpack/filter nodes and scroll offsets; update their committed loadout state together.
- Every deferred coroutine that awaits a frame and uses replaceable UI references must check the modal generation before and after each await. Removing an old Control does not cancel its coroutine.
- Bind button callbacks to the displayed item and action state, then reject stale callbacks and duplicated same-frame presses. Do not add a long debounce that makes normal taps sluggish.
- During this fix, hiding a PanelContainer with visible=false prevented reliable child layout and failed 16 compact-popup checks. Keep layout active and use self_modulate alpha until sizing completes; all 128 checks then pass.
- ProgressBar's default step quantized EXP fractions. Set step=0 for a 0–1 authority ratio and verify a non-integral EXP fraction plus MAX.
- Read rank, player identity and connection state from existing managers. Shorten only the displayed rank/name; keep full rank and UID available in the existing profile/tooltip.
- Record lessons in a dedicated new checkpoint file and keep shared LESSONS out of incremental patches. Never overwrite a changed remote baseline; verify the source blobs and update the authorized checkpoint using a head lease.
