extends Node2D
## One bounded, real-upgrade acknowledgement for all 18 run arts.
const Art = preload("res://scripts/effects/skill_signature_art.gd")
var skill_id: String = ""
var title: String = ""
var benefit: String = ""
var remaining: float = 0.0
var refresh_left: float = 0.0
var plate: StyleBoxFlat = StyleBoxFlat.new()
var proc_id: String = ""
var proc_left: float = 0.0
static func show_applied(_player: Node2D, _id: String, _display_name: String, _effect: String) -> void:
 # Compatibility entry point: upgrades already acknowledge in the choice UI.
 pass
static func show_proc(player: Node2D, id: String) -> void:
 var feedback: Node2D = player.get_node_or_null("SkillAscensionFeedback")
 if feedback == null:
  feedback = (load("res://scripts/player/skill_ascension_feedback.gd") as GDScript).new()
  feedback.name = "SkillAscensionFeedback";player.add_child(feedback)
 feedback.proc_id=id;feedback.proc_left=.45
 feedback.set_process(true);feedback.queue_redraw()
func _ready() -> void:
 z_index = 10
 set_process(false)
func _process(delta: float) -> void:
 remaining = maxf(0, remaining-delta)
 proc_left = maxf(0,proc_left-delta)
 if remaining <= 0 and proc_left <= 0:
  queue_redraw();set_process(false);return
 refresh_left -= delta
 if refresh_left <= 0:
  refresh_left = 1.0/30.0;queue_redraw()
func _draw() -> void:
 if proc_left > 0:
  var proc_alpha: float = proc_left/.45
  Art.draw_emblem(self,proc_id,Vector2(0,-25),16 if SettingsManager.reduced_effects else 21,0.0,proc_alpha*.85)
 if remaining <= 0: return
 var alpha: float = minf(1.0,remaining/.38)
 var elapsed: float = 1.65-remaining
 var ink: Color = Art.color_for(skill_id)
 var font: Font = ThemeDB.fallback_font
 # Text stays above the character and never covers the floor hazard boundary.
 var baseline := Vector2(-140,-77-minf(elapsed,0.4)*9)
 draw_style_box(_plate(),Rect2(baseline-Vector2(6,22),Vector2(292,55)))
 draw_string(font,baseline,title,HORIZONTAL_ALIGNMENT_CENTER,280,17,Color(ink,alpha))
 draw_string(font,baseline+Vector2(0,21),benefit,HORIZONTAL_ALIGNMENT_CENTER,280,11,Color(0.88,0.95,0.9,alpha))
 if not SettingsManager.reduced_effects:
  Art.draw_emblem(self,skill_id,Vector2(0,-35),18,elapsed,alpha*.82)
func _plate() -> StyleBoxFlat:
 var style: StyleBoxFlat = plate
 style.bg_color=Color(.015,.045,.04,minf(1,remaining/.38)*.88)
 style.border_color=Color(Art.color_for(skill_id),minf(1,remaining/.38)*.6)
 style.set_border_width_all(1);style.set_corner_radius_all(8)
 return style
