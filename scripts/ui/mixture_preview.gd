extends Control
class_name MixturePreview


signal item_activated(payload: Resource)
signal item_dropped(payload: Resource)
signal item_selected(payload: Resource)
signal item_deselected()

const INGREDIENT_FALLBACK_ICON: Texture2D = preload("res://assets/test/mixture_bullet_test.png")
const EMPTY_VIAL_COLOR: Color = Color(0.5, 0.5, 0.55, 0.55)

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
@export var accepts_drops: bool = false

@onready var vial_icon: TextureRect = $Row/VialFrame/VialIcon
@onready var grid: GridContainer = $Row/Scroll/Grid
@onready var empty_label: Label = $Row/EmptyLabel


func _ready() -> void:
	empty_label.text = empty_text
	display([], null)


func display(ingredient_paths: Array, inventory: Inventory) -> void:
	for child in grid.get_children():
		child.queue_free()

	if ingredient_paths.is_empty() or inventory == null:
		empty_label.visible = true
		vial_icon.modulate = EMPTY_VIAL_COLOR
		return

	empty_label.visible = false

	var counts: Dictionary = {}
	for path in ingredient_paths:
		counts[path] = counts.get(path, 0) + 1

	var occurrences_by_type: Dictionary = {}
	for key in counts.keys():
		var ingredient: Ingredient = inventory.ingredient_resources.get(key)
		if ingredient == null:
			continue
		var chip: Button = item_chip_scene.instantiate()
		grid.add_child(chip)
		var icon: Texture2D = ingredient.icon if ingredient.icon else INGREDIENT_FALLBACK_ICON
		chip.setup(ingredient, icon, ingredient.nom, counts[key])
		chip.activated.connect(func(payload: Resource) -> void: item_activated.emit(payload))
		chip.selected.connect(func(payload: Resource) -> void: item_selected.emit(payload))
		chip.deselected.connect(func() -> void: item_deselected.emit())
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
