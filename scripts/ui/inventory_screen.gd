extends CanvasLayer

# Écran d'inventaire du joueur local (Phase 5.2). Toggle avec l'action
# "toggle_inventory" (Tab). Purement affichage : ne modifie jamais l'état de
# l'Inventory (autorité hôte, cf. Inventory.gd), se contente de refléter ses
# signaux ingredient_added/removed et weapon_part_added/removed.

const INGREDIENT_FALLBACK_ICON: Texture2D = preload("res://assets/test/mixture_bullet_test.png")
const WEAPON_PART_FALLBACK_ICON: Texture2D = preload("res://assets/test/water_bullet_test.png")

@export var slot_scene: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")

@onready var root: Control = $Root
@onready var currency_label: Label = $Root/Content/CurrencyLabel
@onready var ingredient_grid: GridContainer = $Root/Content/IngredientGrid
@onready var weapon_part_grid: GridContainer = $Root/Content/WeaponPartGrid

var inventory: Inventory


func _ready() -> void:
	root.visible = false
	# Monnaie méta (8.2) affichée ici à titre indicatif : elle vit dans
	# MetaProgression (autoload, par-peer), pas dans Inventory (Node par-joueur
	# recréé à chaque run) — cet écran ne fait qu'y lire/écouter, jamais écrire.
	MetaProgression.currency_changed.connect(_on_currency_changed)
	_on_currency_changed(MetaProgression.get_currency(NetworkManager.get_unique_id()))


func _on_currency_changed(new_amount: int) -> void:
	currency_label.text = "Monnaie : %d" % new_amount


func bind_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory
	inventory.ingredient_added.connect(_on_ingredient_changed)
	inventory.ingredient_removed.connect(_on_ingredient_changed)
	inventory.weapon_part_added.connect(_on_weapon_part_changed)
	inventory.weapon_part_removed.connect(_on_weapon_part_changed)
	_refresh_ingredients()
	_refresh_weapon_parts()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		root.visible = not root.visible
		AudioManager.play_sfx("ui_toggle")


func _on_ingredient_changed(_ingredient: Ingredient, _new_quantity: int) -> void:
	_refresh_ingredients()


func _on_weapon_part_changed(_part: Resource) -> void:
	_refresh_weapon_parts()


func _refresh_ingredients() -> void:
	for child in ingredient_grid.get_children():
		child.queue_free()

	for key in inventory.ingredients.keys():
		var quantity: int = inventory.ingredients[key]
		if quantity <= 0:
			continue
		var ingredient: Ingredient = inventory.ingredient_resources.get(key)
		var slot: Control = slot_scene.instantiate()
		ingredient_grid.add_child(slot)
		var icon: Texture2D = ingredient.icon if (ingredient and ingredient.icon) else INGREDIENT_FALLBACK_ICON
		var nom: String = ingredient.nom if ingredient else key.get_file()
		slot.setup(icon, quantity, nom)


func _refresh_weapon_parts() -> void:
	for child in weapon_part_grid.get_children():
		child.queue_free()

	for part in inventory.weapon_parts:
		var slot: Control = slot_scene.instantiate()
		weapon_part_grid.add_child(slot)
		var icon: Texture2D = part.icon if part.icon else WEAPON_PART_FALLBACK_ICON
		var nom: String = part.resource_path.get_file() if part.resource_path != "" else part.get_class()
		slot.setup(icon, -1, nom)
