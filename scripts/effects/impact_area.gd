extends ImpactEffect
class_name ImpactArea

@export var damage: float = 1.0
@export var radius: float = 50.0

func apply(target: Node, source_position: Vector2) -> void:
	var tree := target.get_tree()
	if tree == null:
		return
	var enemies = tree.get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.global_position.distance_to(source_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)

func to_dict() -> Dictionary:
	return {"type": "area", "damage": damage, "radius": radius}
