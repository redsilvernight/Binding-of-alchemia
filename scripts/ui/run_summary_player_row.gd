extends PanelContainer
## Une ligne du panneau de résumé de run (scripts/ui/run_summary_panel.gd) :
## nom du joueur, icônes de la mixture actuellement chargée, icônes des
## pièces d'arme équipées. Purement affichage, remplie par run_summary_panel.gd.
##
## Cette rangée elle-même doit déjà être dans l'arbre (add_child) avant que
## setup()/add_mixture_slot()/add_weapon_slot() soient appelés : les @onready
## ci-dessous ne sont résolus qu'après _ready(), même piège documenté ailleurs
## dans le projet (cf. room.gd.set_open_sides, boss_healthbar.gd.bind_boss).

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
	# add_child AVANT setup : InventorySlot.setup() écrit dans ses propres
	# @onready (icon_rect/quantity_label), pas encore résolus tant que le
	# noeud n'est pas entré dans l'arbre.
	grid.add_child(slot)
	slot.setup(icon, quantity, tooltip)
