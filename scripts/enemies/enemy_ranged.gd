extends EnemyBase
@export var speed: float = 90.0
@export var damage: float = 8.0
@export var preferred_range: float = 200.0
@export var attack_range: float = 450.0
@export var fire_cooldown: float = 1.5
@export var projectile_speed: float = 320.0
@export var strafe_speed: float = 70.0
@export var retreat_step: float = 140.0
@export var attack_sfx_key: String = "enemy_attack_ranged"
@export var projectile_scene_path: String = "res://scenes/enemies/enemy_projectile.tscn"
var target: Node2D = null
@onready var sprite: AnimatedSprite2D = $Sprite2D
var _last_facing_direction: Vector2 = Vector2.DOWN

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateRangedAttack.new(self)))
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

func fire_at(p_target: Node2D) -> void:
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game == null:
		return
	var fire_direction := global_position.direction_to(p_target.global_position)
	sprite.play(StringName("attack-" + FacingDirection.label_for(fire_direction)))
	game.request_enemy_projectile({
		"scene_path": projectile_scene_path,
		"damage": damage,
		"speed": projectile_speed,
		"lifetime": 2.0,
		"trajectory": Bullet.TrajectoryType.LINEAR,
		"from_position": global_position,
		"direction": global_position.direction_to(p_target.global_position),
		"attack_sfx_key": attack_sfx_key,
	})

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
