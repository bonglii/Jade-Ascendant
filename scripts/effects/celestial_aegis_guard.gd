extends Node
const Catalog=preload("res://scripts/data/equipment_set_catalog.gd")
const Combat=preload("res://scripts/effects/equipment_set_combat.gd")
const QUIET_SECONDS: float=8.0
var quiet: float=0.0
var previous_hp: float=0.0
var enabled: bool=false
func _ready() -> void:
 var health: Node=get_parent()
 previous_hp=health.current_health
 enabled=Catalog.get_active_passive(Combat.equipped_ids()).get("kind","")=="aegis"
 health.health_changed.connect(_health_changed)
 health.qi_shield_blocked.connect(func(_remaining: int):quiet=0.0)
 set_physics_process(enabled)
func _health_changed(current: float,_maximum: float) -> void:
 if current<previous_hp:quiet=0.0
 previous_hp=current
func _physics_process(delta: float) -> void:
 var health: Node=get_parent()
 if not enabled or health.is_dead:return
 quiet=minf(quiet+delta,QUIET_SECONDS)
 if quiet>=QUIET_SECONDS and health.qi_shield_charges==0:
  health.qi_shield_charges=1
  quiet=0.0
  health.health_changed.emit(health.current_health,health.max_health)
