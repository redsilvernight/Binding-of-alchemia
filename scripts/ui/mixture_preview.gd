extends Control
class_name MixturePreview

## Fiole teintée par type dominant + grille empilée des ingrédients d'une
## mixture. Réutilisé pour 3 usages réels (cf. design_no_premature_genericity) :
## la mixture chargée sur l'arme dans inventory_screen.gd (lecture seule), la
## même chose dans alchemy_crafting.gd (lecture seule), et le chaudron
## interactif d'alchemy_crafting.gd (accepts_drops=true, clic pour retirer).
## Purement affichage sinon -- ne modifie jamais l'Inventory/Weapon, se
## contente d'émettre des signaux que l'écran appelant interprète comme il
## veut (ou ignore, en lecture seule).

## Émis quand un ingrédient déjà affiché ici est cliqué (ex : retirer du
## chaudron). Ignoré si personne ne s'y connecte (lecture seule).
signal item_activated(payload: Resource)
## Émis quand quelque chose est glissé depuis ailleurs et déposé ici (ex :
## ajouter au chaudron) -- seulement si accepts_drops est activé.
signal item_dropped(payload: Resource)

const INGREDIENT_FALLBACK_ICON: Texture2D = preload("res://assets/test/mixture_bullet_test.png")
const EMPTY_VIAL_COLOR: Color = Color(0.5, 0.5, 0.55, 0.55)

## Cf. Infos/direction_artistique.md -- seule source de couleur saturée à
## l'écran, ici réutilisée pour teinter la fiole selon le type dominant.
const TYPE_COLORS: Dictionary = {
	Ingredient.TypeAlchimie.FEU: Color(0.95, 0.35, 0.12),
	Ingredient.TypeAlchimie.GLACE: Color(0.35, 0.75, 0.95),
	Ingredient.TypeAlchimie.POISON: Color(0.62, 0.32, 0.82),
	Ingredient.TypeAlchimie.ELECTRIQUE: Color(0.95, 0.85, 0.15),
	Ingredient.TypeAlchimie.SOIN: Color(0.45, 0.9, 0.6),
	Ingredient.TypeAlchimie.EXPLOSIF: Color(0.55, 0.12, 0.1),
}

@export var item_chip_scene: PackedScene = preload("res://scenes/ui/item_chip.tscn")
@export var empty_text: String = "Vide."
## Le chaudron d'alchemy_crafting.gd est la seule instance interactive --
## les aperçus en lecture seule (inventaire, mixture chargée) laissent ça à
## false pour ne pas laisser croire qu'on peut y glisser quelque chose.
@export var accepts_drops: bool = false

@onready var vial_icon: TextureRect = $Row/VialFrame/VialIcon
@onready var grid: GridContainer = $Row/Scroll/Grid
@onready var empty_label: Label = $Row/EmptyLabel


func _ready() -> void:
	empty_label.text = empty_text
	display([], null)


## ingredient_paths : Array de resource_path (String, doublons compris).
## inventory : nécessaire pour résoudre icône/nom/type depuis chaque chemin
## (via ingredient_resources) -- null accepté (affiche l'état vide).
func display(ingredient_paths: Array, inventory: Inventory) -> void:
	for child in grid.get_children():
		child.queue_free()

	if ingredient_paths.is_empty() or inventory == null:
		empty_label.visible = true
		vial_icon.modulate = EMPTY_VIAL_COLOR
		return

	empty_label.visible = false

	var counts: Dictionary = {} # String (resource_path) -> int
	for path in ingredient_paths:
		counts[path] = counts.get(path, 0) + 1

	var occurrences_by_type: Dictionary = {} # Ingredient.TypeAlchimie -> int
	for key in counts.keys():
		var ingredient: Ingredient = inventory.ingredient_resources.get(key)
		if ingredient == null:
			continue
		var chip: Button = item_chip_scene.instantiate()
		grid.add_child(chip)
		var icon: Texture2D = ingredient.icon if ingredient.icon else INGREDIENT_FALLBACK_ICON
		chip.setup(ingredient, icon, ingredient.nom, counts[key])
		chip.activated.connect(func(payload: Resource) -> void: item_activated.emit(payload))
		occurrences_by_type[ingredient.type_alchimie] = occurrences_by_type.get(ingredient.type_alchimie, 0) + counts[key]

	vial_icon.modulate = _dominant_type_color(occurrences_by_type)


func _dominant_type_color(occurrences_by_type: Dictionary) -> Color:
	if occurrences_by_type.is_empty():
		return EMPTY_VIAL_COLOR
	var best_type = null
	var best_count: int = -1
	for type in occurrences_by_type.keys():
		if occurrences_by_type[type] > best_count:
			best_count = occurrences_by_type[type]
			best_type = type
	return TYPE_COLORS.get(best_type, Color.WHITE)


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return accepts_drops and data is Dictionary and data.has("part")


func _drop_data(_position: Vector2, data: Variant) -> void:
	item_dropped.emit(data["part"])
