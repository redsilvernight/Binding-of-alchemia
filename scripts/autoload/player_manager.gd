extends Node

@export var MAX_LIFEPOINT: float = 20.0

func spawnPlayer(id: int):
	var player = preload("res://scenes/player.tscn").instantiate()
	player.set_multiplayer_authority(id)
	player.name = str(id)
	
	return player
