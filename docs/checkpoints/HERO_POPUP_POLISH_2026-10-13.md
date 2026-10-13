# HERO compact popup and dropdown polish — 2026-10-13

Requires the HERO Rework patch. UI-only; no equipment, progression, save, set-passive, weapon or backend authority changes.

- Item/material/stat modals size to their content, capped at 72% of the available safe area and 580/470 design px for item/stats. Header and close stay fixed. Equip, ascension and weapon-level actions stay outside the scrollable description. Long item descriptions scroll without hiding actions. Short material descriptions do not create a full-screen blank panel.
- Stats use six compact tiles (HP, Damage, Movement, EXP, Critical Chance, Set Armor) and scrollable set details. Displayed Movement/EXP/Crit now include the catalog's unconditional set bonuses; runtime values are unchanged. Stats mode survives refresh/resize, and Android Back dismisses the popup before leaving HERO.
- Dropdown buttons reuse existing jade/gold SVG button skins. Actual PopupMenu panel, hover, spacing, text, gold chevron and jade/gold selection marks are styled explicitly. Styling only the OptionButton does not style its PopupMenu.
- Scrollbar uses a slim 6px jade track/thumb rather than panel styles with large content margins.

Validation: 128 native Godot checks, zero failures, at 320×568, 390×844, 648×1152 and 896×504. Covers four item types (material, armor, old weapon, chain), popup/frame bounds, header/action separation, real long-description scroll, stats refresh/Back, all six stats tiles, dropdown panel/icons/skin and unchanged equipment/inventory snapshots. Native OpenGL screenshots inspected for detail, weapon, stats, menu and 320px popup. This does not claim physical Android GPU/touch verification.

Incremental patch checks on original HERO source plus diverged shared lessons/publishers; shared LESSONS and old publishers excluded. No server deployment needed. Import/open Godot and export Android. Dedicated publish_hero_popup.cmd prints GitHub commit URL only after a verified normal checkpoint push. GitHub write access unavailable in this session; no publication claimed.
