extends SceneTree
## Controlled render of production VFX and production Lin Yue sprites.
## The miniature gallery compresses event timing, not gameplay footage.
const VFX = preload("res://scripts/player/legendary_set_vfx.gd")
const Art = preload("res://scripts/player/legendary_set_art.gd")
class RenderHealth extends Node:
	signal health_changed(current: float, maximum: float)
	signal qi_shield_blocked(remaining: int)
	var qi_shield_charges: int = 0
	var current_health: float = 10.0
	var is_dead: bool = false
var effects: Array[Node2D] = []
func _initialize() -> void: run.call_deferred()
func label(parent: Node, text: String, at: Vector2, width: float, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.size.x = width
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	parent.add_child(l)
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(640,760)
	await process_frame
	paused = false
	var stage := Node2D.new()
	root.add_child(stage)
	var bg := ColorRect.new()
	bg.size = Vector2(640,760)
	bg.color = Color(0.024,0.062,0.072)
	stage.add_child(bg)
	label(stage,"LEGENDARY / FOUR-PIECE RESONANCE",Vector2(0,12),640,21,Color(0.92,0.77,0.44))
	label(stage,"Production VFX render / compressed demonstration timing",Vector2(0,42),640,12,Color(0.55,0.75,0.70))
	var index: int = 0
	for id: String in Art.SETS:
		var hero := Node2D.new()
		hero.position = Vector2(160 + (index%2)*320, 222 + (index>>1)*320)
		hero.scale = Vector2.ONE * 1.8
		var health := RenderHealth.new()
		health.name = "PlayerHealth"
		hero.add_child(health)
		var host := Node2D.new()
		host.z_index = 2
		hero.add_child(host)
		stage.add_child(hero)
		var fx: Node2D = VFX.new()
		host.add_child(fx)
		fx.configure(id,4,false)
		fx.set_process(false)
		effects.append(fx)
		var body := AnimatedSprite2D.new()
		body.sprite_frames = load("res://assets/character/player/player_lin_yue_idle_walk_spriteframes.tres")
		body.animation = &"idle_down"
		body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		body.z_index = 3
		hero.add_child(body)
		label(stage,id.replace("_"," ").to_upper(),Vector2((index%2)*320,320+(index>>1)*320),320,19,Color(0.92,0.77,0.44))
		label(stage,str(Art.SETS[id].kind).to_upper()+" / 4 ARMOR + ACCESSORIES",Vector2((index%2)*320,348+(index>>1)*320),320,11,Art.SETS[id].color)
		index += 1
	DirAccess.make_dir_recursive_absolute("/tmp/jade-qa/legendary-render")
	for frame: int in range(48):
		for fx: Node2D in effects:
			if frame == 8:
				if fx.set_id=="celestial_aegis":
					fx.health.qi_shield_charges = 1
					fx.health.health_changed.emit(10.0,10.0)
				else: fx.confirmed_proc(str(Art.SETS[fx.set_id].kind),fx.global_position+Vector2(80,0))
			if frame == 25:
				if fx.set_id=="celestial_aegis":
					fx.health.qi_shield_charges = 0
					fx.health.qi_shield_blocked.emit(0)
				else: fx.confirmed_proc(str(Art.SETS[fx.set_id].kind),fx.global_position+Vector2(-50,-35))
			fx._process(0.05)
			fx.set_process(false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/jade-qa/legendary-render/%03d.png" % frame)
	for fx: Node2D in effects:
		fx.configure(fx.set_id,4,true)
		fx._process(1.0)
		fx.set_process(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/jade-qa/legendary-render/reduced.png")
	print("LEGENDARY_RENDER_PASS frames=48 reduced=1")
	stage.queue_free()
	await process_frame
	quit(0)
