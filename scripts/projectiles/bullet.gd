extends Area2D
class_name Bullet

enum TrajectoryType { LINEAR, ARC, HOMING }

var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var lifetime: float = 3.0
var _base_speed: float = 0.0
var trajectory: TrajectoryType = TrajectoryType.LINEAR
var impact_effect: ImpactEffect = null
var shooter_id: int = 0
var impact_sfx_key: String = "impact_water"

var _arc_time: float = 0.0
var _arc_height: float = 90.0
var _arc_duration: float = 1.1
var _arc_direction: Vector2 = Vector2.RIGHT
var _arc_start_position: Vector2 = Vector2.ZERO
var _arc_landed: bool = false
var _arc_vertical_dir: Vector2 = Vector2.UP

var _homing_target: Node2D = null
var _homing_turn_speed: float = 5.0
const HOMING_ACQUIRE_RANGE: float = 500.0

const SPAWN_WALL_GRACE_TIME: float = 0.15
var _time_since_launch: float = 0.0

const WALL_STRUCTURE_LAYER: int = 8

var bounces_remaining: int = 0

func set_bounce(count: int) -> void:
	bounces_remaining = count

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
	_arc_vertical_dir = _arc_bulge_direction(_arc_direction)
	velocity = _arc_direction * _base_speed
	rotation = velocity.angle()
	if trajectory == TrajectoryType.HOMING:
		_acquire_homing_target()
	if multiplayer.is_server():
		var timer := get_tree().create_timer(lifetime, false)
		timer.timeout.connect(queue_free)

func _arc_bulge_direction(direction: Vector2) -> Vector2:
	return Vector2.UP if direction.y <= 0.0 else Vector2.DOWN

func _acquire_homing_target() -> void:
	var target_group: String = "Enemies" if shooter_id > 0 else "Players"
	var closest: Node2D = null
	var closest_distance: float = HOMING_ACQUIRE_RANGE * HOMING_ACQUIRE_RANGE
	for node in get_tree().get_nodes_in_group(target_group):
		if node.is_dead:
			continue
		var distance: float = global_position.distance_squared_to(node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = node
	set_homing_target(closest)

func _physics_process(delta: float) -> void:
	_time_since_launch += delta
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
	if _arc_landed:
		return
	_arc_time += delta
	var t: float = clamp(_arc_time / _arc_duration, 0.0, 1.0)
	var forward_distance: float = _base_speed * _arc_duration * t
	var offset: Vector2 = _arc_direction * forward_distance
	var height_offset: float = 4.0 * _arc_height * t * (1.0 - t)
	global_position = _arc_start_position + offset + _arc_vertical_dir * height_offset
	var height_rate: float = 4.0 * _arc_height * (1.0 - 2.0 * t) / _arc_duration
	var tangent: Vector2 = _arc_direction * _base_speed + _arc_vertical_dir * height_rate
	if tangent.length_squared() > 0.0:
		rotation = tangent.angle()
	if t >= 1.0:
		_land_arc()

func _land_arc() -> void:
	_arc_landed = true
	_trigger_impact_effect(self)
	if multiplayer.is_server():
		queue_free()

func _process_homing(delta: float) -> void:
	if is_instance_valid(_homing_target):
		var desired_direction: Vector2 = (_homing_target.global_position - global_position).normalized()
		var current_direction: Vector2 = velocity.normalized()
		var new_direction: Vector2 = current_direction.slerp(desired_direction, _homing_turn_speed * delta)
		velocity = new_direction * _base_speed
		rotation = velocity.angle()
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body.has_node("Hurtbox"):
		return
	if body.name == "Floor" and _time_since_launch < SPAWN_WALL_GRACE_TIME:
		return
	if _try_wall_bounce():
		_trigger_impact_effect(self)
		return
	_resolve_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_resolve_hit(area.get_parent())


func _resolve_hit(target: Node) -> void:
	var is_damageable: bool = target.has_method("take_damage")
	_trigger_impact_effect(target)
	if is_damageable and _try_bounce(target):
		return
	if not multiplayer.is_server():
		return
	queue_free()

func _trigger_impact_effect(target: Node) -> void:
	AudioManager.play_sfx_at(impact_sfx_key, global_position)
	if impact_effect != null:
		impact_effect.spawn_visual(get_tree(), global_position)
	if target.has_method("take_damage"):
		_notify_local_shooter_hit(target)
	if not multiplayer.is_server():
		return
	if target.has_method("take_damage"):
		target.take_damage(damage)
	if impact_effect != null:
		impact_effect.apply(target, global_position, shooter_id)

func _notify_local_shooter_hit(target: Node) -> void:
	if shooter_id <= 0:
		return
	for player in get_tree().get_nodes_in_group("Players"):
		var is_matching_shooter: bool = player.name.is_valid_int() and int(player.name) == shooter_id
		if player.is_multiplayer_authority() and is_matching_shooter:
			player.on_hit_dealt(damage, target.max_lifepoint)
			return

func _try_bounce(hit_target: Node) -> bool:
	if bounces_remaining <= 0:
		return false
	if not (hit_target is Node2D):
		return false
	var normal: Vector2 = global_position - (hit_target as Node2D).global_position
	if normal.length() < 0.01:
		normal = -velocity.normalized()
	normal = normal.normalized()
	global_position += normal * 8.0
	_bounce_off(normal)
	return true

func _try_wall_bounce() -> bool:
	if bounces_remaining <= 0:
		return false
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision_shape == null or collision_shape.shape == null:
		return false
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = WALL_STRUCTURE_LAYER
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.get_rest_info(query)
	if result.is_empty():
		return false
	var normal: Vector2 = result.get("normal", Vector2.ZERO)
	if normal == Vector2.ZERO:
		return false
	global_position += normal * 4.0
	_bounce_off(normal)
	return true

func _bounce_off(normal: Vector2) -> void:
	bounces_remaining -= 1
	velocity = velocity.bounce(normal)
	rotation = velocity.angle()
	_arc_time = 0.0
	_arc_start_position = global_position
	_arc_direction = velocity.normalized()
	_arc_vertical_dir = _arc_bulge_direction(_arc_direction)
	_homing_target = null
