class_name EnemyStateRangedAttack
extends EnemyState

var _time_until_shot: float = 0.0
var _strafe_direction: float = 1.0

func enter() -> void:
	_time_until_shot = enemy.fire_cooldown

func physics_process(delta: float) -> void:
	enemy._update_target()
	if not enemy.target or not is_instance_valid(enemy.target):
		return
	var to_target: Vector2 = enemy.target.global_position - enemy.global_position
	var distance: float = to_target.length()
	if distance < enemy.preferred_range:
		var retreat_point: Vector2 = enemy.global_position - to_target.normalized() * enemy.retreat_step
		enemy.move_toward_position(retreat_point, enemy.speed)
	elif distance > enemy.attack_range:
		enemy.move_toward_position(enemy.target.global_position, enemy.speed)
	else:
		var perpendicular: Vector2 = to_target.normalized().orthogonal() * _strafe_direction
		enemy.move(perpendicular, enemy.strafe_speed)
		_time_until_shot -= delta
		if _time_until_shot <= 0.0:
			enemy.fire_at(enemy.target)
			_time_until_shot = enemy.fire_cooldown
			_strafe_direction *= -1.0
