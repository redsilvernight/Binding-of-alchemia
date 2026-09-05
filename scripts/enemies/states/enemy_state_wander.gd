class_name EnemyStateWander
extends EnemyState

const DIRECTION_CHANGE_INTERVAL: float = 1.2
const AVOIDANCE_RADIUS: float = 160.0
const AVOIDANCE_WEIGHT: float = 2.0

var _direction: Vector2 = Vector2.ZERO
var _time_until_change: float = 0.0

func enter() -> void:
	_pick_new_direction()

func physics_process(delta: float) -> void:
	_time_until_change -= delta
	if _time_until_change <= 0.0:
		_pick_new_direction()
	enemy.move(_movement_direction(), enemy.speed)

func _pick_new_direction() -> void:
	_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	_time_until_change = DIRECTION_CHANGE_INTERVAL

func _movement_direction() -> Vector2:
	var player: Node2D = enemy._closest_living_player()
	if player == null:
		return _direction
	var away: Vector2 = enemy.global_position - player.global_position
	var distance: float = away.length()
	if distance <= 0.0 or distance >= AVOIDANCE_RADIUS:
		return _direction
	var avoidance: float = (1.0 - distance / AVOIDANCE_RADIUS) * AVOIDANCE_WEIGHT
	return (_direction + away.normalized() * avoidance).normalized()
