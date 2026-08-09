class_name Mixture
extends Resource

class EffetParType:
	var degats: float = 0.0
	var duree: float = 0.0
	var zone: float = 0.0

@export var type_dominant: Ingredient.TypeAlchimie
var effets_par_type: Dictionary = {} # Dictionary[Ingredient.TypeAlchimie, EffetParType]

func get_effet(type: Ingredient.TypeAlchimie) -> EffetParType:
	return effets_par_type.get(type, null)

func get_types_presents() -> Array:
	return effets_par_type.keys()
