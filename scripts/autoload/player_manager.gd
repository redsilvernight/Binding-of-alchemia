extends Node

@export var MAX_LIFEPOINT: float = 20.0

func spawn_player(id: int) -> Node:
	var player: Node = preload("res://scenes/player.tscn").instantiate()
	player.set_multiplayer_authority(id)
	player.name = str(id)

	player.get_node("Inventory").set_multiplayer_authority(1)

	return player
