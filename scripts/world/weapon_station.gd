extends Node2D


@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	interactable.player_left.connect(_on_player_left)


func _on_interacted(player: Node2D) -> void:
	if player.has_method("open_weapon_crafting"):
		player.open_weapon_crafting()


func _on_player_left(player: Node2D) -> void:
	if player.has_method("close_weapon_crafting"):
		player.close_weapon_crafting()
