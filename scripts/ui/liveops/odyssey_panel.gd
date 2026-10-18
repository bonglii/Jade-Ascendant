extends PanelContainer
const Art=preload("res://scripts/ui/liveops/odyssey_art.gd")
var frame: StyleBoxTexture
var surface: StyleBoxFlat
func _init() -> void:
	var base:=StyleBoxFlat.new(); base.bg_color=Color.TRANSPARENT; base.set_corner_radius_all(12)
	base.content_margin_left=30; base.content_margin_right=30; base.content_margin_top=26; base.content_margin_bottom=26
	surface=StyleBoxFlat.new(); surface.bg_color=Color(0.008,0.10,0.115,0.985); surface.set_corner_radius_all(12); surface.shadow_size=8; surface.shadow_color=Color(0,0.01,0.02,0.35)
	add_theme_stylebox_override("panel",base)
func _ready() -> void:
	frame=Art.panel(); frame.draw_center=false; resized.connect(queue_redraw); queue_redraw()
func _draw() -> void:
	if surface!=null: surface.draw(get_canvas_item(),Rect2(Vector2(18,8),size-Vector2(36,16)))
	if frame!=null: frame.draw(get_canvas_item(),Rect2(Vector2.ZERO,size))
