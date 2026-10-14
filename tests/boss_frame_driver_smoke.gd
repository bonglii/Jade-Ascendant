extends SceneTree
const Driver=preload("res://scripts/enemy/boss_frame_driver.gd")
class Body extends Node2D:
 var is_dead: bool=false
 var facing_left: bool=false
 var visual_action_timer: float=0.0
 var phase_transition_timer: float=0.0
var checks: int=0
var failures: int=0
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("BOSS_FRAMES_FAIL "+label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_boss_frames_qa"):quit(2);return
 var boss:=Body.new();boss.set_meta("frame_driven_boss",true)
 var sprite:=AnimatedSprite2D.new();sprite.name="AnimatedSprite2D"
 sprite.sprite_frames=SpriteFrames.new();sprite.sprite_frames.remove_animation(&"default")
 var texture: Texture2D=load("res://assets/enemy/boss_1_valley_trial_guardian_96x96.png")
 for family: String in ["idle","walk","melee","projectile","radial","lightning","shockwave","phase"]:
  for direction: String in ["left","right"]:
   var name_value:=StringName(family+"_"+direction)
   sprite.sprite_frames.add_animation(name_value)
   sprite.sprite_frames.set_animation_loop(name_value,false)
   for index: int in range(1 if family=="idle" else 6):sprite.sprite_frames.add_frame(name_value,texture)
 boss.add_child(sprite);root.add_child(boss)
 var driver:=Driver.new();boss.add_child(driver);driver.set_physics_process(false)
 for index: int in range(120):driver._physics_process(.016)
 check(sprite.animation==&"idle_right" and sprite.frame==0 and not sprite.is_playing(),"stationary feet stay planted regardless of time")
 boss.position.x+=8;driver._physics_process(.016)
 check(sprite.animation==&"walk_right" and sprite.frame==1,"one eighth-world-pixel step selects distance frame")
 for index: int in range(60):driver._physics_process(.016)
 check(sprite.animation==&"idle_right" and sprite.frame==0,"stopping immediately settles feet")
 for index: int in range(6):boss.position.x+=8;driver._physics_process(.016);check(sprite.frame==(index+1)%6,"complete six-cel cycle follows travel")
 boss.position.x+=300;driver._physics_process(.016)
 check(sprite.animation==&"idle_right","teleport does not spin feet")
 boss.visual_action_timer=.6;driver.play_action("melee",.6,.48)
 boss.position.x+=8;driver._physics_process(.1)
 check(sprite.animation==&"melee_right" and sprite.frame<3,"walk cannot overwrite attack anticipation")
 boss.facing_left=true;driver._physics_process(.19)
 check(sprite.frame==3 and not sprite.flip_h,"release frame uses captured facing")
 driver._physics_process(.31)
 check(sprite.frame==5,"recovery reaches last cel")
 driver._physics_process(.016);boss.visual_action_timer=0;driver._physics_process(.016)
 check(sprite.animation==&"idle_left" and sprite.flip_h,"recovery finishes at planted facing idle")
 driver.play_action("lightning",1.05,.85/1.05)
 driver._physics_process(.84)
 check(sprite.frame<=2,"sky charge holds before actual telegraph impact")
 driver._physics_process(.011)
 check(sprite.frame==3,"sky release matches actual impact")
 driver._physics_process(.199)
 check(sprite.frame==5,"sky recovery")
 boss.is_dead=true;var before: int=sprite.frame;boss.position.x+=10;driver._physics_process(.1)
 check(sprite.frame==before and not sprite.is_playing(),"death cancels advancing frames")
 boss.is_dead=false
 var actor: Node=load("res://scripts/effects/actor_presentation.gd").new();actor.name="QiPresentation";boss.add_child(actor);actor.set_process(false)
 var transform: Transform2D=sprite.transform
 actor.hurt();actor.action(.3)
 for index: int in range(50):actor._process(.016)
 check(sprite.transform==transform,"generic gait/breath/hurt/action never deforms the 2D pose")
 boss.queue_free()
 print("BOSS_FRAME_DRIVER_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
