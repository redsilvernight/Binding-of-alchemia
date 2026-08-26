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

const TYPE_LABELS: Dictionary = {
	Ingredient.TypeAlchimie.FEU: "Feu",
	Ingredient.TypeAlchimie.GLACE: "Givre",
	Ingredient.TypeAlchimie.POISON: "Poison",
	Ingredient.TypeAlchimie.ELECTRIQUE: "Élec.",
	Ingredient.TypeAlchimie.SOIN: "Soin",
	Ingredient.TypeAlchimie.EXPLOSIF: "Explo.",
}

const STAT_SWATCH_WIDTH: float = 20.0

# Bornes de normalisation des jauges — pas des maximums absolus, juste une echelle
# de lecture (un ingredient concentre au max peut deborder la barre, c'est voulu).
const DAMAGE_BAR_MAX: float = 30.0
const ZONE_BAR_MAX: float = 10.0
const DUREE_BAR_MAX: float = 15.0

@export var item_chip_scene: PackedScene = preload("res://scenes/ui/item_chip.tscn")
@export var empty_text: String = "Vide."
@export var accepts_drops: bool = false
@export var stats_position_below: bool = false

@onready var _column: VBoxContainer = $Column
@onready var row: HBoxContainer = $Column/Row
@onready var vial_icon: TextureRect = $Column/Row/VialFrame/VialIcon
@onready var grid: Container = $Column/Row/Scroll/Grid
@onready var empty_label: Label = $Column/Row/EmptyLabel
@onready var stats_scroll: ScrollContainer = $Column/StatsScroll
@onready var stats_grid: GridContainer = $Column/StatsScroll/StatsGrid


func _ready() -> void:
	if not stats_position_below:
		stats_scroll.reparent(row)
	_column.minimum_size_changed.connect(update_minimum_size)
	empty_label.text = empty_text
	display([], null)


func _get_minimum_size() -> Vector2:
	if _column == null:
		return Vector2.ZERO
	return _column.get_combined_minimum_size()


func display(ingredient_paths: Array, inventory: Inventory, loaded_paths: Array = []) -> void:
	for child in grid.get_children():
		child.queue_free()

	if ingredient_paths.is_empty() or inventory == null:
		empty_label.visible = true
		vial_icon.modulate = EMPTY_VIAL_COLOR
	else:
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

		vial_icon.modulate = blended_color_for(occurrences_by_type)

	_update_stats(ingredient_paths, loaded_paths, inventory)


func _update_stats(pending_paths: Array, loaded_paths: Array, inventory: Inventory) -> void:
	if inventory == null:
		stats_scroll.visible = false
		clear_grid(stats_grid)
		return

	var current_mixture: Mixture = resolve_mixture(loaded_paths, inventory)
	var combined_paths: Array = loaded_paths.duplicate()
	combined_paths.append_array(pending_paths)
	var combined_mixture: Mixture = resolve_mixture(combined_paths, inventory)

	stats_scroll.visible = current_mixture != null or combined_mixture != null
	populate_delta_stats_grid(stats_grid, current_mixture, combined_mixture)


static func resolve_mixture(ingredient_paths: Array, inventory: Inventory) -> Mixture:
	if ingredient_paths.is_empty() or inventory == null:
		return null
	var ingredients: Array[Ingredient] = []
	for path in ingredient_paths:
		var ingredient: Ingredient = inventory.ingredient_resources.get(path)
		if ingredient != null:
			ingredients.append(ingredient)
	return AlchemyResolver.resoudre(ingredients)


static func clear_grid(grid_to_clear: GridContainer) -> void:
	for child in grid_to_clear.get_children():
		child.queue_free()


static func _effet_or_zero(mixture: Mixture, type: Ingredient.TypeAlchimie) -> Mixture.EffetParType:
	var effet: Mixture.EffetParType = mixture.get_effet(type) if mixture != null else null
	return effet if effet != null else Mixture.EffetParType.new()


static func populate_delta_stats_grid(grid_to_fill: GridContainer, current_mixture: Mixture, combined_mixture: Mixture) -> void:
	clear_grid(grid_to_fill)
	if current_mixture == null and combined_mixture == null:
		return

	var types_present: Array = []
	for mixture in [current_mixture, combined_mixture]:
		if mixture == null:
			continue
		for type in mixture.get_types_presents():
			if not types_present.has(type):
				types_present.append(type)

	_add_stat_header(grid_to_fill)
	for type in types_present:
		_add_delta_stat_row(grid_to_fill, type, _effet_or_zero(current_mixture, type), _effet_or_zero(combined_mixture, type))


static func _add_stat_header(grid_to_fill: GridContainer) -> void:
	grid_to_fill.add_child(Control.new())
	grid_to_fill.add_child(Control.new())
	for column_text in ["Dégâts", "Zone", "Durée"]:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.72, 0.7, 0.66))
		label.text = column_text
		grid_to_fill.add_child(label)


static func _add_delta_stat_row(grid_to_fill: GridContainer, type: Ingredient.TypeAlchimie, current_effet: Mixture.EffetParType, combined_effet: Mixture.EffetParType) -> void:
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 14)
	dot.color = TYPE_COLORS.get(type, Color.WHITE)
	grid_to_fill.add_child(dot)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.text = TYPE_LABELS.get(type, "?")
	grid_to_fill.add_child(label)

	if type == Ingredient.TypeAlchimie.SOIN:
		var heal_label := Label.new()
		heal_label.add_theme_font_size_override("font_size", 12)
		heal_label.text = "+%.0f soin" % current_effet.degats + _delta_suffix(current_effet.degats, combined_effet.degats, "%.0f")
		grid_to_fill.add_child(heal_label)
		grid_to_fill.add_child(Control.new())
		grid_to_fill.add_child(Control.new())
		return

	grid_to_fill.add_child(_build_delta_stat_value(current_effet.degats, combined_effet.degats, DAMAGE_BAR_MAX, Color(0.9, 0.3, 0.25), "%.0f"))
	grid_to_fill.add_child(_build_delta_stat_value(current_effet.zone, combined_effet.zone, ZONE_BAR_MAX, Color(0.35, 0.85, 0.5), "%.1f"))
	grid_to_fill.add_child(_build_delta_stat_value(current_effet.duree, combined_effet.duree, DUREE_BAR_MAX, Color(0.4, 0.65, 0.95), "%.1fs"))


static func _delta_suffix(current_value: float, combined_value: float, format: String) -> String:
	var delta: float = combined_value - current_value
	if is_equal_approx(delta, 0.0):
		return ""
	return " (%s%s)" % ["+" if delta > 0.0 else "", format % delta]


static func _build_delta_stat_value(current_value: float, combined_value: float, max_value: float, color: Color, format: String) -> Control:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 3)

	var swatch := Control.new()
	swatch.custom_minimum_size = Vector2(STAT_SWATCH_WIDTH, 10)

	var bg := ColorRect.new()
	bg.color = Color(1.0, 1.0, 1.0, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	swatch.add_child(bg)

	var current_ratio: float = clampf(current_value / max_value, 0.0, 1.0)
	var combined_ratio: float = clampf(combined_value / max_value, 0.0, 1.0)
	var base_ratio: float = minf(current_ratio, combined_ratio)

	var fill := ColorRect.new()
	fill.color = color
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_top = 0.0
	fill.offset_bottom = 0.0
	fill.offset_left = 0.0
	fill.offset_right = STAT_SWATCH_WIDTH * base_ratio
	swatch.add_child(fill)

	if combined_ratio > current_ratio:
		var growth := ColorRect.new()
		growth.color = Color(1.0, 1.0, 1.0, 0.75)
		growth.anchor_top = 0.0
		growth.anchor_bottom = 1.0
		growth.offset_top = 0.0
		growth.offset_bottom = 0.0
		growth.offset_left = STAT_SWATCH_WIDTH * base_ratio
		growth.offset_right = STAT_SWATCH_WIDTH * combined_ratio
		swatch.add_child(growth)
	elif combined_ratio < current_ratio:
		var loss := ColorRect.new()
		loss.color = Color(0.95, 0.2, 0.15, 0.85)
		loss.anchor_top = 0.0
		loss.anchor_bottom = 1.0
		loss.offset_top = 0.0
		loss.offset_bottom = 0.0
		loss.offset_left = STAT_SWATCH_WIDTH * base_ratio
		loss.offset_right = STAT_SWATCH_WIDTH * current_ratio
		swatch.add_child(loss)

	wrap.add_child(swatch)

	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.text = format % current_value
	wrap.add_child(value_label)

	var delta: float = combined_value - current_value
	if not is_equal_approx(delta, 0.0):
		var delta_label := Label.new()
		delta_label.add_theme_font_size_override("font_size", 9)
		delta_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55) if delta > 0.0 else Color(0.95, 0.55, 0.45))
		delta_label.text = ("+" if delta > 0.0 else "") + (format % delta)
		wrap.add_child(delta_label)

	return wrap


static func blended_color_for(occurrences_by_type: Dictionary) -> Color:
	if occurrences_by_type.is_empty():
		return EMPTY_VIAL_COLOR
	var total: int = 0
	for count in occurrences_by_type.values():
		total += count
	var blended := Color(0.0, 0.0, 0.0, 0.0)
	for type in occurrences_by_type.keys():
		var weight: float = float(occurrences_by_type[type]) / float(total)
		blended += TYPE_COLORS.get(type, Color.WHITE) * weight
	return blended


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return accepts_drops and data is Dictionary and data.has("part")


func _drop_data(_position: Vector2, data: Variant) -> void:
	item_dropped.emit(data["part"])
