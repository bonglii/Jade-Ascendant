# Production Hero V1.1.1 — Navbar Anchor Warning Fix

Fix:
- Removed runtime `NavBar.position` / `NavBar.size` writes from `_layout_screen()`.
- Shared production navbar geometry is now controlled only by the scene
  anchors/offsets, exactly like the other hub screens.
- Inventory scroll-bottom calculation uses the same fixed navbar top
  (`height - 98`) without mutating the anchored navbar.

Reason:
Godot warns when `size` is assigned to a Control with non-equal opposite
anchors because the anchor layout overrides that size after `_ready()`.

Visual result:
- no navbar visual change
- Hero tab remains active
- no change to Hero/inventory layout or gameplay logic
