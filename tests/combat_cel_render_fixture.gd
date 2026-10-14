extends SceneTree
const Art=preload("res://scripts/effects/combat_cel_art.gd")
class Attack extends Node2D:
	var presentation_theme: String="storm"
	var has_impacted: bool=false
	var strike_radius: float=48
	var explosion_radius: float=48
	var telegraph_duration: float=.8
class HitGallery extends Node2D:
	var age: float=0
	func _draw() -> void:
		for index: int in range(8):
			var t: float=fmod(age+index*.08,.65)/.65
			Art.paint(self,"impacts",index,Vector2((index%4)*90,(index>>2)*90),Vector2.ONE*lerpf(63,78,t),0,.75+.20*sin(age*4+index))
var cards: Node2D
var rain: Node2D
var rains: Array[Node2D]=[]
var gallery: Node2D
var attack: Node2D
func _initialize() -> void:run.call_deferred()
func text(parent: Node,label: String,at: Vector2,width: float,size: int) -> void:
	var node:=Label.new();node.text=label;node.position=at;node.size.x=width;node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size",size);node.add_theme_color_override("font_color",Color(.94,.79,.47));parent.add_child(node)
func make_rain() -> void:
	rains.clear()
	for index: int in range(5):
		rain=load("res://scenes/weapons/heavenly_sword_rain.tscn").instantiate()
		var offset: Vector2=Vector2.ZERO if index==0 else Vector2.RIGHT.rotated(index*TAU/5)*48
		rain.position=Vector2(650,270)+offset*1.3;rain.scale=Vector2.ONE*1.3;rain.strike_radius=44;rain.telegraph_duration=.55
		cards.add_child(rain);rains.append(rain)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(860,940);await process_frame;paused=false
	cards=Node2D.new();root.add_child(cards);current_scene=cards
	var bg:=ColorRect.new();bg.size=Vector2(860,940);bg.color=Color(.025,.06,.075);cards.add_child(bg)
	text(cards,"COMBAT CEL POLISH",Vector2(0,15),860,25)
	text(cards,"Production spell/VFX render / controlled demonstration",Vector2(0,49),860,12)
	var hero:=Node2D.new();hero.position=Vector2(215,260);hero.scale=Vector2.ONE*1.3;cards.add_child(hero)
	var origin:=Marker2D.new();origin.name="CombatOrigin";hero.add_child(origin)
	var sprite:=AnimatedSprite2D.new();sprite.sprite_frames=load("res://assets/character/player/player_lin_yue_idle_walk_spriteframes.tres");sprite.animation=&"idle_down";sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.z_index=3;hero.add_child(sprite)
	for index: int in range(6):
		var blade: Node2D=load("res://scenes/weapons/yin_yang_blade.tscn").instantiate();blade.orbit_radius=116;blade.orbit_angle=index*TAU/6;blade.set_polarity(&"yin" if index%2==0 else &"yang");hero.add_child(blade)
	make_rain()
	text(cards,"YIN-YANG / LEVEL 7",Vector2(0,448),430,19)
	text(cards,"116px orbit / 3 Yin + 3 Yang",Vector2(0,477),430,12)
	text(cards,"SWORD RAIN / LEVEL 7",Vector2(430,448),430,19)
	text(cards,"5 carved jian / sapphire impact",Vector2(430,477),430,12)
	attack=Attack.new();attack.position=Vector2(215,720);cards.add_child(attack)
	attack.draw.connect(func():
		if not attack.has_impacted:attack.draw_arc(Vector2.ZERO,attack.strike_radius,0,TAU,48,Color(.78,.62,1,.9),2.5,true)
	)
	load("res://scripts/enemy/hostile_attack_polish.gd").install(attack,"lightning")
	gallery=HitGallery.new();gallery.position=Vector2(490,620);cards.add_child(gallery)
	text(cards,"HOSTILE TALISMAN / STORM",Vector2(0,835),430,17)
	text(cards,"TRUE WARNING EDGE / INNER ORNAMENT",Vector2(0,864),430,12)
	text(cards,"WEAPON HIT SIGNATURES",Vector2(430,835),430,17)
	text(cards,"Slash / burn / thunder / qi / pierce",Vector2(430,864),430,11)
	DirAccess.make_dir_recursive_absolute("/tmp/jade-qa/combat-cel-render")
	for index: int in range(32):
		if index==14:attack.has_impacted=true;attack.queue_redraw()
		if index==23:
			attack.has_impacted=false;attack.queue_redraw();attack.get_node("HostileAttackPolish").impact_age=0;attack.get_node("HostileAttackPolish").age=0
		if rains.all(func(r):return not is_instance_valid(r)):make_rain()
		gallery.age=index*.05;gallery.queue_redraw()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/jade-qa/combat-cel-render/%03d.png"%index)
	print("COMBAT_CEL_RENDER_PASS frames=32")
	cards.queue_free();current_scene=null
	for i: int in range(4):await process_frame
	Art.cache.clear();Art.palettes.clear()
	for i: int in range(2):await process_frame
	quit(0)
