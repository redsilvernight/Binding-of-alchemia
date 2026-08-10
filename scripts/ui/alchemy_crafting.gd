extends CanvasLayer

# Écran de crafting d'alchimie (Phase 5.5). Remplace le sélecteur hardcodé
# de alchemy_test.gd : la liste d'ingrédients vient du véritable Inventory
# du joueur. Comme inventory_screen.gd, cet écran ne modifie JAMAIS l'état
# lui-même — il envoie l'intention de mix par RPC vers l'hôte
# (Player.request_craft_mixture), qui seul valide le stock, consomme les
# ingrédients et résout la recette (cf. architecture_reseau.md).

@onready var root: Control = $Root
@onready var ingredient_list: ItemList = $Root/Content/IngredientList
@onready var craft_button: Button = $Root/Content/CraftButton
@onready var result_label: Label = $Root/Content/ResultLabel

var inventory: Inventory
var _visible_keys: Array[String] = [] # aligne l'index de la liste avec la clé d'inventaire (resource_path)


func _ready() -> void:
	root.visible = false
	craft_button.pressed.connect(_on_craft_pressed)


func bind_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory
	inventory.ingredient_added.connect(_on_inventory_changed)
	inventory.ingredient_removed.connect(_on_inventory_changed)


func open() -> void:
	_refresh_list()
	result_label.text = ""
	root.visible = true


func close() -> void:
	root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if root.visible and event.is_action_pressed("ui_cancel"):
		close()


func _on_inventory_changed(_ingredient: Ingredient, _new_quantity: int) -> void:
	if root.visible:
		_refresh_list()


func _refresh_list() -> void:
	ingredient_list.clear()
	_visible_keys.clear()
	for key in inventory.ingredients.keys():
		var quantity: int = inventory.ingredients[key]
		if quantity <= 0:
			continue
		var ingredient: Ingredient = inventory.ingredient_resources.get(key)
		var nom: String = ingredient.nom if ingredient else key.get_file()
		ingredient_list.add_item("%s x%d" % [nom, quantity])
		_visible_keys.append(key)


func _on_craft_pressed() -> void:
	var selection: PackedInt32Array = ingredient_list.get_selected_items()
	if selection.is_empty():
		result_label.text = "Sélectionne au moins un ingrédient."
		return

	var selected_paths: Array[String] = []
	for index in selection:
		selected_paths.append(_visible_keys[index])

	# L'hôte revalidera le stock avant de retirer quoi que ce soit ; on ne
	# fait ici qu'exprimer l'intention, jamais de calcul de résultat local.
	get_parent().request_craft_mixture.rpc_id(1, selected_paths)
	result_label.text = "Mixture demandée..."
