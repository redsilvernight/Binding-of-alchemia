extends Node2D

@onready var ingredient_list: ItemList = $UI/IngredientList
@onready var mix_button: Button = $UI/MixButton
@onready var result_label: Label = $UI/ResultLabel

var ingredients_disponibles: Array[Ingredient] = [
	preload("res://resources/ingredients/braise.tres"),
	preload("res://resources/ingredients/cendre_ardente.tres"),
	preload("res://resources/ingredients/cristal_givre.tres"),
	preload("res://resources/ingredients/bave_toxique.tres"),
	preload("res://resources/ingredients/racine_apaisante.tres"),
]


func _ready() -> void:
	for ingredient in ingredients_disponibles:
		ingredient_list.add_item(ingredient.nom)

	mix_button.pressed.connect(_on_mix_pressed)


func _on_mix_pressed() -> void:
	var selection: PackedInt32Array = ingredient_list.get_selected_items()
	if selection.is_empty():
		result_label.text = "Sélectionne au moins un ingrédient."
		return
	var ingredients_choisis: Array[Ingredient] = []
	for index in selection:
		ingredients_choisis.append(ingredients_disponibles[index])
	var mixture: Mixture = AlchemyResolver.resoudre(ingredients_choisis)
	var composite: ImpactEffect = MixtureToEffect.convertir(mixture)
	result_label.text = _formater_resultat(mixture) + "\n\n" + _formater_effets(composite)


func _formater_effets(effect: ImpactEffect) -> String:
	var texte: String = "Effets générés :\n"

	if effect is ImpactComposite:
		for sous_effet in effect.effets:
			texte += _formater_un_effet(sous_effet) + "\n"
	else:
		texte += _formater_un_effet(effect) + "\n"

	return texte


func _formater_un_effet(effect: ImpactEffect) -> String:
	if effect is ImpactArea:
		return "ImpactArea | damage: %.1f | radius: %.1f" % [effect.damage, effect.radius]
	elif effect is ImpactDamage:
		return "ImpactDamage | damage: %.1f" % effect.damage
	else:
		return "Type inconnu : %s" % effect.get_class()

func _formater_resultat(mixture: Mixture) -> String:
	var texte: String = "Type dominant : %s\n" % Ingredient.TypeAlchimie.keys()[mixture.type_dominant]

	for type in mixture.get_types_presents():
		var effet: Mixture.EffetParType = mixture.get_effet(type)
		var nom_type: String = Ingredient.TypeAlchimie.keys()[type]
		texte += "\n[%s] dégâts: %.1f | durée: %.1f | zone: %.1f" % [nom_type, effet.degats, effet.duree, effet.zone]

	return texte
