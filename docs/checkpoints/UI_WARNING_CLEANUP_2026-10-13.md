# UI warning cleanup — 2026-10-13

The supplied editor screenshot reports two local `ready` variables shadowing Node.ready in Daily Quest, a reused `loading` local in Trials presenter, three `scale` locals and one `name` local shadowing Control/Node properties in HERO, a reused `empty` local in HERO, and an incompatible ternary in the event identity banner.

Rename those locals only. Keep inherited properties and named child nodes unchanged. Normalize the event banner coordinate branches to float. The same incompatible ternary pattern was also found in Pavilion's PI/zero angle and two HUD StringName/string scene-name fallbacks; normalize branch types there as well. No assets, rewards, dimensions, animations or gameplay semantics change. No warning suppression is added.

Validation: a temporary QA-only `gdscript/warnings/incompatible_ternary=2` setting made the analyzer pinpoint all offending lines. A runtime script-load scan over repository scripts excluding parked monetization finished without incompatible-ternary errors after cleanup. The QA project setting was restored; the shipped project.godot is unchanged. Existing HERO, menu/touch and event identity regression suites validate affected behavior.

Apply after previous UI patches; re-import Godot and re-export Android. No backend deployment. The protected publish_warning_cleanup.cmd prints the actual verified GitHub commit URL after push.
