class_name EnemyStateWander
extends EnemyState

const DIRECTION_CHANGE_INTERVAL: float = 1.2

var _direction: Vector2 = Vector2.ZERO
var _time_until_change: float = 0.0

func enter() -> void:
	_pick_new_direction()

func physics_process(delta: float) -> void:
	_time_until_change -= delta
	if _time_until_change <= 0.0:
		_pick_new_direction()
	enemy.move(_direction, enemy.speed)

func _pick_new_direction() -> void:
	_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	_time_until_change = DIRECTION_CHANGE_INTERVAL
