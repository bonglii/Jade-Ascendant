# Jade Ascendant — UI / Popup QA Standard

**Standard:** `QA-UI-01` – `QA-UI-10`, `QA-ENG-01` – `QA-ENG-02`
**Updated:** 2026-09-29 (Hero font-authority / selection reflow QA added after Mail Production checkpoint)
**Status:** permanent acceptance criteria for new/reworked UI; existing LOCKED screens change only for real regressions.  
**Source precedence:** approved current repo / source manager authority / project handoff. This document does not modify reward/save functionality.

## QA-UI-01 — Safe scrolling and tap separation
- Independently scrollable areas (mail list vs letter body) do not move each other.
- Swipe gestures never trigger select, claim or close; use touch scroll deadzone and release-time guard where needed.
- Hiding scrollbar visuals must not disable touch swipe, keyboard/scroll accessibility or scrolling itself.
- Long content remains reachable in short displays without obscuring the CTA.

## QA-UI-02 — No excessive deadspace
- Popup body, card and footer remain proportional to real content without large unintentional empty bands.
- Empty, one-item and many-item states must look deliberate; any pinned reward slots keep a stable size.
- Avoid full-height empty mail lists when the source has only a few entries.

## QA-UI-03 — Mobile readability
- Check logical 648 × 1152 and debug window 405 × 860, then a real Android device.
- Contrast against art, font sizes, button touch targets, wallet/HUB NAV safe zones, orientation and viewport stretch must remain legible and actionable.
- Do not make all text smaller just to force a two-column layout; switch to a reader/inbox toggle when the effective width is too small.

## QA-UI-04 — Dynamic description never breaks
- Long English/Indonesian titles, senders and bodies wrap inside a bounded container.
- Configure parent `Container` minimum sizes as well as `Label.autowrap_mode`.
- Summarized inbox titles may ellipsize with the full title readable in the selected letter. Full mail body is never silently truncated.
- Long letter title and body must scroll in the reading zone; attachments and CTA remain pinned.
- Reward amounts, status, localization and empty state must not become one glyph per line, overflow, overlap or unexpectedly resize the footer.

## QA-UI-05 — Popup background conformance [LOCKED]
- The **visible popup frame** defines the intended artwork boundary. Background must align to its **interior shape**, not blindly paint a full rectangular wallpaper underneath an irregular ornament.
- For rectangular windows, clip to the explicit inner rect. For **irregular ornamental frames**, derive the true closed interior alpha silhouette of the *approved frame art* and mask the background to it. Background and frame must then share the **exact same source dimensions, stretch mode, and popup rect**. Do not guess a percent inset or leave dark rectangular scrims hanging outside the silhouette.
- The approved source PNGs remain **byte-for-byte untouched**. If a fitted derivative is needed, add a separate clearly named asset; alter alpha only and preserve the original background RGB and composition.
- All popup layers, decorations, footer and CTA must stay inside their intended visible surfaces. Frame decoration can extend around the art by design, but must not be accidentally clipped at popup edges, and frame visuals must not capture touch events.
- Crop/fit/stretch are chosen explicitly for both the art and its frame. No black gutters, opaque dark strips, squeezed frame, or random wallpaper around the border in 648×1152, 405×860 and actual device frames.
- Any dimming/scrim on a patterned or transparent frame must follow the *same silhouette* or stay inside a local readable card; an unmasked full-width ColorRect is not acceptable over an alpha-masked background.
- Applies to other premium popups going forward; an already LOCKED screen is touched only for a demonstrated issue, not restyled automatically.

## QA-UI-06 — First-render layout stability [NEW LOCKED]
- Inbox height/width, parchment width and CTA positions must be identical when first opened and after selecting another mail with the same item count.
- A manually sized floating panel must use a non-Container `Control`/`Panel`; a `PanelContainer` may override its rect to satisfy dynamic child minimum sizes.
- Do not "fix" a visual size issue solely by deferring a refresh; the ownership of its rect and measured constraints must be deterministic.

## QA-UI-07 — Text stays within its reading surface [NEW LOCKED]
- Letter title, sender and full body stay within the parchment's inner padding even for long English/Indonesian content.
- A bounded reading control with explicit horizontal constraints must own wrapping and vertical scrolling; prefer raw-text `RichTextLabel` for long mail when wrapped `Label` minimum sizes can expand parents.
- Attachment slots and actions stay in a stable pinned footer; longer text never makes the parent or paper expand.
- On all viewport sizes and across selected/claimed/no-reward/empty states, never render text beyond the paper border.

## QA-UI-08 — Transparent themed inbox / sidebar [LOCKED for Mail direction]
- Main inbox container is transparent, not a flat dark slab that hides approved scenery. Maintain label contrast with local outlining/shadows, not an opaque blanket.
- **Each mail item owns its own xianxia-themed gold/jade border**, with a clear selected state, sufficient contrast for both filled and unfilled mail, and readable sender/status text.
- Item borders, hover/pressed states and tap hit targets remain independent of background decoration; content scrolling must never fire a card selection.
- First render and subsequent selections retain identical column bounds for unchanged entry counts; translucent panel style must not accidentally retain a shadow or black fallback.
- No ornamental treatment should silently add permanent save states, unread semantics, additional rewards or new production content.

## QA-UI-09 — Text containment and indivisible reward amounts [LOCKED]
- **Every text element** (titles, senders, statuses, body, empty states, localization, item descriptions, tooltips, button labels, numeric amounts) must stay inside its designated UI surface at the tested effective width. A text control may not force a parent container beyond its allotted rect.
- Prose uses natural word-wrap at word boundaries; do not let a container collapse to a one-glyph column. Long full descriptions live in a bounded, vertical-scrollable reading surface. Summaries may use intentional line limits/ellipsis, but a full message must remain accessible in its reader.
- **Numbers and short atomic tokens are never wrapped into individual characters.** This applies to reward quantities (`×150`, `×3`, `×1000`, `×9999`), wallet values, currency labels, counters, percentages, item stacks and abbreviated status tokens. Explicitly set `autowrap_mode = TextServer.AUTOWRAP_OFF` on quantity labels created by generic `_label()` helpers that otherwise default to wrapping, and reserve sufficient width or choose a safe compact presentation if a value grows.
- For `HBoxContainer` reward tiles, account for icon width + label width + separation + borders/margins. If there is not enough horizontal space, adapt the *tile content* layout without shrinking all fonts or allowing digits to become a vertical string. Transparent tiles must remain transparent; fixing text must never replace the approved card art.
- Empty/no-reward states must **not** insert an auto-wrapped label into a centered, unconstrained reward row where it can receive only a glyph-width allocation. Use the existing bounded notice area or an explicitly width-constrained placeholder.
- Verify with real catalog values and stress content: empty, one reward, two rewards, long translated titles, very long mail, `×3`, `×150`, `×1000`, `×9999`, first render and after switching the selected item. Test nominal 648×1152, 405×860 and real device. Fix measured container constraints, not only `autowrap_mode`.

## QA-UI-10 — Stable typography on first paint and repeated selection [NEW]
- Text must never visibly jump **large → small** or **small → large** after a popup, menu, tab, or card becomes interactive. Test the first rendered frame, first selection and repeated rapid switching on a real Android device.
- Treat font size, wrapping, clipping, and content bounds as a coherent layout: applying a text-size policy after cards become visible can cause a second layout pass and a visible reflow.
- Rebuilding an entire card/list on selection is a regression risk, not an automatic bug. Prefer updating selected state on existing controls when the number and content of entries have not changed; rebuild only when the data model changes.
- When a deferred fit is necessary, make the affected subtree non-interactive/non-visible until the final measurements and font policies settle. Do not hide a real overflow by clipping or shrinking all text.
- Validate at 648×1152, 405×860 and on HP: Hero slots/filter/collection, 7-Day Login cards, Chapter/Stage selection, Backpack, Trials and full text localization. LOCKED screens are modified only after a reproduced regression.

## QA-ENG-01 — Godot warnings-as-errors / inherited member shadowing [LOCKED]
- Audit local identifiers against inherited `Node`/`Control` members, properties and signals **before delivery**. In Godot 4.7.2, `ready` is an existing `Node` signal and must not be used as a local variable name; prefer explicit names such as `has_claimable_attachment`.
- Check other inherited members and project-specific class bindings for the same shadowing class (`rotation`, `name`, etc.); do not rename unrelated identifiers without evidence. Confirm changes with GDScript parse/`PERIKSA_GAME.bat` when available; a static source audit alone does not certify Godot engine QA.
- Warning fixes must preserve gameplay/UI logic and include a narrow before/after diff. Do not use warning cleanup as justification for redesigning any LOCKED screen.

## QA-ENG-02 — One effective font policy / no competing runtime writers [NEW]
- Record **which script owns an element's final font size**. A periodic visual-polish manager must not decrease a font already raised by a screen-specific or shared readability policy; apply a minimum size only if the current effective value is smaller.
- Before adding a new `add_theme_font_size_override`, inspect other writers, timers and `node_added` callbacks for the same control. An unchanged font must not be rewritten on every tick; keep refresh logic idempotent and avoid repeated layout invalidation.
- Test the production scene after the readability manager, shared resource-bar manager and screen-specific polish have all initialized. Verify no post-input font-size oscillation, clipped captions, or changed click targets.
- This contract does **not** authorize blanket global font enlargement or restyling of approved/LOCKED screens; fix a demonstrated overlap at its actual owner, with a minimal diff and HP QA.

## QA execution / production gates
1. Audit actual current source/scene/resources/dependencies before any patch. Protect unpushed local work; do not infer state from an old ZIP.
2. Preview visual direction in isolated LAB, no real source/save/reward grants. Use exact approved images without regeneration.
3. Self-check constraints, content lengths, gesture handling, scroll/close/Back/rapid open-close, fixed footer, image bounds and source-path integrity.
4. If Godot is available, perform headless/import/parse checks. Otherwise label **STATIC REVIEW ONLY**, not engine-tested.
5. User runs `PERIKSA_GAME.bat` on changed files, then targeted real-device verification. No blanket QA PASS before observed test evidence.
6. Only after user visual approval, promote LAB to production using manager authority. Reuse universal reward claim result and semantic reward delivery. Cleanup CMD-only after dependency scan; do not commit or push without approval.

## Mail LAB V2.11 — USER VISUAL DESIGN LOCK (2026-09-28)
- User explicitly approved the **visible Mail LAB V2.11 design**. Lock the approved three original artworks and fitted background, the frame/background containment, existing headline, parchment reader, transparent System Mail column, parchment-colored bordered inbox items, reward-tile transparency, compact reward typography and close-button placement.
- The visual lock is **not** a production/runtime/save gate. A warning-only source patch is permitted without reopening visual design approval; production still requires manager-authoritative integration, `PERIKSA_GAME.bat` and targeted real-device reward/save QA.
- Preserve LAB/mock-only behavior until promotion: do not grant rewards from the LAB or add a second claim-result/flying presenter.

## Mail-specific in-scope contract (2026-09-28; LAB V2.3)
- Existing production `LiveOpsManager.get_mail_entries()`, `get_mail()`, `mark_all_mail_read()` and `claim_mail()` are authoritative. No new claim/delete logic in visual LAB.
- Production has welcome mail (150 Spirit Stones + 3 Refinement Shards) and a non-reward Seven-Day notice at approved HEAD `4fbb286`.
- Mock content exists **only inside LAB**, clearly marked `LAB PREVIEW / NO REAL GRANTS`.
- Do not modify Home UI, universal reward presenters, other LiveOps screens, `main`, or permanent save schema while iterating the isolated Mail LAB.

**V2.3 asset/geometry evidence:** the approved frame PNG is 941×1672 with a closed central alpha interior (measured native bounding box x=68..873, y=147..1526). `spirit_messages_background_frame_fitted.png` is a derived alpha-masked copy of the approved background; it uses that interior silhouette, a 4px underlap behind the frame and a 1.2px feather to avoid seams. Do not replace the approved original background or frame.
