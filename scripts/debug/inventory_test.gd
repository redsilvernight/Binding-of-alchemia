extends Control

# Scène de test physique de l'inventaire (Phase 5 / validation Pickup.gd) :
# le joueur ramasse des ingrédients et des pièces d'arme au sol, l'UI affiche
# en direct le contenu de son Inventory via les signaux (ingredient_added/removed,
# weapon_part_added/removed), exactement comme un futur écran d'inventaire le ferait.

@onready var player: Node = $Player
@onready var status_label: Label = $UI/Panel/StatusLabel

var inventory: Inventory


func _ready() -> void:
	inventory = player.get_node("Inventory")
	inventory.ingredient_added.connect(_on_ingredient_changed)
	inventory.ingredient_removed.connect(_on_ingredient_changed)
	inventory.weapon_part_added.connect(_on_weapon_part_changed)
	inventory.weapon_part_removed.connect(_on_weapon_part_changed)
	_refresh_display()


func _on_ingredient_changed(_ingredient: Ingredient, _new_quantity: int) -> void:
	_refresh_display()


func _on_weapon_part_changed(_part: Resource) -> void:
	_refresh_display()


func _refresh_display() -> void:
	var texte: String = "Déplace-toi (ZQSD/flèches) sur les objets au sol pour les ramasser.\n\n"

	texte += "Ingrédients :\n"
	var has_ingredient: bool = false
	for key in inventory.ingredients.keys():
		var qty: int = inventory.ingredients[key]
		if qty <= 0:
			continue
		has_ingredient = true
		var ingredient: Ingredient = inventory.ingredient_resources.get(key)
		var nom: String = ingredient.nom if ingredient else key.get_file()
		texte += "  %s x%d\n" % [nom, qty]
	if not has_ingredient:
		texte += "  (aucun)\n"

	texte += "\nPièces d'arme :\n"
	if inventory.weapon_parts.is_empty():
		texte += "  (aucune)\n"
	else:
		for part in inventory.weapon_parts:
			var nom_part: String = part.resource_path.get_file() if part.resource_path != "" else part.get_class()
			texte += "  %s\n" % nom_part

	status_label.text = texte
