extends RefCounted
## One contract for target acquisition and real cast hit geometry.
const NORMAL: float = 400.0
const BOSS: float = 300.0
static func normal(player: Node2D) -> float:
 var manager: Node=player.get_node_or_null("WeaponManager") if is_instance_valid(player) else null
 return float(manager.get("maximum_attack_range")) if manager!=null else NORMAL
static func boss(player: Node2D) -> float:
 var manager: Node=player.get_node_or_null("WeaponManager") if is_instance_valid(player) else null
 return minf(normal(player),float(manager.get("boss_attack_range"))) if manager!=null else BOSS
static func limit(player: Node2D,enemy: Node2D) -> float:
 return boss(player) if enemy.is_in_group("boss") else normal(player)
static func contains(player: Node2D,enemy: Node2D) -> bool:
 return player.global_position.distance_squared_to(enemy.global_position)<=pow(limit(player,enemy),2)
