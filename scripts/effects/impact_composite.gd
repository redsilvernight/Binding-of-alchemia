class_name ImpactComposite
extends ImpactEffect

var effets: Array[ImpactEffect] = []

func apply(target: Node, source_position: Vector2) -> void:
	for effet in effets:
		effet.apply(target, source_position)

func to_dict() -> Dictionary:
	var effects_data: Array = []
	for effet in effets:
		effects_data.append(effet.to_dict())
	return {"type": "composite", "effects": effects_data}
