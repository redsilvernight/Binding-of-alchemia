class_name EnemyStateChase
extends EnemyState

func physics_process(_delta: float) -> void:
	enemy._update_target()
	if enemy.target and is_instance_valid(enemy.target):
		enemy.move_toward_position(enemy.target.global_position, enemy.speed)
