extends Node2D

# Station de déblocage méta (Phase 8.2), hub uniquement. Même convention que
# alchemy_station.gd/run_start_station.gd : Interactable détecte, ce script
# relaie vers l'écran de déblocage du joueur qui a interagi.

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _on_interacted(player: Node2D) -> void:
	if player.has_method("open_unlock_screen"):
		player.open_unlock_screen()
