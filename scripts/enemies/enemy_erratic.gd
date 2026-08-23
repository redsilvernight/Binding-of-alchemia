extends EnemyBase
@export var speed: float = 130.0
@export var damage: float = 4.0
@onready var sprite: AnimatedSprite2D = $Sprite2D
var _last_facing_direction: Vector2 = Vector2.DOWN

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateWander.new(self)))
	sprite.play()
	health_changed.connect(_on_health_changed)
	died.connect(_on_death_animation)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	state_machine.physics_process(delta)
	_update_facing(velocity)

func _update_facing(direction: Vector2) -> void:
	if (sprite.animation.begins_with("attack") or sprite.animation.begins_with("hit")) and sprite.is_playing():
		return
	if direction.length() < 0.001:
		return
	_last_facing_direction = direction
	var anim_name := StringName("walk-" + FacingDirection.label_for(direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _on_collision_area_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	var body: Node2D = area.get_parent()
	if body.is_in_group("Players"):
		body.take_damage(damage)
		_play_attack_animation(body.global_position - global_position)
		AudioManager.play_sfx("enemy_attack_melee")

func _play_attack_animation(direction: Vector2) -> void:
	if direction.length() < 0.001:
		return
	sprite.play(StringName("attack-" + FacingDirection.label_for(direction)))

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
