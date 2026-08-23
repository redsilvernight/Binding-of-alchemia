extends PanelContainer

@export var slot_scene: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")

@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var mixture_grid: HBoxContainer = $Margin/VBox/MixtureRow/MixtureGrid
@onready var weapon_grid: HBoxContainer = $Margin/VBox/WeaponRow/WeaponGrid


func setup(display_name: String) -> void:
	name_label.text = display_name


func add_mixture_slot(icon: Texture2D, quantity: int, tooltip: String) -> void:
	_add_slot(mixture_grid, icon, quantity, tooltip)


func add_weapon_slot(icon: Texture2D, quantity: int, tooltip: String) -> void:
	_add_slot(weapon_grid, icon, quantity, tooltip)


func _add_slot(grid: HBoxContainer, icon: Texture2D, quantity: int, tooltip: String) -> void:
	var slot: Control = slot_scene.instantiate()
	grid.add_child(slot)
	slot.setup(icon, quantity, tooltip)
