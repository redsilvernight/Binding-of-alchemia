extends ImpactEffect
class_name ImpactDamage

@export var damage: float = 1.0
## 0 = dégâts instantanés (comportement historique). > 0 = dégâts répartis
## en tics sur cette durée (ex: brûlure/poison d'une mixture), cf.
## ImpactEffect._apply_damage_over_time.
@export var duration: float = 0.0

func apply(target: Node, _source_position: Vector2, _shooter_id: int = 0) -> void:
	_apply_damage_over_time(target, damage, duration)

func to_dict() -> Dictionary:
	return {"type": "damage", "damage": damage, "duration": duration}
