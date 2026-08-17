extends ImpactEffect
class_name ImpactHeal

## Vol de vie : soigne le TIREUR (shooter_id), pas la cible touchée -- cf.
## MixtureToEffect, type SOIN. `target` n'est utilisé que pour retrouver
## l'arbre de scène (groupe "Players"), jamais soigné lui-même.
@export var amount: float = 1.0

func apply(target: Node, _source_position: Vector2, shooter_id: int = 0) -> void:
	var tree := target.get_tree()
	if tree == null:
		return
	for player in tree.get_nodes_in_group("Players"):
		if player.name.is_valid_int() and int(player.name) == shooter_id and player.has_method("heal"):
			player.heal(amount)
			return

func to_dict() -> Dictionary:
	return {"type": "heal", "amount": amount}
