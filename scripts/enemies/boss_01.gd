extends EnemyBase
@export var boss_max_lifepoint: float = 180.0
@export var speed: float = 110.0
@export var contact_damage: float = 12.0
@export var preferred_range: float = 220.0
@export var attack_range: float = 500.0
@export var fire_cooldown: float = 1.0
@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 340.0
@export var strafe_speed: float = 70.0
@export var retreat_step: float = 140.0
@export var melee_lunge_range: float = 260.0
@export var melee_telegraph_duration: float = 0.5
@export var melee_lunge_duration: float = 0.35
@export var melee_lunge_speed: float = 420.0
@export var melee_cooldown_duration: float = 0.6
var target: Node2D = null
@onready var sprite: AnimatedSprite2D = $Sprite2D
var _last_facing_direction: Vector2 = Vector2.DOWN

var state_machine: EnemyStateMachine
var _phase: int = 1
var _shot_index: int = 0

const LIFEPOINT_GROWTH_PER_FLOOR: float = 0.10
const DAMAGE_GROWTH_PER_FLOOR: float = 0.05
const FIRE_COOLDOWN_REDUCTION_PER_FLOOR: float = 0.03
const MIN_FIRE_COOLDOWN_MULTIPLIER: float = 0.5
const PHASE3_HEALTH_THRESHOLD: float = 0.2
const PHASE3_FIRE_COOLDOWN_MULTIPLIER: float = 0.6
const RANGED_TRAJECTORY_PATTERN: Array[Bullet.TrajectoryType] = [
	Bullet.TrajectoryType.LINEAR,
	Bullet.TrajectoryType.LINEAR,
	Bullet.TrajectoryType.ARC,
	Bullet.TrajectoryType.HOMING,
]

func _ready() -> void:
	var floor_bonus: int = RunManager.current_floor - 1
	max_lifepoint = boss_max_lifepoint * (1.0 + LIFEPOINT_GROWTH_PER_FLOOR * floor_bonus)
	contact_damage *= 1.0 + DAMAGE_GROWTH_PER_FLOOR * floor_bonus
	projectile_damage *= 1.0 + DAMAGE_GROWTH_PER_FLOOR * floor_bonus
	fire_cooldown *= max(MIN_FIRE_COOLDOWN_MULTIPLIER, 1.0 - FIRE_COOLDOWN_REDUCTION_PER_FLOOR * floor_bonus)
	super()
	add_to_group("Boss")
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateBossMelee.new(self)))
	sprite.play()
	health_changed.connect(_on_health_changed)
	died.connect(_on_death_animation)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	if not _process_pull(delta):
		state_machine.physics_process(delta)
	_update_facing(velocity)

func _update_facing(direction: Vector2) -> void:
	if (sprite.animation.begins_with("attack") or sprite.animation.begins_with("hit")) and sprite.is_playing():
		return
	var is_moving := direction.length() > 0.001
	if is_moving:
		_last_facing_direction = direction
	var prefix := "walk-" if is_moving else "idle-"
	var anim_name := StringName(prefix + FacingDirection.label_for(_last_facing_direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _update_target() -> void:
	target = _closest_living_player()

func _on_collision_area_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if _phase != 1 and _phase != 3:
		return
	var body: Node2D = area.get_parent()
	if body.is_in_group("Players"):
		body.take_damage(contact_damage)
		var direction: Vector2 = body.global_position - global_position
		if direction.length() >= 0.001:
			sprite.play(StringName("attack-melee-" + FacingDirection.label_for(direction)))
			AudioManager.play_sfx_at("enemy_attack_melee", global_position)

func play_telegraph_animation(direction: Vector2) -> void:
	if direction.length() < 0.001:
		return
	_last_facing_direction = direction
	sprite.play(StringName("attack-melee-" + FacingDirection.label_for(direction)))

func fire_at(p_target: Node2D) -> void:
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game == null:
		return
	var fire_direction := global_position.direction_to(p_target.global_position)
	sprite.play(StringName("attack-ranged-" + FacingDirection.label_for(fire_direction)))
	var trajectory: Bullet.TrajectoryType = RANGED_TRAJECTORY_PATTERN[_shot_index % RANGED_TRAJECTORY_PATTERN.size()]
	_shot_index += 1
	game.request_enemy_projectile({
		"scene_path": "res://scenes/enemies/enemy_projectile_boss.tscn",
		"damage": projectile_damage,
		"speed": projectile_speed,
		"lifetime": 2.0,
		"trajectory": trajectory,
		"from_position": global_position,
		"direction": global_position.direction_to(p_target.global_position),
		"attack_sfx_key": "boss_attack_ranged",
	})

func take_damage(degat: float) -> void:
	super(degat)
	if not multiplayer.is_server() or is_dead:
		return
	if _phase == 1 and lifepoint <= max_lifepoint / 2.0:
		_phase = 2
		state_machine.transition_to(EnemyStateRangedAttack.new(self))
		_rpc_notify_phase.rpc(2)
	elif _phase == 2 and lifepoint <= max_lifepoint * PHASE3_HEALTH_THRESHOLD:
		_phase = 3
		fire_cooldown *= PHASE3_FIRE_COOLDOWN_MULTIPLIER
		_rpc_notify_phase.rpc(3)

@rpc("any_peer", "call_local", "reliable")
func _rpc_notify_phase(phase: int) -> void:
	match phase:
		2:
			modulate = Color(1.0, 0.55, 0.55)
			AudioManager.play_sfx("boss_phase")
		3:
			modulate = Color(1.0, 0.2, 0.2)
			AudioManager.play_sfx("boss_phase")

func _on_health_changed(_max_lifepoint: float, lifepoint: float) -> void:
	if lifepoint <= 0:
		return
	if sprite.animation.begins_with("attack"):
		return
	sprite.play(StringName("hit-" + FacingDirection.label_for(_last_facing_direction)))

func _on_death_animation() -> void:
	sprite.play(StringName("death-" + FacingDirection.label_for(_last_facing_direction)))

func _die_and_free() -> void:
	await sprite.animation_finished
	if is_instance_valid(self):
		queue_free()

func _get_death_sfx_key() -> String:
	return "boss_death"
