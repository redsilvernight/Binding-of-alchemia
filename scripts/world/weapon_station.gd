extends Node2D

# Station d'arme (Phase 5.3/5.4). Ne fait que relier le signal générique
# d'Interactable à l'ouverture de l'écran de crafting du joueur qui a
# interagi. Aucune logique de jeu ici — cf. Interactable pour la convention.

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	interactable.player_left.connect(_on_player_left)


func _on_interacted(player: Node2D) -> void:
	if player.has_method("open_weapon_crafting"):
		player.open_weapon_crafting()


## Retour utilisateur : fermer l'écran en s'éloignant, même comportement
## que AlchemyStation._on_player_left.
func _on_player_left(player: Node2D) -> void:
	if player.has_method("close_weapon_crafting"):
		player.close_weapon_crafting()
