extends Resource
class_name ImpactEffect

func apply(_target: Node, _source_position: Vector2) -> void:
	pass

## Sérialise cet effet en Dictionary de types de base (String/float/Array),
## pour pouvoir le transmettre via RPC sans dépendre d'un resource_path.
## À surcharger dans chaque sous-classe.
func to_dict() -> Dictionary:
	return {"type": "none"}

## Reconstruit un ImpactEffect depuis un Dictionary produit par to_dict().
static func from_dict(data: Dictionary) -> ImpactEffect:
	match data.get("type", "none"):
		"damage":
			var e := ImpactDamage.new()
			e.damage = data.get("damage", 0.0)
			return e
		"area":
			var e := ImpactArea.new()
			e.damage = data.get("damage", 0.0)
			e.radius = data.get("radius", 0.0)
			return e
		"composite":
			var e := ImpactComposite.new()
			var sous_effets: Array[ImpactEffect] = []
			for sous_data in data.get("effects", []):
				sous_effets.append(ImpactEffect.from_dict(sous_data))
			e.effets = sous_effets
			return e
		_:
			return null
