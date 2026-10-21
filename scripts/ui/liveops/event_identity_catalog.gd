extends RefCounted
## Reviewed event artwork. Keys are navigation IDs, never reward IDs.
const ROOT: String="res://assets/ui/liveops/event_identity/"
const ART: Dictionary={
	"odyssey":"res://assets/ui/liveops/odyssey/temple.png",
	"pilgrimage":ROOT+"pilgrimage.png",
	"boss_hunt":ROOT+"boss_hunt.png",
	"heavenly_ladder":ROOT+"heavenly_ladder.png",
	"treasure_hunt":ROOT+"treasure_hunt.png",
	"five_elements":ROOT+"five_elements.png",
	"daily":"res://assets/ui/trials/trials_hall.png",
	"pavilion":"res://assets/ui/pavilion/sanctum_premium/pavilion_unified.png"
}
static func texture_for(id: String) -> Texture2D:
	return load(str(ART[id])) as Texture2D if ART.has(id) else null

static func add_detail_art(parent: VBoxContainer,id: String) -> void:
	var banner=load("res://scripts/ui/liveops/event_identity_banner.gd").new()
	banner.name="EventIdentityArtwork"
	banner.identity=id
	banner.artwork=texture_for(id)
	banner.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(banner)
static func wrap_mobile_controls(root: Node) -> void:
	# Long reward/CTA text must wrap before it can enlarge a portrait container.
	if root is Label:
		var font_size: int=maxi(root.get_theme_font_size("font_size"),16)
		root.add_theme_font_size_override("font_size",font_size)
		var numeric := RegEx.new()
		numeric.compile("^(?:#[0-9]{1,3}|(?:ASCENT|STAGE|CHAPTER|TAHAP|BAB) [0-9-]{1,8}|[0-9]+(?: *[/] *[0-9]+)?%?)$")
		if numeric.search(root.text.strip_edges())!=null:
			root.autowrap_mode=TextServer.AUTOWRAP_OFF
			root.custom_minimum_size.x=maxf(root.custom_minimum_size.x,root.get_theme_font("font").get_string_size(root.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+2)
		else:root.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		# Wrapping + ellipsis can report a 1px minimum in a styled status pill.
		# Reserve one readable line even before the container measures its width.
		root.custom_minimum_size.y=maxf(root.custom_minimum_size.y,float(font_size)*1.6)
	elif root is Button:
		var font_size: int=maxi(root.get_theme_font_size("font_size"),16)
		var numeric := RegEx.new()
		numeric.compile("^(?:#[0-9]{1,3}|(?:ASCENT|STAGE|CHAPTER|TAHAP|BAB) [0-9-]{1,8}|[0-9]+(?: *[/] *[0-9]+)?%?)$")
		if numeric.search(root.text.strip_edges())!=null:
			root.autowrap_mode=TextServer.AUTOWRAP_OFF
			root.custom_minimum_size.x=maxf(root.custom_minimum_size.x,root.get_theme_font("font").get_string_size(root.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+2)
		else:root.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for child: Node in root.get_children(): wrap_mobile_controls(child)
