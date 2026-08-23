class_name EnemyStateRangedAttack
extends EnemyState

var _time_until_shot: float = 0.0

func enter() -> void:
	_time_until_shot = enemy.fire_cooldown

func physics_process(delta: float) -> void:
	enemy._update_target()
	if not enemy.target or not is_instance_valid(enemy.target):
		return
	var to_target: Vector2 = enemy.target.global_position - enemy.global_position
	var distance: float = to_target.length()
	if distance < enemy.preferred_range:
		enemy.move(-to_target.normalized(), enemy.speed)
	elif distance > enemy.attack_range:
		enemy.move_toward_position(enemy.target.global_position, enemy.speed)
	else:
		enemy.move(Vector2.ZERO, 0.0)
		_time_until_shot -= delta
		if _time_until_shot <= 0.0:
			enemy.fire_at(enemy.target)
			_time_until_shot = enemy.fire_cooldown
