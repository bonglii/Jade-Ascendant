extends RefCounted
const ATLAS = preload("res://assets/ui/liveops/odyssey/imperial_v2/ui_atlas.png")
const DIE = preload("res://assets/ui/liveops/odyssey/imperial_v2/dice.png")
const FONT = preload("res://assets/ui/library/fonts/archive_serif.ttf")
const GOLD := Color("f3d9a0")
static var cache: Dictionary = {}
static func texture(kind: String) -> Texture2D:
	if cache.has(kind): return cache[kind]
	var region := Rect2i(0,40,1280,330)
	var target := Vector2i(512,132)
	if kind=="panel": region=Rect2i(70,398,1120,330); target=Vector2i(512,150)
	elif kind=="medallion": region=Rect2i(365,730,525,485); target=Vector2i(128,128)
	var source: Image=ATLAS.get_image()
	var ratio: float=float(source.get_width())/1280.0
	region=Rect2i(Vector2i(Vector2(region.position)*ratio),Vector2i(Vector2(region.size)*ratio))
	var image: Image=source.get_region(region)
	image.resize(target.x,target.y,Image.INTERPOLATE_LANCZOS)
	var result:=ImageTexture.create_from_image(image); cache[kind]=result; return result
static func panel() -> StyleBoxTexture:
	var box:=StyleBoxTexture.new(); box.texture=texture("panel")
	box.texture_margin_left=72; box.texture_margin_right=72; box.texture_margin_top=58; box.texture_margin_bottom=58
	box.content_margin_left=30; box.content_margin_right=30; box.content_margin_top=26; box.content_margin_bottom=26
	return box
static func reduced(node: Node) -> bool:
	var settings: Node=node.get_node_or_null("/root/SettingsManager")
	return settings!=null and bool(settings.get("reduced_effects"))
