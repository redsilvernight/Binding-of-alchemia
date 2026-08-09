extends Area2D
class_name Bullet

enum TrajectoryType { LINEAR, ARC, HOMING }

var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var lifetime: float = 3.0
var _base_speed: float = 0.0
var trajectory: TrajectoryType = TrajectoryType.LINEAR
var impact_effect: ImpactEffect = null

# --- ARC ---
var _arc_time: float = 0.0
var _arc_height: float = 40.0
var _arc_duration: float = 0.6
var _arc_direction: Vector2 = Vector2.RIGHT
var _arc_start_position: Vector2 = Vector2.ZERO

# --- HOMING ---
var _homing_target: Node2D = null
var _homing_turn_speed: float = 5.0

func setup(p_damage: float, p_speed: float, p_lifetime: float = 3.0, p_trajectory: TrajectoryType = TrajectoryType.LINEAR) -> void:
	damage = p_damage
	_base_speed = p_speed
	lifetime = p_lifetime
	trajectory = p_trajectory

func set_impact_effect(effect: ImpactEffect) -> void:
	impact_effect = effect

func set_arc_params(height: float, duration: float) -> void:
	_arc_height = height
	_arc_duration = duration

func set_homing_target(target: Node2D, turn_speed: float = 5.0) -> void:
	_homing_target = target
	_homing_turn_speed = turn_speed

func launch(from_position: Vector2, aim_direction: Vector2) -> void:
	global_position = from_position
	_arc_start_position = from_position
	_arc_direction = aim_direction.normalized()
	velocity = _arc_direction * _base_speed
	rotation = velocity.angle()
	if multiplayer.is_server():
		var timer := get_tree().create_timer(lifetime)
		timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	match trajectory:
		TrajectoryType.LINEAR:
			_process_linear(delta)
		TrajectoryType.ARC:
			_process_arc(delta)
		TrajectoryType.HOMING:
			_process_homing(delta)

func _process_linear(delta: float) -> void:
	global_position += velocity * delta

func _process_arc(delta: float) -> void:
	_arc_time += delta
	var t: float = clamp(_arc_time / _arc_duration, 0.0, 1.0)
	var forward_distance: float = _base_speed * _arc_time
	var offset: Vector2 = _arc_direction * forward_distance
	var height_offset: float = -4.0 * _arc_height * t * (1.0 - t)
	var perpendicular: Vector2 = _arc_direction.rotated(-PI / 2.0)
	global_position = _arc_start_position + offset + perpendicular * height_offset

func _process_homing(delta: float) -> void:
	if is_instance_valid(_homing_target):
		var desired_direction: Vector2 = (_homing_target.global_position - global_position).normalized()
		var current_direction: Vector2 = velocity.normalized()
		var new_direction: Vector2 = current_direction.slerp(desired_direction, _homing_turn_speed * delta)
		velocity = new_direction * _base_speed
		rotation = velocity.angle()
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if impact_effect != null:
		impact_effect.apply(body, global_position)
	elif body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
