extends ImpactEffect
class_name ImpactArea

@export var damage: float = 1.0
@export var radius: float = 50.0
## Même sémantique que ImpactDamage.duration : 0 = instantané, sinon dégâts
## répartis en tics par ennemi touché (le rayon n'est mesuré qu'une fois, à
## l'impact -- pas de re-scan pendant les tics).
@export var duration: float = 0.0

func apply(target: Node, source_position: Vector2, _shooter_id: int = 0) -> void:
	var tree := target.get_tree()
	if tree == null:
		return
	var enemies = tree.get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.global_position.distance_to(source_position) <= radius:
			_apply_damage_over_time(enemy, damage, duration)

func to_dict() -> Dictionary:
	return {"type": "area", "damage": damage, "radius": radius, "duration": duration}
