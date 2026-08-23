class_name EnemyStateCharge
extends EnemyState

enum Phase { APPROACH, TELEGRAPH, DASH, COOLDOWN }

var _phase: int = Phase.APPROACH
var _timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO

func physics_process(delta: float) -> void:
	enemy._update_target()
	if not enemy.target or not is_instance_valid(enemy.target):
		enemy.move(Vector2.ZERO, 0.0)
		return
	match _phase:
		Phase.APPROACH:
			_process_approach()
		Phase.TELEGRAPH:
			_process_telegraph(delta)
		Phase.DASH:
			_process_dash(delta)
		Phase.COOLDOWN:
			_process_cooldown(delta)

func _process_approach() -> void:
	var to_target: Vector2 = enemy.target.global_position - enemy.global_position
	if to_target.length() <= enemy.charge_range:
		_dash_direction = to_target.normalized()
		enemy.move(Vector2.ZERO, 0.0)
		enemy._play_telegraph_animation(_dash_direction)
		_timer = enemy.telegraph_duration
		_phase = Phase.TELEGRAPH
		return
	enemy.move_toward_position(enemy.target.global_position, enemy.speed)

func _process_telegraph(delta: float) -> void:
	enemy.move(Vector2.ZERO, 0.0)
	_timer -= delta
	if _timer <= 0.0:
		_timer = enemy.dash_duration
		_phase = Phase.DASH

func _process_dash(delta: float) -> void:
	enemy.move(_dash_direction, enemy.dash_speed)
	_timer -= delta
	if _timer <= 0.0:
		_timer = enemy.cooldown_duration
		_phase = Phase.COOLDOWN

func _process_cooldown(delta: float) -> void:
	enemy.move(Vector2.ZERO, 0.0)
	_timer -= delta
	if _timer <= 0.0:
		_phase = Phase.APPROACH
