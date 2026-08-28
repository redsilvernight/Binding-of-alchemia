extends ImpactEffect
class_name ImpactHeal

@export var amount: float = 1.0

func apply(target: Node, _source_position: Vector2, shooter_id: int = 0) -> void:
	if not target.is_in_group("Enemies"):
		return
	var tree := target.get_tree()
	if tree == null:
		return
	for player in tree.get_nodes_in_group("Players"):
		if player.name.is_valid_int() and int(player.name) == shooter_id and player.has_method("heal"):
			player.heal(amount)
			return

func to_dict() -> Dictionary:
	return {"type": "heal", "amount": amount}
