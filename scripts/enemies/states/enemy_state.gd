class_name EnemyState
extends RefCounted

var enemy: Node

func _init(p_enemy: Node) -> void:
	enemy = p_enemy

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_process(_delta: float) -> void:
	pass
