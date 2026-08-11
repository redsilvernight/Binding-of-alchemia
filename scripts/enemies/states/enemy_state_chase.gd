## Poursuit le joueur le plus proche. Reprend telle quelle la logique de
## ciblage/déplacement qui vivait dans ennemi_test.gd avant la FSM (7.2) —
## le script concret doit exposer `speed` (float), `target` (Node2D) et
## `_update_target()` (qui écrit `target`).
class_name EnemyStateChase
extends EnemyState

func physics_process(_delta: float) -> void:
	enemy._update_target()
	if enemy.target and is_instance_valid(enemy.target):
		var direction: Vector2 = enemy.global_position.direction_to(enemy.target.global_position)
		enemy.move(direction, enemy.speed)
