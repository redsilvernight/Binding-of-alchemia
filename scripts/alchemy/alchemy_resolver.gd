class_name AlchemyResolver
extends RefCounted

static func resoudre(ingredients: Array[Ingredient]) -> Mixture:
	if ingredients.is_empty():
		return null

	var occurrences: Dictionary = {} # Dictionary[TypeAlchimie, int]
	var effets_par_type: Dictionary = {} # Dictionary[TypeAlchimie, Mixture.EffetParType]

	for ingredient in ingredients:
		var type: Ingredient.TypeAlchimie = ingredient.type_alchimie

		if not occurrences.has(type):
			occurrences[type] = 0
		occurrences[type] += 1

		if not effets_par_type.has(type):
			effets_par_type[type] = Mixture.EffetParType.new()

		var effet: Mixture.EffetParType = effets_par_type[type]
		effet.degats += ingredient.degats_base
		effet.duree += ingredient.duree_base
		effet.zone += ingredient.zone_base

	var type_dominant: Ingredient.TypeAlchimie = _determiner_type_dominant(occurrences)

	var mixture := Mixture.new()
	mixture.type_dominant = type_dominant
	mixture.effets_par_type = effets_par_type

	return mixture


static func _determiner_type_dominant(occurrences: Dictionary) -> Ingredient.TypeAlchimie:
	var max_count: int = 0
	for type in occurrences.keys():
		if occurrences[type] > max_count:
			max_count = occurrences[type]

	var candidats: Array = []
	for type in occurrences.keys():
		if occurrences[type] == max_count:
			candidats.append(type)

	return candidats[randi() % candidats.size()]
