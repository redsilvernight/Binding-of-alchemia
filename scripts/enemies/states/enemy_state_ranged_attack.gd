class_name EnemyStateRangedAttack
extends EnemyState

const AXIS_ALIGNMENT_SIN_THRESHOLD: float = 0.2

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
		_resolve_axis_conflict(to_target)
		var perpendicular: Vector2 = to_target.normalized().orthogonal() * _strafe_direction
		enemy.move(perpendicular, enemy.strafe_speed)
		_time_until_shot -= delta
		if _time_until_shot <= 0.0:
			enemy.fire_at(enemy.target)
			_time_until_shot = enemy.fire_cooldown
			_strafe_direction *= -1.0

func _resolve_axis_conflict(to_target: Vector2) -> void:
	if enemy.origin_room == null:
		return
	var bearing_to_self: Vector2 = -to_target.normalized()
	for sibling in enemy.origin_room.get_alive_enemies():
		if sibling == enemy or not is_instance_valid(sibling):
			continue
		if sibling.get_script() != enemy.get_script() or sibling.target != enemy.target:
			continue
		if enemy.get_instance_id() > sibling.get_instance_id():
			continue
		var sibling_offset: Vector2 = sibling.global_position - enemy.target.global_position
		var bearing_to_sibling: Vector2 = sibling_offset.normalized()
		var alignment: float = bearing_to_self.cross(bearing_to_sibling)
		if absf(alignment) < AXIS_ALIGNMENT_SIN_THRESHOLD:
			_strafe_direction = signf(alignment) if alignment != 0.0 else 1.0
			return
