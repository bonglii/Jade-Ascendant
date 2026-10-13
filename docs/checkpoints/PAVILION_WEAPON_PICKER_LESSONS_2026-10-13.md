# Pavilion picker/popup lessons — 2026-10-13

- Distinguish available summon pool, featured showcase and saved Wish target. Filtering targets to featured made valid weapons inaccessible. Keep independent browsing without silently changing Wish odds or resetting Fate on banner rotation.
- Separate the deliberate 1–5 summon unlock from shop/forge item progression. Verify before/after the exact boundary and all catalog items, not only the two new weapons.
- Reuse existing inspected Pavilion frame assets and size short informational modals to content. Long History/Target content must scroll with fixed close/header. Use one column and short headings on narrow screens; the first two-column native preview broke weapon names and was corrected.
- A new Back override initially swallowed cinematic cancel; the existing native suite caught ten failures. Preserve super() for the original cinematic path and test it alongside new-sheet dismissal.
- The original file uses tabs. An initial space-indented append failed parsing; normalize added code to the source indentation and run the engine import/parse check before UI tests.
- Guard deferred modal layout by generation on resize and stale picker callbacks by epoch. Prevent drag-release from selecting a target and resetting Fate.
- Search/category inputs only change the view and must not invalidate an already reviewed banner document or discard hidden selections.
- Refresh dashboard catalog/assets without repeating D1 schema deployment. Keep existing account, deployment config and records intact; use the absolute Windows PowerShell launcher.
