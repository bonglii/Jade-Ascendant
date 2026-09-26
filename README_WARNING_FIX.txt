JADE ASCENDANT - Pavilion Warning Fix

Only change:
- Renamed local variable `set_name` to `equipment_set_name` in pavilion_runtime_screen_vfx.gd.

Reason:
- Avoids shadowing Node.set_name(), which Godot reports as a warning.

No behavior, layout, cinematic, summon, economy, pity, inventory, or save logic changed.
