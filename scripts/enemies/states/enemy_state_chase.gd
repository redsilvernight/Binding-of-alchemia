## Poursuit le joueur le plus proche. Reprend telle quelle la logique de
## ciblage qui vivait dans ennemi_test.gd avant la FSM (7.2) — le script
## concret doit exposer `speed` (float), `target` (Node2D) et
## `_update_target()` (qui écrit `target`). Déplacement via
## EnemyBase.move_toward_position() (Phase 11.1, pathfinding) au lieu d'une
## ligne droite pure.
class_name EnemyStateChase
extends EnemyState

func physics_process(_delta: float) -> void:
	enemy._update_target()
	if enemy.target and is_instance_valid(enemy.target):
		enemy.move_toward_position(enemy.target.global_position, enemy.speed)
