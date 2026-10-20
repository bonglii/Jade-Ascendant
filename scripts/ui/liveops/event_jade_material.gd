extends RefCounted
## Transparent SVG corners; no atlas matte and no opaque rectangular underlay.
const Surface=preload("res://scripts/ui/liveops/event_jade_surface.gd")
const BUTTON: Texture2D = preload("res://assets/ui/liveops/odyssey/material/jade_button.svg")
const MEDALLION: Texture2D = preload("res://assets/ui/liveops/odyssey/material/jade_medallion.svg")
const PANEL: Texture2D = preload("res://assets/ui/liveops/odyssey/material/jade_panel.svg")
const PAPER: Texture2D = preload("res://assets/ui/liveops/odyssey/material/ivory_card.svg")
static func skin(texture: Texture2D, margin: float, padding: float) -> StyleBox:
	var box := Surface.new()
	box.texture = texture
	box.corner = Vector2.ONE*margin
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
static func button(disabled: bool = false, pressed: bool = false) -> StyleBox:
	var box := skin(BUTTON, 16, 14)
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.modulate_color = Color(.66,.78,.70) if disabled else Color(.8,.92,.85) if pressed else Color.WHITE
	return box
static func panel(paper: bool = false) -> StyleBox:
	return skin(PAPER if paper else PANEL, 20 if paper else 24, 22 if paper else 18)
static func medallion(disabled: bool = false, pressed: bool = false) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = MEDALLION
	box.modulate_color = Color(.66,.78,.70) if disabled else Color(.8,.92,.85) if pressed else Color.WHITE
	return box
