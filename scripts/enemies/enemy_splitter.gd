extends EnemyBase
@export var speed: float = 95.0
@export var damage: float = 8.0
@export var split_scene_path: String = "res://scenes/enemies/enemy_splitter_shard.tscn"
@export var split_count: int = 2
@export var split_spawn_radius: float = 48.0
var target: Node2D = null
var _has_split: bool = false
@onready var sprite: AnimatedSprite2D = $Sprite2D
var _last_facing_direction: Vector2 = Vector2.DOWN

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateChase.new(self)))
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
	if direction.length() < 0.001:
		return
	_last_facing_direction = direction
	var anim_name := StringName("walk-" + FacingDirection.label_for(direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _update_target() -> void:
	target = _closest_living_player()

func _on_collision_area_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	var body: Node2D = area.get_parent()
	if body.is_in_group("Players"):
		body.take_damage(damage)
		_play_attack_animation(body.global_position - global_position)
		AudioManager.play_sfx_at("enemy_attack_melee", global_position)

func _play_attack_animation(direction: Vector2) -> void:
	if direction.length() < 0.001:
		return
	sprite.play(StringName("attack-" + FacingDirection.label_for(direction)))

func take_damage(degat: float) -> void:
	if not multiplayer.is_server():
		super(degat)
		return
	var was_above_half: bool = lifepoint > max_lifepoint * 0.5
	super(degat)
	if not _has_split and was_above_half and lifepoint > 0.0 and lifepoint <= max_lifepoint * 0.5:
		_split()

func _split() -> void:
	_has_split = true
	can_take_damage = false
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game != null:
		game.request_enemy_split(split_scene_path, global_position, split_count, split_spawn_radius, origin_room)
	AudioManager.play_sfx_at("enemy_attack_melee", global_position)
	_vanish()

func _vanish() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2)
	await tween.finished
	if is_instance_valid(self):
		queue_free()

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
