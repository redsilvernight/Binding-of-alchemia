class_name EnemyBase
extends Character

var active: bool = false

@export var currency_reward: int = 5

var carries_ingredient_path: String = ""
var origin_room: Room = null

const AMBIENT_MIN_INTERVAL: float = 4.0
const AMBIENT_MAX_INTERVAL: float = 10.0
const AMBIENT_RANGE: float = 1400.0
@export var ambient_sfx_key: String = "mob_ambient_1"

var _ambient_timer: float = 0.0

var nav_agent: NavigationAgent2D

var speed_multiplier: float = 1.0
var _slow_timer: Timer

func _ready() -> void:
	super()
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = 8.0
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 28.0
	add_child(nav_agent)
	nav_agent.velocity_computed.connect(_on_nav_velocity_computed)
	add_to_group("Enemies")
	_reset_ambient_timer()
	_setup_shadow()
	health_changed.connect(_on_health_changed_blink)

const DEFAULT_SHADOW_CAPSULE_RADIUS: float = 32.0

func _setup_shadow() -> void:
	var sprite: CanvasItem = get_node_or_null("Sprite2D")
	if sprite != null:
		sprite.light_mask = 2
	var capsule_radius: float = DEFAULT_SHADOW_CAPSULE_RADIUS
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision != null and collision.shape is CapsuleShape2D:
		capsule_radius = (collision.shape as CapsuleShape2D).radius
	var radius_x: float = capsule_radius * 0.55
	var radius_y: float = capsule_radius * 0.32
	var points := PackedVector2Array()
	const POINT_COUNT: int = 8
	for i in POINT_COUNT:
		var angle: float = TAU * i / POINT_COUNT
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	var occluder_polygon := OccluderPolygon2D.new()
	occluder_polygon.polygon = points
	var occluder := LightOccluder2D.new()
	occluder.occluder = occluder_polygon
	occluder.position = Vector2(0, radius_y * 1.4)
	add_child(occluder)

func move(direction: Vector2, speed: float) -> void:
	super(direction, speed * speed_multiplier)

func move_toward_position(target_position: Vector2, speed: float) -> void:
	nav_agent.target_position = target_position
	if nav_agent.is_navigation_finished():
		move(Vector2.ZERO, 0.0)
		return
	var next_point: Vector2 = nav_agent.get_next_path_position()
	nav_agent.set_velocity(global_position.direction_to(next_point) * speed * speed_multiplier)

func apply_slow(multiplier: float, duration: float) -> void:
	speed_multiplier = multiplier
	if _slow_timer == null:
		_slow_timer = Timer.new()
		_slow_timer.one_shot = true
		add_child(_slow_timer)
		_slow_timer.timeout.connect(func() -> void: speed_multiplier = 1.0)
	_slow_timer.start(duration)

var _pull_target_position: Vector2 = Vector2.ZERO
var _pull_strength: float = 0.0
var _pull_timer: Timer

func apply_pull(target_position: Vector2, strength: float, duration: float) -> void:
	_pull_target_position = target_position
	_pull_strength = strength
	if _pull_timer == null:
		_pull_timer = Timer.new()
		_pull_timer.one_shot = true
		add_child(_pull_timer)
	_pull_timer.start(duration)

func is_being_pulled() -> bool:
	return _pull_timer != null and _pull_timer.time_left > 0.0

func _process_pull(_delta: float) -> bool:
	if not is_being_pulled():
		return false
	velocity = global_position.direction_to(_pull_target_position) * _pull_strength
	move_and_slide()
	return true

func _on_nav_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

func _process(delta: float) -> void:
	if is_dead:
		return
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_reset_ambient_timer()
		_maybe_play_ambient_sound()

func _reset_ambient_timer() -> void:
	_ambient_timer = randf_range(AMBIENT_MIN_INTERVAL, AMBIENT_MAX_INTERVAL)

func _maybe_play_ambient_sound() -> void:
	var player: Node2D = _closest_living_player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > AMBIENT_RANGE:
		return
	AudioManager.play_sfx(ambient_sfx_key)

func _get_hit_sfx_key() -> String:
	return "hit_enemy"

const HIT_BLINK_ALPHA: float = 0.25
const HIT_BLINK_STEP_DURATION: float = 0.06
const HIT_BLINK_COUNT: int = 3

func _on_health_changed_blink(_max_lifepoint: float, p_lifepoint: float) -> void:
	if p_lifepoint <= 0:
		return
	var sprite: CanvasItem = get_node_or_null("Sprite2D")
	if sprite == null:
		return
	var base_alpha: float = sprite.modulate.a
	var tween: Tween = create_tween()
	tween.set_loops(HIT_BLINK_COUNT)
	tween.tween_property(sprite, "modulate:a", HIT_BLINK_ALPHA, HIT_BLINK_STEP_DURATION)
	tween.tween_property(sprite, "modulate:a", base_alpha, HIT_BLINK_STEP_DURATION)

func _on_death() -> void:
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game == null:
		return
	game.request_currency_drop(global_position, currency_reward)
	if carries_ingredient_path != "":
		game.request_enemy_drop(global_position, carries_ingredient_path)

func kill() -> void:
	if multiplayer.is_server():
		_on_death()
	super()

func _closest_living_player() -> Node2D:
	var closest: Node2D = null
	var closest_distance: float = INF
	for player in get_tree().get_nodes_in_group("Players"):
		if player.is_dead:
			continue
		var distance: float = global_position.distance_squared_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = player
	return closest
