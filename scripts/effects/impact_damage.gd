extends ImpactEffect
class_name ImpactDamage

@export var damage: float = 1.0

func apply(target: Node, _source_position: Vector2) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
