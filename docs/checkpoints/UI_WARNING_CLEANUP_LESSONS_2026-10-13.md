# UI warning cleanup lessons — 2026-10-13

- Do not name local variables ready/name/scale in Node or Control scripts. Use offer_available, set_display_name and ui_scale. Keep local labels distinct from later Node references in the same parent scope.
- Godot's analyzer checks ternary branch compatibility before an outer cast. Convert StringName to String inside its branch. Use matching float literals in coordinate/angle branches.
- Runtime smoke tests alone do not establish a warning-free editor. Use a temporary QA warning-as-error setting to locate reported type warnings, then restore QA configuration. Do not suppress warnings in production to hide them.
