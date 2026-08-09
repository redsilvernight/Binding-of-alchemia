class_name ImpactComposite
extends ImpactEffect

var effets: Array[ImpactEffect] = []

func apply(target: Node, source_position: Vector2) -> void:
	for effet in effets:
		effet.apply(target, source_position)
