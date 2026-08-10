class_name Room
extends Node2D

# Salle de donjon générique (Phase 6.1). Un template déclare ses 4 côtés
# (North/South/East/West), chacun pré-câblé dans la scène avec deux
# configurations de collision : "Closed" (mur plein) et "Open" (mur avec
# une ouverture de porte). Le générateur (DungeonGenerator, appelé depuis
# game.gd côté hôte) décide quels côtés sont réellement connectés à une
# salle voisine et appelle set_open_sides() en conséquence — le template
# lui-même ne sait rien de sa position dans le donjon.

const SIDES: Array[String] = ["north", "south", "east", "west"]

@onready var _closed_by_side: Dictionary = {
	"north": $North/Closed,
	"south": $South/Closed,
	"east": $East/Closed,
	"west": $West/Closed,
}
@onready var _open_by_side: Dictionary = {
	"north": $North/Open,
	"south": $South/Open,
	"east": $East/Open,
	"west": $West/Open,
}


func set_open_sides(open_sides: Array) -> void:
	for side in SIDES:
		var is_open: bool = side in open_sides
		_set_body_disabled(_closed_by_side[side], is_open)
		_set_body_disabled(_open_by_side[side], not is_open)


func _set_body_disabled(body: StaticBody2D, disabled: bool) -> void:
	for child in body.get_children():
		if child is CollisionShape2D:
			child.disabled = disabled
