## Classe de base d'un état de la FSM ennemi (Phase 7.2). `enemy` n'est pas
## typé strictement : chaque état accède aux membres qu'il attend par duck
## typing (même convention que Room.register_enemy() pour `enemy.active`),
## pour rester réutilisable par n'importe quel script d'ennemi concret.
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
