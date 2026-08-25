class_name Ingredient
extends Resource

enum TypeAlchimie {
	FEU,
	GLACE,
	POISON,
	ELECTRIQUE,
	SOIN,
	EXPLOSIF
}

@export var nom: String = ""
@export_multiline var description: String = ""
@export var type_alchimie: TypeAlchimie = TypeAlchimie.FEU
@export var degats_base: float = 0.0
@export var duree_base: float = 0.0
@export var zone_base: float = 0.0
@export var icon: Texture2D = null
