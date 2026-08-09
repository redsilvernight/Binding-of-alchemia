extends Node

var enemy_test: PackedScene = preload("res://scenes/mobs/ennemy_test.tscn")

func get_enemy_scene() -> PackedScene:
	return enemy_test
