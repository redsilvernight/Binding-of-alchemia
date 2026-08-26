extends Control
class_name WeaponStatsPreview


const FIRE_ROWS: Array[Dictionary] = [
	{
		"label": "Eau", "color": Color(0.4, 0.7, 0.95),
		"fields": ["water_damage", "water_fire_rate", "water_projectile_speed"],
		"maxes": [20.0, 3.0, 600.0],
		"formats": ["%.0f", "%.1f/s", "%.0f"],
	},
	{
		"label": "Mixture", "color": Color(0.78, 0.5, 0.9),
		"fields": ["mixture_damage_multiplier", "mixture_fire_rate", "mixture_projectile_speed"],
		"maxes": [15.0, 3.0, 500.0],
		"formats": ["%.1f", "%.1f/s", "%.0f"],
	},
]

const SECONDARY_ROWS: Array[Dictionary] = [
	{"label": "Capacité", "field": "mixture_max_capacity", "color": Color(0.4, 0.85, 0.7), "max": 300.0, "format": "%.0f"},
	{"label": "Régén.", "field": "mixture_regen_rate", "color": Color(0.4, 0.85, 0.7), "max": 10.0, "format": "%.1f/s"},
	{"label": "Portée", "field": "range_value", "color": Color(0.9, 0.75, 0.35), "max": 150.0, "format": "%.0f"},
]

@export var stack_secondary_below: bool = false
@export var group_separation: int = 8
@export var fire_row_separation: int = 6

@onready var column: VBoxContainer = $Column
@onready var stats_row: HBoxContainer = $Column/StatsRow
@onready var fire_grid: GridContainer = $Column/StatsRow/FireGrid
@onready var spacer: Control = $Column/StatsRow/Spacer
@onready var secondary_grid: GridContainer = $Column/StatsRow/SecondaryGrid


func _ready() -> void:
	column.add_theme_constant_override("separation", group_separation)
	fire_grid.add_theme_constant_override("v_separation", fire_row_separation)
	if stack_secondary_below:
		spacer.queue_free()
		secondary_grid.reparent(column)
	column.minimum_size_changed.connect(update_minimum_size)
	display_stats(null)


func _get_minimum_size() -> Vector2:
	if column == null:
		return Vector2.ZERO
	return column.get_combined_minimum_size()


func display_stats(current_stats: WeaponStats, combined_stats: WeaponStats = null) -> void:
	stats_row.visible = current_stats != null or combined_stats != null
	populate_delta_stats_grid(fire_grid, secondary_grid, current_stats, combined_stats if combined_stats != null else current_stats)


static func populate_delta_stats_grid(fire_grid_to_fill: GridContainer, secondary_grid_to_fill: GridContainer, current_stats: WeaponStats, combined_stats: WeaponStats) -> void:
	for child in fire_grid_to_fill.get_children():
		child.queue_free()
	for child in secondary_grid_to_fill.get_children():
		child.queue_free()
	if current_stats == null and combined_stats == null:
		return

	var current: WeaponStats = current_stats if current_stats != null else WeaponStats.new()
	var combined: WeaponStats = combined_stats if combined_stats != null else WeaponStats.new()

	_add_fire_header(fire_grid_to_fill)
	for row in FIRE_ROWS:
		_add_fire_row(fire_grid_to_fill, row, current, combined)

	for row in SECONDARY_ROWS:
		secondary_grid_to_fill.add_child(_build_stat_cell(row, current, combined))


static func _add_fire_header(grid_to_fill: GridContainer) -> void:
	grid_to_fill.add_child(Control.new())
	grid_to_fill.add_child(Control.new())
	for column_text in ["Dégâts", "Cadence", "Vitesse"]:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.72, 0.7, 0.66))
		label.text = column_text
		grid_to_fill.add_child(label)


static func _add_fire_row(grid_to_fill: GridContainer, row: Dictionary, current: WeaponStats, combined: WeaponStats) -> void:
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 14)
	dot.color = row["color"]
	grid_to_fill.add_child(dot)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.text = row["label"]
	grid_to_fill.add_child(label)

	var fields: Array = row["fields"]
	var maxes: Array = row["maxes"]
	var formats: Array = row["formats"]
	for i in fields.size():
		var field: String = fields[i]
		grid_to_fill.add_child(StatBar.build_delta_value(current.get(field), combined.get(field), maxes[i], row["color"], formats[i]))


static func _build_stat_cell(row: Dictionary, current: WeaponStats, combined: WeaponStats) -> Control:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 6)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 14)
	dot.color = row["color"]
	cell.add_child(dot)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.text = row["label"]
	cell.add_child(label)

	cell.add_child(StatBar.build_delta_value(current.get(row["field"]), combined.get(row["field"]), row["max"], row["color"], row["format"]))
	return cell
