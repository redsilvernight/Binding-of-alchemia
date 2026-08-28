extends EnemyBase
@export var speed: float = 140.0
@export var heal_amount: float = 8.0
@export var heal_cooldown: float = 3.0
@export var heal_range: float = 260.0
@export var flee_range: float = 300.0
var heal_target: Node2D = null
@onready var sprite: AnimatedSprite2D = $Sprite2D
var _last_facing_direction: Vector2 = Vector2.DOWN

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateSupport.new(self)))
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

func _update_heal_target() -> void:
	var best: Node2D = null
	var best_ratio: float = 1.0
	for other in get_tree().get_nodes_in_group("Enemies"):
		if other == self or other.is_dead:
			continue
		if other.lifepoint >= other.max_lifepoint:
			continue
		var ratio: float = other.lifepoint / other.max_lifepoint
		if ratio < best_ratio:
			best_ratio = ratio
			best = other
	heal_target = best

func heal_at(p_target: Node2D) -> void:
	p_target.heal(heal_amount)
	var direction: Vector2 = global_position.direction_to(p_target.global_position)
	if direction.length() >= 0.001:
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
